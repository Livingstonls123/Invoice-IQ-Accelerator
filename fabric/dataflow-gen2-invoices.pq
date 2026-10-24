// =====================================================================================
// Dataflow Gen2 query: invoices
// Reads table 'InvoiceOutput' from the agent's Excel workbook and shapes every row.
// Fabric workspace → New item → Dataflow Gen2 → Get data → Blank query → paste → OK.
// Data destination: Lakehouse 'lh_invoiceiq' → table 'invoices' → Update method: Replace.
//
// The agent writes values as text and may write "NA", "USD 549.00", "28-11-2025" or
// "3-Sep-26" depending on the document, so every column is parsed defensively here.
// =====================================================================================
let
    // ---- 1. Where the workbook lives -------------------------------------------------
    // SharePoint site:   "https://<tenant>.sharepoint.com/sites/<FinanceSite>"
    // Personal OneDrive: "https://<tenant>-my.sharepoint.com/personal/<user>_<domain>_com"
    SiteUrl  = "https://<tenant>-my.sharepoint.com/personal/<user>_<domain>_com",
    FileName = "AutomatedInvoiceProcessingAgentOutput.xlsx",

    Files    = SharePoint.Files(SiteUrl, [ApiVersion = 15]),
    File     = Table.SelectRows(Files, each [Name] = FileName){0}[Content],
    Workbook = Excel.Workbook(File, true, true),
    Source   = Workbook{[Item = "InvoiceOutput", Kind = "Table"]}[Data],

    // ---- 2. Helpers ------------------------------------------------------------------
    Clean = (v as any) as nullable text =>
        let t = if v = null then null else Text.Trim(Text.From(v, "en-US"))
        in  if t = null or t = "" or List.Contains({"NA", "N/A", "NULL", "-", "NONE"}, Text.Upper(t)) then null else t,

    ToNumber = (v as any) as nullable number =>
        if v is number then v
        else
            let t = Clean(v),
                digits = if t = null then null else Text.Select(t, {"0".."9", ".", "-"})
            in  if digits = null or digits = "" or digits = "." then null
                else try Number.FromText(digits, "en-US") otherwise null,

    ToDate = (v as any) as nullable date =>
        if v is date then v
        else if v is datetime then Date.From(v)
        else if v is number then Date.From(v)                       // Excel serial date
        else
            let t = Clean(v),
                formats = {"yyyy-MM-dd", "dd-MM-yyyy", "dd/MM/yyyy", "d-MMM-yy", "d-MMM-yyyy",
                           "dd-MMM-yyyy", "MMM d, yyyy", "d MMM yyyy", "MMMM d, yyyy", "dd.MM.yyyy"},
                hits = if t = null then {}
                       else List.RemoveNulls(List.Transform(formats,
                            (f) => try Date.FromText(t, [Format = f, Culture = "en-US"]) otherwise null))
            in  if t = null then null
                else if List.IsEmpty(hits) then (try Date.FromText(t, [Culture = "en-IN"]) otherwise null)
                else hits{0},

    CurrencyFromText = (v as any) as nullable text =>
        let t = Clean(v),
            letters = if t = null then null else Text.Select(Text.Upper(t), {"A".."Z"})
        in  if letters <> null and Text.Length(letters) = 3 then letters else null,

    // ---- 3. Shape ----------------------------------------------------------------------
    Indexed   = Table.AddIndexColumn(Source, "RowOrder", 1, 1, Int64.Type),

    WithCurrency = Table.AddColumn(Indexed, "CurrencyCode",
        each let c = Clean([Currency])
             in  if c <> null then Text.Upper(c)
                 else (CurrencyFromText([InvoiceTotal]) ?? CurrencyFromText([TotalTax])),
        type nullable text),

    Typed = Table.TransformColumns(WithCurrency, {
        {"VendorName",      each Clean(_),    type nullable text},
        {"InvoiceNumber",   each Clean(_),    type nullable text},
        {"CustomerName",    each Clean(_),    type nullable text},
        {"InvoiceDate",     each ToDate(_),   type nullable date},
        {"TotalTax",        each ToNumber(_), type nullable number},
        {"InvoiceTotal",    each ToNumber(_), type nullable number},
        {"ConfidenceScore", each ToNumber(_), type nullable number},
        {"DocumentURL",     each Clean(_),    type nullable text}
    }),
    Currency  = Table.RenameColumns(Table.RemoveColumns(Typed, {"Currency"}), {{"CurrencyCode", "Currency"}}),

    NonEmpty  = Table.SelectRows(Currency, each [VendorName] <> null or [InvoiceNumber] <> null or [InvoiceTotal] <> null),

    // Same vendor + invoice number processed twice (file re-uploaded) → keep the latest row
    WithKey   = Table.AddColumn(NonEmpty, "InvoiceKey",
        each if [InvoiceNumber] = null then "ROW-" & Text.From([RowOrder])
             else Text.Upper(Text.Trim([VendorName] ?? "")) & "|" & Text.Upper(Text.Trim([InvoiceNumber])),
        type text),
    Latest    = Table.Distinct(Table.Buffer(Table.Sort(WithKey, {{"RowOrder", Order.Descending}})), {"InvoiceKey"}),

    // ---- 4. Report-friendly columns ------------------------------------------------------
    AddFile   = Table.AddColumn(Latest, "FileName",
        each if [DocumentURL] = null then null
             else Text.Replace(Text.AfterDelimiter([DocumentURL], "/", {0, RelativePosition.FromEnd}), "%20", " "),
        type nullable text),
    AddMonth  = Table.AddColumn(AddFile, "InvoiceMonth",
        each if [InvoiceDate] = null then null else Date.StartOfMonth([InvoiceDate]), type nullable date),
    AddMissing = Table.AddColumn(AddMonth, "MissingFieldCount",
        each List.Count(List.Select({[VendorName], [InvoiceNumber], [InvoiceDate], [CustomerName],
                                     [TotalTax], [InvoiceTotal], [Currency]}, (x) => x = null)),
        Int64.Type),
    AddBand   = Table.AddColumn(AddMissing, "ConfidenceBand",
        each if [ConfidenceScore] = null then "Unknown"
             else if [ConfidenceScore] >= 0.9 then "High"
             else if [ConfidenceScore] >= 0.7 then "Medium" else "Low",
        type text),
    AddQuality = Table.AddColumn(AddBand, "DataQuality",
        each if [MissingFieldCount] = 0 and ([ConfidenceScore] ?? 0) >= 0.8 then "Complete" else "Check",
        type text),
    AddLoaded = Table.AddColumn(AddQuality, "LoadedAtUtc",
        each DateTimeZone.RemoveZone(DateTimeZone.UtcNow()), type datetime),

    Final = Table.SelectColumns(AddLoaded, {
        "InvoiceKey", "VendorName", "InvoiceNumber", "InvoiceDate", "InvoiceMonth", "CustomerName",
        "TotalTax", "InvoiceTotal", "Currency", "ConfidenceScore", "ConfidenceBand",
        "MissingFieldCount", "DataQuality", "FileName", "DocumentURL", "LoadedAtUtc"})
in
    Final

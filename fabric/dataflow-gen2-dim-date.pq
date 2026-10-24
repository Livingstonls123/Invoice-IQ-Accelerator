// =====================================================================================
// Dataflow Gen2 query: dim_date  (second query in the same dataflow)
// Destination: Lakehouse 'lh_invoiceiq' → table 'dim_date' → Replace.
// Direct Lake semantic models can't use DAX calculated tables, so the calendar is built here.
// Fiscal year follows the Indian FY (April–March); change FiscalStartMonth for other calendars.
// =====================================================================================
let
    StartDate        = #date(2024, 4, 1),
    EndDate          = Date.EndOfYear(Date.AddYears(DateTime.Date(DateTime.LocalNow()), 1)),
    FiscalStartMonth = 4,

    Dates = List.Dates(StartDate, Duration.Days(EndDate - StartDate) + 1, #duration(1, 0, 0, 0)),
    T0 = Table.FromList(Dates, Splitter.SplitByNothing(), type table [Date = date]),
    T1 = Table.AddColumn(T0, "Year",        each Date.Year([Date]), Int64.Type),
    T2 = Table.AddColumn(T1, "MonthNo",     each Date.Month([Date]), Int64.Type),
    T3 = Table.AddColumn(T2, "Month",       each Date.ToText([Date], [Format = "MMM yyyy", Culture = "en-US"]), type text),
    T4 = Table.AddColumn(T3, "MonthStart",  each Date.StartOfMonth([Date]), type date),
    T5 = Table.AddColumn(T4, "FiscalYearStart",
            each if Date.Month([Date]) >= FiscalStartMonth then Date.Year([Date]) else Date.Year([Date]) - 1, Int64.Type),
    T6 = Table.AddColumn(T5, "FiscalYear",
            each "FY" & Text.From([FiscalYearStart]) & "-" & Text.End(Text.From([FiscalYearStart] + 1), 2), type text),
    T7 = Table.AddColumn(T6, "FiscalQuarter",
            each "Q" & Text.From(Number.IntegerDivide(Number.Mod(Date.Month([Date]) - FiscalStartMonth + 12, 12), 3) + 1), type text),
    T8 = Table.AddColumn(T7, "Weekday",     each Date.ToText([Date], [Format = "ddd", Culture = "en-US"]), type text)
in
    T8

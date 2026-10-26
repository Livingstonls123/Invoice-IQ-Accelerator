# Microsoft Fabric — Excel → Dataflow Gen2 → Lakehouse → Semantic model → Power BI

```
AutomatedInvoiceProcessingAgentOutput.xlsx  (table InvoiceOutput, written by the agent)
        │  Dataflow Gen2  df_invoiceiq        ← fabric/dataflow-gen2-invoices.pq, dataflow-gen2-dim-date.pq
        ▼
Lakehouse  lh_invoiceiq   tables: invoices, dim_date
        │  Direct Lake
        ▼
Semantic model  sm_invoiceiq                 ← fabric/semantic-model-measures.dax
        │
        ▼
Power BI report  Invoice Insights (Overview) ← fabric/powerbi-copilot-prompt.md
```

**Prerequisites:** a Fabric capacity (F2 is enough for a pilot, or a Fabric trial) and a workspace, e.g. `InvoiceIQ`, assigned to it. Your account needs read access to the Excel file.

---

## Step 1 — Create the Lakehouse
Workspace → **+ New item → Lakehouse** → name `lh_invoiceiq` → Create. (Leave *Lakehouse schemas* off for the simplest setup.)

## Step 2 — Dataflow Gen2: read the Excel file
1. Workspace → **+ New item → Dataflow Gen2** → name `df_invoiceiq`.
2. **Get data → Blank query** → paste [`dataflow-gen2-invoices.pq`](dataflow-gen2-invoices.pq) → **Next**.
3. Edit the two lines at the top:
   - `SiteUrl` — where the workbook lives. For the OneDrive used in the reference build it's the personal site: open the file in Excel for the web → *File → Info → Copy path*, and keep everything up to and including `/personal/<user>_<domain>_com`.
     For a SharePoint team site use `https://<tenant>.sharepoint.com/sites/<SiteName>`.
   - `FileName` — `AutomatedInvoiceProcessingAgentOutput.xlsx` (or your file name).
4. **Configure connection** → *Organizational account* → sign in.
5. Rename the query to **`invoices`**. Check the preview: amounts are numbers, dates are dates, `NA` became empty, duplicates collapsed.
6. **Get data → Blank query** again → paste [`dataflow-gen2-dim-date.pq`](dataflow-gen2-dim-date.pq) → rename to **`dim_date`**.

> What the dataflow cleans up: `NA` → null · `"USD 549.00"` → `549.00` and `USD` · dates in `yyyy-MM-dd`, `dd-MM-yyyy`, `3-Sep-26`, `Oct 12, 2026`… → date · re-processed invoices (same vendor + number) → latest row only · empty template row removed. It also adds `InvoiceMonth`, `FileName`, `MissingFieldCount`, `ConfidenceBand`, `DataQuality`, `LoadedAtUtc`.

## Step 3 — Save to the Lakehouse
For **each** query (`invoices`, then `dim_date`):
1. Select the query → bottom-right **Data destination → +** → **Lakehouse**.
2. Choose `lh_invoiceiq` → **New table** → name `invoices` / `dim_date` → Next.
3. **Update method: Replace** → keep *Use automatic settings* → Save settings.

**Save & run** (or **Publish**). Open `lh_invoiceiq` → Tables → `invoices` should show the rows from Excel.

**Schedule:** dataflow **⋯ → Settings → Refresh → Scheduled refresh** — e.g. every 30 minutes, 08:00–20:00 IST. Direct Lake models read the new data automatically after each refresh.

## Step 4 — Semantic model
1. Open `lh_invoiceiq` → ribbon **New semantic model** → name `sm_invoiceiq` → tick `invoices` and `dim_date` → Confirm. (This is a **Direct Lake** model.)
2. **Open data model** (web modelling):
   - Relationship: drag `dim_date[Date]` onto `invoices[InvoiceDate]` → *Many to one*, single direction, active.
   - Select `dim_date` → **Mark as date table** → column `Date`.
   - `dim_date[Month]` → *Sort by column* → `MonthStart`.
   - Hide `InvoiceKey`, `DocumentURL`, `LoadedAtUtc`, `invoices[InvoiceDate]` (use `dim_date` for dates).
   - `invoices[DocumentURL]` → *Data category* = **Web URL** (lets the report link to the source file for users who have storage access).
3. Add the measures from [`semantic-model-measures.dax`](semantic-model-measures.dax) — select `invoices` → **New measure** → paste one measure at a time.
4. Formats: amount measures `#,##0.00`; `%` measures *Percentage*, 1 decimal; `Average Confidence` *Percentage*.

## Step 5 — Power BI report
From the semantic model → **Create report → Start from scratch**, open the **Copilot** pane and run the Overview prompt in [`powerbi-copilot-prompt.md`](powerbi-copilot-prompt.md). Save as **Invoice Insights** in the same workspace.

## Step 6 — Share
Workspace → **Create app** → include the report → audience *Finance & Ops* group. (Consumers need Power BI Pro/PPU unless the capacity is F64 or larger.)

---

## Troubleshooting
| Symptom | Cause | Fix |
|---|---|---|
| Visuals and fields are named `Column1`, `Column3`, `Column8` … | The dataflow read the **sheet** instead of the **table**, or headers weren't promoted, so the Lakehouse table has generic column names | Use [`dataflow-gen2-invoices.pq`](dataflow-gen2-invoices.pq) as-is: it reads `Item = "InvoiceOutput", Kind = "Table"` with headers. If you built the query with *Get data → Excel*, pick the **InvoiceOutput** table (not *Invoice Output* sheet) and **Use first row as headers**. Re-run the dataflow, then **refresh** the semantic model schema |
| "Total Invoice Value" shows a small decimal such as `8.47` | The card sums `ConfidenceScore` (a generic column picked by Copilot) instead of `InvoiceTotal` | Fix the column names first (row above), then use the `Total Invoice Value` **measure**, not an implicit sum |
| Amount cards are blank | More than one currency in the filter context | By design — select one currency in the slicer |
| Amounts look like text (`USD 5,875.00`) or `NA` appears in totals | Rows written by an older agent version, or a dataflow without the type steps | The query's `ToNumber`/`Clean` helpers convert these; make sure the destination column types are **Decimal number** / **Date** |
| New invoices don't appear | Dataflow hasn't refreshed since the agent wrote the row | Run the dataflow or shorten the scheduled refresh interval |
| Same invoice twice | File re-uploaded with a different vendor spelling or invoice number | De-duplication is by vendor + invoice number; correct the source row in Excel |

### Scaling notes
- Excel is fine for a pilot (hundreds to a few thousand rows). Beyond that, change Flow 2 to write to **Dataverse** or a **SharePoint list** and point this dataflow at it — the Lakehouse table, model and report stay the same.
- For incremental loads, switch the `invoices` destination to **Append** and filter the source on `LoadedAtUtc`/a processed flag, or move to a Fabric notebook.

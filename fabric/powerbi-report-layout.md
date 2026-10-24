# Power BI report — "Invoice Insights"

Built on `sm_invoiceiq`. Canvas 16:9. One accent colour; amber only for items that need checking.

**On every page:** a single-select **Currency** slicer (default `INR`), a **FiscalYear** slicer, and a small text card showing `Last Refresh (UTC)`.

## Page 1 — Overview
| Area | Visual | Fields |
|---|---|---|
| Top row | 5 cards | `Total Invoice Value` · `Invoice Count` · `Vendor Count` · `Average Invoice Value` · `Total Tax` |
| Middle left | Line and clustered column | X `dim_date[Month]` · Column `Total Invoice Value` · Line `Invoice Count` |
| Middle right | Bar chart, Top 10 | Y `VendorName` · X `Total Invoice Value` (visual filter: Top N = 10 by `Total Invoice Value`) |
| Bottom left | Donut | Legend `Currency` · Values `Invoice Count` (shows the currency mix; ignore the currency slicer via *Edit interactions*) |
| Bottom right | Table | `InvoiceDate`, `VendorName`, `InvoiceNumber`, `CustomerName`, `InvoiceTotal`, `Currency` — sorted by date desc |

## Page 2 — Vendors
- Matrix: rows `VendorName` · values `Invoice Count`, `Total Invoice Value`, `Average Invoice Value`, `Largest Invoice`, `Vendor Rank`.
- Card: `Top Vendor Share %` (subtitle: "Share of spend with the largest vendor").
- Treemap: `VendorName` by `Total Invoice Value`.
- Line: `Total Invoice Value` by `dim_date[Month]`, small multiples by `VendorName` (top 6).

## Page 3 — Customers & tax
- Bar: `CustomerName` by `Total Invoice Value`.
- Clustered column: `dim_date[Month]` · `Net Value (excl. Tax)` and `Total Tax`.
- Card: `Tax % of Invoice Value`.

## Page 4 — Extraction quality
- Cards: `Average Confidence` · `Complete Extraction %` · `Invoices Needing Check` · `Low Confidence Invoices`.
- Stacked bar: `ConfidenceBand` by `Invoice Count`.
- Table (conditional formatting on `ConfidenceScore` and `MissingFieldCount`): `FileName`, `VendorName`, `InvoiceNumber`, `InvoiceTotal`, `ConfidenceScore`, `MissingFieldCount`, `DataQuality`, `DocumentURL` (Web URL → shows a link icon). Page filter `DataQuality = Check`.

## Page 5 — Vendor detail (drill-through)
- Drill-through field: `VendorName` (right-click a vendor anywhere → *Drill through*).
- Cards: `Total Invoice Value`, `Invoice Count`, `Average Invoice Value`, `Invoice Value MoM %`.
- Line: `Total Invoice Value` by month. Table: every invoice for that vendor.

## Dashboard (optional)
Pin the five Overview cards and the monthly trend to a dashboard `Invoice Insights – Live`; add a **data alert** on `Invoices Needing Check`.

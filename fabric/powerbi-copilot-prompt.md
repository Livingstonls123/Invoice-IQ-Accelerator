# Power BI report — Overview page with Copilot

Build the **Overview** page of the *Invoice Insights* report with Copilot in Power BI.

## Before you start
- The semantic model `sm_invoiceiq` exists, with the relationship `dim_date[Date]` → `invoices[InvoiceDate]` and the measures from [`semantic-model-measures.dax`](semantic-model-measures.dax). The prompt refers to them by name.
- Copilot is enabled by your Fabric admin and the workspace is on a Fabric capacity.

## Steps
1. Open `sm_invoiceiq` → **Create report → Start from scratch**.
2. Open the **Copilot** pane → **Create a page** (or type in the chat box).
3. Paste the prompt below and run it.
4. Save the report as **Invoice Insights** in the same workspace.

## Prompt
```
Create a report page called "Overview" for invoice spend analysis using the invoices and dim_date tables.
Top row: five KPI cards for Total Invoice Value, Invoice Count, Vendor Count, Average Invoice Value and Total Tax.
Middle left: a line and clustered column chart with dim_date[Month] on the x-axis, Total Invoice Value as columns and Invoice Count as a line.
Middle right: a horizontal bar chart of the top 10 VendorName by Total Invoice Value.
Bottom left: a donut chart of Invoice Count by Currency.
Bottom right: a table of InvoiceDate, VendorName, InvoiceNumber, CustomerName, InvoiceTotal and Currency, sorted by InvoiceDate newest first.
Add single-select slicers for Currency and dim_date[FiscalYear] at the top, and a card showing Last Refresh (UTC).
```

## Check after Copilot builds the page
- **Top 10 vendors** — if the bar chart shows every vendor, add a *Top N* filter on `VendorName` = 10 by `Total Invoice Value`.
- **Currency donut** — Format → **Edit interactions** → set the Currency slicer to *None* on the donut so it always shows the full currency mix.
- **Month order** — if months sort alphabetically, set `dim_date[Month]` → *Sort by column* → `MonthStart` in the model.
- **Blank amount cards** — expected when more than one currency is selected; amount measures only total one currency at a time. Set the Currency slicer default (e.g. `INR`).

## Share
Workspace → **Create app** → include *Invoice Insights* → audience *Finance & Ops*.

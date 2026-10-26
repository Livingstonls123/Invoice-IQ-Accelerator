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

## Demo prompt — Invoice Processing Overview
The prompt used in the reference demo. It focuses on extraction quality as well as spend, which suits a live demo better than the Overview above. Run it on a second page (or a separate report) called **Invoice Processing Overview**.
```
Create a report page called "Invoice Processing Overview" using the invoices and dim_date tables.
Top row: KPI cards for Total Invoice Value, Total Tax, Invoice Count, Average Invoice Value, and Average Confidence formatted as a percentage.
Middle row: a clustered bar chart of Total Invoice Value by VendorName, sorted descending, and a clustered bar chart of Total Invoice Value by CustomerName, sorted descending.
Bottom row: a table of VendorName, InvoiceNumber, InvoiceDate, InvoiceTotal, Currency and ConfidenceScore, with conditional formatting that highlights ConfidenceScore below 0.92 in red, and a card for Invoices Below Review Threshold.
Add slicers for Currency, VendorName and dim_date[Date]. Default the Currency slicer to INR so amounts in different currencies are not mixed. Use a clean, consistent colour theme.
```
After Copilot builds it:
- If the red highlight is missing: select the table → *ConfidenceScore* → **Conditional formatting → Font colour → Format style: Field value → `Confidence Colour`**.
- Set the Currency slicer to **single select** and pick `INR`.

## Check after Copilot builds the page
- **Top 10 vendors** — if the bar chart shows every vendor, add a *Top N* filter on `VendorName` = 10 by `Total Invoice Value`.
- **Currency donut** — Format → **Edit interactions** → set the Currency slicer to *None* on the donut so it always shows the full currency mix.
- **Month order** — if months sort alphabetically, set `dim_date[Month]` → *Sort by column* → `MonthStart` in the model.
- **Blank amount cards** — expected when more than one currency is selected; amount measures only total one currency at a time. Set the Currency slicer default (e.g. `INR`).

## Share
Workspace → **Create app** → include *Invoice Insights* → audience *Finance & Ops*.

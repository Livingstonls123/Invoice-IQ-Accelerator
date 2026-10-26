# InvoiceIQ — Demo script (≈ 4 minutes)

A presenter runbook that follows the reference recording. Use it after the [deployment guide](deployment-guide.md) is complete.

## Before the demo
- [ ] Agent **published**; one test invoice processed in the last hour (warms up the MCP app; first call can take ~20 s).
- [ ] Browser tabs open, in this order:
  1. Copilot Studio → *Automated Invoice Processing Agent* → **Overview**
  2. Azure portal → Storage account → Containers → `automated-invoice-processing-agent`
  3. Copilot Studio → **Activity**
  4. Excel for the web → `AutomatedInvoiceProcessingAgentOutput.xlsx` → sheet **Invoice Output**
  5. Fabric workspace (Dataflow, Lakehouse `lh_invoiceiq`, semantic model `sm_invoiceiq`)
  6. A blank Power BI report on `sm_invoiceiq` with the **Copilot** pane open
- [ ] A sample on your desktop that is **not** already in the container, e.g. `sample-data/04_Graphic_Design_Institute_CHF.pdf` (rename it if you've used it before; re-uploading the same name also triggers a run).
- [ ] Dataflow refreshed after the last test so the Lakehouse already has rows.
- [ ] Copilot prompt copied to the clipboard ([fabric/powerbi-copilot-prompt.md](../fabric/powerbi-copilot-prompt.md) → *Demo prompt*).

## Run of show
| Time | Screen | Do | Say |
|---|---|---|---|
| 0:00 – 0:45 | Tab 1 — Agent overview | Scroll through Details, Model, Instructions | "Finance and operations teams process large volumes of invoices. Each one is opened and keyed in by hand — vendor, invoice number, tax, currency, total. That's slow, error-prone, and gets worse as volumes grow. This agent removes that step." |
| 0:45 – 1:10 | Tab 2 — Blob container | **Upload** → pick the sample → Upload | "Invoices land in Azure Blob Storage — from a person, a scanner or another system. The upload is the only manual step." |
| 1:10 – 1:30 | Tab 1 — Tools & Triggers | Point at the trigger, *Invoice Extraction MCP*, *Save Automated Invoice Output* | "The upload fires this trigger. The agent calls the Invoice Extraction MCP tool, which uses Azure AI Document Intelligence, then hands the fields to a Power Automate flow that writes them to Excel." |
| 1:30 – 1:45 | Tab 3 — Activity | Refresh → open the newest run → click `extract_invoice` | "Here's the run: trigger, extraction in about nine seconds, save in about five. *Invoice processed successfully.* No one touched it." |
| 1:45 – 2:00 | Tab 4 — Excel | Show the new row; point at Currency, ConfidenceScore, DocumentURL | "Vendor, invoice number, date, customer, tax, total, currency, a confidence score, and a link back to the source file." |
| 2:00 – 2:40 | Tab 5 — Fabric | Dataflow → Lakehouse table → semantic model | "Excel isn't the end. A Fabric Dataflow Gen2 cleans and types the data into a Lakehouse table, and a semantic model sits on top for reporting." |
| 2:40 – 3:40 | Tab 6 — Power BI | Paste the prompt in Copilot → run → wait for the page | "Instead of building visuals by hand, I ask Copilot for the dashboard: KPIs, spend by vendor and customer, and anything below 92 % confidence highlighted for review." |
| 3:40 – 4:00 | Generated page | Change the Currency slicer; point at the low-confidence highlight | "Finance now monitors a dashboard instead of scrolling a spreadsheet. A manual, time-consuming process becomes fast, simple and auditable." |

## If something goes wrong
| Symptom | Recovery |
|---|---|
| No run in Activity after ~1 minute | The trigger polls every minute; refresh. Check the agent is **published** and the file extension is PDF/JPG/PNG/TIFF (trigger condition). Show a previous successful run instead. |
| Run shows `Error` from `extract_invoice` | Usually a cold start or an expired SAS. Re-upload the file; meanwhile show an earlier run. |
| Power BI cards blank | More than one currency is selected — pick one in the Currency slicer. |
| Visuals show `Column1`, `Column8` | The semantic model isn't on the cleaned `invoices` table. See [Fabric troubleshooting](../fabric/README.md#troubleshooting); use a pre-built report for the demo. |
| Copilot is slow or unavailable | Open the saved *Invoice Insights* report instead. |

## Likely questions
**Why Power Automate as well as the agent?** It runs the Blob trigger and writes to Excel. The model decides *what* the data is; the flow puts it *where it belongs* — consistently, with a stored connection, retries and run history. The same flow can later write to Dataverse, SQL or ERP, or route low-confidence invoices for approval, without changing the agent.

**Why MCP instead of a connector?** Copilot Studio discovers MCP tools and their descriptions automatically, and the same server can serve Microsoft 365 Copilot, Azure AI Foundry agents or developer tools.

**How accurate is it?** Every row carries Document Intelligence's confidence score. The report flags anything under the threshold (0.92 in the demo) for a human check. For vendors with poor accuracy, train a custom or composed model and set `DOCINTEL_MODEL`.

**Is the data secure?** The MCP server uses managed identity for Document Intelligence and Storage, the API key lives in Key Vault, SAS links are read-only for 2 hours and are never saved to Excel. See [hardening.md](hardening.md) for private endpoints, OAuth and keyless storage.

**Does it scale?** Excel is fine for a pilot. At higher volumes, point the save flow at Dataverse, a SharePoint list or a Fabric Lakehouse; the report and model stay the same.

**What about line items and GST validation?** Not in the base accelerator. Document Intelligence returns line items and tax details; add them as extra MCP output columns or Power BI exception measures (see [hardening.md → Quality](hardening.md#quality)).

## Reset after the demo
Delete the demo row from Excel (or leave it — re-processed invoices are de-duplicated by vendor + invoice number in the Dataflow) and delete the uploaded blob if you want to reuse the same sample name.

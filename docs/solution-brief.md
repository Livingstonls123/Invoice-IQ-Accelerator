# InvoiceIQ — Solution brief

*For customer conversations and proposals. The technical build is in the [deployment guide](deployment-guide.md); a Word version of this overview, with screenshots, is in [InvoiceIQ_Solution_Demo_Overview.docx](InvoiceIQ_Solution_Demo_Overview.docx).*

## Executive summary
InvoiceIQ is an autonomous invoice processing agent built in **Microsoft Copilot Studio**. When an invoice is uploaded to **Azure Blob Storage**, the agent starts by itself. It extracts the key fields with **Azure AI Document Intelligence** (exposed to the agent as an MCP tool) and writes the result to an **Excel** table through a **Power Automate** agent flow.

**Microsoft Fabric** then picks the data up. A Dataflow Gen2 loads it into a Lakehouse, a semantic model sits on top, and a **Power BI** report is built with Copilot. A manual, error-prone data-entry task becomes a hands-off pipeline that ends in a live finance dashboard.

## The business problem
Finance and operations teams receive invoices in many formats, from many vendors and in several currencies. Each invoice is opened and keyed in by hand: vendor details, invoice number and date, line items, tax, currency and total. As volumes grow, this:
- takes up skilled staff time,
- introduces data-entry errors, and
- delays approvals, payments and month-end close.

## The solution
| # | Step | What happens | Service |
|---|---|---|---|
| 1 | **Upload** | A user, scanner or upstream system drops the invoice into a storage container | Azure Blob Storage |
| 2 | **Trigger** | *When a blob is added or modified (properties only) (V2)* wakes the agent with a short-lived, read-only link to the file | Copilot Studio trigger (Power Automate) |
| 3 | **Extract** | The agent calls `extract_invoice` on the Invoice Extraction MCP server | Azure AI Document Intelligence `prebuilt-invoice` |
| 4 | **Save** | The agent calls *Save Automated Invoice Output*, which adds a row to the Excel table | Power Automate agent flow → Excel Online |
| 5 | **Ingest** | Dataflow Gen2 cleans, types and de-duplicates the rows into a Lakehouse table | Microsoft Fabric |
| 6 | **Report** | A Direct Lake semantic model feeds a Power BI report created with Copilot | Power BI |

In the reference demo, one invoice goes from upload to Excel in **about 14 seconds** (extraction ≈ 9 s, save ≈ 5 s) with no human involvement.

### What is captured
`VendorName` · `InvoiceNumber` · `InvoiceDate` · `CustomerName` · `TotalTax` · `InvoiceTotal` · `Currency` · `ConfidenceScore` · `DocumentURL`

The same nine fields are the MCP tool output, the agent-flow inputs and the Excel columns (single contract in [`models.py`](../src/mcp-server/invoiceiq/models.py)).

### Why each piece is there
| Component | Role | Why it matters |
|---|---|---|
| **Copilot Studio agent** | Decides what to do with each new document | Autonomous: no one has to chat to it; rules live in plain-English [instructions](../copilot-studio/agent-instructions.md) |
| **Invoice Extraction MCP** | Wraps Document Intelligence as one tool | Reusable by Microsoft 365 Copilot, Azure AI Foundry agents or VS Code; secured with managed identity and an API key held in Key Vault |
| **Power Automate** | Runs the Blob trigger and writes to Excel | The model decides *what* the data is; the flow decides *where it goes*, the same way every time, with retries and run history. Swap Excel for Dataverse, SQL or a Lakehouse later without touching the agent |
| **Microsoft Fabric** | Turns rows into a governed dataset | One place to fix types, currencies and duplicates for every report |
| **Power BI + Copilot** | Dashboard for Finance | Monitor spend, vendors and extraction quality instead of scrolling through spreadsheets |

## Business benefits
- **Speed** — invoices processed end-to-end in seconds, around the clock.
- **Accuracy** — AI extraction with a confidence score replaces manual keying; low-confidence invoices are flagged for review.
- **Coverage** — handles invoices, bills, purchase orders, sales orders and utility bills across layouts, industries and currencies (INR, USD, GBP, CHF and more).
- **Traceability** — every row links back to its source document (the link carries no access token).
- **Visibility** — spend, vendor concentration and data quality on one dashboard.
- **Platform fit** — low-code Microsoft stack the customer already licenses; extensible without rework.

## Built-in safeguards
The reference demo surfaced several issues; this accelerator fixes them by default.

| Issue seen in the demo | How the accelerator handles it |
|---|---|
| Report visuals showed `Column1`, `Column8` and a "Total Invoice Value" that was really a sum of confidence scores | The Dataflow reads the named Excel table with headers and types every column; a [troubleshooting](../fabric/README.md#troubleshooting) section covers the symptom |
| Amounts stored as text with a currency prefix (`USD 5,875.00`) | MCP returns numbers and a separate ISO currency code; the Dataflow also parses legacy text values |
| `NA` written into number and date columns | `NA` is kept for readability in Excel and becomes `null` in Fabric |
| Full SAS tokens stored in Excel | Token stripped before saving; SAS links are read-only and expire after 2 hours |
| Storage used access-key authentication | Keyless option documented ([hardening](hardening.md)); MCP server already uses managed identity |
| Web Search enabled on the agent; agent warnings | Web Search off, no knowledge sources; warnings explained in the [Copilot Studio guide](../copilot-studio/README.md#resolve-agent-status-warnings) |
| Mixed currencies summed together | Amount measures only return a value for one currency at a time |

## Typical engagement
| Phase | Duration | Outcome |
|---|---|---|
| Discovery | 1 week | Invoice volumes, formats, target system of record, success metrics |
| Pilot | 2–3 weeks | This accelerator deployed in the customer tenant with their sample invoices |
| Production | 3–6 weeks | Hardening checklist, custom Document Intelligence models for top vendors, ERP/Dataverse integration, ALM |

## Prerequisites
- Azure subscription (Document Intelligence S0, App Service, Storage, Key Vault)
- Power Platform environment with Copilot Studio capacity
- Microsoft 365 (OneDrive / SharePoint, Excel Online)
- Fabric capacity (F2 or trial) with Copilot enabled for the Power BI step

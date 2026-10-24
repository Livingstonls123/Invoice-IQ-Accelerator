# InvoiceIQ — Automated Invoice Processing Agent · Solution Accelerator

Drop an invoice into Azure Blob Storage and an **autonomous Copilot Studio agent** extracts it with **Azure AI Document Intelligence** (through a custom **MCP server** on Azure App Service) and saves it as a row in **Excel**. **Microsoft Fabric** then loads the Excel data through **Dataflow Gen2** into a **Lakehouse**, models it in a **semantic model**, and shows it in a **Power BI** report.

![Solution overview](docs/images/solution-overview.png)

## The flow

| # | Step | Service | In this repo |
|---|---|---|---|
| 1 | Invoice is uploaded | Azure Blob Storage — container `automated-invoice-processing-agent` | `infra/modules/storage.bicep`, `scripts/upload_sample.sh` |
| 2 | Agent wakes up | Copilot Studio trigger *When a blob is added or modified (properties only) (V2)* + SAS URL | `power-automate/README.md` (Flow 1) |
| 3 | AI reads it | **Invoice Extraction MCP** → `extract_invoice` → Document Intelligence `prebuilt-invoice` | `src/mcp-server/`, `infra/` |
| 4 | Saved to Excel | Agent flow **Save Automated Invoice Output** → table `InvoiceOutput` | `power-automate/README.md` (Flow 2), `excel/` |
| 5 | Load & shape | Fabric **Dataflow Gen2** | `fabric/dataflow-gen2-*.pq` |
| 6 | Store | Fabric **Lakehouse** (`invoices`, `dim_date`) | `fabric/README.md` |
| 7 | Model | **Semantic model** (Direct Lake) + DAX measures | `fabric/semantic-model-measures.dax` |
| 8 | Report | **Power BI** report *Invoice Insights* | `fabric/powerbi-report-layout.md` |

## Quick start
```bash
azd auth login
azd env new invoiceiq-dev
azd env set AZURE_LOCATION centralindia
azd env set MCP_API_KEY $(openssl rand -hex 32)
azd up
```
Then follow **[docs/deployment-guide.md](docs/deployment-guide.md)** — six phases, each ending with a check.

## Repository layout
```
├── azure.yaml                       azd: provision infra + deploy the MCP server
├── infra/                           Bicep (subscription scope)
│   ├── main.bicep, main.parameters.json
│   └── modules/  storage · docintel · appservice · keyvault · monitoring · rbac
├── src/mcp-server/                  Invoice Extraction MCP (Python, Streamable HTTP at /mcp)
│   ├── invoiceiq/  server.py · extractor.py · models.py · config.py
│   └── tests/
├── copilot-studio/                  agent instructions, setup guide, optional MCP custom connector
├── power-automate/                  Flow 1 (blob trigger + SAS) and Flow 2 (save to Excel)
├── excel/                           AutomatedInvoiceProcessingAgentOutput.xlsx (table InvoiceOutput)
├── fabric/                          Dataflow Gen2 M queries, DAX measures, report layout
├── sample-data/                     3 test invoices (INR, USD, GBP)
├── scripts/                         deploy.sh · upload_sample.sh · test_mcp.py · build_assets.py
├── docs/                            deployment guide, architecture, CI/CD setup, hardening, screenshots
└── .github/workflows/               ci.yml (tests + Bicep lint) · deploy.yml (OIDC)
```

## Excel output (what the agent writes)
| VendorName | InvoiceNumber | InvoiceDate | CustomerName | TotalTax | InvoiceTotal | Currency | ConfidenceScore | DocumentURL |
|---|---|---|---|---|---|---|---|---|
| Contoso Supplies Pvt Ltd | CS-2026-1042 | 2026-10-05 | Fabrikam Industries Ltd | 3690 | 24190 | INR | 0.98 | https://…/automated-invoice-processing-agent/01_Contoso….pdf |

Missing values are written as `NA`. The SAS token is removed from `DocumentURL`.

## Security defaults
Managed identity from the MCP app to Document Intelligence, Storage and Key Vault · Document Intelligence key auth disabled · MCP API key only in Key Vault · read-only 2-hour SAS per invoice, never stored · HTTPS/TLS 1.2. The storage account allows access keys by default because the reference build's Blob connector uses them; [docs/hardening.md](docs/hardening.md) shows the keyless setup and the rest of the production checklist.

## Docs
- [Step-by-step deployment guide](docs/deployment-guide.md)
- [Architecture & data contract](docs/architecture.md)
- [GitHub Actions setup](docs/github-actions-setup.md)
- [Production hardening](docs/hardening.md)

## License
MIT

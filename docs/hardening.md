# Production hardening checklist

The accelerator is safe for a pilot: Document Intelligence and Key Vault are Entra-ID only, the MCP endpoint needs an API key kept in Key Vault, SAS URLs are short-lived and read-only and never written to Excel, everything is HTTPS/TLS 1.2. For production, work through this list.

## Identity & access
- [ ] **Keyless storage.** Switch the Blob trigger connection to Entra ID, set `allowSharedKeyAccess=false`, and pass the plain blob URL (see the note at the end of `power-automate/README.md`). The MCP app already has *Storage Blob Data Reader*.
- [ ] **OAuth on the MCP server** instead of an API key: register an Entra app, enable App Service Authentication (Easy Auth) with it, choose *OAuth 2.0* in the Copilot Studio MCP connection, then clear `MCP_API_KEY`.
- [ ] Rotate `mcp-api-key` on a schedule if you keep API-key auth (Key Vault rotation + update the Copilot Studio connection).
- [ ] Restrict who can upload to the container (RBAC on the container, not the account).

## Network
- [ ] Private endpoints for Storage, Document Intelligence and Key Vault; App Service VNet integration; `publicNetworkAccess: 'Disabled'` on those resources. (With a storage firewall, Document Intelligence can't fetch SAS URLs — use the keyless download path, which runs inside your VNet.)
- [ ] Front the MCP endpoint with **Azure API Management** for rate limiting, Power Platform service-tag IP filtering and request logging.

## Data
- [ ] Lifecycle policy on the invoice container: Cool after 30 days, Archive after 1 year, delete per your retention policy (in India GST and Companies Act rules typically mean 6–8 years — confirm with Finance).
- [ ] Sensitivity labels on the Excel workbook and the Fabric workspace (Microsoft Purview).
- [ ] Power Platform **DLP policy**: Azure Blob Storage, Excel Online (Business), the MCP connector and Copilot Studio in the same *Business* group.
- [ ] Row-level security in the semantic model if different teams should see different vendors / entities.

## Reliability & operations
- [ ] App Service P0v3+ with 2 instances (zone-redundant where available).
- [ ] Alerts: App Insights 5xx and exception rate on the MCP app; Document Intelligence 429 throttling; dataflow refresh failures.
- [ ] Weekly review of Copilot Studio **Activity** for failed runs; re-upload (or touch) the blob to re-process.
- [ ] Dev / test / prod: one Azure environment per stage, Power Platform **solutions** (managed in test/prod), Fabric **deployment pipelines**.

## Quality
- [ ] Track *Complete Extraction %* and *Average Confidence* in the report; review with Finance in the first month.
- [ ] Train a **custom** or **composed** Document Intelligence model for top vendors with poor accuracy, and set `DOCINTEL_MODEL`.
- [ ] Add business rules your Finance team needs (GSTIN format, PO match, vendor allow-list, subtotal + tax = total) as extra MCP output columns or Power BI exception measures.
- [ ] Above a few thousand invoices, move the register from Excel to Dataverse or a SharePoint list (only Flow 2 and the dataflow source change).

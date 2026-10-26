# Power Automate — the two flows behind the agent

Create both in the **same Power Platform environment** as the agent. For dev → test → prod, create them inside a **solution** (`AutomatedInvoiceProcessing`) together with the agent.

| # | Flow | Created from | Role |
|---|---|---|---|
| 1 | Blob trigger flow | Copilot Studio → *Triggers → Add trigger* | Wakes the agent and hands it a SAS URL for the new file |
| 2 | **Save Automated Invoice Output** | Copilot Studio → *Flows / Tools → New agent flow* | Writes one invoice row to Excel |

---

## Flow 1 — Blob trigger: *When a blob is added or modified (properties only) (V2)*

### 1a. Create the trigger in Copilot Studio
1. Agent **Overview → Triggers → + Add trigger** → search *blob* → **When a blob is added or modified (properties only) (V2)** → **Next**.
2. Trigger name: `When a blob is added or modified (properties only) (V2)`.
3. **Connection — Azure Blob Storage**:
   - *Authentication type*: **Access Key** (as in the reference build) — Storage account name = `STORAGE_ACCOUNT_NAME`, key from *Storage account → Security + networking → Access keys*.
   - Or **Microsoft Entra ID Integrated** with an account that has *Storage Blob Data Contributor* (see note at the end — SAS creation then needs a different action).
4. Parameters: *Storage account name* = your account, *Container* = `/automated-invoice-processing-agent`, *Number of blobs to return* = `10`, *How often to check* = `1 minute`.
5. **Create trigger**.

### 1b. Add the SAS URL step (Power Automate)
The default trigger flow only sends blob *properties* to the agent. `extract_invoice` needs a URL that Document Intelligence can read, so add a short-lived SAS URL.

1. On the trigger card click **…  → Edit in Power Automate**.
2. Trigger settings → **Trigger conditions** (process only invoices):
   ```
   @or(endsWith(toLower(triggerBody()?['Name']),'.pdf'),endsWith(toLower(triggerBody()?['Name']),'.jpg'),endsWith(toLower(triggerBody()?['Name']),'.jpeg'),endsWith(toLower(triggerBody()?['Name']),'.png'),endsWith(toLower(triggerBody()?['Name']),'.tif'),endsWith(toLower(triggerBody()?['Name']),'.tiff'))
   ```
   Keep **Split on** enabled (one agent run per file).
3. **+ New step** (between the trigger and *Sends a prompt to the specified copilot for processing*) → **Azure Blob Storage → Create SAS URI by path (V2)**
   - Storage account name: same as trigger
   - Blob path: `Path` (dynamic content from the trigger)
   - Advanced: *Permissions* = **Read**, *Expiry Time* = `@{addHours(utcNow(), 2)}`, *Shared Access Protocol* = **HttpsOnly**
4. In **Sends a prompt to the specified copilot for processing**, set *Body/message* to:
   ```
   A new invoice document was uploaded to Azure Blob Storage.
   File name: @{triggerBody()?['Name']}
   Blob path: @{triggerBody()?['Path']}
   Document URL: @{body('Create_SAS_URI_by_path_(V2)')?['WebUrl']}
   Process this invoice now.
   ```
5. **Save**. Back in Copilot Studio, **Publish** the agent.

> The SAS URL is used only for this run (2-hour, read-only). The MCP server strips the token before the URL is written to Excel, so no live SAS links end up in the workbook.

---

## Flow 2 — Save Automated Invoice Output (agent flow)

### 2a. Put the workbook in place
Upload `excel/AutomatedInvoiceProcessingAgentOutput.xlsx` to **OneDrive for Business** or a **SharePoint** document library (a Finance site is better for a team — the Fabric dataflow reads it from there). It contains sheet **Invoice Output** with table **`InvoiceOutput`**. Don't rename the table or the columns.

### 2b. Build the flow
1. Copilot Studio → agent → **Tools → + Add a tool → New tool → Agent flow** (or **Flows → New agent flow**).
2. Trigger **When an agent calls the flow** → add **nine Text inputs** (Text, so `NA` is always accepted):

   | Input | Description (the orchestrator reads these) |
   |---|---|
   | `VendorName` | Supplier / seller name |
   | `InvoiceNumber` | Invoice number as printed on the document |
   | `InvoiceDate` | Invoice date, yyyy-MM-dd |
   | `CustomerName` | Bill-to customer name |
   | `TotalTax` | Total tax amount |
   | `InvoiceTotal` | Invoice grand total |
   | `Currency` | ISO currency code, e.g. INR, USD |
   | `ConfidenceScore` | Extraction confidence 0–1 |
   | `DocumentURL` | Blob URL of the source document |

3. **+ → Excel Online (Business) → Add a row into a table**
   - Location: *OneDrive for Business* or the SharePoint site · Document Library · File: `AutomatedInvoiceProcessingAgentOutput.xlsx`
   - Table: **InvoiceOutput**
   - Map each column to the input with the same name.
4. **+ → Respond to the agent** → output `Status` (Text) = `Saved`.
5. Name the flow **Save Automated Invoice Output** → **Save** → **Publish**.
6. Flow **Settings**: on the Excel action, *Retry policy* = Exponential, 4 retries. Under the trigger, *Concurrency control* = **On**, degree **1** (Excel tables don't like parallel writes).

### 2c. Optional — notify Finance
After *Add a row*: **Condition** `ConfidenceScore` is less than `0.92` (the review threshold used in the Power BI report — keep the two in step) (or any field equals `NA`) → **Microsoft Teams → Post message in a chat or channel** with the vendor, invoice number and DocumentURL so someone checks it.

---

### Note — Entra ID instead of access keys
The reference build uses an access-key Blob connection because *Create SAS URI by path (V2)* signs with the account key. To go keyless:
- set `allowSharedKeyAccess=false` in `infra/main.parameters.json`,
- use an **Entra ID** Blob connection for the trigger,
- remove the SAS step and set *Document URL* to `https://<account>.blob.core.windows.net@{replace(triggerBody()?['Path'],' ','%20')}` (the trigger's `Path` already starts with `/automated-invoice-processing-agent/`). The MCP server sees a URL on its own storage account **without** a SAS token and downloads the file with its managed identity (it has *Storage Blob Data Reader*).

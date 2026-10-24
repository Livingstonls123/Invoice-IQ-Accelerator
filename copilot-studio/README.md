# Copilot Studio — Automated Invoice Processing Agent

An **autonomous** agent: it runs when a file lands in Blob Storage, with nobody chatting to it.

| Component | Type | What it does |
|---|---|---|
| *When a blob is added or modified (properties only) (V2)* | Trigger (Azure Blob Storage) | Fires for each new invoice in `automated-invoice-processing-agent` |
| **Invoice Extraction MCP** | Tool — Model Context Protocol | `extract_invoice(document_url)` → Document Intelligence fields |
| **Save Automated Invoice Output** | Tool — agent flow | Adds one row to the Excel table `InvoiceOutput` |

## 1. Create the agent
1. **copilotstudio.microsoft.com** → choose your environment → **Create → New agent → Skip to configure**.
2. **Name:** `Automated Invoice Processing Agent`
   **Description:** *Automatically processes invoice documents uploaded to Azure Blob Storage, extracts invoice information using Azure Document Intelligence, and stores the extracted data in Excel.*
3. **Instructions:** paste [`agent-instructions.md`](agent-instructions.md) (everything below the line).
4. **Model:** keep the default model (any current GPT/Claude model offered in your tenant works).
5. **Settings → Generative AI → Orchestration:** **Generative** (required for MCP tools and triggers).
6. **Knowledge:** add none. **Web Search:** turn **off** (the agent must only use tool output).
7. **Create.**

## 2. Add the Invoice Extraction MCP tool
**Tools → Add a tool → New tool → Model Context Protocol**
| Field | Value |
|---|---|
| Server name | `Invoice Extraction MCP` |
| Server description | `Extract invoice data using Azure Document Intelligence.` |
| Server URL | `MCP_SERVER_URL` output, e.g. `https://app-invoice-mcp-xxxx.azurewebsites.net/mcp` |
| Authentication | **API key** → Type **Header** → Header name `x-api-key` |

**Create** → **Create new connection** → paste the `MCP_API_KEY` value → **Add to agent**.
Open the tool: it should list one tool, **extract_invoice**.

*(Alternative: Power Apps → Custom connectors → Import an OpenAPI file → [`mcp-connector.swagger.yaml`](mcp-connector.swagger.yaml), then add it under Tools.)*

## 3. Add the Save Automated Invoice Output tool
Build the agent flow in [`../power-automate/README.md` → Flow 2](../power-automate/README.md#flow-2--save-automated-invoice-output-agent-flow), then **Tools → Add a tool → Flow → Save Automated Invoice Output**.
On the tool's details page set *Additional details → When this will be used* → **Agent may use this tool at any time**, and make sure each input's description is filled (the orchestrator reads them).

## 4. Add the Blob trigger
Follow [`../power-automate/README.md` → Flow 1](../power-automate/README.md#flow-1--blob-trigger-when-a-blob-is-added-or-modified-properties-only-v2). This creates the trigger in Copilot Studio and then adds the SAS-URL step to it in Power Automate.

## 5. Test
1. **Publish** the agent (triggers only run on the published version).
2. Upload a sample:
   ```bash
   ./scripts/upload_sample.sh <STORAGE_ACCOUNT_NAME> sample-data/01_Contoso_Office_Supplies_INR.pdf
   ```
   or upload it in the portal: Storage account → Containers → `automated-invoice-processing-agent` → **Upload**.
3. Within ~1 minute: **Activity** tab shows a run started by the trigger → `extract_invoice` → `Save Automated Invoice Output` → *"Invoice processed successfully…"*.
4. Open the Excel file — a new row in **Invoice Output**.

## Agent status warnings you can ignore
The Overview page may show warnings such as "no knowledge sources" — expected for this agent.

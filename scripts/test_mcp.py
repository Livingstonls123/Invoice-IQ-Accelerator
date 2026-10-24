"""Call extract_invoice on a running Invoice Extraction MCP server.
Usage:
  python scripts/test_mcp.py <MCP_SERVER_URL> <MCP_API_KEY> <document_url>
  (get a SAS URL for a sample with scripts/upload_sample.sh)
"""
import json, sys
import httpx

url, key, doc = sys.argv[1:4]
h = {"x-api-key": key, "accept": "application/json, text/event-stream", "content-type": "application/json"}
init = {"jsonrpc": "2.0", "id": 1, "method": "initialize",
        "params": {"protocolVersion": "2025-06-18", "capabilities": {}, "clientInfo": {"name": "test", "version": "1"}}}
httpx.post(url, json=init, headers=h, timeout=30).raise_for_status()
call = {"jsonrpc": "2.0", "id": 2, "method": "tools/call",
        "params": {"name": "extract_invoice", "arguments": {"document_url": doc}}}
r = httpx.post(url, json=call, headers=h, timeout=180)
r.raise_for_status()
res = r.json()["result"]
print(json.dumps(res.get("structuredContent", res), indent=2))

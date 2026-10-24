"""Invoice Extraction MCP server (Azure App Service).

Exposes one MCP tool, extract_invoice, over Streamable HTTP at /mcp for Copilot Studio.
Run locally:  python -m uvicorn invoiceiq.server:app --port 8000
"""
from __future__ import annotations

import hmac
import logging
import os
from functools import lru_cache
from typing import Any
from urllib.parse import urlparse

from mcp.server.fastmcp import FastMCP
from starlette.requests import Request
from starlette.responses import JSONResponse

from .config import get_settings
from .extractor import InvoiceExtractor, has_sas, host_allowed, strip_sas, to_record

logging.basicConfig(level=os.getenv("LOG_LEVEL", "INFO"))
log = logging.getLogger("invoiceiq")
settings = get_settings()

mcp = FastMCP(
    "Invoice Extraction MCP",
    instructions="Extract invoice data using Azure Document Intelligence. "
                 "Call extract_invoice with the document URL (preferably an Azure Blob SAS URL).",
    host="0.0.0.0",
    stateless_http=True,
    json_response=True,
)


@lru_cache(maxsize=1)
def _extractor() -> InvoiceExtractor:
    return InvoiceExtractor(settings.docintel_endpoint, settings.docintel_model)


def _own_storage(url: str) -> bool:
    if not settings.storage_account_url:
        return False
    return (urlparse(url).hostname or "").lower() == (urlparse(settings.storage_account_url).hostname or "").lower()


@mcp.tool()
def extract_invoice(document_url: str) -> dict[str, Any]:
    """Extract invoice information from an invoice, bill, sales order, purchase order or
    utility bill. Input must be a document URL, preferably an Azure Blob SAS URL.

    Returns VendorName, InvoiceNumber, InvoiceDate (yyyy-MM-dd), CustomerName, TotalTax,
    InvoiceTotal, Currency, ConfidenceScore (0-1) and DocumentURL (without SAS token).
    Values that are not on the document are returned as "NA".
    """
    url = (document_url or "").strip()
    if not host_allowed(url, settings.allowed_hosts):
        return {"status": "Error", "message": "document_url must be an https URL on an allowed host "
                                              f"({settings.allowed_hosts})"}
    try:
        ex = _extractor()
        if has_sas(url) or not _own_storage(url):
            result = ex.analyze_url(url)               # Document Intelligence fetches the file
        else:
            result = ex.analyze_bytes(ex.download_with_identity(url))  # private blob, no SAS
    except Exception as exc:  # surfaced to the agent as a readable message
        log.exception("Extraction failed for %s", strip_sas(url))
        return {"status": "Error", "message": f"Could not analyze the document: {type(exc).__name__}: {exc}"[:500]}

    if not result.documents:
        return {"status": "NoInvoiceFound", "message": "No invoice was detected in the document.",
                "DocumentURL": strip_sas(url)}

    doc = result.documents[0]
    record = to_record(doc.fields or {}, getattr(doc, "confidence", None), url, settings.missing_value)
    log.info("Extracted %s / %s (confidence %s)", record["VendorName"], record["InvoiceNumber"], record["ConfidenceScore"])
    return {"status": "Success", **record}


# --------------------------------------------------------------------------- ASGI app
class ApiKeyMiddleware:
    """Pure-ASGI API key check on /mcp (keeps streaming responses intact)."""

    def __init__(self, app, key: str, header: str):
        self.app, self.key, self.header = app, key, header.lower().encode()

    async def __call__(self, scope, receive, send):
        if scope["type"] == "http" and self.key and scope["path"].startswith("/mcp"):
            supplied = dict(scope.get("headers", [])).get(self.header, b"").decode()
            if not hmac.compare_digest(supplied, self.key):
                await JSONResponse({"error": "unauthorized"}, status_code=401)(scope, receive, send)
                return
        await self.app(scope, receive, send)


async def health(_: Request) -> JSONResponse:
    return JSONResponse({"status": "ok", "service": "invoice-extraction-mcp"})


_starlette = mcp.streamable_http_app()
_starlette.add_route("/health", health, methods=["GET"])
app = ApiKeyMiddleware(_starlette, settings.api_key, settings.api_key_header)

if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=int(os.getenv("PORT", "8000")))

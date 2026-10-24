"""Azure AI Document Intelligence (prebuilt-invoice) -> flat invoice record."""
from __future__ import annotations

import fnmatch
import logging
from datetime import date
from typing import Any, Mapping
from urllib.parse import parse_qs, urlparse, urlunparse

from .models import OUTPUT_COLUMNS

log = logging.getLogger(__name__)

# prebuilt-invoice field -> output column
FIELD_MAP = {
    "VendorName": "VendorName",
    "InvoiceId": "InvoiceNumber",
    "InvoiceDate": "InvoiceDate",
    "CustomerName": "CustomerName",
    "TotalTax": "TotalTax",
    "InvoiceTotal": "InvoiceTotal",
}
AMOUNT_COLUMNS = {"TotalTax", "InvoiceTotal"}


# --------------------------------------------------------------------------- URL helpers
def strip_sas(url: str) -> str:
    """Remove the query string (SAS token) so it is never written to Excel."""
    p = urlparse(url)
    return urlunparse(p._replace(query="", fragment=""))


def has_sas(url: str) -> bool:
    return "sig" in parse_qs(urlparse(url).query)


def host_allowed(url: str, patterns: str) -> bool:
    p = urlparse(url)
    hosts = [h.strip().lower() for h in patterns.split(",") if h.strip()]
    return p.scheme == "https" and any(fnmatch.fnmatch((p.hostname or "").lower(), h) for h in hosts)


# --------------------------------------------------------------------------- field mapping
def _value(field: Any) -> Any:
    if field is None:
        return None
    ftype = getattr(field, "type", None)
    if ftype == "currency" and getattr(field, "value_currency", None) is not None:
        return field.value_currency.amount
    if ftype == "date" and getattr(field, "value_date", None) is not None:
        v = field.value_date
        return v.isoformat() if isinstance(v, date) else str(v)
    if ftype == "number" and getattr(field, "value_number", None) is not None:
        return field.value_number
    if ftype == "string" and getattr(field, "value_string", None) is not None:
        return field.value_string
    return getattr(field, "content", None)


def _currency(fields: Mapping[str, Any]) -> str | None:
    for name in ("InvoiceTotal", "SubTotal", "AmountDue", "TotalTax"):
        cur = getattr(fields.get(name), "value_currency", None)
        if cur is not None:
            code = getattr(cur, "currency_code", None)
            if code:
                return code
    for name in ("InvoiceTotal", "AmountDue"):
        cur = getattr(fields.get(name), "value_currency", None)
        if cur is not None and getattr(cur, "currency_symbol", None):
            return {"₹": "INR", "$": "USD", "€": "EUR", "£": "GBP", "¥": "JPY"}.get(cur.currency_symbol, cur.currency_symbol)
    return None


def to_record(fields: Mapping[str, Any], doc_confidence: float | None, document_url: str,
              missing: str = "NA") -> dict[str, Any]:
    """Map Document Intelligence fields to the Excel/flow contract. Pure function (unit-tested)."""
    rec: dict[str, Any] = {c: missing for c in OUTPUT_COLUMNS}
    for di_name, col in FIELD_MAP.items():
        val = _value(fields.get(di_name))
        if val in (None, ""):
            continue
        if col in AMOUNT_COLUMNS:
            try:
                val = round(float(val), 2)
            except (TypeError, ValueError):
                continue
        else:
            val = str(val).strip()
        rec[col] = val
    rec["Currency"] = _currency(fields) or missing
    rec["ConfidenceScore"] = round(float(doc_confidence), 2) if doc_confidence is not None else missing
    rec["DocumentURL"] = strip_sas(document_url)
    return rec


class InvoiceExtractor:
    def __init__(self, endpoint: str, model_id: str = "prebuilt-invoice", credential: Any = None):
        from azure.ai.documentintelligence import DocumentIntelligenceClient
        from azure.identity import DefaultAzureCredential

        self.credential = credential or DefaultAzureCredential()
        self.model_id = model_id
        self.client = DocumentIntelligenceClient(endpoint, self.credential)

    def analyze_url(self, url: str):
        from azure.ai.documentintelligence.models import AnalyzeDocumentRequest

        return self.client.begin_analyze_document(self.model_id, AnalyzeDocumentRequest(url_source=url)).result()

    def analyze_bytes(self, content: bytes):
        return self.client.begin_analyze_document(
            self.model_id, content, content_type="application/octet-stream").result()

    def download_with_identity(self, url: str) -> bytes:
        from azure.storage.blob import BlobClient

        return BlobClient.from_blob_url(url, credential=self.credential).download_blob().readall()

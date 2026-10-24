import asyncio
from datetime import date
from types import SimpleNamespace as NS

import pytest

from invoiceiq import server
from invoiceiq.extractor import has_sas, host_allowed, strip_sas, to_record
from invoiceiq.models import OUTPUT_COLUMNS

SAS_URL = ("https://stinvq.blob.core.windows.net/automated-invoice-processing-agent/Sample_Invoice.pdf"
           "?sv=2023-11-03&se=2026-10-01T00%3A00Z&sr=b&sp=r&sig=abc%3D")


def cur(amount, code="INR", symbol="₹"):
    return NS(type="currency", value_currency=NS(amount=amount, currency_code=code, currency_symbol=symbol),
              confidence=0.95, content=str(amount))


def s(v):
    return NS(type="string", value_string=v, content=v, confidence=0.9)


FULL_FIELDS = {
    "VendorName": s("ANONET Connecting Networks"),
    "InvoiceId": s("ANO252607/012332"),
    "InvoiceDate": NS(type="date", value_date=date(2025, 11, 28), content="28-11-2025", confidence=0.97),
    "CustomerName": s("ANSH97"),
    "TotalTax": cur(106.77),
    "InvoiceTotal": cur(699.98),
}


def test_full_record_matches_excel_contract():
    r = to_record(FULL_FIELDS, 0.998, SAS_URL)
    assert list(r) == OUTPUT_COLUMNS
    assert r["VendorName"] == "ANONET Connecting Networks"
    assert r["InvoiceNumber"] == "ANO252607/012332"
    assert r["InvoiceDate"] == "2025-11-28"
    assert (r["TotalTax"], r["InvoiceTotal"], r["Currency"]) == (106.77, 699.98, "INR")
    assert r["ConfidenceScore"] == 1.0
    assert "sig=" not in r["DocumentURL"] and r["DocumentURL"].endswith("Sample_Invoice.pdf")


def test_missing_values_become_na():
    r = to_record({"VendorName": s("CTS"), "InvoiceTotal": cur(5875.0, "USD", "$")}, None, SAS_URL)
    assert r["TotalTax"] == "NA" and r["CustomerName"] == "NA" and r["ConfidenceScore"] == "NA"
    assert r["Currency"] == "USD"


def test_currency_from_symbol_when_no_code():
    r = to_record({"InvoiceTotal": cur(10, code=None, symbol="£")}, 0.9, SAS_URL)
    assert r["Currency"] == "GBP"


def test_url_helpers():
    assert has_sas(SAS_URL) and not has_sas(strip_sas(SAS_URL))
    assert host_allowed(SAS_URL, "*.blob.core.windows.net")
    assert not host_allowed("http://stinvq.blob.core.windows.net/x.pdf", "*.blob.core.windows.net")
    assert not host_allowed("https://evil.example.com/x.pdf", "*.blob.core.windows.net")


class FakeExtractor:
    def __init__(self, fields, docs=True):
        self.fields, self.docs, self.calls = fields, docs, []

    def analyze_url(self, url):
        self.calls.append(("url", url))
        return NS(documents=[NS(fields=self.fields, confidence=0.93)] if self.docs else [])

    def analyze_bytes(self, content):
        self.calls.append(("bytes", len(content)))
        return self.analyze_url("bytes")

    def download_with_identity(self, url):
        self.calls.append(("download", url))
        return b"%PDF-1.4"


@pytest.fixture
def fake(monkeypatch):
    fx = FakeExtractor(FULL_FIELDS)
    monkeypatch.setattr(server, "_extractor", lambda: fx)
    return fx


def test_tool_sas_url_goes_straight_to_document_intelligence(fake):
    out = server.extract_invoice(SAS_URL)
    assert out["status"] == "Success" and out["InvoiceTotal"] == 699.98
    assert fake.calls == [("url", SAS_URL)]


def test_tool_private_blob_is_downloaded_with_identity(fake, monkeypatch):
    monkeypatch.setattr(server, "_own_storage", lambda url: True)
    out = server.extract_invoice(strip_sas(SAS_URL))
    assert out["status"] == "Success" and fake.calls[0][0] == "download"


def test_tool_rejects_disallowed_host(fake):
    out = server.extract_invoice("https://example.com/invoice.pdf")
    assert out["status"] == "Error" and not fake.calls


def test_tool_no_invoice_found(monkeypatch):
    monkeypatch.setattr(server, "_extractor", lambda: FakeExtractor({}, docs=False))
    assert server.extract_invoice(SAS_URL)["status"] == "NoInvoiceFound"


def test_single_tool_registered():
    names = [t.name for t in asyncio.run(server.mcp.list_tools())]
    assert names == ["extract_invoice"]

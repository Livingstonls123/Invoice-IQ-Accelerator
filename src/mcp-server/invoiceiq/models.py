"""Output contract of the extract_invoice tool.

These keys are the columns of the Excel table 'InvoiceOutput' (sheet 'Invoice Output')
and the inputs of the 'Save Automated Invoice Output' agent flow. Keep the three in sync;
scripts/build_assets.py regenerates the Excel template from OUTPUT_COLUMNS.
"""
from __future__ import annotations

OUTPUT_COLUMNS = [
    "VendorName",
    "InvoiceNumber",
    "InvoiceDate",
    "CustomerName",
    "TotalTax",
    "InvoiceTotal",
    "Currency",
    "ConfidenceScore",
    "DocumentURL",
]

# Short descriptions reused in the Power Automate input definitions (docs) and tool output
COLUMN_DESCRIPTIONS = {
    "VendorName": "Supplier / seller name",
    "InvoiceNumber": "Invoice number as printed on the document",
    "InvoiceDate": "Invoice date, yyyy-MM-dd",
    "CustomerName": "Bill-to customer name",
    "TotalTax": "Total tax amount (number)",
    "InvoiceTotal": "Invoice grand total (number)",
    "Currency": "ISO currency code, e.g. INR, USD",
    "ConfidenceScore": "Document Intelligence document-level confidence, 0-1",
    "DocumentURL": "Blob URL of the source document (SAS token removed)",
}

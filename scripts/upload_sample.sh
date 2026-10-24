#!/usr/bin/env bash
# Upload an invoice to the watched container (this is what fires the agent) and print a
# 1-hour read-only SAS URL you can pass to scripts/test_mcp.py.
# Uses your Entra login (user-delegation SAS) - no account keys.
# Usage: ./scripts/upload_sample.sh <storage-account-name> <file.pdf> [container]
set -euo pipefail
ACCOUNT=${1:?storage account name}; FILE=${2:?file}; CONTAINER=${3:-automated-invoice-processing-agent}
NAME=$(basename "$FILE")
az storage blob upload --auth-mode login --account-name "$ACCOUNT" -c "$CONTAINER" -f "$FILE" -n "$NAME" --overwrite -o none
EXPIRY=$(date -u -d "+1 hour" '+%Y-%m-%dT%H:%MZ' 2>/dev/null || date -u -v+1H '+%Y-%m-%dT%H:%MZ')
SAS=$(az storage blob generate-sas --auth-mode login --as-user --account-name "$ACCOUNT" -c "$CONTAINER" -n "$NAME" \
      --permissions r --expiry "$EXPIRY" --https-only -o tsv)
echo "Uploaded: $NAME"
echo "https://$ACCOUNT.blob.core.windows.net/$CONTAINER/$NAME?$SAS"

#!/usr/bin/env bash
# Plain Azure CLI deployment (alternative to `azd up`). Run from repo root after `az login`.
# Usage: ./scripts/deploy.sh <environmentName> [location]
set -euo pipefail
ENV_NAME=${1:?environment name, e.g. invoiceiq-dev}
LOCATION=${2:-centralindia}
MCP_API_KEY=${MCP_API_KEY:-$(openssl rand -hex 32)}
ME=$(az ad signed-in-user show --query id -o tsv 2>/dev/null || echo "")

echo ">> Provisioning infrastructure in $LOCATION ..."
OUT=$(az deployment sub create --name "invoiceiq-$ENV_NAME" --location "$LOCATION" \
  --template-file infra/main.bicep \
  --parameters environmentName="$ENV_NAME" location="$LOCATION" mcpApiKey="$MCP_API_KEY" \
               developerPrincipalId="$ME" \
  --query properties.outputs -o json)

RG=$(jq -r .AZURE_RESOURCE_GROUP.value <<<"$OUT")
APP=$(jq -r .MCP_APP_NAME.value <<<"$OUT")
URL=$(jq -r .MCP_SERVER_URL.value <<<"$OUT")

echo ">> Deploying MCP server to $APP ..."
( cd src/mcp-server && rm -f /tmp/invoiceiq-mcp.zip && zip -qr /tmp/invoiceiq-mcp.zip . -x "tests/*" ".env*" "__pycache__/*" )
az webapp deploy -g "$RG" -n "$APP" --src-path /tmp/invoiceiq-mcp.zip --type zip --async false

echo
echo "================ InvoiceIQ deployed ================"
jq -r 'to_entries[] | "\(.key)=\(.value.value)"' <<<"$OUT"
echo "MCP_API_KEY=$MCP_API_KEY   (store it safely - Copilot Studio needs it)"
echo "Health: ${URL%/mcp}/health"
echo "Next: ./scripts/upload_sample.sh $(jq -r .STORAGE_ACCOUNT_NAME.value <<<"$OUT") sample-data/01_Contoso_Office_Supplies_INR.pdf"

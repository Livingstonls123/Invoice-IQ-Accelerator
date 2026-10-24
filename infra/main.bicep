// Automated Invoice Processing Agent - Azure infrastructure
// Blob Storage (invoice drop zone) + Document Intelligence + Invoice Extraction MCP server (App Service)
// Deploy: azd up   |   az deployment sub create -l centralindia -f infra/main.bicep -p infra/main.parameters.json
targetScope = 'subscription'

@minLength(1)
@maxLength(20)
@description('Short environment name, used to build resource names (e.g. invoiceiq-dev).')
param environmentName string

@description('Azure region for all resources.')
param location string

@description('Region for Document Intelligence (must support the prebuilt-invoice model).')
param docIntelLocation string = location

@description('Blob container the agent watches for new invoices.')
param invoiceContainerName string = 'automated-invoice-processing-agent'

@description('Allow storage access keys (needed by the Power Platform Azure Blob connector with access-key auth, as used in the reference build).')
param allowSharedKeyAccess bool = true

@description('App Service plan SKU. B1 is fine for a pilot; use P0v3+ for production.')
param appServiceSku string = 'B1'

@secure()
@description('API key Copilot Studio sends in the x-api-key header to call the MCP server.')
param mcpApiKey string

@description('Object ID of a user to grant Blob (Contributor) + Document Intelligence access for testing. Optional.')
param developerPrincipalId string = ''

var token = toLower(uniqueString(subscription().id, environmentName, location))
var tags = { 'azd-env-name': environmentName, solution: 'invoiceiq-agent' }

resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: 'rg-${environmentName}'
  location: location
  tags: tags
}

module monitoring 'modules/monitoring.bicep' = {
  scope: rg
  name: 'monitoring'
  params: { location: location, tags: tags, name: 'log-${token}' }
}

module storage 'modules/storage.bicep' = {
  scope: rg
  name: 'storage'
  params: {
    location: location
    tags: tags
    name: 'stinvq${take(token, 16)}'
    containerName: invoiceContainerName
    allowSharedKeyAccess: allowSharedKeyAccess
  }
}

module docintel 'modules/docintel.bicep' = {
  scope: rg
  name: 'docintel'
  params: { location: docIntelLocation, tags: tags, name: 'di-invoiceiq-${token}' }
}

module keyvault 'modules/keyvault.bicep' = {
  scope: rg
  name: 'keyvault'
  params: { location: location, tags: tags, name: 'kv-invq-${take(token, 12)}', mcpApiKey: mcpApiKey }
}

module app 'modules/appservice.bicep' = {
  scope: rg
  name: 'appservice'
  params: {
    location: location
    tags: tags
    planName: 'asp-invoiceiq-${token}'
    appName: 'app-invoice-mcp-${token}'
    sku: appServiceSku
    appInsightsConnectionString: monitoring.outputs.appInsightsConnectionString
    storageAccountUrl: storage.outputs.blobEndpoint
    docIntelEndpoint: docintel.outputs.endpoint
    mcpApiKeySecretUri: keyvault.outputs.mcpApiKeySecretUri
  }
}

module rbac 'modules/rbac.bicep' = {
  scope: rg
  name: 'rbac'
  params: {
    principalId: app.outputs.principalId
    principalType: 'ServicePrincipal'
    storageName: storage.outputs.name
    docIntelName: docintel.outputs.name
    keyVaultName: keyvault.outputs.name
    blobAccess: 'Reader'
  }
}

module devRbac 'modules/rbac.bicep' = if (!empty(developerPrincipalId)) {
  scope: rg
  name: 'rbac-dev'
  params: {
    principalId: developerPrincipalId
    principalType: 'User'
    storageName: storage.outputs.name
    docIntelName: docintel.outputs.name
    keyVaultName: keyvault.outputs.name
    blobAccess: 'Contributor'
  }
}

output AZURE_RESOURCE_GROUP string = rg.name
output AZURE_LOCATION string = location
output STORAGE_ACCOUNT_NAME string = storage.outputs.name
output STORAGE_ACCOUNT_URL string = storage.outputs.blobEndpoint
output INVOICE_CONTAINER string = storage.outputs.containerName
output DOCINTEL_ENDPOINT string = docintel.outputs.endpoint
output KEY_VAULT_NAME string = keyvault.outputs.name
output MCP_APP_NAME string = app.outputs.name
output MCP_SERVER_URL string = 'https://${app.outputs.defaultHostName}/mcp'

// Invoice Extraction MCP server on Azure App Service (Linux, Python 3.12)
param location string
param tags object
param planName string
param appName string
param sku string
param appInsightsConnectionString string
param storageAccountUrl string
param docIntelEndpoint string
param mcpApiKeySecretUri string

resource plan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: planName
  location: location
  tags: tags
  kind: 'linux'
  sku: { name: sku }
  properties: { reserved: true }
}

resource site 'Microsoft.Web/sites@2023-12-01' = {
  name: appName
  location: location
  tags: union(tags, { 'azd-service-name': 'mcp-server' })
  kind: 'app,linux'
  identity: { type: 'SystemAssigned' }
  properties: {
    serverFarmId: plan.id
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'PYTHON|3.12'
      appCommandLine: 'python -m uvicorn invoiceiq.server:app --host 0.0.0.0 --port 8000 --workers 2 --timeout-keep-alive 120'
      alwaysOn: true
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      http20Enabled: true
      healthCheckPath: '/health'
      appSettings: [
        { name: 'SCM_DO_BUILD_DURING_DEPLOYMENT', value: 'true' }
        { name: 'APPLICATIONINSIGHTS_CONNECTION_STRING', value: appInsightsConnectionString }
        { name: 'STORAGE_ACCOUNT_URL', value: storageAccountUrl }
        { name: 'DOCINTEL_ENDPOINT', value: docIntelEndpoint }
        { name: 'DOCINTEL_MODEL', value: 'prebuilt-invoice' }
        { name: 'MCP_API_KEY', value: '@Microsoft.KeyVault(SecretUri=${mcpApiKeySecretUri})' }
        { name: 'ALLOWED_DOCUMENT_HOSTS', value: '*.blob.${environment().suffixes.storage}' }
        { name: 'MISSING_VALUE', value: 'NA' }
      ]
    }
  }
}

output name string = site.name
output defaultHostName string = site.properties.defaultHostName
output principalId string = site.identity.principalId

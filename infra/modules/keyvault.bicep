// Secret: the MCP API key Copilot Studio uses
param location string
param tags object
param name string
@secure()
param mcpApiKey string

resource kv 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    tenantId: subscription().tenantId
    sku: { family: 'A', name: 'standard' }
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 30
    enablePurgeProtection: true
  }
}

resource apiKey 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: kv
  name: 'mcp-api-key'
  properties: { value: mcpApiKey }
}

output name string = kv.name
output mcpApiKeySecretUri string = apiKey.properties.secretUri

// Least-privilege data-plane roles for the App Service managed identity (no keys anywhere)
param principalId string
@allowed(['ServicePrincipal', 'User', 'Group'])
param principalType string
param storageName string
param docIntelName string
param keyVaultName string
@description('Blob role: Reader for the MCP app (it only reads invoices), Contributor for a developer who uploads test files.')
@allowed(['Reader', 'Contributor'])
param blobAccess string = 'Reader'

var blobRoleId = blobAccess == 'Reader' ? '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1' : 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
var cognitiveServicesUser = 'a97b65f3-24c7-4388-baec-2e87135dc908'
var keyVaultSecretsUser = '4633458b-17de-408a-b874-0445c86b69e6'

resource sa 'Microsoft.Storage/storageAccounts@2023-05-01' existing = { name: storageName }
resource di 'Microsoft.CognitiveServices/accounts@2024-10-01' existing = { name: docIntelName }
resource kv 'Microsoft.KeyVault/vaults@2023-07-01' existing = { name: keyVaultName }

resource blobRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: sa
  name: guid(sa.id, principalId, blobRoleId)
  properties: {
    principalId: principalId
    principalType: principalType
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', blobRoleId)
  }
}

resource diRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: di
  name: guid(di.id, principalId, cognitiveServicesUser)
  properties: {
    principalId: principalId
    principalType: principalType
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', cognitiveServicesUser)
  }
}

resource kvRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: kv
  name: guid(kv.id, principalId, keyVaultSecretsUser)
  properties: {
    principalId: principalId
    principalType: principalType
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', keyVaultSecretsUser)
  }
}

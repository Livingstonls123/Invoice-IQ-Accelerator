// Step 4 - AI reads it: Azure AI Document Intelligence (Entra ID auth only)
param location string
param tags object
param name string

resource di 'Microsoft.CognitiveServices/accounts@2024-10-01' = {
  name: name
  location: location
  tags: tags
  kind: 'FormRecognizer'
  sku: { name: 'S0' }
  identity: { type: 'SystemAssigned' }
  properties: {
    customSubDomainName: name
    disableLocalAuth: true
    publicNetworkAccess: 'Enabled'
  }
}

output name string = di.name
output endpoint string = di.properties.endpoint

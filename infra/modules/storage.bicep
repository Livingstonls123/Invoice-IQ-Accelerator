// Step 3 - Stored safely: private container, TLS 1.2, versioning + soft delete
param location string
param tags object
param name string
param containerName string
@description('Shared-key access. The Copilot Studio / Power Automate Azure Blob connector in the reference video uses an access-key connection (needed for "Create SAS URI by path"). Set false if you use Entra ID connections only.')
param allowSharedKeyAccess bool = true

resource sa 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: name
  location: location
  tags: tags
  kind: 'StorageV2'
  sku: { name: 'Standard_ZRS' }
  properties: {
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: allowSharedKeyAccess
    supportsHttpsTrafficOnly: true
    defaultToOAuthAuthentication: !allowSharedKeyAccess
    encryption: {
      keySource: 'Microsoft.Storage'
      services: { blob: { enabled: true } }
    }
  }
}

resource blobSvc 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  parent: sa
  name: 'default'
  properties: {
    deleteRetentionPolicy: { enabled: true, days: 30 }
    containerDeleteRetentionPolicy: { enabled: true, days: 30 }
    isVersioningEnabled: true
  }
}

resource invoices 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: blobSvc
  name: containerName
  properties: { publicAccess: 'None' }
}

output name string = sa.name
output blobEndpoint string = sa.properties.primaryEndpoints.blob
output containerName string = invoices.name

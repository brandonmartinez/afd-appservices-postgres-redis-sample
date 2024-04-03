@description('The name of the storage account to approve the private endpoint connection')
param storageAccountName string

@description('The name of the private endpoint connection to approve')
param privateEndpointConnectionName string

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' existing = {
  name: storageAccountName
}

resource privateEndpointConnection 'Microsoft.Storage/storageAccounts/privateEndpointConnections@2023-01-01' = {
  parent: storageAccount
  name: privateEndpointConnectionName
  properties: {
    privateLinkServiceConnectionState: {
      status: 'Approved'
      description: 'Approved by pipeline'
    }
  }
}

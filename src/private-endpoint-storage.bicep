@description('The name of the storage account to approve the private endpoint connection')
param storageAccountName string

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' existing = {
  name: storageAccountName
}

output storageAccountPrivateEndpointConnectionName string = storageAccount.properties.privateEndpointConnections[0].name

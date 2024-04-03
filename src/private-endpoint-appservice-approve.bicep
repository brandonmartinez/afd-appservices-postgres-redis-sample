@description('The name of the App Service to approve the private endpoint connection')
param appServiceName string

@description('The name of the private endpoint connection to approve')
param privateEndpointConnectionName string

resource appService 'Microsoft.Web/sites@2023-01-01' existing = {
  name: appServiceName
}

resource privateEndpointConnection 'Microsoft.Web/sites/privateEndpointConnections@2023-01-01' = {
  parent: appService
  name: privateEndpointConnectionName
  properties: {
    privateLinkServiceConnectionState: {
      status: 'Approved'
      description: 'Approved by pipeline'
    }
  }
}

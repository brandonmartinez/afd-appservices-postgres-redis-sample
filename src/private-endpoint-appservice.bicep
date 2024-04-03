@description('The name of the App Service to approve the private endpoint connection')
param appServiceName string

resource appService 'Microsoft.Web/sites@2023-01-01' existing = {
  name: appServiceName
}
#disable-next-line BCP053
output appServicePrivateEndpointConnectionName string = appService.properties.privateEndpointConnections[0].name

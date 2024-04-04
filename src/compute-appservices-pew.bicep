// Parameters
//////////////////////////////////////////////////
@description('Parameters specific to this module.')
param parameters object

// Resources
//////////////////////////////////////////////////
module appServicePrivateEndpoint 'private-endpoint-appservice.bicep' = {
  name: parameters.appServicesPrivateEndpointDeploymentName
  params: {
    appServiceName: parameters.appServiceWebAppName
  }
}

module appServicePrivateEndpointApproval 'private-endpoint-appservice-approve.bicep' = {
  name: parameters.appServicesPrivateEndpointApprovalDeploymentName
  params: {
    appServiceName: parameters.appServiceWebAppName
    privateEndpointConnectionName: appServicePrivateEndpoint.outputs.appServicePrivateEndpointConnectionName
  }
}

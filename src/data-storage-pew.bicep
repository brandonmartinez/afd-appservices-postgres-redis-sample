// Parameters
//////////////////////////////////////////////////
@description('Parameters specific to this module.')
param parameters object

// Resources
//////////////////////////////////////////////////
module storagePrivateEndpoint 'private-endpoint-storage.bicep' = {
  name: parameters.storagePrivateEndpointDeploymentName
  params: {
    storageAccountName: parameters.storageAccountName
  }
}

module storagePrivateEndpointApproval 'private-endpoint-storage-approve.bicep' = {
  name: parameters.storagePrivateEndpointApprovalDeploymentName
  params: {
    storageAccountName: parameters.storageAccountName
    privateEndpointConnectionName: storagePrivateEndpoint.outputs.storageAccountPrivateEndpointConnectionName
  }
}

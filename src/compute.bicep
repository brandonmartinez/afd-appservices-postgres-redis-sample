// Parameters
//////////////////////////////////////////////////
@description('The Azure region of the resources.')
param location string

@description('Parameters specific to this module.')
param parameters object

@description('Tags to associate with the resources.')
param tags object

@description('Configuration for conditional deployment of resources.')
param conditionalDeployment object

// Resources
//////////////////////////////////////////////////
module appServices 'compute-appservices.bicep' =
  if (conditionalDeployment.deployComputeAppServicePrivateEndpointApproval == 'true') {
    name: parameters.appServicesDeploymentName
    params: {
      location: location
      parameters: parameters
      tags: tags
    }
  }

module virtualMachine 'compute-virtualmachine.bicep' =
  if (conditionalDeployment.deployComputeAppServicePrivateEndpointApproval == 'true') {
    name: parameters.virtualMachineDeploymentName
    params: {
      location: location
      parameters: parameters
      tags: tags
    }
  }

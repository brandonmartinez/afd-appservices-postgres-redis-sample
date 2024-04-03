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
module appServices 'compute-appservices.bicep' = {
  name: parameters.appServicesDeploymentName
  params: {
    location: location
    parameters: parameters
    tags: tags
    conditionalDeployment: conditionalDeployment
  }
}

module virtualMachine 'compute-virtualmachine.bicep' = {
  name: parameters.virtualMachineDeploymentName
  params: {
    location: location
    parameters: parameters
    tags: tags
  }
}

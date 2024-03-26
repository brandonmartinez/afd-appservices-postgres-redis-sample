// Parameters
//////////////////////////////////////////////////
@description('The Azure region of the resources.')
param location string = resourceGroup().location
param conditionalDeployment object
param managementModuleParameters object
param securityModuleParameters object
param networkingModuleParameters object
param computeAndDataModuleParameters object
param tags object

// Modules and Resources
//////////////////////////////////////////////////
module management './management.bicep' = if(conditionalDeployment.deployManagement == 'true') {
  name: managementModuleParameters.deploymentName
  params: {
    location: location
    tags: tags
    parameters: managementModuleParameters
  }
}

module security './security.bicep' = if(conditionalDeployment.deploySecurity == 'true') {
  name: securityModuleParameters.deploymentName
  params: {
    location: location
    tags: tags
    parameters: securityModuleParameters
  }
}

module networking './networking.bicep' = if(conditionalDeployment.deployNetworking == 'true') {
  name: networkingModuleParameters.deploymentName
  dependsOn: [
    // wait for security as we need certs and identities setup
    security
  ]
  params: {
    location: location
    tags: tags
    parameters: networkingModuleParameters
  }
}

module computeAndData 'compute-and-data.bicep' = if(conditionalDeployment.deployComputeAndData == 'true') {
  name: computeAndDataModuleParameters.deploymentName
  dependsOn: [
    // wait for networking as we need the vnet and subnet
    networking
  ]
  params: {
    location: location
    tags: tags
    parameters: computeAndDataModuleParameters
  }
}

// Outputs
//////////////////////////////////////////////////

// Passed in configuration
// NOTE: this contains secure info and should not be output in a real environment
output managementParameters object = managementModuleParameters
output securityParameters object = securityModuleParameters
output networkingParameters object = networkingModuleParameters
output computeAndDataModuleParameters object = computeAndDataModuleParameters

// Management Module Outputs
output logAnalyticsWorkspaceId string = management.outputs.logAnalyticsWorkspaceId
output applicationInsightsId string = management.outputs.applicationInsightsId
output applicationInsightsConnectionString string = management.outputs.applicationInsightsConnectionString

// Networking Module Outputs
output natGatewayId string = networking.outputs.natGatewayId

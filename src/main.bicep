// Parameters
//////////////////////////////////////////////////
@description('The Azure region of the resources.')
param location string = resourceGroup().location
param conditionalDeployment object
param managementModuleParameters object
param securityModuleParameters object
param networkingModuleParameters object
param dataModuleParameters object
param computeModuleParameters object
param tags object

// Modules and Resources
//////////////////////////////////////////////////
module management './management.bicep' =
  if (conditionalDeployment.deployManagement == 'true') {
    name: managementModuleParameters.deploymentName
    params: {
      location: location
      tags: tags
      parameters: managementModuleParameters
    }
  }

module security './security.bicep' =
  if (conditionalDeployment.deploySecurity == 'true') {
    name: securityModuleParameters.deploymentName
    params: {
      location: location
      tags: tags
      parameters: securityModuleParameters
    }
  }

module networking './networking.bicep' =
  if (conditionalDeployment.deployNetworking == 'true') {
    name: networkingModuleParameters.deploymentName
    dependsOn: (conditionalDeployment.deploySecurity == 'true')
      ? [
          // wait for networking as we need the vnet and subnet
          security
        ]
      : []
    params: {
      location: location
      tags: tags
      parameters: networkingModuleParameters
    }
  }

module data 'data.bicep' =
  if (conditionalDeployment.deployData == 'true') {
    name: dataModuleParameters.deploymentName
    dependsOn: (conditionalDeployment.deployNetworking == 'true')
      ? [
          // wait for networking as we need the vnet and subnet
          networking
        ]
      : []
    params: {
      location: location
      tags: tags
      conditionalDeployment: conditionalDeployment
      parameters: dataModuleParameters
    }
  }

module compute 'compute.bicep' =
  if (conditionalDeployment.deployCompute == 'true') {
    name: computeModuleParameters.deploymentName
    dependsOn: (conditionalDeployment.deployNetworking == 'true')
      ? [
          // wait for networking as we need the vnet and subnet
          networking
        ]
      : []
    params: {
      location: location
      tags: tags
      parameters: computeModuleParameters
    }
  }

// Outputs
//////////////////////////////////////////////////
var generatedOutputs = {
  // Management Module Outputs
  logAnalyticsWorkspaceId: (conditionalDeployment.deployManagement == 'true')
    ? management.outputs.logAnalyticsWorkspaceId
    : ''
  applicationInsightsId: (conditionalDeployment.deployManagement == 'true')
    ? management.outputs.applicationInsightsId
    : ''
  applicationInsightsConnectionString: (conditionalDeployment.deployManagement == 'true')
    ? management.outputs.applicationInsightsConnectionString
    : ''

  // Networking Module Outputs
  natGatewayId: (conditionalDeployment.deployNetworking == 'true') ? networking.outputs.natGatewayId : ''
}

output generatedOutputs object = generatedOutputs

// Passed in configuration
// NOTE: this contains secure info and should not be output in a real environment
output managementParameters object = managementModuleParameters
output securityParameters object = securityModuleParameters
output networkingParameters object = networkingModuleParameters
output dataModuleParameters object = dataModuleParameters
output computeModuleParameters object = computeModuleParameters


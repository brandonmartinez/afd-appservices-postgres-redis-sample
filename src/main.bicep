// Parameters
//////////////////////////////////////////////////
@description('The Azure region of the resources.')
param location string = resourceGroup().location
param conditionalDeployment object
param managementModuleParameters object
param securityModuleParameters object
param networkingModuleParameters object
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

// Outputs
//////////////////////////////////////////////////

// Management Module Outputs
output logAnalyticsWorkspaceId string = management.outputs.logAnalyticsWorkspaceId
output logAnalyticsWorkspaceName string = management.outputs.logAnalyticsWorkspaceName
output applicationInsightsName string = management.outputs.applicationInsightsName
output applicationInsightsId string = management.outputs.applicationInsightsId
output applicationInsightsConnectionString string = management.outputs.applicationInsightsConnectionString

// Networking Module Outputs
output virtualNetworkName string = networking.outputs.virtualNetworkName
output natGatewayName string = networking.outputs.natGatewayName
output natGatewayId string = networking.outputs.natGatewayId
output natGatewayPublicIpPrefixName string = networking.outputs.natGatewayPublicIpPrefixName

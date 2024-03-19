// Parameters
//////////////////////////////////////////////////
@description('The current date.')
param currentDate string = utcNow('yyyy-MM-dd')

@description('The Azure region of the resources.')
param location string = resourceGroup().location

@description('The workload or logical environment of the resources.')
param appenv string

@description('The public IP address to be used in allowing access to Azure services via Bastion.')
param publicIpAddress string

// Variables
//////////////////////////////////////////////////
var tags = {
  deploymentDate: currentDate
  environment: appenv
}
var managementModuleParameters = {
  // Log Analytics Workspace Variables
  logAnalyticsWorkspaceName: 'log-${appenv}'

  // Application Insights Variables
  applicationInsightsName: 'appinsights-${appenv}'
}

var networkingModuleParameters = {
  // NSG Variables
  bastionNetworkSecurityGroupName: 'nsg-${appenv}-bastion'
  vnetIntegrationNetworkSecurityGroupName: 'nsg-${appenv}-vnetintegration'

  // NAT Gateway Variables
  natGatewayPublicIpPrefixName: 'pipp-${appenv}-ngw'
  natGatewayName: 'ngw-${appenv}'

  // Virtual Network Variables
  virtualNetworkName: 'vnet-${appenv}'
  virtualNetworkPrefix: '10.0.0.0/16'

  // Virtual Network Subnet Variables
  appServicesSubnetName: 'app-services'
  appServicesSubnetAddressPrefix: '10.0.1.0/24'
  bastionSubnetName: 'AzureBastionSubnet' // Must be this name: https://learn.microsoft.com/en-us/azure/bastion/configuration-settings#subnet
  bastionSubnetAddressPrefix: '10.0.200.0/24'
}

// Modules and Resources
//////////////////////////////////////////////////
module management './management.bicep' = {
  name: 'management'
  params: {
    location: location
    tags: tags
    managementModuleParameters: managementModuleParameters
  }
}

module networking './networking.bicep' = {
  name: 'networking'
  params: {
    location: location
    tags: tags
    publicIpAddress: publicIpAddress
    networkingModuleParameters: networkingModuleParameters
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

// Parameters
//////////////////////////////////////////////////
@description('The current datetime.')
param currentDateTime string = utcNow('yyyMMddTHmm')

@description('The Azure region of the resources.')
param location string

@description('Parameters specific to the networking module.')
param networkingModuleParameters object

@description('Tags to associate with the resources.')
param tags object

@description('The public IP address to be used in allowing access to Azure services via Bastion.')
param publicIpAddress string

// Resources
//////////////////////////////////////////////////
resource natGatewayPublicIpPrefix 'Microsoft.Network/publicIPPrefixes@2022-09-01' = {
  name: networkingModuleParameters.natGatewayPublicIpPrefixName
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    prefixLength: 31
    publicIPAddressVersion: 'IPv4'
  }
}

resource natGateway 'Microsoft.Network/natGateways@2022-09-01' = {
  name: networkingModuleParameters.natGatewayName
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    idleTimeoutInMinutes: 4
    publicIpPrefixes: [
      {
        id: natGatewayPublicIpPrefix.id
      }
    ]
  }
}

resource bastionNetworkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2022-09-01' = {
  name: networkingModuleParameters.bastionNetworkSecurityGroupName
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'HTTPS_Inbound'
        properties: {
          description: 'Allow HTTPS Access from Current Location'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: publicIpAddress
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      {
        name: 'Gateway_Manager_Inbound'
        properties: {
          description: 'Allow Gateway Manager Access'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: 'GatewayManager'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 200
          direction: 'Inbound'
        }
      }
      {
        name: 'SSH_RDP_Outbound'
        properties: {
          description: 'Allow SSH and RDP Outbound'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRanges: [
            '22'
            '3389'
          ]
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 100
          direction: 'Outbound'
        }
      }
      {
        name: 'Azure_Cloud_Outbound'
        properties: {
          description: 'Allow Azure Cloud Outbound'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'AzureCloud'
          access: 'Allow'
          priority: 200
          direction: 'Outbound'
        }
      }
    ]
  }
}

resource vnetIntegrationNetworkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2022-09-01' = {
  name: networkingModuleParameters.vnetIntegrationNetworkSecurityGroupName
  location: location
  tags: tags
}

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2019-11-01' = {
  name: networkingModuleParameters.virtualNetworkName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        networkingModuleParameters.virtualNetworkPrefix
      ]
    }
    subnets: [
      {
        name: networkingModuleParameters.bastionSubnetName
        properties: {
          addressPrefix: networkingModuleParameters.bastionSubnetAddressPrefix
          networkSecurityGroup: {
            id: bastionNetworkSecurityGroup.id
          }
        }
      }
      {
        name: networkingModuleParameters.appServicesSubnetName
        properties: {
          addressPrefix: networkingModuleParameters.appServicesSubnetAddressPrefix
          natGateway: {
            id: natGateway.id
          }
          delegations: [
            {
              name: 'appServicePlanDelegation'
              properties: {
                serviceName: 'Microsoft.Web/serverFarms'
              }
            }
          ]
          networkSecurityGroup: {
            id: vnetIntegrationNetworkSecurityGroup.id
          }
          privateEndpointNetworkPolicies: 'Enabled'
        }
      }
    ]
  }
  resource bastionSubnet 'subnets' existing = {
    name: 'AzureBastionSubnet'
  }
}

module bastion './networking-bastion.bicep' = {
  name: 'az-bastion-${currentDateTime}'
  params: {
    location: location
    networkingModuleParameters: networkingModuleParameters
    tags: tags
    bastionSubnetId: virtualNetwork::bastionSubnet.id
  }
}

// Outputs
//////////////////////////////////////////////////
output virtualNetworkName string = virtualNetwork.name
output natGatewayName string = natGateway.name
output natGatewayId string = natGateway.id
output natGatewayPublicIpPrefixName string = natGatewayPublicIpPrefix.name

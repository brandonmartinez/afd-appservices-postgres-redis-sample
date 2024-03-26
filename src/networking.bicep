// Parameters
//////////////////////////////////////////////////
@description('The Azure region of the resources.')
param location string

@description('Parameters specific to this module.')
param parameters object

@description('Tags to associate with the resources.')
param tags object

// Resources
//////////////////////////////////////////////////
resource natGatewayPublicIpPrefix 'Microsoft.Network/publicIPPrefixes@2022-09-01' = {
  name: parameters.natGatewayPublicIpPrefixName
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
  name: parameters.natGatewayName
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
  name: parameters.bastionNetworkSecurityGroupName
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
          sourceAddressPrefix: parameters.publicIpAddress
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
  name: parameters.vnetIntegrationNetworkSecurityGroupName
  location: location
  tags: tags
}

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: parameters.virtualNetworkName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        parameters.virtualNetworkPrefix
      ]
    }
    subnets: [
      {
        name: parameters.bastionSubnetName
        properties: {
          addressPrefix: parameters.bastionSubnetAddressPrefix
          networkSecurityGroup: {
            id: bastionNetworkSecurityGroup.id
          }
        }
      }
      {
        name: parameters.virtualMachineSubnetName
        properties: {
          addressPrefix: parameters.virtualMachineSubnetAddressPrefix
          networkSecurityGroup: {
            id: vnetIntegrationNetworkSecurityGroup.id
          }
        }
      }
      {
        name: parameters.appServicesSubnetName
        properties: {
          addressPrefix: parameters.appServicesSubnetAddressPrefix
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
      {
        name: parameters.postgresSubnetName
        properties: {
          addressPrefix: parameters.postgresSubnetAddressPrefix
          delegations: [
            {
              name: 'postgresDelegation'
              properties: {
                serviceName: 'Microsoft.DBforPostgreSQL/flexibleServers'
              }
            }
          ]
          networkSecurityGroup: {
            id: vnetIntegrationNetworkSecurityGroup.id
          }
          privateEndpointNetworkPolicies: 'Enabled'
        }
      }
      {
        name: parameters.storageSubnetName
        properties: {
          addressPrefix: parameters.storageSubnetAddressPrefix
          networkSecurityGroup: {
            id: vnetIntegrationNetworkSecurityGroup.id
          }
          privateEndpointNetworkPolicies: 'Enabled'
        }
      }
      {
        name: parameters.redisSubnetName
        properties: {
          addressPrefix: parameters.redisSubnetAddressPrefix
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

resource dnsZone 'Microsoft.Network/dnsZones@2018-05-01' = {
  name: parameters.dnsZoneName
  location: 'global'
}

module bastion './networking-bastion.bicep' = {
  name: parameters.bastionDeploymentName
  params: {
    location: location
    parameters: parameters
    tags: tags
    bastionSubnetId: virtualNetwork::bastionSubnet.id
  }
}

module frontDoor './networking-frontdoor.bicep' = {
  name: parameters.frontDoorDeploymentName
  params: {
    parameters: parameters
    tags: tags
  }
}

// Outputs
//////////////////////////////////////////////////
output virtualNetworkName string = virtualNetwork.name
output natGatewayName string = natGateway.name
output natGatewayId string = natGateway.id
output natGatewayPublicIpPrefixName string = natGatewayPublicIpPrefix.name

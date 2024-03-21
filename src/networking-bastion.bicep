// Parameters
//////////////////////////////////////////////////
@description('The Azure region of the resources.')
param location string

@description('Parameters specific to this module.')
param parameters object

@description('Tags to associate with the resources.')
param tags object

@description('ID of the subnet to deploy Bastion into.')
param bastionSubnetId string

// Resources
//////////////////////////////////////////////////
resource bastionPublicIpAddress 'Microsoft.Network/publicIPAddresses@2022-09-01' = {
  name: parameters.bastionPublicIpAddressName
  location: location
  tags: tags
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
  sku: {
    name: 'Standard'
  }
}

resource bastion 'Microsoft.Network/bastionHosts@2022-09-01' = {
  name: parameters.bastionName
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'ipConf'
        properties: {
          publicIPAddress: {
            id: bastionPublicIpAddress.id
          }
          subnet: {
            id: bastionSubnetId
          }
        }
      }
    ]
  }
}

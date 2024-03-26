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
resource bastionPublicIpAddress 'Microsoft.Network/publicIPAddresses@2023-09-01' = {
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

resource bastion 'Microsoft.Network/bastionHosts@2023-09-01' = {
  name: parameters.bastionName
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    disableCopyPaste: false
    enableFileCopy: true
    enableIpConnect: true
    enableShareableLink: true
    enableTunneling: true
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

// Parameters
//////////////////////////////////////////////////
param baseName string

param dnsZoneName string

param groupIds array = []

@description('The Azure region of the resources.')
param location string

param serviceId string

param subnetId string

param virtualNetworkId string

// Resources
//////////////////////////////////////////////////
resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: dnsZoneName
  location: 'global'

  resource vNetLink 'virtualNetworkLinks' = {
    name: '${baseName}-link'
    location: 'global'
    properties: {
      registrationEnabled: false
      virtualNetwork: { id: virtualNetworkId }
    }
  }
}

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2023-05-01' = {
  name: '${baseName}-pe'
  location: location
  properties: {
    subnet: {
      id: subnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${baseName}-pe-conn'
        properties: {
          privateLinkServiceId: serviceId
          groupIds: groupIds
          privateLinkServiceConnectionState: {
            status: 'Approved'
            actionsRequired: 'None'
          }
        }
      }
    ]
  }
}

resource privateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-05-01' = {
  parent: privateEndpoint
  name: '${baseName}-peg'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: privateDnsZone.name
        properties: {
          privateDnsZoneId: privateDnsZone.id
        }
      }
    ]
  }
}

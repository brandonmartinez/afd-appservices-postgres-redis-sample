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
resource virtualNetwork 'Microsoft.Network/virtualNetworks@2023-09-01' existing = {
  name: parameters.virtualNetworkName
  resource postgresSubnet 'subnets@2023-09-01' existing = {
    name: parameters.postgresSubnetName
  }
  resource storageSubnet 'subnets@2023-09-01' existing = {
    name: parameters.storageSubnetName
  }
}

resource postgresManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: parameters.postgresManagedIdentityName
}

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'private.postgres.database.azure.com'
  location: 'global'
  resource vNetLink 'virtualNetworkLinks' = {
    name: '${parameters.postgresServerName}-link'
    location: 'global'
    properties: {
      registrationEnabled: false
      virtualNetwork: { id: virtualNetwork.id }
    }
  }
}

resource postgresServer 'Microsoft.DBforPostgreSQL/flexibleServers@2022-12-01' = {
  name: parameters.postgresServerName
  location: location
  tags: tags
  sku: {
    name: parameters.postgresServerSkuName
    tier: parameters.postgresServerSkuTier
  }
  properties: {
    administratorLogin: parameters.postgresServerAdminUsername
    administratorLoginPassword: parameters.postgresServerAdminPassword
    authConfig: {
      passwordAuth: 'Enabled'
      activeDirectoryAuth: 'Enabled'
      tenantId: tenant().tenantId
    }
    version: parameters.postgresServerVersion
    network: {
      delegatedSubnetResourceId: virtualNetwork::postgresSubnet.id
      privateDnsZoneArmResourceId: privateDnsZone.id
    }
    storage: {
      storageSizeGB: parameters.postgresServerStorageSize
    }
    backup: {
      backupRetentionDays: 7
      geoRedundantBackup: 'Disabled'
    }
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${postgresManagedIdentity.id}': {}
    }
  }
  resource database 'databases' = {
    name: 'webapp'
  }
}

module postgresAdminUser 'data-postgres-adminuser.bicep' = {
  name: parameters.postgressAdminUserDeploymentName
  params: {
    managedIdentityName: postgresManagedIdentity.name
    managedIdentityObjectId: postgresManagedIdentity.properties.principalId
    postgresServerName: postgresServer.name
  }
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: parameters.storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: true
    minimumTlsVersion: 'TLS1_2'
    dnsEndpointType: 'Standard'
    defaultToOAuthAuthentication: false
    supportsHttpsTrafficOnly: true
    networkAcls: {
      bypass: 'AzureServices'
      virtualNetworkRules: []
      ipRules: []
      defaultAction: 'Deny'
    }
    encryption: {
      requireInfrastructureEncryption: false
      services: {
        file: {
          keyType: 'Account'
          enabled: true
        }
        blob: {
          keyType: 'Account'
          enabled: true
        }
      }
      keySource: 'Microsoft.Storage'
    }
  }
}

resource storageAccountContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-09-01' = {
  #disable-next-line use-parent-property
  name: '${storageAccount.name}/default/assets'
  properties: {
    publicAccess: 'None'
  }
}

resource storageAccountBlobPrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.blob.${environment().suffixes.storage}'
  location: 'global'
}

resource storageAccountBlobPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-05-01' = {
  name: '${storageAccount.name}-blob-pe'
  location: location
  properties:{
    subnet: {
      id: virtualNetwork::storageSubnet.id
    }
    privateLinkServiceConnections: [
    {
      name: '${storageAccount.name}-blob-pe-conn'
      properties: {
        privateLinkServiceId: storageAccount.id
        groupIds:[
          'blob'
        ]
        privateLinkServiceConnectionState: {
          status: 'Approved'
          actionsRequired: 'None'
        }
      }
    }
    ]
  }
}

resource storageAccountBlobPrivateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-05-01' = {
  parent: storageAccountBlobPrivateEndpoint
  name: '${storageAccount.name}-blob-peg'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: storageAccountBlobPrivateDnsZone.name
        properties: {
          privateDnsZoneId: storageAccountBlobPrivateDnsZone.id
        }
      }
    ]
  }
}

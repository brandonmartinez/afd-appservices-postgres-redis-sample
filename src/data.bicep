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
  resource redisSubnet 'subnets@2023-09-01' existing = {
    name: parameters.redisSubnetName
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

module storagePrivateEndpoint 'private-endpoint.bicep' = {
  name: parameters.storagePrivateEndpointDeploymentName
  params: {
    baseName: '${storageAccount.name}-blob'
    dnsZoneName: 'privatelink.blob.${environment().suffixes.storage}'
    groupIds: [
      'blob'
    ]
    location: location
    serviceId: storageAccount.id
    subnetId: virtualNetwork::storageSubnet.id
    virtualNetworkId: virtualNetwork.id
  }
}

resource redisManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: parameters.redisManagedIdentityName
}

resource redisCache 'Microsoft.Cache/redis@2023-08-01' = {
  name: parameters.redisCacheName
  location: location
  properties: {
    sku: {
      name: 'Basic'
      family: 'C'
      capacity: 0
    }
    publicNetworkAccess: 'Disabled'
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${redisManagedIdentity.id}': {}
    }
  }
}

module redisPrivateEndpoint 'private-endpoint.bicep' = {
  name: parameters.redisPrivateEndpointDeploymentName
  params: {
    baseName: redisCache.name
    dnsZoneName: 'privatelink.redis.cache.windows.net'
    groupIds: [
      'redisCache'
    ]
    location: location
    serviceId: redisCache.id
    subnetId: virtualNetwork::redisSubnet.id
    virtualNetworkId: virtualNetwork.id
  }
}

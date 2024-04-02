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

resource frontDoorEndpoint 'Microsoft.Cdn/profiles/afdEndpoints@2021-06-01' existing = {
  name: parameters.frontDoorEndpointName
}

resource frontDoorCertificateSecret 'Microsoft.Cdn/profiles/secrets@2023-05-01' existing = {
  name: parameters.frontDoorCertificateSecretName
}

resource frontDoorRuleSet 'Microsoft.Cdn/profiles/ruleSets@2023-07-01-preview' existing = {
  name: parameters.frontDoorRuleSetName
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

module postgresManagedIdentityAdminUser 'data-postgres-adminuser.bicep' = {
  name: parameters.postgressAdminManagedIdentityDeploymentName
  params: {
    identityName: postgresManagedIdentity.name
    identityObjectId: postgresManagedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
    postgresServerName: postgresServer.name
  }
}

module postgresEntraUserIdentityAdminUser 'data-postgres-adminuser.bicep' = {
  name: parameters.postgressAdminUserDeploymentName
  params: {
    identityName: parameters.entraUserEmail
    identityObjectId: parameters.entraUserObjectId
    principalType: 'User'
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

module storageFrontDoorSite 'networking-frontdoor-site.bicep' = {
  name: parameters.storageFrontDoorSiteDeploymentName
  params: {
    location: location
    certificateSecretId: frontDoorCertificateSecret.id
    dnsZoneName: parameters.frontDoorDnsZoneName
    endpointHostName: frontDoorEndpoint.properties.hostName
    endpointName: parameters.frontDoorEndpointName
    privateEndpointResourceId: storagePrivateEndpoint.outputs.privateEndpointId
    privateEndpointResourceType: 'blob'
    profileName: parameters.frontDoorProfileName
    ruleSetId: frontDoorRuleSet.id
    usePrivateLink: true
    parameters: parameters.storageFrontDoorSite
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
    redisConfiguration: {
      'aad-enabled': 'true'
    }
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${redisManagedIdentity.id}': {}
    }
  }
}

module redisManagedIdentityAdminUser 'data-redis-adminuser.bicep' = {
  name: parameters.redisAdminManagedIdentityDeploymentName
  params: {
    redisCacheAccessPolicyName: '${redisCache.name}-accesspolicy-mi'
    identityName: redisManagedIdentity.name
    identityObjectId: redisManagedIdentity.properties.principalId
    builtInPolicyName: 'Data Owner'
    redisCacheName: redisCache.name
  }
}

module redisEntraUserAdminUser 'data-redis-adminuser.bicep' = {
  name: parameters.redisAdminUserDeploymentName
  params: {
    redisCacheAccessPolicyName: '${redisCache.name}-accesspolicy-ei'
    identityName: parameters.entraUserEmail
    identityObjectId: parameters.entraUserObjectId
    builtInPolicyName: 'Data Owner'
    redisCacheName: redisCache.name
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

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
  resource redisSubnet 'subnets@2023-09-01' existing = {
    name: parameters.redisSubnetName
  }
}

resource redisManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: parameters.redisManagedIdentityName
}

resource redisCache 'Microsoft.Cache/redis@2023-08-01' = {
  name: parameters.redisCacheName
  location: location
  tags: tags
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
  dependsOn: [
    // We want the managed identity to always succeed, so run this one second
    redisManagedIdentityAdminUser
  ]
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

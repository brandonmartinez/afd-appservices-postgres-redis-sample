// Parameters
//////////////////////////////////////////////////
@description('The name of the Redis Cache.')
param redisCacheName string

@description('The name of the Redis Cache access policy.')
param redisCacheAccessPolicyName string

@description('The managed identity object/principal ID.')
param identityObjectId string

@allowed([
  'Data Owner'
  'Data Contributor'
  'Data Reader'
])
@description('The principal type of the managed identity.')
param builtInPolicyName string = 'Data Owner'

@description('The name of the managed identity')
param identityName string

// Resources
//////////////////////////////////////////////////
resource redisCache 'Microsoft.Cache/redis@2023-08-01' existing = {
  name: redisCacheName
}

resource redisCacheBuiltInAccessPolicyAssignment 'Microsoft.Cache/redis/accessPolicyAssignments@2023-08-01' = {
  name: redisCacheAccessPolicyName
  parent: redisCache
  properties: {
    accessPolicyName: builtInPolicyName
    objectId: identityObjectId
    objectIdAlias: identityName
  }
}

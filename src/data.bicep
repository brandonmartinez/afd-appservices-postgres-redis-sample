// Parameters
//////////////////////////////////////////////////
@description('The Azure region of the resources.')
param location string

@description('Parameters specific to this module.')
param parameters object

@description('Tags to associate with the resources.')
param tags object

@description('Configuration for conditional deployment of resources.')
param conditionalDeployment object

// Resources
//////////////////////////////////////////////////
module postgress 'data-postgres.bicep' =
  if (conditionalDeployment.deployDataPostgres) {
    name: parameters.postgresDeploymentName
    params: {
      location: location
      tags: tags
      parameters: parameters
    }
  }

module storageAccount 'data-storage.bicep' =
  if (conditionalDeployment.deployDataStorage) {
    name: parameters.storageDeploymentName
    params: {
      location: location
      tags: tags
      parameters: parameters
      deployDataStoragePrivateEndpointApproval: conditionalDeployment.deployDataStoragePrivateEndpointApproval
    }
  }
module redis 'data-redis.bicep' =
  if (conditionalDeployment.deployDataRedis) {
    name: parameters.redisDeploymentName
    params: {
      location: location
      tags: tags
      parameters: parameters
    }
  }

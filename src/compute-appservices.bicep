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
  resource appservicesSubnet 'subnets@2023-09-01' existing = {
    name: parameters.appServicesSubnetName
  }
}

resource frontDoorProfile 'Microsoft.Cdn/profiles@2022-11-01-preview' existing = {
  name: parameters.frontDoorProfileName
}

resource appServiceManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: parameters.appServiceManagedIdentityName
}

resource postgresManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: parameters.postgresManagedIdentityName
}

resource redisManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: parameters.redisManagedIdentityName
}

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: parameters.applicationInsightsName
}

resource postgresServer 'Microsoft.DBforPostgreSQL/flexibleServers@2022-12-01' existing = {
  name: parameters.postgresServerName
}

resource redisCache 'Microsoft.Cache/redis@2023-08-01' existing = {
  name: parameters.redisCacheName
}

resource appServicePlan 'Microsoft.Web/serverfarms@2023-01-01' = {
  name: parameters.appServicePlanName
  location: location
  tags: tags
  sku: {
    name: 'P1v3'
    capacity: 1
  }
  properties: {
    reserved: true
  }
  kind: 'linux'
}

resource webAppAppService 'Microsoft.Web/sites@2023-01-01' = {
  name: parameters.appServiceWebAppName
  location: location
  tags: tags
  kind: 'linux'
  properties: {
    serverFarmId: appServicePlan.id
    virtualNetworkSubnetId: virtualNetwork::appservicesSubnet.id
    vnetRouteAllEnabled: true
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'DOCKER|ghcr.io/brandonmartinez/brandonmartinez/node-redis-postgres-azure-app:latest'
      alwaysOn: true
      ipSecurityRestrictions: [
        {
          ipAddress: '168.63.129.16/32'
          action: 'Allow'
          priority: 100
          name: 'AzureInf001'
        }
        {
          ipAddress: '169.254.169.254/32'
          action: 'Allow'
          priority: 100
          name: 'AzureInf002'
        }
        {
          ipAddress: 'AzureFrontDoor.Backend'
          tag: 'ServiceTag'
          action: 'Allow'
          priority: 100
          name: 'AFD'
          headers: {
            'x-azure-fdid': [
              frontDoorProfile.properties.frontDoorId
            ]
          }
        }
      ]
      appSettings: [
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: applicationInsights.properties.ConnectionString
        }
        {
          name: 'POSTGRES_DATABASE_NAME'
          value: 'webapp'
        }
        {
          name: 'POSTGRES_SERVER'
          value: postgresServer.properties.fullyQualifiedDomainName
        }
        {
          name: 'POSTGRES_USER_MANAGED_IDENTITY_CLIENTID'
          value: postgresManagedIdentity.properties.clientId
        }
        {
          name: 'POSTGRES_USER_MANAGED_IDENTITY_USERNAME'
          value: postgresManagedIdentity.name
        }
        {
          name: 'REDIS_SERVER'
          value: redisCache.properties.hostName
        }
        {
          name: 'REDIS_USER_MANAGED_IDENTITY_CLIENTID'
          value: redisManagedIdentity.properties.clientId
        }
        {
          name: 'REDIS_USER_MANAGED_IDENTITY_USERNAME'
          value: redisManagedIdentity.properties.principalId
        }
      ]
    }
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${appServiceManagedIdentity.id}': {}
      '${postgresManagedIdentity.id}': {}
      '${redisManagedIdentity.id}': {}
    }
  }
}

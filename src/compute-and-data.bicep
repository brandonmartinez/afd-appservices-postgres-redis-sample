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
  resource appservicesSubnet 'subnets@2023-09-01' existing = {
    name: parameters.appServicesSubnetName
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
    authConfig:{
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

module computeAndDataPostgressAdmin 'compute-and-data-postgres-admin.bicep' = {
  name: parameters.postgressAdminUserDeploymentName
  params: {
    managedIdentityName: postgresManagedIdentity.name
    managedIdentityObjectId: postgresManagedIdentity.properties.principalId
    postgresServerName: postgresServer.name
  }
}

resource appServiceManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: parameters.appServiceManagedIdentityName
}

resource appServicePlan 'Microsoft.Web/serverfarms@2023-01-01' = {
  name: parameters.appServicePlanName
  location: location
  tags: tags
  sku: {
    name: 'P1v3'
    capacity: 1
  }
  kind: 'linux'
}

resource webAppAppService 'Microsoft.Web/sites@2023-01-01' = {
  name: parameters.appServiceWebAppName
  location: location
  tags: tags
  properties: {
    serverFarmId: appServicePlan.id
    virtualNetworkSubnetId: virtualNetwork::appservicesSubnet.id
    siteConfig: {
      vnetRouteAllEnabled: true
      linuxFxVersion: 'DOCKER|dpage/pgadmin4:latest'
      alwaysOn: true
      connectionStrings: [
        {
          connectionString: '${postgresServer.name}.postgres.database.azure.com'
          type: 'PostgreSQL'
        }
      ]
      appSettings: [
        {
          name: 'DATABASE_USERNAME'
          value: computeAndDataPostgressAdmin.outputs.aadUserName
        }
        {
          name: 'PGADMIN_DEFAULT_EMAIL'
          value: parameters.appServicePgAdminEmail
        }
        {
          name: 'PGADMIN_DEFAULT_PASSWORD'
          value: parameters.appServicePgAdminPassword
        }
        {
          name: 'PGADMIN_DISABLE_POSTFIX'
          value: 'True'
        }
      ]
    }
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${appServiceManagedIdentity.id}': {}
    }
  }
}

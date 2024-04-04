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
    name: parameters.postgresAdminManagedIdentityDeploymentName
    params: {
      identityName: postgresManagedIdentity.name
      identityObjectId: postgresManagedIdentity.properties.principalId
      principalType: 'ServicePrincipal'
      postgresServerName: postgresServer.name
    }
  }

module postgresEntraUserIdentityAdminUser 'data-postgres-adminuser.bicep' = {
    name: parameters.postgresAdminUserDeploymentName
    params: {
      identityName: parameters.entraUserEmail
      identityObjectId: parameters.entraUserObjectId
      principalType: 'User'
      postgresServerName: postgresServer.name
    }
  }

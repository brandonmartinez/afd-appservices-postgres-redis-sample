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
      linuxFxVersion: 'DOCKER|dpage/pgadmin4:latest'
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
      connectionStrings: [
        {
          connectionString: '${parameters.postgresServerName}.postgres.database.azure.com'
          type: 'PostgreSQL'
          name: 'DATABASE_CONNECTION_STRING'
        }
      ]
      appSettings: [
        {
          name: 'DATABASE_USERNAME'
          value: '${parameters.postgresServerName}/${postgresManagedIdentity.properties.principalId}'
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

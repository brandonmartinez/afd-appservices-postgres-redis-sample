@description('The name of the Postgres server.')
param postgresServerName string

@description('The managed identity object/principal ID.')
param managedIdentityObjectId string

@description('The name of the managed identity')
param managedIdentityName string

resource aadUser 'Microsoft.DBforPostgreSQL/flexibleServers/administrators@2022-12-01' = {
  name: '${postgresServerName}/${managedIdentityObjectId}'
  properties: {
    tenantId: subscription().tenantId
    principalType: 'ServicePrincipal'
    principalName: managedIdentityName
  }
}

output aadUserName string = aadUser.name

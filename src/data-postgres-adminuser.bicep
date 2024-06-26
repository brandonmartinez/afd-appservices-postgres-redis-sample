// Parameters
//////////////////////////////////////////////////
@description('The name of the Postgres server.')
param postgresServerName string

@description('The identity object/principal ID.')
param identityObjectId string

@allowed([
  'Group'
  'ServicePrincipal'
  'User'
])
@description('The principal type of the identity.')
param principalType string = 'ServicePrincipal'

@description('The name of the identity')
param identityName string

// Resources
//////////////////////////////////////////////////
resource entraAdminUser 'Microsoft.DBforPostgreSQL/flexibleServers/administrators@2022-12-01' = {
  name: '${postgresServerName}/${identityObjectId}'
  properties: {
    tenantId: subscription().tenantId
    principalType: principalType
    principalName: identityName
  }
}

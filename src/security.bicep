// Parameters
//////////////////////////////////////////////////
@description('The Azure region of the resources.')
param location string

@description('Parameters specific to the security module.')
param securityModuleParameters object

@description('Tags to associate with the resources.')
param tags object

// Resources
//////////////////////////////////////////////////
resource frontDoorManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: securityModuleParameters.frontDoorManagedIdentityName
  location: location
  tags: tags
}

resource virtualMachineManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: securityModuleParameters.virtualMachineManagedIdentityName
  location: location
  tags: tags
}

resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' = {
  name: securityModuleParameters.keyVaultName
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'standard'
      family: 'A'
    }
    enabledForDeployment: true
    enabledForDiskEncryption: true
    enabledForTemplateDeployment: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
    enablePurgeProtection: true
    tenantId: subscription().tenantId
    publicNetworkAccess: 'Enabled'
    accessPolicies: []
  }
}

resource certificateBase64StringSecret 'Microsoft.KeyVault/vaults/secrets@2021-11-01-preview' = {
  parent: keyVault
  name: securityModuleParameters.certificateSecretName
  properties: {
    value: securityModuleParameters.certificateBase64String
    contentType: 'application/x-pkcs12'
  }
}

resource resourcePasswordSecret 'Microsoft.KeyVault/vaults/secrets@2022-11-01' = {
  parent: keyVault
  name: securityModuleParameters.resourcePasswordSecretName
  properties: {
    value: securityModuleParameters.resourcePassword
  }
}

resource accessPolicy 'Microsoft.KeyVault/vaults/accessPolicies@2023-02-01' = {
  parent: keyVault
  name: 'add'
  properties: {
    accessPolicies: [
      {
        objectId: frontDoorManagedIdentity.properties.principalId
        tenantId: subscription().tenantId
        permissions: {
          certificates: ['get']
          keys: ['get', 'unwrapKey', 'wrapKey']
          secrets: ['get']
        }
      }
      {
        objectId: virtualMachineManagedIdentity.properties.principalId
        tenantId: subscription().tenantId
        permissions: {
          certificates: ['get']
          secrets: ['get']
        }
      }
    ]
  }
}

// Outputs
//////////////////////////////////////////////////
output frontDoorManagedIdentityId string = frontDoorManagedIdentity.id
output virtualMachineManagedIdentityId string = virtualMachineManagedIdentity.id

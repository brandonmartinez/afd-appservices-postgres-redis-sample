// Parameters
//////////////////////////////////////////////////
@description('The Azure region of the resources.')
param location string

@description('Parameters specific to the security module.')
param parameters object

@description('Tags to associate with the resources.')
param tags object

// Resources
//////////////////////////////////////////////////
resource frontDoorManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: parameters.frontDoorManagedIdentityName
  location: location
  tags: tags
}

resource redisManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: parameters.redisManagedIdentityName
  location: location
  tags: tags
}

resource appServiceManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: parameters.appServiceManagedIdentityName
  location: location
  tags: tags
}

resource postgresManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: parameters.postgresManagedIdentityName
  location: location
  tags: tags
}

resource storageManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: parameters.storageManagedIdentityName
  location: location
  tags: tags
}

resource virtualMachineManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: parameters.virtualMachineManagedIdentityName
  location: location
  tags: tags
}

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: parameters.keyVaultName
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

resource certificateBase64StringSecret 'Microsoft.KeyVault/vaults/secrets@2021-11-01-preview' =
  if (!parameters.useManagedCertificate) {
    parent: keyVault
    name: parameters.certificateSecretName
    properties: {
      value: parameters.certificateBase64String
      contentType: 'application/x-pkcs12'
    }
  }

resource resourcePasswordSecret 'Microsoft.KeyVault/vaults/secrets@2022-11-01' = {
  parent: keyVault
  name: parameters.resourcePasswordSecretName
  properties: {
    value: parameters.resourcePassword
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
          certificates: ['get', 'import']
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
      {
        objectId: appServiceManagedIdentity.properties.principalId
        tenantId: subscription().tenantId
        permissions: {
          certificates: ['get']
          secrets: ['get']
        }
      }
    ]
  }
}

resource deploymentScript 'Microsoft.Resources/deploymentScripts@2023-08-01' =
  if (parameters.uploadCertificate && !parameters.useManagedCertificate) {
    name: '${parameters.certificateSecretName}-importCertificate'
    dependsOn: [
      accessPolicy
    ]
    kind: 'AzureCLI'
    location: location
    identity: {
      type: 'UserAssigned'
      userAssignedIdentities: {
        '${frontDoorManagedIdentity.id}': {}
      }
    }
    properties: {
      azCliVersion: '2.54.0'
      scriptContent: '''
      echo "$CERTIFICATE_BASE64" | base64 -d > certificate.pfx
      az keyvault certificate import --vault-name "$KEY_VAULT_NAME" --name "$CERTIFICATE_NAME" --file certificate.pfx --password "$CERTIFICATE_PASSWORD"
    '''
      environmentVariables: [
        {
          name: 'KEY_VAULT_NAME'
          value: keyVault.name
        }
        {
          name: 'CERTIFICATE_BASE64'
          value: parameters.certificateBase64String
        }
        {
          name: 'CERTIFICATE_NAME'
          value: parameters.certificateCertificateName
        }
        {
          name: 'CERTIFICATE_PASSWORD'
          value: parameters.certificatePassword
        }
      ]
      timeout: 'PT5M'
      retentionInterval: 'P1D'
    }
  }

// Outputs
//////////////////////////////////////////////////
output frontDoorManagedIdentityId string = frontDoorManagedIdentity.id
output virtualMachineManagedIdentityId string = virtualMachineManagedIdentity.id

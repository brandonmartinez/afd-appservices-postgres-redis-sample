// Parameters
//////////////////////////////////////////////////
@description('The Azure region of the resources.')
param location string

@description('Parameters specific to this module.')
param parameters object

@description('Tags to associate with the resources.')
param tags object

@description('Deploy the Storage Account Private Endpoint approval workflow.')
param deployDataStoragePrivateEndpointApproval bool = false

// Resources
//////////////////////////////////////////////////
resource virtualNetwork 'Microsoft.Network/virtualNetworks@2023-09-01' existing = {
  name: parameters.virtualNetworkName
  resource virtualMachineSubnet 'subnets@2023-09-01' existing = {
    name: parameters.virtualMachineSubnetName
  }
  resource storageSubnet 'subnets@2023-09-01' existing = {
    name: parameters.storageSubnetName
  }
}

resource frontDoorProfile 'Microsoft.Cdn/profiles@2022-11-01-preview' existing = {
  name: parameters.frontDoorProfileName
}

resource frontDoorEndpoint 'Microsoft.Cdn/profiles/afdEndpoints@2021-06-01' existing = {
  parent: frontDoorProfile
  name: parameters.frontDoorEndpointName
}

resource frontDoorCertificateSecret 'Microsoft.Cdn/profiles/secrets@2023-05-01' existing =
  if (!parameters.frontDoorUseManagedCertificate) {
    parent: frontDoorProfile
    name: parameters.frontDoorCertificateSecretName
  }

resource frontDoorRuleSet 'Microsoft.Cdn/profiles/ruleSets@2023-07-01-preview' existing = {
  parent: frontDoorProfile
  name: parameters.frontDoorRuleSetName
}

resource storageManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: parameters.storageManagedIdentityName
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: parameters.storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  tags: tags
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: true
    allowSharedKeyAccess: true
    minimumTlsVersion: 'TLS1_2'
    dnsEndpointType: 'Standard'
    defaultToOAuthAuthentication: false
    supportsHttpsTrafficOnly: true
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
      ipRules: [
        {
          action: 'Allow'
          value: parameters.storageAccountAllowedIpAddress
        }
      ]
      virtualNetworkRules: [
        {
          action: 'Allow'
          id: virtualNetwork::virtualMachineSubnet.id
        }
      ]
    }
    encryption: {
      requireInfrastructureEncryption: false
      services: {
        file: {
          keyType: 'Account'
          enabled: true
        }
        blob: {
          keyType: 'Account'
          enabled: true
        }
      }
      keySource: 'Microsoft.Storage'
    }
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${storageManagedIdentity.id}': {}
    }
  }
}

@description('This is the built-in Storage Blob Data Contributor role. See https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#storage')
resource storageBlobDataContributorRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b'
}

resource storageManagedIdentityRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: storageAccount
  name: guid(storageAccount.id, storageManagedIdentity.id, storageBlobDataContributorRoleDefinition.id)
  properties: {
    roleDefinitionId: storageBlobDataContributorRoleDefinition.id
    principalId: storageManagedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource storageEntraUserRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: storageAccount
  name: guid(storageAccount.id, parameters.entraUserObjectId, storageBlobDataContributorRoleDefinition.id)
  properties: {
    roleDefinitionId: storageBlobDataContributorRoleDefinition.id
    principalId: parameters.entraUserObjectId
    principalType: 'User'
  }
}

resource storageAccountContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-09-01' = {
  #disable-next-line use-parent-property
  name: '${storageAccount.name}/default/images'
  properties: {
    publicAccess: 'Blob'
  }
}

module storageFrontDoorSite 'networking-frontdoor-site.bicep' = {
  name: parameters.storageFrontDoorSiteDeploymentName
  params: {
    location: location
    certificateSecretId: (!parameters.frontDoorUseManagedCertificate) ? frontDoorCertificateSecret.id : null
    dnsZoneName: parameters.frontDoorDnsZoneName
    endpointHostName: frontDoorEndpoint.properties.hostName
    endpointName: frontDoorEndpoint.name
    privateEndpointResourceId: storageAccount.id
    privateEndpointResourceType: 'blob'
    profileName: frontDoorProfile.name
    ruleSetId: frontDoorRuleSet.id
    usePrivateLink: true
    useManagedCertificate: parameters.frontDoorUseManagedCertificate
    parameters: parameters.storageFrontDoorSite
  }
}

module storagePrivateEndpoint 'data-storage-pew.bicep' =
  if (deployDataStoragePrivateEndpointApproval) {
    name: parameters.storagePrivateEndpointWorkflowDeploymentName
    dependsOn: [
      storageAccount
      storageFrontDoorSite
    ]
    params: {
      parameters: parameters
    }
  }

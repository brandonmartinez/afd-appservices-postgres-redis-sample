// Parameters
//////////////////////////////////////////////////
@description('Parameters specific to this module.')
param parameters object

@description('Tags to associate with the resources.')
param tags object

// Resources
//////////////////////////////////////////////////
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: parameters.keyVaultName
  resource certificateSecret 'secrets' existing = {
    name: parameters.certificateCertificateName
  }
}

resource frontDoorManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: parameters.frontDoorManagedIdentityName
}

resource wafPolicy 'Microsoft.Network/FrontDoorWebApplicationFirewallPolicies@2022-05-01' = {
  name: parameters.frontDoorWafPolicyName
  location: 'global'
  tags: tags
  sku: {
    name: 'Standard_AzureFrontDoor'
  }
  properties: {
    policySettings: {
      enabledState: 'Enabled'
      mode: 'Detection'
    }
  }
}

resource profile 'Microsoft.Cdn/profiles@2022-11-01-preview' = {
  name: parameters.frontDoorProfileName
  location: 'global'
  tags: tags
  sku: {
    name: 'Standard_AzureFrontDoor'
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${frontDoorManagedIdentity.id}': {}
    }
  }
}

resource endpoint 'Microsoft.Cdn/profiles/afdEndpoints@2021-06-01' = {
  parent: profile
  name: parameters.frontDoorEndpointName
  location: 'global'
  properties: {
    enabledState: 'Enabled'
  }
}

resource securityPolicy 'Microsoft.Cdn/profiles/securityPolicies@2021-06-01' = {
  parent: profile
  name: parameters.frontDoorSecurityPolicyName
  properties: {
    parameters: {
      type: 'WebApplicationFirewall'
      wafPolicy: {
        id: wafPolicy.id
      }
      associations: [
        {
          domains: [
            {
              id: endpoint.id
            }
          ]
          patternsToMatch: [
            '/*'
          ]
        }
      ]
    }
  }
}

resource frontDoorCertificateSecret 'Microsoft.Cdn/profiles/secrets@2023-05-01' = {
  parent: profile
  name: parameters.frontDoorCertificateSecretName
  properties: {
    parameters: {
      type: 'CustomerCertificate'
      useLatestVersion: true
      secretSource: {
        id: keyVault::certificateSecret.id
      }
    }
  }
}

resource frontDoorRuleSet 'Microsoft.Cdn/profiles/ruleSets@2023-07-01-preview' = {
  name: parameters.frontDoorRuleSetName
  parent: profile
}

resource frontDoorRules 'Microsoft.Cdn/profiles/ruleSets/rules@2023-07-01-preview' = {
  name: parameters.frontDoorRulesName
  parent: frontDoorRuleSet
  properties: {
    actions: [
      {
        name: 'ModifyResponseHeader'
        parameters: {
          headerAction: 'Overwrite'
          headerName: 'Strict-Transport-Security'
          typeName: 'DeliveryRuleHeaderActionParameters'
          value: 'max-age=31536000; includeSubDomains; preload'
        }
      }
    ]
    conditions: [

    ]
    matchProcessingBehavior: 'Continue'
    order: 1
  }
}

module frontDoorSites 'networking-frontdoor-site.bicep' = [
  for (site, i) in parameters.frontDoorSites: {
    name: replace(parameters.frontDoorSitesDeploymentNameTemplate, '$NUMBER', string(i))
    params: {
      profileName: parameters.frontDoorProfileName
      dnsZoneName: parameters.dnsZoneName
      endpointName: parameters.frontDoorEndpointName
      endpointHostName: endpoint.properties.hostName
      certificateSecretId: frontDoorCertificateSecret.id
      ruleSetId: frontDoorRuleSet.id
      parameters: site
    }
  }
]

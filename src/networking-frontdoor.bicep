// Parameters
//////////////////////////////////////////////////
@description('Parameters specific to this module.')
param parameters object

@description('Tags to associate with the resources.')
param tags object

@description('Deploy diagnostic logs for Front Door.')
param deployFrontDoorDiagnostics bool

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

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: parameters.logAnalyticsWorkspaceName
}

resource wafPolicy 'Microsoft.Network/FrontDoorWebApplicationFirewallPolicies@2022-05-01' = {
  name: parameters.frontDoorWafPolicyName
  location: 'global'
  tags: tags
  sku: {
    name: 'Premium_AzureFrontDoor'
  }
  properties: {
    policySettings: {
      enabledState: 'Enabled'
      mode: 'Detection'
    }
    managedRules: {
      managedRuleSets: [
        {
          ruleSetType: 'Microsoft_BotManagerRuleSet'
          ruleSetVersion: '1.0'
        }
      ]
    }
    customRules: {
      rules: [
        {
          name: 'ApplyRateLimit'
          priority: 100
          enabledState: 'Enabled'
          ruleType: 'RateLimitRule'
          rateLimitThreshold: 100
          rateLimitDurationInMinutes: 1
          action: 'Block'
          matchConditions: [
            // Currently Front Door requires that a rate limit rule has a match condition. This specifies the subset
            // of requests it should apply to. For this sample, we are using an IP address-based match condition
            // and setting the value to "not 192.0.2.0/24". This is an IANA documentation range and no real clients
            // will use that range, so this match condition effectively matches all requests.
            // Note that the rate limit is applied per IP address.
            {
              matchVariable: 'RemoteAddr'
              operator: 'IPMatch'
              negateCondition: true
              matchValue: [
                '192.0.2.0/24'
              ]
            }
          ]
        }
      ]
    }
  }
}

resource profile 'Microsoft.Cdn/profiles@2022-11-01-preview' = {
  name: parameters.frontDoorProfileName
  location: 'global'
  tags: tags
  sku: {
    name: 'Premium_AzureFrontDoor'
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

resource frontDoorCertificateSecret 'Microsoft.Cdn/profiles/secrets@2023-05-01' =
  if (!parameters.frontDoorUseManagedCertificate) {
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
  parent: profile
  name: parameters.frontDoorRuleSetName
}

resource frontDoorRules 'Microsoft.Cdn/profiles/ruleSets/rules@2023-07-01-preview' = {
  parent: frontDoorRuleSet
  name: parameters.frontDoorRulesName
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
    conditions: []
    matchProcessingBehavior: 'Continue'
    order: 1
  }
}

resource frontDoorDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' =
  if (deployFrontDoorDiagnostics) {
    scope: profile
    name: '${profile.name}-diagnostics'
    properties: {
      workspaceId: logAnalyticsWorkspace.id
      logs: [
        {
          categoryGroup: 'AllLogs'
          enabled: true
        }
      ]
      metrics: [
        {
          category: 'AllMetrics'
          enabled: true
        }
      ]
    }
  }

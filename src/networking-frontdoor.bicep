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
      mode: 'Prevention'
    }
    managedRules: {
      managedRuleSets: [
        {
          ruleSetType: 'Microsoft_DefaultRuleSet'
          ruleSetVersion: '2.1'
          ruleSetAction: 'Block'
        }
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
          rateLimitDurationInMinutes: 5
          action: 'Block'
          matchConditions: [
            {
              matchVariable: 'SocketAddr'
              operator: 'IPMatch'
              negateCondition: false
              matchValue: [
                '0.0.0.0'
                '::/0'
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

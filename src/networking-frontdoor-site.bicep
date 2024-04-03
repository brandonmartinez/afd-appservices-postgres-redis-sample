// Parameters
//////////////////////////////////////////////////
@description('The Azure region of the resources.')
param location string

@description('The Profile Name from Front Door.')
param profileName string

@description('The DNS Zone Name from Front Door.')
param dnsZoneName string

@description('The Endpoint Name from Front Door.')
param endpointName string

@description('The Host Name of the Endpoint from Front Door.')
param endpointHostName string

@description('The Id of the Rule Set of the Profile from Front Door.')
param ruleSetId string

@description('If a Private Link should be configured for the site.')
param usePrivateLink bool = false

@description('The Private Link Resource Id.')
param privateEndpointResourceId string = ''

@description('The Private Link Resource Type.')
param privateEndpointResourceType string = ''

@secure()
@description('The Certificate Secret Id from Front Door.')
param certificateSecretId string = ''

@description('Whether to use the Front Door Managed Certificate or Key Vault Secret.')
param useManagedCertificate bool = true

@description('Parameters specific to this module.')
param parameters object

// Resources
//////////////////////////////////////////////////
resource profile 'Microsoft.Cdn/profiles@2023-05-01' existing = {
  name: profileName
}

resource endpoint 'Microsoft.Cdn/profiles/afdEndpoints@2023-05-01' existing = {
  parent: profile
  name: endpointName
}

resource originGroup 'Microsoft.Cdn/profiles/originGroups@2023-05-01' = {
  parent: profile
  name: parameters.originGroupName
  properties: {
    loadBalancingSettings: {
      sampleSize: 4
      successfulSamplesRequired: 3
    }
    healthProbeSettings: {
      probePath: parameters.originGroupHealthProbePath
      probeRequestType: 'HEAD'
      probeProtocol: 'Https'
      probeIntervalInSeconds: 100
    }
  }
}

resource origin 'Microsoft.Cdn/profiles/originGroups/origins@2023-07-01-preview' = {
  parent: originGroup
  name: parameters.originName
  properties: {
    hostName: parameters.originHostName
    httpPort: 80
    httpsPort: 443
    originHostHeader: parameters.originHostName
    priority: 1
    weight: 1000
    sharedPrivateLinkResource: usePrivateLink
      ? {
          privateLink: {
            id: privateEndpointResourceId
          }
          groupId: privateEndpointResourceType
          privateLinkLocation: location
          requestMessage: 'Created by Deployment Pipeline'
          status: 'Approved'
        }
      : null
  }
}

resource customDomain 'Microsoft.Cdn/profiles/customDomains@2021-06-01' = {
  parent: profile
  name: parameters.customDomainName
  properties: {
    hostName: parameters.customDomain
    tlsSettings: {
      certificateType: (useManagedCertificate) ? 'ManagedCertificate' : 'CustomerCertificate'
      minimumTlsVersion: 'TLS12'
      secret: (useManagedCertificate)
        ? null
        : {
            id: certificateSecretId
          }
    }
  }
}

resource route 'Microsoft.Cdn/profiles/afdEndpoints/routes@2021-06-01' = {
  parent: endpoint
  name: parameters.routeName
  dependsOn: [
    // This explicit dependency is required to ensure that the origin group is not empty when the route is created.
    origin
  ]
  properties: {
    customDomains: [
      {
        id: customDomain.id
      }
    ]
    originGroup: {
      id: originGroup.id
    }
    supportedProtocols: [
      'Http'
      'Https'
    ]
    patternsToMatch: [
      '/*'
    ]
    forwardingProtocol: 'HttpsOnly'
    linkToDefaultDomain: 'Disabled'
    httpsRedirect: 'Enabled'
    ruleSets: [
      {
        id: ruleSetId
      }
    ]
  }
}

resource dnsCnameRecord 'Microsoft.Network/dnsZones/CNAME@2018-05-01' = {
  name: '${dnsZoneName}/${parameters.customDomainPrefix}'
  properties: {
    TTL: 3600
    CNAMERecord: {
      cname: endpointHostName
    }
  }
}

module appServiceDnsTxtRecord 'networking-frontdoor-site-domainvalidation.bicep' =
  if (useManagedCertificate) {
    name: parameters.customDomainValidationDeploymentName
    params: {
      dnsZoneName: dnsZoneName
      customDomainName: customDomain.name
      customDomainPrefix: parameters.customDomainPrefix
      profileName: profile.name
    }
  }

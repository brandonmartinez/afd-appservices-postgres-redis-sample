// Parameters
//////////////////////////////////////////////////
@description('The Profile Name from Front Door.')
param profileName string

@description('The DNS Zone Name from Front Door.')
param dnsZoneName string

@description('The Endpoint Name from Front Door.')
param endpointName string

@description('The Host Name of the Endpoint from Front Door.')
param endpointHostName string

@secure()
@description('The Certificate Secret Id from Front Door.')
param certificateSecretId string

@description('Parameters specific to this module.')
param parameters object

// Resources
//////////////////////////////////////////////////
resource profile 'Microsoft.Cdn/profiles@2022-11-01-preview' existing = {
  name: profileName
}

resource endpoint 'Microsoft.Cdn/profiles/afdEndpoints@2021-06-01' existing = {
  parent: profile
  name: endpointName
}

resource originGroup 'Microsoft.Cdn/profiles/originGroups@2021-06-01' = {
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

resource origin 'Microsoft.Cdn/profiles/originGroups/origins@2021-06-01' = {
  parent: originGroup
  name: parameters.originName
  properties: {
    hostName: parameters.originHostName
    httpPort: 80
    httpsPort: 443
    originHostHeader: parameters.originHostName
    priority: 1
    weight: 1000
  }
}

resource customDomain 'Microsoft.Cdn/profiles/customDomains@2021-06-01' = {
  parent: profile
  name: parameters.customDomainName
  properties: {
    hostName: parameters.customDomain
    tlsSettings: {
      certificateType: 'CustomerCertificate'
      minimumTlsVersion: 'TLS12'
      secret: {
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
    forwardingProtocol: 'MatchRequest'
    linkToDefaultDomain: 'Disabled'
    httpsRedirect: 'Enabled'
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

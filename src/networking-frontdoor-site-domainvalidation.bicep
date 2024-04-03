@description('The Profile Name from Front Door.')
param profileName string

@description('The Custom Domain Name from Front Door.')
param customDomainName string

@description('The DNS Zone Name from Front Door.')
param dnsZoneName string

@description('The subdomain of the application.')
param customDomainPrefix string

resource profile 'Microsoft.Cdn/profiles@2023-05-01' existing = {
  name: profileName
}

resource customDomain 'Microsoft.Cdn/profiles/customDomains@2021-06-01' existing = {
  parent: profile
  name: customDomainName
}

resource appServiceDnsTxtRecord 'Microsoft.Network/dnsZones/TXT@2018-05-01' = {
  name: '${dnsZoneName}/_dnsauth.${customDomainPrefix}'
  properties: {
    TTL: 3600
    TXTRecords: [
      {
        value: [
          customDomain.properties.validationProperties.validationToken
        ]
      }
    ]
  }
}

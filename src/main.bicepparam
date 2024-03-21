using '../src/main.bicep'

// Injected Variables from Pipeline
//////////////////////////////////////////////////
var appenv = readEnvironmentVariable('AZURE_APPENV', '')
var certificateBase64String = readEnvironmentVariable('CERTIFICATE_BASE64_STRING', '')
var currentDateTime = readEnvironmentVariable('CURRENT_DATE_TIME', '')
var publicIpAddress = readEnvironmentVariable('PUBLIC_IP_ADDRESS', '')
var rootDomain = readEnvironmentVariable('ROOT_DOMAIN', '')
var uploadCertificate = readEnvironmentVariable('UPLOAD_CERTIFICATE', 'true')

// Note: it's not generally recommended to store passwords here, use key vault instead
// https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/key-vault-parameter
var resourcePassword = readEnvironmentVariable('AZURE_RESOURCE_PASSWORD', '')
var certificatePassword = readEnvironmentVariable('CERTIFICATE_PASSWORD', '')

// Shared Module Variables
//////////////////////////////////////////////////
var appServiceWebAppName = 'app-${appenv}-webapp'
var appServiceWebAppHostName = '${appServiceWebAppName}.azurewebsites.net'
var storageName = replace('sa-${appenv}-web', '-', '')
// var storageHostName = '${storageName}.blob.${environment().suffixes.storage}'
#disable-next-line no-hardcoded-env-urls
var storageHostName = '${storageName}.blob.core.windows.net'
var keyVaultName = 'kv-${appenv}'
var certificateSecretName = 'secret-cert-${appenv}'
var certificateCertificateName = 'certificate-${appenv}'
var frontDoorManagedIdentityName = 'id-${appenv}-frontdoor'

// Parameters
//////////////////////////////////////////////////
param location = readEnvironmentVariable('AZURE_LOCATION', '')

// Module Parameters
//////////////////////////////////////////////////
param tags = {
  deploymentDate: currentDateTime
  environment: appenv
}

param managementModuleParameters = {
  deploymentName: 'az-management-${currentDateTime}'

  // Log Analytics Workspace Variables
  logAnalyticsWorkspaceName: 'log-${appenv}'

  // Application Insights Variables
  applicationInsightsName: 'appinsights-${appenv}'
}

param securityModuleParameters = {
  deploymentName: 'az-security-${currentDateTime}'

  // Managed Identity Variables
  frontDoorManagedIdentityName: frontDoorManagedIdentityName
  virtualMachineManagedIdentityName: 'id-${appenv}-virtualmachine'

  // Key Vault Variables
  keyVaultName: keyVaultName
  certificateBase64String: certificateBase64String
  certificateCertificateName: certificateCertificateName
  certificatePassword: certificatePassword
  certificateSecretName: certificateSecretName
  resourcePassword: resourcePassword
  resourcePasswordSecretName: 'password-${appenv}'
  uploadCertificate: uploadCertificate
}

param networkingModuleParameters = {
  deploymentName: 'az-networking-${currentDateTime}'
  bastionDeploymentName: 'az-bastion-${currentDateTime}'
  frontDoorManagedIdentityName: frontDoorManagedIdentityName
  frontDoorDeploymentName: 'az-frontdoor-${currentDateTime}'
  frontDoorSitesDeploymentNameTemplate: 'az-frontdoor-site$NUMBER-${currentDateTime}'

  // General Variables
  publicIpAddress: publicIpAddress
  keyVaultName: keyVaultName
  certificateSecretName: certificateSecretName
  certificateCertificateName: certificateCertificateName

  // NSG Variables
  bastionNetworkSecurityGroupName: 'nsg-${appenv}-bastion'
  vnetIntegrationNetworkSecurityGroupName: 'nsg-${appenv}-vnetintegration'

  // NAT Gateway Variables
  natGatewayPublicIpPrefixName: 'pipp-${appenv}-ngw'
  natGatewayName: 'ngw-${appenv}'

  // Virtual Network Variables
  virtualNetworkName: 'vnet-${appenv}'
  virtualNetworkPrefix: '10.0.0.0/16'

  // Virtual Network Subnet Variables
  appServicesSubnetName: 'app-services'
  appServicesSubnetAddressPrefix: '10.0.1.0/24'
  bastionSubnetName: 'AzureBastionSubnet' // Must be this name: https://learn.microsoft.com/en-us/azure/bastion/configuration-settings#subnet
  bastionSubnetAddressPrefix: '10.0.200.0/24'

  // Bastion Variables
  bastionPublicIpAddressName: 'pip-${appenv}-bastion'
  bastionName: 'bastion-${appenv}'

  // Front Door Variables
  frontDoorWafPolicyName: replace('wafpolicy-${appenv}', '-', '')
  frontDoorProfileName: 'afd-${appenv}'
  frontDoorEndpointName: 'fde-${appenv}'
  frontDoorSecurityPolicyName: 'securitypolicy-${appenv}'
  frontDoorCertificateSecretName: 'secret-${appenv}-certificate'

  frontDoorSites: [
    {
      originGroupName: 'origingroup-${appenv}-webapp'
      originGroupHealthProbePath: '/'
      originName: 'origin-${appenv}-webapp'
      originHostName: appServiceWebAppHostName
      customDomainName: 'domainname-${appenv}-webapp'
      customDomain: 'www.${rootDomain}'
      routeName: 'route-${appenv}-webapp'
    }
    {
      originGroupName: 'origingroup-${appenv}-storage'
      originGroupHealthProbePath: '/'
      originName: 'origin-${appenv}-storage'
      originHostName: storageHostName
      customDomainName: 'domainname-${appenv}-storage'
      customDomain: 'assets.${rootDomain}'
      routeName: 'route-${appenv}-storage'
    }
  ]
}

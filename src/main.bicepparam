using '../src/main.bicep'

// Injected Variables from Pipeline
//////////////////////////////////////////////////
var appenv = readEnvironmentVariable('AZURE_APPENV', '')
var certificateBase64String = readEnvironmentVariable('CERTIFICATE_BASE64_STRING', '')
var currentDateTime = readEnvironmentVariable('CURRENT_DATE_TIME', '')
var publicIpAddress = readEnvironmentVariable('PUBLIC_IP_ADDRESS', '')
var rootDomain = readEnvironmentVariable('ROOT_DOMAIN', '')
var uploadCertificate = readEnvironmentVariable('UPLOAD_CERTIFICATE', 'true')
var resourceUserName = readEnvironmentVariable('AZURE_RESOURCE_USERNAME', 'bicep')
var entraUserEmail = readEnvironmentVariable('ENTRA_USER_EMAIL', 'bicep')
var entraUserObjectId = readEnvironmentVariable('ENTRA_USER_OBJECTID', 'bicep')

// Note: it's not generally recommended to store passwords here, use key vault instead
// https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/key-vault-parameter
var resourcePassword = readEnvironmentVariable('AZURE_RESOURCE_PASSWORD', '')
var certificatePassword = readEnvironmentVariable('CERTIFICATE_PASSWORD', '')

// Shared Module Variables
//////////////////////////////////////////////////
var appServiceWebAppName = 'app-${appenv}-webapp'
var appServiceWebAppHostName = '${appServiceWebAppName}.azurewebsites.net'
var storageAccountName = replace('sa-${appenv}-web', '-', '')

var conditionalVariables = {
  deployManagement: readEnvironmentVariable('DEPLOY_MANAGEMENT', 'true')
  deploySecurity: readEnvironmentVariable('DEPLOY_SECURITY', 'true')
  deployNetworking: readEnvironmentVariable('DEPLOY_NETWORKING', 'true')
  deployData: readEnvironmentVariable('DEPLOY_DATA', 'true')
  deployCompute: readEnvironmentVariable('DEPLOY_COMPUTE', 'true')
}

// TODO: when there's support for environment(), use that
// var storageAccountHostName = '${storageAccountName}.blob.${environment().suffixes.storage}'
#disable-next-line no-hardcoded-env-urls
var storageAccountHostName = '${storageAccountName}.blob.core.windows.net'

var managementVariables = {
  deploymentName: 'az-management-${currentDateTime}'

  // Log Analytics Workspace Variables
  logAnalyticsWorkspaceName: 'log-${appenv}'

  // Application Insights Variables
  applicationInsightsName: 'appinsights-${appenv}'
}

var securityVariables = {
  deploymentName: 'az-security-${currentDateTime}'

  // Managed Identity Variables
  appServiceManagedIdentityName: 'id-${appenv}-appservice'
  frontDoorManagedIdentityName: 'id-${appenv}-frontdoor'
  postgresManagedIdentityName: 'id-${appenv}-postgres'
  redisManagedIdentityName: 'id-${appenv}-redis'
  virtualMachineManagedIdentityName: 'id-${appenv}-virtualmachine'

  // Key Vault Variables
  keyVaultName: 'kv-${appenv}'
  certificateBase64String: certificateBase64String
  certificateCertificateName: 'certificate-${appenv}'
  certificatePassword: certificatePassword
  certificateSecretName: 'secret-cert-${appenv}'
  resourcePassword: resourcePassword
  resourcePasswordSecretName: 'password-${appenv}'
  uploadCertificate: uploadCertificate
}

var networkingVariables = {
  deploymentName: 'az-networking-${currentDateTime}'
  bastionDeploymentName: 'az-bastion-${currentDateTime}'
  frontDoorDeploymentName: 'az-frontdoor-${currentDateTime}'
  frontDoorSitesDeploymentNameTemplate: 'az-frontdoor-site$NUMBER-${currentDateTime}'

  // General Variables
  publicIpAddress: publicIpAddress
  keyVaultName: securityVariables.keyVaultName
  certificateSecretName: securityVariables.certificateSecretName
  certificateCertificateName: securityVariables.certificateCertificateName

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
  postgresSubnetName: 'postgres'
  postgresSubnetAddressPrefix: '10.0.2.0/24'
  storageSubnetName: 'storage'
  storageSubnetAddressPrefix: '10.0.3.0/24'
  redisSubnetName: 'redis'
  redisSubnetAddressPrefix: '10.0.4.0/24'
  virtualMachineSubnetName: 'virtual-machine'
  virtualMachineSubnetAddressPrefix: '10.0.5.0/24'
  bastionSubnetName: 'AzureBastionSubnet' // Must be this name: https://learn.microsoft.com/en-us/azure/bastion/configuration-settings#subnet
  bastionSubnetAddressPrefix: '10.0.200.0/24'

  // DNS Variables
  dnsZoneName: rootDomain

  // Bastion Variables
  bastionPublicIpAddressName: 'pip-${appenv}-bastion'
  bastionName: 'bastion-${appenv}'

  // Front Door Variables
  frontDoorCertificateSecretName: 'secret-${appenv}-certificate'
  frontDoorEndpointName: 'fde-${appenv}'
  frontDoorManagedIdentityName: securityVariables.frontDoorManagedIdentityName
  frontDoorProfileName: 'afd-${appenv}'
  frontDoorRuleSetName: replace('afd-${appenv}-ruleset', '-', '')
  frontDoorRulesName: replace('afd-${appenv}-rules', '-', '')
  frontDoorSecurityPolicyName: 'securitypolicy-${appenv}'
  frontDoorWafPolicyName: replace('wafpolicy-${appenv}', '-', '')

  frontDoorSites: [
    {
      originGroupName: 'origingroup-${appenv}-webapp'
      originGroupHealthProbePath: '/'
      originName: 'origin-${appenv}-webapp'
      originHostName: appServiceWebAppHostName
      customDomainName: 'domainname-${appenv}-webapp'
      customDomain: 'www.${rootDomain}'
      customDomainPrefix: 'www'
      routeName: 'route-${appenv}-webapp'
    }
    {
      originGroupName: 'origingroup-${appenv}-storage'
      originGroupHealthProbePath: '/'
      originName: 'origin-${appenv}-storage'
      originHostName: storageAccountHostName
      customDomainName: 'domainname-${appenv}-storage'
      customDomain: 'assets.${rootDomain}'
      customDomainPrefix: 'assets'
      routeName: 'route-${appenv}-storage'
    }
  ]
}

var dataVariables = {
  deploymentName: 'az-data-${currentDateTime}'
  postgressAdminManagedIdentityDeploymentName: 'az-data-admin-mi-${currentDateTime}'
  postgressAdminUserDeploymentName: 'az-data-admin-ei-${currentDateTime}'
  redisAdminManagedIdentityDeploymentName: 'az-data-redis-admin-mi-${currentDateTime}'
  redisAdminUserDeploymentName: 'az-data-redis-admin-ei-${currentDateTime}'
  storagePrivateEndpointDeploymentName: 'az-data-storage-pe-${currentDateTime}'
  redisPrivateEndpointDeploymentName: 'az-data-redis-pe-${currentDateTime}'

  // General Variables
  virtualNetworkName: networkingVariables.virtualNetworkName

  // Postgres Variables
  postgresManagedIdentityName: securityVariables.postgresManagedIdentityName
  postgresSubnetName: networkingVariables.postgresSubnetName

  postgresServerAdminPassword: resourcePassword
  postgresServerAdminUsername: resourceUserName
  postgresServerName: 'pgdb-${appenv}-server'
  postgresServerSkuName: 'Standard_B1ms'
  postgresServerSkuTier: 'Burstable'
  postgresServerStorageSize: 128
  postgresServerVersion: '16'

  entraUserEmail: entraUserEmail
  entraUserObjectId: entraUserObjectId

  // Storage Variables
  storageAccountName: storageAccountName
  storageAccountHostName: storageAccountHostName
  storageSubnetName: networkingVariables.storageSubnetName

  // Redis Variables
  redisManagedIdentityName: securityVariables.redisManagedIdentityName
  redisCacheName: 'redis-${appenv}'
  redisSubnetName: networkingVariables.redisSubnetName

}

var computeVariables = {
  deploymentName: 'az-compute-${currentDateTime}'
  appServicesDeploymentName: 'az-compute-appservices-${currentDateTime}'
  virtualMachineDeploymentName: 'az-compute-virtualmachine-${currentDateTime}'
  frontDoorProfileName: networkingVariables.frontDoorProfileName
  postgresManagedIdentityName: securityVariables.postgresManagedIdentityName
  redisManagedIdentityName: securityVariables.redisManagedIdentityName

  // General Variables
  applicationInsightsName: managementVariables.applicationInsightsName
  storageAccountName: dataVariables.storageAccountName
  virtualNetworkName: networkingVariables.virtualNetworkName

  // App Service Variables
  appServicePlanName: 'plan-${appenv}'
  appServiceWebAppName: appServiceWebAppName
  appServiceWebAppHostName: appServiceWebAppHostName
  appServiceManagedIdentityName: securityVariables.appServiceManagedIdentityName
  appServicesSubnetName: networkingVariables.appServicesSubnetName

  postgresServerName: dataVariables.postgresServerName
  redisCacheName: dataVariables.redisCacheName

  // Virtual Machine Variables
  virtualMachineSubnetName: networkingVariables.virtualMachineSubnetName
  virtualMachineName: 'vm-${appenv}'
  virtualMachineNicName: 'vm-${appenv}-nic'
  virtualMachineOsDiskName: 'vm-${appenv}-osdisk'
  virtualMachineDataDiskName: 'vm-${appenv}-datadisk'
  virtualMachineAdminPassword: resourcePassword
  virtualMachineAdminUsername: resourceUserName
}

// Parameters
//////////////////////////////////////////////////
param location = readEnvironmentVariable('AZURE_LOCATION', '')

// Module Parameters
//////////////////////////////////////////////////
param tags = {
  deploymentDate: currentDateTime
  environment: appenv
}

param conditionalDeployment = conditionalVariables

param managementModuleParameters = managementVariables

param securityModuleParameters = securityVariables

param networkingModuleParameters = networkingVariables

param dataModuleParameters = dataVariables

param computeModuleParameters = computeVariables

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
  deployCompute: readEnvironmentVariable('DEPLOY_COMPUTE', 'true')
  deployData: readEnvironmentVariable('DEPLOY_DATA', 'true')
  deployDataPostgres: readEnvironmentVariable('DEPLOY_DATA_POSTGRES', 'true')
  deployDataRedis: readEnvironmentVariable('DEPLOY_DATA_REDIS', 'true')
  deployDataStorage: readEnvironmentVariable('DEPLOY_DATA_STORAGE', 'true')
  deployManagement: readEnvironmentVariable('DEPLOY_MANAGEMENT', 'true')
  deployNetworking: readEnvironmentVariable('DEPLOY_NETWORKING', 'true')
  deploySecurity: readEnvironmentVariable('DEPLOY_SECURITY', 'true')
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
  // Using the following pattern:
  // 10.0.x.0 - compute services
  // 10.0.4x.0 - data services
  // 10.0.2xx.0 - perimeter services
  appServicesSubnetAddressPrefix: '10.0.1.0/24'
  appServicesSubnetName: 'app-services'
  bastionSubnetAddressPrefix: '10.0.200.0/24'
  bastionSubnetName: 'AzureBastionSubnet' // Must be this name: https://learn.microsoft.com/en-us/azure/bastion/configuration-settings#subnet
  postgresSubnetAddressPrefix: '10.0.41.0/24'
  postgresSubnetName: 'postgres'
  redisSubnetAddressPrefix: '10.0.42.0/24'
  redisSubnetName: 'redis'
  storageSubnetAddressPrefix: '10.0.40.0/24'
  storageSubnetName: 'storage'
  virtualMachineSubnetAddressPrefix: '10.0.2.0/24'
  virtualMachineSubnetName: 'virtual-machine'

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
}

var dataVariables = {
  deploymentName: 'az-data-${currentDateTime}'
  postgressAdminManagedIdentityDeploymentName: 'az-data-admin-mi-${currentDateTime}'
  postgressAdminUserDeploymentName: 'az-data-admin-ei-${currentDateTime}'
  redisAdminManagedIdentityDeploymentName: 'az-data-redis-admin-mi-${currentDateTime}'
  redisAdminUserDeploymentName: 'az-data-redis-admin-ei-${currentDateTime}'
  redisPrivateEndpointDeploymentName: 'az-data-redis-pe-${currentDateTime}'
  storageFrontDoorSiteDeploymentName: 'az-data-storage-fds-${currentDateTime}'
  storagePrivateEndpointDeploymentName: 'az-data-storage-pe-${currentDateTime}'
  storagePrivateEndpointApprovalDeploymentName: 'az-data-storage-pea-${currentDateTime}'

  // Existing Resource References
  frontDoorCertificateSecretName: networkingVariables.frontDoorCertificateSecretName
  frontDoorDnsZoneName: networkingVariables.dnsZoneName
  frontDoorEndpointName: networkingVariables.frontDoorEndpointName
  frontDoorProfileName: networkingVariables.frontDoorProfileName
  frontDoorRuleSetName: networkingVariables.frontDoorRuleSetName

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
  storageAccountAllowedIpAddress: publicIpAddress
  storageFrontDoorSite: {
    customDomain: 'assets.${rootDomain}'
    customDomainName: 'domainname-${appenv}-storage'
    customDomainPrefix: 'assets'
    originGroupHealthProbePath: '/'
    originGroupName: 'origingroup-${appenv}-storage'
    originHostName: storageAccountHostName
    originName: 'origin-${appenv}-storage'
    routeName: 'route-${appenv}-storage'
  }

  // Redis Variables
  redisManagedIdentityName: securityVariables.redisManagedIdentityName
  redisCacheName: 'redis-${appenv}'
  redisSubnetName: networkingVariables.redisSubnetName
}

var computeVariables = {
  deploymentName: 'az-compute-${currentDateTime}'
  appServicesDeploymentName: 'az-compute-appservices-${currentDateTime}'
  appServiceFrontDoorSiteDeploymentName: 'az-compute-appservices-fds-${currentDateTime}'
  appServicesPrivateEndpointDeploymentName: 'az-compute-appservices-pe-${currentDateTime}'
  virtualMachineDeploymentName: 'az-compute-virtualmachine-${currentDateTime}'

  // Existing Resource References
  frontDoorCertificateSecretName: networkingVariables.frontDoorCertificateSecretName
  frontDoorDnsZoneName: networkingVariables.dnsZoneName
  frontDoorEndpointName: networkingVariables.frontDoorEndpointName
  frontDoorProfileName: networkingVariables.frontDoorProfileName
  frontDoorRuleSetName: networkingVariables.frontDoorRuleSetName
  postgresManagedIdentityName: securityVariables.postgresManagedIdentityName
  postgresServerName: dataVariables.postgresServerName
  redisCacheName: dataVariables.redisCacheName
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
  appServicesFrontDoorSite: {
    customDomain: 'www.${rootDomain}'
    customDomainName: 'domainname-${appenv}-webapp'
    customDomainPrefix: 'www'
    originGroupHealthProbePath: '/'
    originGroupName: 'origingroup-${appenv}-webapp'
    originHostName: appServiceWebAppHostName
    originName: 'origin-${appenv}-webapp'
    routeName: 'route-${appenv}-webapp'
  }

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

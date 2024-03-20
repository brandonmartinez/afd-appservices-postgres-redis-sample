using '../src/main.bicep'

param currentDateTime = '$CURRENT_DATE_TIME'
param location = '$AZURE_LOCATION'
param appenv = '$AZURE_APPENV'
param publicIpAddress = '$PUBLIC_IP_ADDRESS'
param certificateBase64String = '$CERTIFICATE_BASE64_STRING'
// Note: it's not generally recommended to store passwords here, use key vault instead
// https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/key-vault-parameter
param resourcePassword = '$AZURE_RESOURCE_PASSWORD'

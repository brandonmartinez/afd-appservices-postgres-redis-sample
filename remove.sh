#!/usr/bin/env bash

set -eo pipefail

export ENV_FILE="${1:-.env}"

export CURRENT_DATE_TIME=$(date +"%Y%m%dT%H%M")

if [ "$ENV_FILE" = ".env" ]; then
    export LOG_FILE_NAME="remove-$CURRENT_DATE_TIME.log"
else
    SUBLOG=$(echo "$ENV_FILE" | awk -F '.' '{print $NF}')
    export LOG_FILE_NAME="$SUBLOG-remove-$CURRENT_DATE_TIME.log"
fi

source ./logging.sh

if [ ! -f $ENV_FILE ]; then
    cp .envsample $ENV_FILE
    warn "Update $ENV_FILE with parameter values and run again"
    exit 1
fi

debug "Sourcing $ENV_FILE file"

set -a

# pulling from the .env file
source $ENV_FILE
# some other exports that are used
export AZURE_RESOURCEGROUP="rg-$AZURE_APPENV"

set +a

section "Configuring AZ CLI"

if ! az account show &> /dev/null; then
    az login
fi

info "Setting Azure subscription to $AZURE_SUBSCRIPTIONID"
az account set --subscription "$AZURE_SUBSCRIPTIONID"

info "Setting default location to $AZURE_LOCATION and resource group to $AZURE_RESOURCEGROUP"
az configure --defaults location="$AZURE_LOCATION" group="$AZURE_RESOURCEGROUP"

section "Removing Azure Infrastructure"

warn "This will remove all resources in the resource group $AZURE_RESOURCEGROUP"
warn "and any other resources created. Are you sure you want to continue? y/n"

read -r response
response=$(echo "$response" | tr '[:upper:]' '[:lower:]') # convert response to lowercase

if [[ $response == "n" || $response == "no" ]]; then
    warn "Removal cancelled. Exiting."
    exit 0
elif [[ $response == "y" || $response == "yes" ]]; then
    info "Removal confirmed, proceeding..."
else
    error "Invalid response. Exiting."
    exit 1
fi

VNETINTEGRATION_URI="https://ms.portal.azure.com/#view/WebsitesExtension/VnetIntegration.ReactView/resourceUri/%2Fsubscriptions%2F$AZURE_SUBSCRIPTIONID%2FresourceGroups%2F$AZURE_RESOURCEGROUP%2Fproviders%2FMicrosoft.Web%2Fsites%2Fapp-$AZURE_APPENV-webapp"
warn "There is currently an issue with removing App Services with VNet Integration;"
warn "To get around this, you will need to visit the following URL and choose 'disconnect'"
warn "before proceding with the removal of the resources."
warn ""
warn "If you do not do this step, the removal will leave behind the Vnet and App Service"
warn "subnet, and will require a support ticket to remove."
warn ""
warn "$VNETINTEGRATION_URI"
warn ""
warn "If you are unable to get to that URL, navigate the portal to the App Service,"
warn "click on Networking, and choose the Virtual network integration called vnet-$AZURE_APPENV/app-services."
warn ""
error "Have you completed this step and the portal notified you the process was complete? y/n"

read -r response
response=$(echo "$response" | tr '[:upper:]' '[:lower:]') # convert response to lowercase

if [[ $response == "n" || $response == "no" ]]; then
    warn "Disconnect cancelled. Exiting."
    exit 0
elif [[ $response == "y" || $response == "yes" ]]; then
    info "Disconnect confirmed, proceeding..."
else
    error "Invalid response. Exiting."
    exit 1
fi

info "Validating the App Service Link is removed by directly deleting the subnet"
info "If this fails, you will need to open a support ticket as the underlying resource is locked."

az network vnet subnet update --name "app-services" --vnet-name "vnet-$AZURE_APPENV" --remove "delegations"
az network vnet subnet delete --name "app-services" --vnet-name "vnet-$AZURE_APPENV"

# TODO: this should eventually fix it, however there's an issue with deleting the service link
# info "Removing App Service Virtual Network Integration"

# az webapp vnet-integration remove --name "app-$AZURE_APPENV-webapp"

# APPSERVICELINK_URI="https://management.azure.com/subscriptions/$AZURE_SUBSCRIPTIONID/resourceGroups/$AZURE_RESOURCEGROUP/providers/Microsoft.Network/virtualNetworks/vnet-$AZURE_APPENV/subnets/app-services/serviceAssociationLinks/AppServiceLink?api-version=2018-10-01"

# debug "Removing App Service Link at $APPSERVICELINK_URI"
# az rest --method delete --uri "$APPSERVICELINK_URI"


info "Removing Log Analytics workspace"

az monitor log-analytics workspace delete --force --workspace-name "log-$AZURE_APPENV" --yes

info "Removing Resource Group"

az group delete --name "$AZURE_RESOURCEGROUP" --yes

info "Done!"

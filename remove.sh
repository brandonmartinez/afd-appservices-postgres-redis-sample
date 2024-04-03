#!/usr/bin/env bash

set -eo pipefail

source ./logging.sh

LOG_FILE_NAME='remove.log'

if [ ! -f .env ]; then
    cp .envsample .env
    warn "Update .env with parameter values and run again"
    exit 1
fi

debug "Sourcing .env file"

set -a

# pulling from the .env file
source .env
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

info "Removing Log Analytics workspace"

az monitor log-analytics workspace delete --force --workspace-name "log-$AZURE_APPENV" --yes

info "Removing Resource Group"

az group delete --name "$AZURE_RESOURCEGROUP" --yes

info "Done!"

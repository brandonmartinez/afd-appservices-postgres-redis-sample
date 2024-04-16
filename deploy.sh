#!/usr/bin/env bash

set -eo pipefail

source ./logging.sh

export CURRENT_DATE_TIME=$(date +"%Y%m%dT%H%M")
LOG_FILE_NAME="deploy-$CURRENT_DATE_TIME.log"

export ENV_FILE="${1:-.env}"

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

WORKING_DIR=$(dirname "$(realpath "$0")")
SRC_DIR="$WORKING_DIR/src"
TEMP_DIR="$WORKING_DIR/.temp"

if [ "$ENV_FILE" != ".env" ]; then
    SUBFOLDER=$(echo "$ENV_FILE" | awk -F '.' '{print $NF}')
    TEMP_DIR="$TEMP_DIR/$SUBFOLDER"
fi

debug "Making temporary directory for merged files"
mkdir -p "$TEMP_DIR"

section "Configuring AZ CLI"

if ! az account show &> /dev/null; then
    az login
fi

info "Setting Azure subscription to $AZURE_SUBSCRIPTIONID"
az account set --subscription "$AZURE_SUBSCRIPTIONID"

info "Setting default location to $AZURE_LOCATION and resource group to $AZURE_RESOURCEGROUP"
az configure --defaults location="$AZURE_LOCATION" group="$AZURE_RESOURCEGROUP"

info "Setting Bicep to use the locally installed binary (workaround for arm64 architecture)"
az config set bicep.use_binary_from_path=True

info "Capturing current user entra details for deployment"
output=$(az ad signed-in-user show --query "{user: userPrincipalName, objectId: id}")
export ENTRA_USER_EMAIL=$(echo "$output" | jq -r '.user')
export ENTRA_USER_OBJECTID=$(echo "$output" | jq -r '.objectId')

section "Starting Azure infrastructure deployment"

info "Creating resource group $AZURE_RESOURCEGROUP if it does not exist"
az group create --name "$AZURE_RESOURCEGROUP" --location "$AZURE_LOCATION"

info "Transforming Bicep to ARM JSON"
START_TIME=$(date +%s)

debug "Manually building the bicep template, as there are some cross-platform issues with az deployment group create"
az bicep build --file "$SRC_DIR/main.bicep" --outdir "$TEMP_DIR"
az bicep build-params --file "$SRC_DIR/main.bicepparam" --outfile "$TEMP_DIR/main.parameters.json"

# Attempt to recover Key Vault in case it was previously deleted"
set +e
AZURE_KEYVAULT_NAME="kv-$AZURE_APPENV"
az keyvault show --name "$AZURE_KEYVAULT_NAME" --query "name" &> /dev/null
if [ $? -ne 0 ]; then
    info "Attempting to recover Key Vault in case it was previously deleted"
    az keyvault recover --location "$AZURE_LOCATION" --name $AZURE_KEYVAULT_NAME
    if [ $? -eq 0 ]; then
        info "Key Vault $AZURE_KEYVAULT_NAME recovered successfully"
    else
        warn "Key Vault $KEYVAULT_NAME was not recovered"
    fi
fi
set -e

info "Initiating the Bicep deployment of infrastructure"

# TODO: use stacks instead of deployment
AZ_DEPLOYMENT_NAME="az-main-$CURRENT_DATE_TIME"
output=$(az deployment group create \
    -n "$AZ_DEPLOYMENT_NAME" \
    --template-file "$TEMP_DIR/main.json" \
    --parameters "$TEMP_DIR/main.parameters.json" \
    -g "$AZURE_RESOURCEGROUP" \
    --verbose \
    --query 'properties.outputs')

# Echo output to the log for easy access to the deployment outputs
$(echo "$output" | jq --raw-output 'to_entries[] | .value.value' | while IFS= read -r line; do debug "$line"; done)

END_TIME=$(date +%s)

DURATION=$((END_TIME - START_TIME))

section "Azure infrastructure deployment completed"

info "Deployment was completed in $DURATION seconds"

info "For more information, open .logs/logs.txt"

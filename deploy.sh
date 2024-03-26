#!/usr/bin/env bash

set -eo pipefail

source ./logging.sh

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
export CURRENT_DATE_TIME=$(date +"%Y%m%dT%H%M")
export AZURE_RESOURCEGROUP="rg-$AZURE_APPENV"

set +a

WORKING_DIR=$(dirname "$(realpath "$0")")
SRC_DIR="$WORKING_DIR/src"
TEMP_DIR="$WORKING_DIR/.temp"

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

section "Starting Azure infrastructure deployment"

info "Creating resource group $AZURE_RESOURCEGROUP if it does not exist"
az group create --name "$AZURE_RESOURCEGROUP" --location "$AZURE_LOCATION"

info "Initiating the Bicep deployment of infrastructure"

debug "Manually building the bicep template, as there are some cross-platform issues with az deployment group create"
az bicep build --file "$SRC_DIR/main.bicep" --outdir "$TEMP_DIR"
az bicep build-params --file "$SRC_DIR/main.bicepparam" --outfile "$TEMP_DIR/main.parameters.json"

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

section "Azure infrastructure deployment completed"
info "For more information, open .logs/logs.txt"

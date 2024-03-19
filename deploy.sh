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
source .env
export AZURE_RESOURCEGROUP="rg-$AZURE_WORKLOAD"
set +a

WORKING_DIR=$(dirname "$(realpath "$0")")
SRC_DIR="$WORKING_DIR/src"
TEMPLATE_DIR="$WORKING_DIR/templates"
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

section "Starting Azure infrastructure deployment"

info "Token substitution of environment variables to Bicep parameters"
envsubst < "$TEMPLATE_DIR/main.parameters.json" > "$TEMP_DIR/main.parameters.json"

info "Creating resource group $AZURE_RESOURCEGROUP if it does not exist"
az group create --name "$AZURE_RESOURCEGROUP" --location "$AZURE_LOCATION"

info "Initiating the Bicep deployment of infrastructure"
AZ_DEPLOYMENT_TIMESTAMP=$(date +"%Y-%m-%d-%H-%M-%S")

AZ_DEPLOYMENT_NAME="AZ-$AZ_DEPLOYMENT_TIMESTAMP"
# output=$(az deployment group create \
#     -n "$AZ_DEPLOYMENT_NAME" \
#     --template-file "$SRC_DIR/main.bicep" \
#     --parameters "$TEMP_DIR/main.parameters.json" \
#     -g "$AZURE_RESOURCEGROUP" \
#     --query 'properties.outputs')

#!/bin/bash
#################################################################################
# AKS Cluster Deployment Script
# Purpose: Creates or updates AKS cluster based on naming convention settings
#         Supports both old and new naming conventions
#################################################################################

set -e

# Install required Python packages
echo "[INFO] Setting up Python environment"
pip config set global.trusted-host it4it-nexus-tp-repo.swissbank.com
pip config set global.index-url https://it4it-nexus-tp-repo.swissbank.com/repository/public-lib-python-pypi/simple
pip install pyyaml yq --user

# Generate AKS parameter file
echo "[INFO] Generating AKS parameter file"
python src/main/python-scripts/updateParams.py --env-yml $VAR_FILE \
    --params-template src/main/arm/aks/dev.k8s.azure.managedidentity.params._template.json \
    --prefix-to-remove common_,aks_

[ $? -eq 0 ] && echo "[SUCCESS] AKS parameter file generated" || { echo "[ERROR] Failed to generate AKS ARM parameter file"; exit 1; }

# Set Azure subscription
az account set --subscription $SUBSCRIPTION --output none

# Get existing cluster info
CLUSTER_COUNT=$(az aks list --resource-group ${resourceGroupName} --query "length(@)" --output tsv)
EXISTING_CLUSTER_NAME=$(az aks list --resource-group ${resourceGroupName} --query "[].name" --output tsv)

# Determine naming convention to use
USE_NEW_NAMING="false"  # Default to false unless explicitly set to true
CONFIG_FILE="env/$ENV-$CLUSTER_SUFFIX.yml"

# Check if new naming convention is enabled in config
if [ -f "$CONFIG_FILE" ]; then
    if [ ${CI} == true ]; then
        NEW_NAMING_VALUE=$(/root/.local/bin/yq -r '.[].variables.common_useNewNamingConvention // "false"' $CONFIG_FILE)
    else
        NEW_NAMING_VALUE=$(/root/.local/bin/yq -r '.[].common_useNewNamingConvention // "false"' $CONFIG_FILE)
    fi
    
    # Convert to lowercase for comparison
    NEW_NAMING_VALUE=$(echo "$NEW_NAMING_VALUE" | tr '[:upper:]' '[:lower:]')
    
    if [ "$NEW_NAMING_VALUE" == "true" ]; then
        USE_NEW_NAMING="true"
    fi
fi

# Set cluster name based on naming convention
if [ "$USE_NEW_NAMING" == "true" ]; then
    echo "[INFO] Using new naming convention"
    # Build cluster name using old convention
    OP_ENV=$(az group show --name ${resourceGroupName} --query "tags.opEnvironment" -o tsv | tr '[:upper:]' '[:lower:]' | cut -c-1)
    SUB_ID=$(az account show --query "id" -otsv | cut -c1-4)
    AT_NUM=$(az group show --name ${resourceGroupName} --query "tags.cmdbReference" -o tsv  | grep -o '[0-9]\{5\}')

    # Get suffix from config based on environment
    if [ ${CI} == true ]; then
        SUFFIX=$(/root/.local/bin/yq -r '.[].variables.common_oldClusterNameSuffix' $CONFIG_FILE)
    else
        SUFFIX=$(/root/.local/bin/yq -r '.[].common_oldClusterNameSuffix' $CONFIG_FILE)
    fi

    TARGET_CLUSTER_NAME="k${OP_ENV}${SUB_ID}${AT_NUM}${SUFFIX}"
else
    echo "[INFO] Using existing cluster name"
    TARGET_CLUSTER_NAME=$EXISTING_CLUSTER_NAME
    if [ -z "$TARGET_CLUSTER_NAME" ]; then
        echo "[ERROR] No existing cluster found and USE_NEW_NAMING is false"
        exit 1
    fi
fi

# Validate cluster names match if updating existing cluster
UPDATE_CLUSTER=false
if [[ "$TARGET_CLUSTER_NAME" == "$EXISTING_CLUSTER_NAME" ]]; then
    UPDATE_CLUSTER=true
else
    echo "[INFO] Cluster names do not match:"
    echo "[INFO] Target Cluster Name: $TARGET_CLUSTER_NAME"
    echo "[INFO] Existing Cluster Name: $EXISTING_CLUSTER_NAME"
fi

# Create or update cluster
if [[ "$CLUSTER_COUNT" -lt 1 || "$UPDATE_CLUSTER" == true ]]; then
    echo "[INFO] Number of clusters in RG ${resourceGroupName}: $CLUSTER_COUNT"
    
    if [[ "$CLUSTER_COUNT" -lt 1 ]]; then
        echo "[INFO] Creating new AKS cluster..."
    else
        echo "[INFO] Updating existing AKS cluster..."
    fi

    # Deploy using ARM template
    az deployment group create \
        --name deploy-${ENV}-cluster-${TARGET_CLUSTER_NAME} \
        --resource-group $resourceGroupName \
        --template-file src/main/arm/aks/dev.k8s.azure.managedidentity.json \
        --parameters src/main/arm/aks/dev.k8s.azure.managedidentity.params.json \
        --parameters extraTags='{"clusterType":"uk8s","codeVersion":"'$ARTEFACT_VERSION'"}'

    [ $? -eq 0 ] && echo "[SUCCESS] Cluster deployment completed" || { echo "[ERROR] Failed to deploy cluster"; exit 1; }
else
    echo "[ERROR] Cannot create new cluster - existing cluster found in RG ${resourceGroupName}"
    exit 1
fi



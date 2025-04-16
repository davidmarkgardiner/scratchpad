#!/bin/bash

# Enable strict mode: exit on error (-e) and print commands as they are executed (-x)
set -ex

###########################################
# Environment Setup
###########################################
# Load environment variables from .env if it exists
ENV_FILE="docs/ado/ado2/.env"
if [ -f "$ENV_FILE" ]; then
    echo "[INFO] Loading configuration from .env file"
    export $(cat "$ENV_FILE" | xargs)
fi

# Configure pip to use custom repository
pip config set global.trusted-host it4it-nexus-tp-repo.swissbank.com
pip config set global.index-url https://it4it-nexus-tp-repo.swissbank.com/repository/public-lib-python-pypi/simple

# Install required Python packages
pip install pyyaml yq --user

echo "[INFO] Generating AKS parameter file"
python src/main/python-scripts/updateParams.py --env-yml $VAR_FILE \
    --params-template src/main/arm/aks/dev.k8s.azure.managedidentity.params._template.json \
    --prefix-to-remove common_,aks_

[ $? -eq 0 ] && echo "[SUCCESS] AKS parameter file generated. Parameter file as below." || { echo "[ERROR] Failed to generate AKS ARM parameter file"; exit 1; }

cat src/main/arm/aks/dev.k8s.azure.managedidentity.params.json

# Set Azure subscription context
az account set --subscription $SUBSCRIPTION --output none

# Get existing cluster information
CLUSTER_COUNT=$(az aks list --resource-group ${resourceGroupName} --query "length(@)" --output tsv)
EXISTING_CLUSTER_NAME=$(az aks list --resource-group ${resourceGroupName} --query "[].name" --output tsv)

###########################################
# Naming Convention Configuration
###########################################
# Define config file paths based on environment
CONFIG_FILE="env/$ENV-$CLUSTER_SUFFIX.yml"
ADO_CONFIG_FILE="env/$ENV/$CLUSTER_SUFFIX.yml"
ENV_CONFIG_FILE="docs/ado/ado2/.env"
USE_NEW_NAMING="false"  # Default to false unless explicitly set to true

# Check if config file exists and determine naming convention
if [ -f "$CONFIG_FILE" ] || [ -f "$ENV_CONFIG_FILE" ]; then
    # Check if we should use new naming convention based on environment
    if [ "$CI" == "true" ]; then
        # GitLab environment
        if [ -f "$CONFIG_FILE" ]; then
            NEW_NAMING_VALUE=$(/root/.local/bin/yq -r '.[].variables.common_useNewNamingConvention // "false"' $CONFIG_FILE)
        else
            NEW_NAMING_VALUE=${common_useNewNamingConvention:-false}
        echo "[INFO] New naming value: $NEW_NAMING_VALUE"
        fi
    else
        # ADO environment
        if [ -f "$ADO_CONFIG_FILE" ]; then
            NEW_NAMING_VALUE=$(/root/.local/bin/yq -r '.[].common_useNewNamingConvention // "false"' $ADO_CONFIG_FILE)
        elif [ -f "$ENV_CONFIG_FILE" ]; then
            NEW_NAMING_VALUE=${common_useNewNamingConvention:-false}
            echo "[INFO] New naming value: $NEW_NAMING_VALUE"
        fi
        echo "[INFO] New naming value: $NEW_NAMING_VALUE"
    fi
    
    # Convert to lowercase for case-insensitive comparison
    NEW_NAMING_VALUE=$(echo "$NEW_NAMING_VALUE" | tr '[:upper:]' '[:lower:]')
    
    # Only set to true if explicitly "true"
    if [ "$NEW_NAMING_VALUE" == "true" ]; then
        USE_NEW_NAMING="true"
    fi
    
    echo "[INFO] Using new naming convention: $USE_NEW_NAMING"
fi

###########################################
# Cluster Name Resolution
###########################################
# Set cluster name based on naming convention
if [ "$USE_NEW_NAMING" == "true" ]; then
    echo "[INFO] Using new naming convention"
    
    # Extract cluster name from config file based on CI environment
    if [ "$CI" == "true" ]; then
        if [ -f "$CONFIG_FILE" ]; then
            TARGET_CLUSTER_NAME=$(/root/.local/bin/yq -r '.[].variables.common_newClusterName // .[].variables.clusterName' "$CONFIG_FILE")
        else
            TARGET_CLUSTER_NAME=${config_newClusterName:-}
        fi
        echo "[INFO] Target cluster name: $TARGET_CLUSTER_NAME"
    else
        if [ -f "$ADO_CONFIG_FILE" ]; then
            TARGET_CLUSTER_NAME=$(/root/.local/bin/yq -r '.[].common_newClusterName // .[].clusterName' "$ADO_CONFIG_FILE")
        elif [ -f "$ENV_CONFIG_FILE" ]; then
            TARGET_CLUSTER_NAME=${config_newClusterName:-}
        fi
        echo "[INFO] Target cluster name: $TARGET_CLUSTER_NAME"
    fi
else
    # Use existing cluster name if not using new naming convention
    echo "[INFO] Using existing cluster name"
    TARGET_CLUSTER_NAME=$EXISTING_CLUSTER_NAME
    if [ -z "$TARGET_CLUSTER_NAME" ]; then
        echo "[ERROR] No existing cluster found and USE_NEW_NAMING is false"
        exit 1
    fi
fi

###########################################
# Cluster Deployment
###########################################
# Determine if creating new or updating existing cluster
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
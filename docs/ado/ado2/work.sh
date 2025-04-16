#!/bin/sh

# Enable strict mode: exit on error (-e) and print commands as they are executed (-x)
set -ex

# Set the Azure subscription context
az account set --subscription $SUBSCRIPTION --output none

###########################################
# AKS Feature Registration
###########################################
echo "[INFO] Registering AKS features"

# Install and update AKS preview extension
az extension add --name aks-preview --allow-preview true
az extension update --name aks-preview

# Register required Azure features for AKS functionality
az feature register --namespace Microsoft.Compute --name EncryptionAtHost
az feature register --namespace Microsoft.ContainerService --name AdvancedNetworkingPreview
az feature register --namespace Microsoft.ContainerService --name AKS-KedaPreview
az feature register --namespace Microsoft.ContainerService --name AzureMonitorMetricsControlPlanePreview
az feature register --namespace Microsoft.ContainerService --name ClusterCostAnalysis
az feature register --namespace Microsoft.ContainerService --name CustomCATrustPreview
az feature register --namespace Microsoft.ContainerService --name CustomKubeletIdentityPreview
az feature register --namespace Microsoft.ContainerService --name DisableSSHPreview
az feature register --namespace Microsoft.ContainerService --name EnablePodIdentityPreview
az feature register --namespace Microsoft.ContainerService --name KubeletDefaultSeccompProfilePreview
az feature register --namespace Microsoft.ContainerService --name NetworkObservabilityPreview
az feature register --namespace Microsoft.ContainerService --name UserAssignedIdentityPreview

# Wait for feature registration to propagate
sleep 20

# Register required resource providers
az provider register -n Microsoft.Compute
az provider register -n Microsoft.ContainerService

# Verify feature registration status
az feature show --namespace Microsoft.ContainerService --name AdvancedNetworkingPreview
az feature show --namespace Microsoft.ContainerService --name AKS-KedaPreview
az feature show --namespace Microsoft.ContainerService --name AzureMonitorMetricsControlPlanePreview
az feature show --namespace Microsoft.ContainerService --name CustomCATrustPreview
az feature show --namespace Microsoft.ContainerService --name NetworkObservabilityPreview

###########################################
# Python Environment Setup
###########################################
# Configure pip to use custom repository
pip config set global.trusted-host it4it-nexus-tp-repo.swissbank.com
pip config set global.index-url https://it4it-nexus-tp-repo.swissbank.com/repository/public-lib-python-pypi/simple

# Set up local Python environment
mkdir -p $(pwd)/.local/bin
export PYTHONUSERBASE=$(pwd)/.local
pip install yq --user
export PATH=$(pwd)/.local/bin:$PATH

###########################################
# AKS Deployment Validation
###########################################
# Validate required input parameters
if [[ -z "$resourceGroupName" ]] || [[ -z "$location" ]]; then
    echo "[ERROR] Missing required parameters: resourceGroupName and/or location"
    exit 1
fi

# Determine configuration file path based on environment
CONFIG_FILE="env/$ENV-$CLUSTER_SUFFIX.yml"
ADO_CONFIG_FILE="env/$ENV/$CLUSTER_SUFFIX.yml"

# Check if resource group exists
EXISTING_RG=$(az group exists --name ${resourceGroupName})

# Handle cluster naming based on convention flag
if [[ "$USE_NEW_NAMING" == "true" ]]; then
    echo "[INFO] Using new naming convention logic"
    
    # Extract cluster name from config file based on CI environment
    if [ "$CI" == "true" ]; then
        if [ -f "$CONFIG_FILE" ]; then
            NEW_CLUSTER_NAME=$(yq -r '.[].variables.common_newClusterName // .[].variables.clusterName' "$CONFIG_FILE")
            echo "[INFO] New cluster name: $NEW_CLUSTER_NAME"
        fi
    else
        if [ -f "$ADO_CONFIG_FILE" ]; then
            NEW_CLUSTER_NAME=$(yq -r '.[].common_newClusterName // .[].clusterName' "$ADO_CONFIG_FILE")
            echo "[INFO] New cluster name: $NEW_CLUSTER_NAME"
        fi
    fi
else
    echo "[INFO] New cluster name: $NEW_CLUSTER_NAME"
    
    # Extract suffix for old naming convention
    if [ "$CI" == "true" ]; then
        SUFFIX=$(yq -r '.[].variables.common_oldClusterNameSuffix // .[].variables.oldClusterNameSuffix' "$CONFIG_FILE")
    else
        SUFFIX=$(yq -r '.[].common_oldClusterNameSuffix // .[].oldClusterNameSuffix' "$ADO_CONFIG_FILE")
    fi
fi

echo "[INFO] New cluster name: $NEW_CLUSTER_NAME"

# Validate cluster uniqueness in resource group
if [[ "$EXISTING_RG" == "true" ]]; then
    CLUSTER_COUNT=$(az aks list --resource-group ${resourceGroupName} --query "length(@)" --output tsv)

    if [ "$CLUSTER_COUNT" -gt 0 ]; then
        EXISTING_CLUSTER_NAME=$(az aks list --resource-group ${resourceGroupName} --query "[].name" --output tsv)
        echo "[INFO] Existing cluster name: $EXISTING_CLUSTER_NAME"

        # Enforce one-cluster-per-RG policy
        if [ "$NEW_CLUSTER_NAME" != "$EXISTING_CLUSTER_NAME" ]; then
            echo "[ERROR] ❌ Resource group already has a cluster with a different name"
            echo "[ERROR] 🚫 Only one cluster per resource group is allowed"
            exit 1
        else
            echo "[INFO] ✅ Existing cluster name matches expected cluster name"
        fi
    else
        echo "[INFO] ✅ No existing clusters in resource group"
    fi
else
    # Create new resource group if it doesn't exist
    echo "[INFO] Creating new Rg: ${resourceGroupName}"
    if [[ -z "$billingReference" ]] || [[ -z "$opEnvironment" ]] || [[ -z "$cmdbReference" ]]; then
        echo "[INFO] No tag defined - assuming inheritance"
        az group create --name ${resourceGroupName} \
            --location ${location}
        exit 0
    fi

    # Create resource group with required tags
    az group create --name ${resourceGroupName} \
        --location ${location} \
        --tags "billingReference=${billingReference}" "opEnvironment=${opEnvironment}" "cmdbReference=${cmdbReference}"
    
    # Check resource group creation status
    [ $? -eq 0 ] && echo "[SUCCESS] ✅ ${resourceGroupName} created." || { echo "[ERROR] ❌ Failed to create ${resourceGroupName}"; exit 1; }
fi

echo "[INFO] ✅ Validation completed successfully"

 
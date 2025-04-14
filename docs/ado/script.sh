#!/bin/bash
#################################################################################
# AKS Deployment Pre-requisites Script
# Purpose: This script prepares Azure environment for AKS deployment
#          It works in both GitLab CI and Azure DevOps pipelines
#
# Features:
# - Registers required Azure features for AKS
# - Validates resource groups and cluster configurations
# - Enforces one-cluster-per-resource-group policy
# - Handles different naming conventions
#
# Environment variables required:
# - SUBSCRIPTION: Azure subscription ID
# - ENV: Environment name (dev, test, prod, etc.)
# - CLUSTER_SUFFIX: Suffix for the cluster name
# - resourceGroupName: Name of the resource group
# - location: Azure region for deployment
# - billingReference: (Optional) Billing reference tag
# - opEnvironment: (Optional) Operating environment tag
# - cmdbReference: (Optional) CMDB reference tag
#################################################################################

# Exit on error, print commands as executed, expand unset variables as empty strings
set -ex

#################################################################################
# SECTION 1: Set up Azure environment
#################################################################################

echo "[INFO] Setting subscription context to $SUBSCRIPTION"
az account set --subscription $SUBSCRIPTION --output none

echo "[INFO] Registering required AKS features"
# Add and update AKS preview extension
az extension add --name aks-preview --allow-preview true
az extension update --name aks-preview

# Register necessary Azure features for AKS
echo "[INFO] Registering Azure features for AKS"
FEATURES_TO_REGISTER=(
    "Microsoft.Compute/EncryptionAtHost"
    "Microsoft.ContainerService/AdvancedNetworkingPreview"
    "Microsoft.ContainerService/AKS-KedaPreview"
    "Microsoft.ContainerService/AzureMonitorMetricsControlPlanePreview"
    "Microsoft.ContainerService/ClusterCostAnalysis"
    "Microsoft.ContainerService/CustomCATrustPreview"
    "Microsoft.ContainerService/CustomKubeletIdentityPreview"
    "Microsoft.ContainerService/DisableSSHPreview"
    "Microsoft.ContainerService/EnablePodIdentityPreview"
    "Microsoft.ContainerService/KubeletDefaultSeccompProfilePreview"
    "Microsoft.ContainerService/NetworkObservabilityPreview"
    "Microsoft.ContainerService/UserAssignedIdentityPreview"
)

# Register all features
for feature in "${FEATURES_TO_REGISTER[@]}"; do
    NAMESPACE=$(echo $feature | cut -d'/' -f1)
    FEATURE_NAME=$(echo $feature | cut -d'/' -f2)
    echo "[INFO] Registering feature: $NAMESPACE/$FEATURE_NAME"
    az feature register --namespace $NAMESPACE --name $FEATURE_NAME
done

# Wait briefly for registration to begin
sleep 20

# Register required providers
echo "[INFO] Registering resource providers"
az provider register -n Microsoft.Compute
az provider register -n Microsoft.ContainerService

# Check status of critical features
echo "[INFO] Checking status of critical features"
CRITICAL_FEATURES=(
    "Microsoft.ContainerService/AdvancedNetworkingPreview"
    "Microsoft.ContainerService/AKS-KedaPreview"
    "Microsoft.ContainerService/AzureMonitorMetricsControlPlanePreview"
    "Microsoft.ContainerService/CustomCATrustPreview"
    "Microsoft.ContainerService/NetworkObservabilityPreview"
)

for feature in "${CRITICAL_FEATURES[@]}"; do
    NAMESPACE=$(echo $feature | cut -d'/' -f1)
    FEATURE_NAME=$(echo $feature | cut -d'/' -f2)
    echo "[INFO] Checking feature status: $NAMESPACE/$FEATURE_NAME"
    az feature show --namespace $NAMESPACE --name $FEATURE_NAME
done

#################################################################################
# SECTION 2: Set up Python environment
#################################################################################

echo "[INFO] Configuring Python pip for private repository"
# Configure pip to use private repository
pip config set global.trusted-host it4it-nexus-tp-repo.swissbank.com
pip config set global.index-url https://it4it-nexus-tp-repo.swissbank.com/repository/public-lib-python-pypi/simple

# Install YQ for YAML parsing - used differently in GitLab vs ADO
echo "[INFO] Installing YQ YAML parser"
pip install yq --user

#################################################################################
# SECTION 3: Resource Group and Cluster Validation
#################################################################################

# Set the subscription context again
az account set --subscription $SUBSCRIPTION --output none

# Check required parameters
echo "[INFO] Validating required parameters"
if [[ -z "$resourceGroupName" ]] || [[ -z "$location" ]]; then
    echo "[ERROR] Missing required parameters: resourceGroupName and/or location"
    exit 1
fi

# Check if the resource group exists
EXISTING_RG=$(az group exists --name ${resourceGroupName})

if [[ ${EXISTING_RG} == true ]]; then
    echo "[INFO] Resource group $resourceGroupName exists in subscription"
    
    # Check for existing clusters in the resource group
    CLUSTER_COUNT=$(az aks list --resource-group ${resourceGroupName} --query "length(@)" --output tsv)
    EXISTING_CLUSTER_NAME=$(az aks list --resource-group ${resourceGroupName} --query "[].name" --output tsv)
    
    # Determine new cluster name based on environment file
    # Handles different naming conventions between old and new deployments
    if [ -f "env/$ENV-$CLUSTER_SUFFIX.yml" ]; then
        # Old naming convention - requires building name from components
        echo "[INFO] Using old naming convention for the cluster"
        
        # Find the environment file that matches the pattern
        VAR_FILE=env/$(ls env | grep -i -E "^$ENV.*$CLUSTER_SUFFIX\.yml$")
        echo "[INFO] Using environment file: $VAR_FILE"
        
        # Extract components for cluster name
        OP_ENV=$(az group show --name ${resourceGroupName} --query "tags.opEnvironment" -o tsv | tr '[:upper:]' '[:lower:]' | cut -c-1)
        SUB_ID=$(az account show --query "id" -otsv | cut -c1-4)
        AT_NUM=$(az group show --name ${resourceGroupName} --query "tags.cmdbReference" -o tsv | grep -o '[0-9]\{5\}')
        
        # Different YQ syntax between GitLab and ADO
        if [ "$CI" == "true" ]; then
            # GitLab syntax
            SUFFIX=$(/root/.local/bin/yq -r '.[].variables.common_oldClusterNameSuffix' $VAR_FILE)
            echo "[INFO] Using GitLab YQ syntax, suffix: $SUFFIX"
        else
            # ADO syntax
            SUFFIX=$(/root/.local/bin/yq -r '.[].common_oldClusterNameSuffix' $VAR_FILE)
            echo "[INFO] Using ADO YQ syntax, suffix: $SUFFIX"
        fi
        
        # Construct the cluster name
        NEW_CLUSTER_NAME="k${OP_ENV}${SUB_ID}${AT_NUM}${SUFFIX}"
        
        # Check if NEW_CLUSTER_NAME is empty and try alternative source
        if [[ -z "$NEW_CLUSTER_NAME" ]]; then
            echo "[INFO] NEW_CLUSTER_NAME is empty, trying alternative source"
            if [ "$CI" == "true" ]; then
                # GitLab syntax for new cluster name
                NEW_CLUSTER_NAME=$(/root/.local/bin/yq -r '.[].variables.common_newClusterName' $VAR_FILE)
                echo "[INFO] Using GitLab YQ syntax for direct cluster name: $NEW_CLUSTER_NAME"
            else
                # ADO syntax for new cluster name
                NEW_CLUSTER_NAME=$(/root/.local/bin/yq -r '.[].common_newClusterName' $VAR_FILE)
                echo "[INFO] Using ADO YQ syntax for direct cluster name: $NEW_CLUSTER_NAME"
            fi
        fi
        
        # Make the cluster name available to the ADO pipeline
        if [ "$CI" != "true" ]; then
            # ADO syntax for setting pipeline variables
            echo "##vso[task.setvariable variable=NEW_CLUSTER_NAME]${NEW_CLUSTER_NAME}"
            echo "[INFO] Made NEW_CLUSTER_NAME available to ADO pipeline: ${NEW_CLUSTER_NAME}"
        fi
        
        # Debug output to verify the cluster name
        echo "[DEBUG] NEW_CLUSTER_NAME has been set to: ${NEW_CLUSTER_NAME}"
    else
        # New naming convention - just use the suffix directly
        NEW_CLUSTER_NAME=$CLUSTER_SUFFIX
        
        # Check if NEW_CLUSTER_NAME is empty and try to read from config file
        if [[ -z "$NEW_CLUSTER_NAME" ]] && [ -f "env/$ENV.yml" ]; then
            echo "[INFO] NEW_CLUSTER_NAME is empty, trying to read from env/$ENV.yml"
            VAR_FILE="env/$ENV.yml"
            
            if [ "$CI" == "true" ]; then
                # GitLab syntax for direct cluster name
                NEW_CLUSTER_NAME=$(/root/.local/bin/yq -r '.[].variables.common_newClusterName' $VAR_FILE)
                echo "[INFO] Using GitLab YQ syntax for direct cluster name: $NEW_CLUSTER_NAME"
            else
                # ADO syntax for direct cluster name
                NEW_CLUSTER_NAME=$(/root/.local/bin/yq -r '.[].common_newClusterName' $VAR_FILE)
                echo "[INFO] Using ADO YQ syntax for direct cluster name: $NEW_CLUSTER_NAME"
            fi
        fi
        
        # Make the cluster name available to the ADO pipeline
        if [ "$CI" != "true" ]; then
            # ADO syntax for setting pipeline variables
            echo "##vso[task.setvariable variable=NEW_CLUSTER_NAME]${NEW_CLUSTER_NAME}"
            echo "[INFO] Made NEW_CLUSTER_NAME available to ADO pipeline: ${NEW_CLUSTER_NAME}"
        fi
        
        # Debug output to verify the cluster name
        echo "[DEBUG] NEW_CLUSTER_NAME has been set to: ${NEW_CLUSTER_NAME}"
    fi
    
    # Check if new cluster name matches existing one
    if [ "$NEW_CLUSTER_NAME" == "$EXISTING_CLUSTER_NAME" ]; then
        SAME_CLUSTER=true
    else
        SAME_CLUSTER=false
    fi
    
    # Validate the one-cluster-per-RG policy
    if [ "$CLUSTER_COUNT" -lt 1 ] || [ "$SAME_CLUSTER" == "true" ]; then
        echo "[INFO] Number of clusters in resource group ${resourceGroupName}: $CLUSTER_COUNT"
        echo "[INFO] Cluster name validation passed"
        
        # Placeholder for additional resource group creation
        # Commented out in original script, leaving as commented reference
        # # Create an Prometheus resource group
        # az group create --name RG-NEU-DEV-UK8SCORE \
        #     --location northeurope \
        #     --tags "billingReference=${billingReference}" "opEnvironment=${opEnvironment}" "cmdbReference=${cmdbReference}"
        
    else
        # Fail if trying to create a different cluster in an RG that already has one
        echo "[ERROR] ❌ The new cluster name does not match the existing cluster name"
        echo "[INFO] New Cluster Name: $NEW_CLUSTER_NAME"
        echo "[INFO] Existing Cluster Name: $EXISTING_CLUSTER_NAME"
        echo "[ERROR] 🚫 Aborting... Resource group already has an AKS cluster"
        echo "[ERROR] Only one cluster per resource group is allowed"
        exit 1
    fi
else
    # Resource group doesn't exist, create it
    echo "[INFO] Creating new resource group: ${resourceGroupName}"
    
    # Check if tags are provided - if not, create RG without tags
    if [[ -z "$billingReference" ]] || [[ -z "$opEnvironment" ]] || [[ -z "$cmdbReference" ]]; then
        echo "[INFO] No tags defined - creating resource group without tags"
        az group create --name ${resourceGroupName} \
            --location ${location}
        
        # Previous script had a mistake here with missing fi and unconditional exit
        # This corrected version maintains the flow without exiting
    else
        # Create resource group with tags
        echo "[INFO] Creating resource group with tags"
        az group create --name ${resourceGroupName} \
            --location ${location} \
            --tags "billingReference=${billingReference}" "opEnvironment=${opEnvironment}" "cmdbReference=${cmdbReference}"
        
        # Check result and provide appropriate message
        if [ $? -eq 0 ]; then
            echo "[SUCCESS] ✅ ${resourceGroupName} created successfully"
        else
            echo "[ERROR] ❌ Failed to create ${resourceGroupName}"
            exit 1
        fi
    fi
fi

echo "[INFO] Script completed successfully"
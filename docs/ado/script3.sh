#!/bin/bash
#################################################################################
# Simplified AKS Deployment Validation Script
# Purpose: Validates resource group and enforces one-cluster-per-RG policy
#         Supports both old and new naming conventions
#################################################################################

set -e

# Set subscription context
echo "[INFO] Setting subscription context"
az account set --subscription $SUBSCRIPTION --output none

# Check required parameters
if [[ -z "$resourceGroupName" ]] || [[ -z "$location" ]]; then
    echo "[ERROR] Missing required parameters: resourceGroupName and/or location"
    exit 1
fi

# First, determine if we should use the new naming convention or not
CONFIG_FILE="env/$ENV.yml"
USE_NEW_NAMING=true # Default to true

if [ -f "$CONFIG_FILE" ]; then
    # Check if we should use new naming convention
    if [ "$CI" == "true" ]; then
        # GitLab environment
        USE_NEW_NAMING=$(/root/.local/bin/yq -r '.[].variables.common_useNewNamingConvention // "true"' $CONFIG_FILE)
    else
        # ADO environment
        USE_NEW_NAMING=$(/root/.local/bin/yq -r '.[].common_useNewNamingConvention // "true"' $CONFIG_FILE)
    fi
    echo "[INFO] Using new naming convention: $USE_NEW_NAMING"
fi

# Check if resource group exists
EXISTING_RG=$(az group exists --name ${resourceGroupName})

# If not using new naming convention, simplified logic applies
if [[ "$USE_NEW_NAMING" == "false" ]]; then
    echo "[INFO] Using simplified logic (old naming convention)"
    
    if [[ ${EXISTING_RG} == true ]]; then
        echo "[INFO] ✅ Resource group $resourceGroupName exists, continuing"
    else
        echo "[INFO] Creating resource group: $resourceGroupName"
        
        # Check if tags are provided
        if [[ -z "$billingReference" ]] || [[ -z "$opEnvironment" ]] || [[ -z "$cmdbReference" ]]; then
            echo "[INFO] Creating resource group without tags"
            az group create --name ${resourceGroupName} --location ${location}
        else
            echo "[INFO] Creating resource group with tags"
            az group create --name ${resourceGroupName} \
                --location ${location} \
                --tags "billingReference=${billingReference}" "opEnvironment=${opEnvironment}" "cmdbReference=${cmdbReference}"
        fi
        
        # Check if resource group was created successfully
        if [ $? -ne 0 ]; then
            echo "[ERROR] ❌ Failed to create resource group"
            exit 1
        fi
        
        echo "[INFO] ✅ Resource group created successfully"
    fi
else
    # Using new naming convention - full validation logic applies
    echo "[INFO] Using full validation logic (new naming convention)"
    
    if [[ ${EXISTING_RG} == true ]]; then
        echo "[INFO] Resource group $resourceGroupName exists"
        
        # Check for existing clusters
        CLUSTER_COUNT=$(az aks list --resource-group ${resourceGroupName} --query "length(@)" --output tsv)
        
        # If there are existing clusters, get their names
        if [ "$CLUSTER_COUNT" -gt 0 ]; then
            EXISTING_CLUSTER_NAME=$(az aks list --resource-group ${resourceGroupName} --query "[].name" --output tsv)
            
            # For GitLab/ADO compatibility - try both methods of getting the desired cluster name
            if [ "$CI" == "true" ]; then
                # GitLab environment
                if [ -f "$CONFIG_FILE" ]; then
                    TARGET_CLUSTER_NAME=$(/root/.local/bin/yq -r '.[].variables.common_newClusterName // .[].variables.clusterName' $CONFIG_FILE)
                else
                    TARGET_CLUSTER_NAME=$CLUSTER_SUFFIX
                fi
            else
                # ADO environment
                if [ -f "$CONFIG_FILE" ]; then
                    TARGET_CLUSTER_NAME=$(/root/.local/bin/yq -r '.[].common_newClusterName // .[].clusterName' $CONFIG_FILE)
                else
                    TARGET_CLUSTER_NAME=$CLUSTER_SUFFIX
                fi
            fi
            
            # Default to CLUSTER_SUFFIX if still empty
            if [[ -z "$TARGET_CLUSTER_NAME" ]]; then
                TARGET_CLUSTER_NAME=$CLUSTER_SUFFIX
            fi
            
            # Make the variable available to the pipeline
            if [ "$CI" != "true" ]; then
                echo "##vso[task.setvariable variable=TARGET_CLUSTER_NAME]${TARGET_CLUSTER_NAME}"
            fi
            
            echo "[INFO] Target cluster name: $TARGET_CLUSTER_NAME"
            echo "[INFO] Existing cluster name: $EXISTING_CLUSTER_NAME"
            
            # Check if target cluster name matches existing cluster
            if [ "$TARGET_CLUSTER_NAME" != "$EXISTING_CLUSTER_NAME" ]; then
                echo "[ERROR] ❌ Resource group already has a cluster with a different name"
                echo "[ERROR] 🚫 Only one cluster per resource group is allowed"
                exit 1
            else
                echo "[INFO] ✅ Existing cluster name matches target cluster name"
            fi
        else
            echo "[INFO] ✅ No existing clusters in resource group"
        fi
    else
        echo "[INFO] Creating resource group: $resourceGroupName"
        
        # Check if tags are provided
        if [[ -z "$billingReference" ]] || [[ -z "$opEnvironment" ]] || [[ -z "$cmdbReference" ]]; then
            echo "[INFO] Creating resource group without tags"
            az group create --name ${resourceGroupName} --location ${location}
        else
            echo "[INFO] Creating resource group with tags"
            az group create --name ${resourceGroupName} \
                --location ${location} \
                --tags "billingReference=${billingReference}" "opEnvironment=${opEnvironment}" "cmdbReference=${cmdbReference}"
        fi
        
        # Check if resource group was created successfully
        if [ $? -ne 0 ]; then
            echo "[ERROR] ❌ Failed to create resource group"
            exit 1
        fi
        
        echo "[INFO] ✅ Resource group created successfully"
    fi
fi

echo "[INFO] ✅ Validation completed successfully"
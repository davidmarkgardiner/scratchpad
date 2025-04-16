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
USE_NEW_NAMING="false"  # Default to false unless explicitly set to true

echo "[INFO] Checking config file: $CONFIG_FILE"

# Check environment variable first, then fall back to config file
if [ ! -z "$common_useNewNamingConvention" ]; then
    NEW_NAMING_VALUE="$common_useNewNamingConvention"
    echo "[INFO] Using naming convention from environment variable"
elif [ -f "$CONFIG_FILE" ]; then
    # Check if we should use new naming convention from config file
    if [ "$CI" == "true" ]; then
        # GitLab environment
        echo "[INFO] Reading naming convention from GitLab config path: .[].variables.common_useNewNamingConvention"
        NEW_NAMING_VALUE=$(/root/.local/bin/yq -r '.[].variables.common_useNewNamingConvention // "false"' $CONFIG_FILE)
    else
        # ADO environment
        echo "[INFO] Reading naming convention from ADO config path: .[].common_useNewNamingConvention"
        NEW_NAMING_VALUE=$(/root/.local/bin/yq -r '.[].common_useNewNamingConvention // "false"' $CONFIG_FILE)
    fi
    echo "[INFO] Using naming convention from config file"
fi

# Convert to lowercase for case-insensitive comparison
NEW_NAMING_VALUE=$(echo "$NEW_NAMING_VALUE" | tr '[:upper:]' '[:lower:]')
echo "[INFO] New naming value: ${NEW_NAMING_VALUE}"

# Only set to true if explicitly "true"
if [ "$NEW_NAMING_VALUE" == "true" ]; then
    USE_NEW_NAMING="true"
fi

echo "[INFO] Using new naming convention: $USE_NEW_NAMING"

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
            
            # Get cluster name from config
            if [ "$CI" == "true" ]; then
                # GitLab environment
                if [ -f "$CONFIG_FILE" ]; then
                    echo "[INFO] Reading cluster name from GitLab config path: .[].variables.common_newClusterName"
                    TARGET_CLUSTER_NAME=$(/root/.local/bin/yq -r '.[].variables.common_newClusterName // .[].variables.clusterName' $CONFIG_FILE)
                fi
            else
                # ADO environment
                if [ -f "$CONFIG_FILE" ]; then
                    echo "[INFO] Reading cluster name from ADO config path: .[].common_newClusterName"
                    TARGET_CLUSTER_NAME=$(/root/.local/bin/yq -r '.[].common_newClusterName // .[].clusterName' $CONFIG_FILE)
                fi
            fi

            if [ -z "$TARGET_CLUSTER_NAME" ]; then
                echo "[ERROR] Could not determine cluster name from config file"
                exit 1
            fi
            
            echo "[INFO] Read cluster name from config: ${TARGET_CLUSTER_NAME}"
            
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
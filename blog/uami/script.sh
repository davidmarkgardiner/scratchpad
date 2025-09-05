#!/bin/bash

# Azure UAMI Federation Cleanup Script
# This script loops through UAMIs federated with clusters and removes federations for offline clusters

# Configuration
CLUSTER_NAME_PREFIX="your-cluster-prefix"  # e.g., "aks-cluster-"
RESOURCE_GROUP="your-resource-group"       # Resource group containing the clusters
SUBSCRIPTION_ID="your-subscription-id"     # Optional: specify subscription

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to log messages
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Set subscription if provided
if [ ! -z "$SUBSCRIPTION_ID" ]; then
    log_info "Setting subscription to: $SUBSCRIPTION_ID"
    az account set --subscription "$SUBSCRIPTION_ID"
fi

# Function to check if AKS cluster is running
check_cluster_status() {
    local cluster_name=$1
    local resource_group=$2
    
    # Get cluster power state
    power_state=$(az aks show \
        --name "$cluster_name" \
        --resource-group "$resource_group" \
        --query "powerState.code" \
        --output tsv 2>/dev/null)
    
    if [ $? -ne 0 ]; then
        log_error "Failed to get status for cluster: $cluster_name"
        return 2
    fi
    
    if [ "$power_state" == "Running" ]; then
        return 0  # Cluster is running
    else
        return 1  # Cluster is stopped
    fi
}

# Function to get federated credentials for a UAMI
get_federated_credentials() {
    local uami_name=$1
    local uami_rg=$2
    
    az identity federated-credential list \
        --identity-name "$uami_name" \
        --resource-group "$uami_rg" \
        --query "[].{name:name, issuer:issuer, subject:subject}" \
        --output json
}

# Function to delete federated credential
delete_federated_credential() {
    local uami_name=$1
    local uami_rg=$2
    local credential_name=$3
    
    log_warn "Deleting federated credential: $credential_name from UAMI: $uami_name"
    
    az identity federated-credential delete \
        --identity-name "$uami_name" \
        --resource-group "$uami_rg" \
        --name "$credential_name" \
        --yes
    
    if [ $? -eq 0 ]; then
        log_info "Successfully deleted federated credential: $credential_name"
        return 0
    else
        log_error "Failed to delete federated credential: $credential_name"
        return 1
    fi
}

# Main execution
main() {
    log_info "Starting UAMI federation cleanup process..."
    log_info "Cluster prefix: $CLUSTER_NAME_PREFIX"
    log_info "Resource group: $RESOURCE_GROUP"
    
    # Get all UAMIs in the subscription
    log_info "Fetching all User-Assigned Managed Identities..."
    
    uamis=$(az identity list --query "[].{name:name, resourceGroup:resourceGroup, id:id}" --output json)
    
    if [ -z "$uamis" ] || [ "$uamis" == "[]" ]; then
        log_warn "No UAMIs found in the subscription"
        exit 0
    fi
    
    # Process each UAMI
    echo "$uamis" | jq -c '.[]' | while read uami; do
        uami_name=$(echo "$uami" | jq -r '.name')
        uami_rg=$(echo "$uami" | jq -r '.resourceGroup')
        
        log_info "Processing UAMI: $uami_name in resource group: $uami_rg"
        
        # Get federated credentials for this UAMI
        fed_creds=$(get_federated_credentials "$uami_name" "$uami_rg")
        
        if [ -z "$fed_creds" ] || [ "$fed_creds" == "[]" ]; then
            log_info "No federated credentials found for UAMI: $uami_name"
            continue
        fi
        
        # Check each federated credential
        echo "$fed_creds" | jq -c '.[]' | while read cred; do
            cred_name=$(echo "$cred" | jq -r '.name')
            issuer=$(echo "$cred" | jq -r '.issuer')
            subject=$(echo "$cred" | jq -r '.subject')
            
            # Check if this credential is related to our clusters
            if [[ "$issuer" == *"$CLUSTER_NAME_PREFIX"* ]] || [[ "$subject" == *"$CLUSTER_NAME_PREFIX"* ]]; then
                
                # Extract cluster name from issuer or subject
                # This regex extraction might need adjustment based on your issuer format
                cluster_name=""
                
                # Try to extract cluster name from issuer URL (common format)
                if [[ "$issuer" =~ /${CLUSTER_NAME_PREFIX}[0-9]+/ ]]; then
                    cluster_name=$(echo "$issuer" | grep -oP "${CLUSTER_NAME_PREFIX}[0-9]+")
                elif [[ "$subject" =~ ${CLUSTER_NAME_PREFIX}[0-9]+ ]]; then
                    cluster_name=$(echo "$subject" | grep -oP "${CLUSTER_NAME_PREFIX}[0-9]+")
                fi
                
                if [ -z "$cluster_name" ]; then
                    log_warn "Could not extract cluster name from federated credential: $cred_name"
                    continue
                fi
                
                log_info "Found federation for cluster: $cluster_name"
                
                # Check if cluster is running
                check_cluster_status "$cluster_name" "$RESOURCE_GROUP"
                status=$?
                
                if [ $status -eq 1 ]; then
                    # Cluster is stopped, delete the federation
                    log_warn "Cluster $cluster_name is stopped. Removing federation..."
                    delete_federated_credential "$uami_name" "$uami_rg" "$cred_name"
                elif [ $status -eq 0 ]; then
                    log_info "Cluster $cluster_name is running. Keeping federation."
                else
                    log_error "Could not determine status of cluster $cluster_name. Skipping..."
                fi
            fi
        done
    done
    
    log_info "UAMI federation cleanup completed!"
}

# Run main function
main
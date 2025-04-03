#!/bin/bash
# Script to check if AKS cluster is ready before deploying Flux

# Set variables (can be passed from pipeline)
RESOURCE_GROUP="${RESOURCE_GROUP:-myAKSResourceGroup}"
CLUSTER_NAME="${CLUSTER_NAME:-myAKSCluster}"
MAX_RETRIES="${MAX_RETRIES:-30}"
RETRY_INTERVAL="${RETRY_INTERVAL:-20}"

echo "Checking if AKS cluster '$CLUSTER_NAME' is ready..."

# Function to check cluster readiness
check_aks_ready() {
    # Get cluster provisioning state
    PROVISIONING_STATE=$(az aks show \
        --resource-group "$RESOURCE_GROUP" \
        --name "$CLUSTER_NAME" \
        --query "provisioningState" \
        --output tsv 2>/dev/null)
    
    if [[ "$PROVISIONING_STATE" == "Succeeded" ]]; then
        # Even when provisioning state is Succeeded, the API server might not be ready yet
        # Try to get nodes as an additional check
        if az aks get-credentials --resource-group "$RESOURCE_GROUP" --name "$CLUSTER_NAME" --overwrite-existing --only-show-errors; then
            if kubectl get nodes -o name &>/dev/null; then
                echo "Cluster is ready. API server is responding and nodes are available."
                return 0
            else
                echo "Cluster is provisioned but API server is not yet ready or nodes are not registered."
                return 1
            fi
        else
            echo "Cluster credentials could not be retrieved."
            return 1
        fi
    else
        echo "Cluster is not ready. Current state: $PROVISIONING_STATE"
        return 1
    fi
}

# Main loop to check cluster readiness
count=0
while [ $count -lt $MAX_RETRIES ]; do
    if check_aks_ready; then
        echo "AKS cluster is ready for Flux deployment."
        exit 0
    else
        echo "Waiting for AKS cluster to be ready... Attempt $(($count + 1))/$MAX_RETRIES"
        sleep $RETRY_INTERVAL
        count=$((count + 1))
    fi
done

echo "Timeout waiting for AKS cluster to be ready after $MAX_RETRIES attempts."
exit 1
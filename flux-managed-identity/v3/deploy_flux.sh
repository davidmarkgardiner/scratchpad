#!/bin/bash

# Deploy Flux GitOps to a specific cluster using shared managed identity
# Usage: ./deploy-cluster-flux.sh <cluster-rg> <cluster-name> <environment>

set -e

if [ $# -ne 3 ]; then
    echo "Usage: $0 <cluster-resource-group> <cluster-name> <environment>"
    echo "Example: $0 myapp-prod-rg myapp-prod-aks prod"
    exit 1
fi

CLUSTER_RG=$1
CLUSTER_NAME=$2
ENVIRONMENT=$3

# Validate environment
case $ENVIRONMENT in
    dev|test|staging|prod)
        echo "✅ Valid environment: $ENVIRONMENT"
        ;;
    *)
        echo "❌ Invalid environment. Must be: dev, test, staging, or prod"
        exit 1
        ;;
esac

TEMPLATE_FILE="flux-shared-mi-template.json"
PARAM_FILE="flux-${ENVIRONMENT}-parameters.json"

echo "🚀 Deploying Flux GitOps to cluster: $CLUSTER_NAME"
echo "   Resource Group: $CLUSTER_RG"
echo "   Environment: $ENVIRONMENT"
echo "   Using shared identity for: $ENVIRONMENT"

# Check if parameter file exists
if [ ! -f "$PARAM_FILE" ]; then
    echo "❌ Parameter file not found: $PARAM_FILE"
    echo "Run the setup-shared-identities.sh script first!"
    exit 1
fi

# Check if template file exists
if [ ! -f "$TEMPLATE_FILE" ]; then
    echo "❌ Template file not found: $TEMPLATE_FILE"
    exit 1
fi

# Deploy
echo "📤 Starting deployment..."
az deployment group create \
    --resource-group $CLUSTER_RG \
    --template-file $TEMPLATE_FILE \
    --parameters @$PARAM_FILE \
    --parameters clusterName=$CLUSTER_NAME \
    --name "flux-gitops-$(date +%Y%m%d-%H%M%S)"

if [ $? -eq 0 ]; then
    echo "✅ Deployment completed successfully!"
    
    echo ""
    echo "🔍 Verifying deployment..."
    
    # Get AKS credentials
    az aks get-credentials --resource-group $CLUSTER_RG --name $CLUSTER_NAME --overwrite-existing
    
    # Check Flux extension
    echo "📋 Checking Flux extension status..."
    az k8s-extension show --cluster-name $CLUSTER_NAME --cluster-type managedClusters \
        --resource-group $CLUSTER_RG --name flux --query "installState" -o tsv
    
    # Check source controller
    echo "🔧 Checking source controller..."
    kubectl get deployment source-controller -n flux-system
    
    # Check workload identity annotation
    echo "🆔 Checking workload identity configuration..."
    kubectl describe sa source-controller -n flux-system | grep -A 5 -B 5 "azure.workload.identity"
    
    # Check GitRepository status
    echo "📁 Checking GitRepository status..."
    kubectl get gitrepository -n flux-system
    
    echo ""
    echo "🎉 Flux GitOps setup complete for $CLUSTER_NAME!"
    echo "Monitor with: kubectl get gitrepository,kustomization -n flux-system"
    
else
    echo "❌ Deployment failed!"
    exit 1
fi
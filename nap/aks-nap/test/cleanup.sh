#!/bin/bash

# Set variables
RESOURCE_GROUP="nap-test-rg"
CLUSTER_NAME="nap-test-cluster"
LOCATION="uksouth"
# Delete Helm releases
echo "Deleting Helm releases..."
helm uninstall cert-manager -n cert-manager
helm uninstall external-secrets -n external-secrets
helm uninstall kyverno -n kyverno

# Delete namespaces
# echo "Deleting namespaces..."
# kubectl delete namespace cert-manager
# kubectl delete namespace external-secrets
# kubectl delete namespace kyverno

# Delete AKS cluster
echo "Deleting AKS cluster..."
az aks delete \
    --name $CLUSTER_NAME \
    --resource-group $RESOURCE_GROUP \
    --yes

# Delete resource group (optional - uncomment if you want to remove everything)
# echo "Deleting resource group..."
# az group delete \
#     --name $RESOURCE_GROUP \
#     --yes

echo "Cleanup complete!" 
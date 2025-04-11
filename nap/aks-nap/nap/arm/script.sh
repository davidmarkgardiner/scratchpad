#!/bin/bash
# Set variables
RESOURCE_GROUP="myAKSResourceGroup"
LOCATION="eastus"

# Create resource group
echo "Creating resource group $RESOURCE_GROUP in $LOCATION..."
az group create --name $RESOURCE_GROUP --location $LOCATION

# Step 1: Deploy the AKS cluster
echo "Deploying AKS cluster with Node Auto Provisioner..."
az deployment group create \
  --resource-group $RESOURCE_GROUP \
  --template-file aks-template.json \
  --parameters @aks-parameters.json

# Get credentials for the AKS cluster
echo "Getting credentials for the AKS cluster..."
az aks get-credentials --resource-group $RESOURCE_GROUP --name myAKSCluster --overwrite-existing

# Step 2: Deploy the Flux configuration
echo "Deploying Flux configuration to the AKS cluster..."
az deployment group create \
  --resource-group $RESOURCE_GROUP \
  --template-file flux-template.json \
  --parameters @flux-parameters.json

# Verify the AKS cluster nodes
echo "Verifying AKS cluster nodes..."
kubectl get nodes

# Verify the Flux installation
echo "Verifying Flux installation..."
kubectl get ns flux-system
kubectl get pods -n flux-system

# List GitRepository and Kustomization resources
echo "Checking Flux GitRepository and Kustomization resources..."
kubectl get gitrepositories.source.toolkit.fluxcd.io -A
kubectl get kustomizations.kustomize.toolkit.fluxcd.io -A

echo "Deployment completed!"
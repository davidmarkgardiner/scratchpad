#!/bin/bash

# Set variables
RESOURCE_GROUP="nap-test-rg"
CLUSTER_NAME="nap-test-cluster"
LOCATION="uksouth"

# Create resource group
az group create --name $RESOURCE_GROUP --location $LOCATION

# Install aks-preview extension if not already installed
az extension add --name aks-preview || az extension update --name aks-preview

# Register NodeAutoProvisioningPreview feature flag
az feature register --namespace "Microsoft.ContainerService" --name "NodeAutoProvisioningPreview"
az provider register --namespace Microsoft.ContainerService

# Wait for feature registration
echo "Waiting for feature registration..."
sleep 30

# Create AKS cluster with NAP enabled
az aks create \
    --name $CLUSTER_NAME \
    --resource-group $RESOURCE_GROUP \
    --node-provisioning-mode Auto \
    --network-plugin azure \
    --network-plugin-mode overlay \
    --network-dataplane cilium \
    --generate-ssh-keys

# Get credentials
az aks get-credentials --name $CLUSTER_NAME --resource-group $RESOURCE_GROUP 
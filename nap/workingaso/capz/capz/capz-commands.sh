#!/bin/bash
# Set up the environment variables
# Azure subscription and location
export AZURE_SUBSCRIPTION_ID="<your-subscription-id>"
export AZURE_TENANT_ID="<your-tenant-id>"
export AZURE_LOCATION="<your-region>"  # e.g., eastus

# Cluster basics
export CLUSTER_NAME="<your-cluster-name>"
export KUBERNETES_VERSION="1.31.0"  # Match to your required version
export RESOURCE_GROUP="${CLUSTER_NAME}"

# Network configuration
export VNET_RG="<your-vnet-resource-group>"
export VNET_NAME="<your-vnet-name>"
export SUBNET_NAME="<your-subnet-name>"
export POD_CIDR="10.244.0.0/16"
export SERVICE_CIDR="10.96.0.0/16"
export DNS_SERVICE_IP="10.96.0.10"

# Node configuration
export VM_SIZE="Standard_D2s_v3"
export NODE_COUNT="3"
export OS_DISK_SIZE="128"
export ENABLE_AUTO_SCALING="true"

# Identity
export IDENTITY_RG="<your-identity-resource-group>"
export CONTROL_PLANE_IDENTITY="<your-control-plane-identity>"
export RUNTIME_IDENTITY="<your-runtime-identity>"
export KUBELET_CLIENT_ID="<your-kubelet-client-id>"
export KUBELET_OBJECT_ID="<your-kubelet-object-id>"

# AAD integration
export ADMIN_GROUP_ID="<your-admin-group-id>"

# Log Analytics
export LOG_ANALYTICS_RG="<your-log-analytics-resource-group>"
export LOG_ANALYTICS_WORKSPACE="<your-log-analytics-workspace>"

# Tags
export APPLICATION_TAG="<your-application-tag>"
export COST_CENTER="<your-cost-center>"
export ENVIRONMENT="<your-environment>"

# SSH Key - generate or use existing
export SSH_PUBLIC_KEY="$(cat ~/.ssh/id_rsa.pub)"

# CAPZ specific settings
export AZURE_CLUSTER_IDENTITY_SECRET_NAME="cluster-identity-secret"
export AZURE_CLUSTER_IDENTITY_SECRET_NAMESPACE="default"
export CLUSTER_IDENTITY_NAME="cluster-identity"
export EXP_MACHINE_POOL=true  # Enable MachinePool feature

# Create a management cluster with kind
kind create cluster

# Create a service principal for CAPZ
az ad sp create-for-rbac --role Contributor --scopes="/subscriptions/${AZURE_SUBSCRIPTION_ID}" --sdk-auth > sp.json

# Extract credentials
export AZURE_CLIENT_SECRET="$(cat sp.json | jq -r .clientSecret | tr -d '\n')"
export AZURE_CLIENT_ID="$(cat sp.json | jq -r .clientId | tr -d '\n')"

# Create a secret in the management cluster for the SP credentials
kubectl create secret generic "${AZURE_CLUSTER_IDENTITY_SECRET_NAME}" \
  --from-literal=clientSecret="${AZURE_CLIENT_SECRET}" \
  --namespace "${AZURE_CLUSTER_IDENTITY_SECRET_NAMESPACE}"

# Install the Cluster API provider for Azure
clusterctl init --infrastructure azure

# Apply the cluster configuration
# (Assuming you've saved the YAML configuration to aks-cluster.yaml)
kubectl apply -f aks-cluster.yaml

# Monitor the deployment
kubectl get cluster-api -o wide
kubectl get azuremanagedcontrolplane,azuremanagedcluster,azuremanagedmachinepool -o wide

# Get kubeconfig once the cluster is provisioned (may take 10-15 minutes)
clusterctl get kubeconfig ${CLUSTER_NAME} > ${CLUSTER_NAME}.kubeconfig

# Set the new kubeconfig as your current context
export KUBECONFIG=${CLUSTER_NAME}.kubeconfig

# Verify access to the new cluster
kubectl get nodes

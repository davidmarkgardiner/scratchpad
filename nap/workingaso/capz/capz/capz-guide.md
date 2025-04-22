# Deploying AKS Cluster with CAPZ: Step-by-Step Guide

This guide walks through the process of deploying an AKS cluster using Cluster API Provider for Azure (CAPZ), replicating the configuration from your ASO-based deployment.

## Prerequisites

- kubectl CLI installed
- Azure CLI installed and configured
- kind or another Kubernetes cluster for management
- Helm (for CAPI operator installation)

## Step 1: Set Up Environment Variables

First, set up the necessary environment variables that will be used throughout the deployment process:

```bash
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
```

## Step 2: Create a Management Cluster

You'll need a Kubernetes cluster to act as the management plane. Using kind is the simplest approach:

```bash
kind create cluster
```

## Step 3: Create Service Principal for CAPZ

```bash
# Create a service principal for CAPZ
az ad sp create-for-rbac --role Contributor --scopes="/subscriptions/${AZURE_SUBSCRIPTION_ID}" --sdk-auth > sp.json

# Extract credentials
export AZURE_CLIENT_SECRET="$(cat sp.json | jq -r .clientSecret | tr -d '\n')"
export AZURE_CLIENT_ID="$(cat sp.json | jq -r .clientId | tr -d '\n')"
```

## Step 4: Create Cluster Identity Secret

Create a secret in the management cluster to store the Service Principal credentials:

```bash
kubectl create secret generic "${AZURE_CLUSTER_IDENTITY_SECRET_NAME}" \
  --from-literal=clientSecret="${AZURE_CLIENT_SECRET}" \
  --namespace "${AZURE_CLUSTER_IDENTITY_SECRET_NAMESPACE}"
```

## Step 5: Install Cluster API Components

```bash
# Initialize with the Azure infrastructure provider
clusterctl init --infrastructure azure
```

## Step 6: Create Cluster Configuration

Now create a comprehensive YAML file for your AKS cluster with the advanced configuration:

```yaml
---
apiVersion: cluster.x-k8s.io/v1beta1
kind: Cluster
metadata:
  name: ${CLUSTER_NAME}
  namespace: default
spec:
  clusterNetwork:
    services:
      cidrBlocks: ["${SERVICE_CIDR}"]
    pods:
      cidrBlocks: ["${POD_CIDR}"]
  controlPlaneRef:
    apiVersion: infrastructure.cluster.x-k8s.io/v1beta1
    kind: AzureManagedControlPlane
    name: ${CLUSTER_NAME}
  infrastructureRef:
    apiVersion: infrastructure.cluster.x-k8s.io/v1beta1
    kind: AzureManagedCluster
    name: ${CLUSTER_NAME}
---
apiVersion: infrastructure.cluster.x-k8s.io/v1beta1
kind: AzureManagedControlPlane
metadata:
  name: ${CLUSTER_NAME}
  namespace: default
spec:
  location: ${AZURE_LOCATION}
  resourceGroupName: ${RESOURCE_GROUP}
  subscriptionID: ${AZURE_SUBSCRIPTION_ID}
  version: ${KUBERNETES_VERSION}
  sshPublicKey: ${SSH_PUBLIC_KEY}
  
  # Network Configuration
  virtualNetwork:
    name: ${VNET_NAME}
    resourceGroup: ${VNET_RG}
    subnet:
      name: ${SUBNET_NAME}
  networkPlugin: azure
  networkPluginMode: overlay
  networkPolicy: cilium
  networkDataplane: cilium
  outboundType: userDefinedRouting
  dnsServiceIP: ${DNS_SERVICE_IP}
  
  # Private Cluster Configuration
  apiServerAccessProfile:
    enablePrivateCluster: true
    enablePrivateClusterPublicFQDN: true
    privateDNSZone: none
    disableRunCommand: true
  
  # AAD Integration
  aadProfile:
    managed: true
    enableAzureRBAC: true
    adminGroupObjectIDs:
    - "${ADMIN_GROUP_ID}"
  
  # Identity Configuration
  identity:
    type: UserAssigned
    resourceID: /subscriptions/${AZURE_SUBSCRIPTION_ID}/resourcegroups/${IDENTITY_RG}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/${CONTROL_PLANE_IDENTITY}
  
  # Additional Configurations
  disableLocalAccounts: true
  
  # Addon Profiles
  addonProfiles:
  - name: azureKeyvaultSecretsProvider
    enabled: true
    config:
      enableSecretRotation: "true"
      rotationPollInterval: "30m"
  - name: azurepolicy
    enabled: true
    config:
      version: "v2"
  
  # OIDC Issuer
  oidcIssuerProfile:
    enabled: true
  
  # Auto-upgrade Profile
  autoUpgradeProfile:
    upgradeChannel: stable
    nodeOSUpgradeChannel: NodeImage
  
  # Security Profile
  securityProfile:
    workloadIdentity:
      enabled: true
    imageCleaner:
      enabled: true
      intervalHours: 168
    defender:
      securityMonitoring:
        enabled: true
      logAnalyticsWorkspaceResourceID: /subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${LOG_ANALYTICS_RG}/providers/Microsoft.OperationalInsights/workspaces/${LOG_ANALYTICS_WORKSPACE}
  
  # Storage Profile
  storageProfile:
    blobCSIDriver:
      enabled: true
    diskCSIDriver:
      enabled: true
    fileCSIDriver:
      enabled: true
    snapshotController:
      enabled: true
  
  # ServiceMesh Profile
  serviceMeshProfile:
    mode: Istio
    istio:
      revisions:
      - asm-1-23
      components:
        ingressGateways:
        - enabled: true
          mode: Internal
  
  # Tags
  tags:
    Application: ${APPLICATION_TAG}
    CostCenter: ${COST_CENTER}
    Environment: ${ENVIRONMENT}
  
  # SKU
  sku:
    tier: Standard
---
apiVersion: infrastructure.cluster.x-k8s.io/v1beta1
kind: AzureManagedCluster
metadata:
  name: ${CLUSTER_NAME}
  namespace: default
---
apiVersion: cluster.x-k8s.io/v1beta1
kind: MachinePool
metadata:
  name: systempool
  namespace: default
spec:
  clusterName: ${CLUSTER_NAME}
  replicas: ${NODE_COUNT}
  template:
    spec:
      bootstrap:
        dataSecretName: ""
      clusterName: ${CLUSTER_NAME}
      infrastructureRef:
        apiVersion: infrastructure.cluster.x-k8s.io/v1beta1
        kind: AzureManagedMachinePool
        name: systempool
        namespace: default
      version: ${KUBERNETES_VERSION}
---
apiVersion: infrastructure.cluster.x-k8s.io/v1beta1
kind: AzureManagedMachinePool
metadata:
  name: systempool
  namespace: default
spec:
  mode: System
  sku: ${VM_SIZE}
  osDiskSizeGB: ${OS_DISK_SIZE}
  osSKU: AzureLinux
  
  # Node scaling
  enableAutoScaling: ${ENABLE_AUTO_SCALING}
  maxPods: 250
  
  # Node security profile
  securityProfile:
    enableSecureBoot: false
    enableVTPM: false
  
  # Availability zones
  availabilityZones:
  - "1"
  - "2"
  - "3"
  
  # Node upgrade settings
  upgradeSettings:
    maxSurge: "10%"
  
  # Identity settings
  kubeletIdentityClientID: ${KUBELET_CLIENT_ID}
  runtimeIdentityResourceID: /subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${IDENTITY_RG}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/${RUNTIME_IDENTITY}
---
apiVersion: infrastructure.cluster.x-k8s.io/v1beta1
kind: AzureClusterIdentity
metadata:
  name: ${CLUSTER_IDENTITY_NAME}
  namespace: default
spec:
  type: ServicePrincipal
  tenantID: ${AZURE_TENANT_ID}
  clientID: ${AZURE_CLIENT_ID}
  clientSecret:
    name: ${AZURE_CLUSTER_IDENTITY_SECRET_NAME}
    namespace: ${AZURE_CLUSTER_IDENTITY_SECRET_NAMESPACE}
  allowedNamespaces:
    selector:
      matchLabels: {}
```

Save this to a file named `aks-cluster.yaml`.

## Step A: Alternative Template Generation (Optional)

Instead of writing the YAML manually, you can generate a base template with clusterctl and then modify it:

```bash
clusterctl generate cluster ${CLUSTER_NAME} \
  --kubernetes-version ${KUBERNETES_VERSION} \
  --flavor aks > aks-cluster.yaml
```

This generates a basic AKS cluster configuration that you'll need to enhance with the settings from your ASO version.

## Step 7: Apply the Cluster Configuration

Deploy your cluster:

```bash
# Apply the cluster manifest
kubectl apply -f aks-cluster.yaml

# Check the status
kubectl get cluster-api -o wide
```

## Step 8: Get Kubeconfig for the New Cluster

Once the cluster is provisioned (this may take 10-15 minutes), retrieve the kubeconfig:

```bash
# Get kubeconfig for the new AKS cluster
clusterctl get kubeconfig ${CLUSTER_NAME} > ${CLUSTER_NAME}.kubeconfig

# Set it as your current context
export KUBECONFIG=${CLUSTER_NAME}.kubeconfig

# Verify access to the new cluster
kubectl get nodes
```

## Step 9: Install CSI Drivers and Add-ons (If Needed)

While many add-ons are configured in the AzureManagedControlPlane, you might need to install additional components:

```bash
# Install cert-manager if needed
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.1/cert-manager.yaml
```

## Advanced Features and Customizations

### 1. Enabling Preview Features

If you need to use preview features not yet represented in the CAPZ API:

```yaml
apiVersion: infrastructure.cluster.x-k8s.io/v1beta1
kind: AzureManagedControlPlane
metadata:
  name: ${CLUSTER_NAME}
spec:
  enablePreviewFeatures: true
  asoManagedClusterPatches:
  - '{"spec": {"enableNamespaceResources": true}}'
```

### 2. Using Existing Resource Groups

If you want to use existing resource groups for your cluster:

```yaml
apiVersion: infrastructure.cluster.x-k8s.io/v1beta1
kind: AzureManagedControlPlane
metadata:
  name: ${CLUSTER_NAME}
spec:
  resourceGroupName: ${EXISTING_RESOURCE_GROUP}
```

### 3. AKS Fleet Integration

To join your cluster to an AKS fleet:

```yaml
apiVersion: infrastructure.cluster.x-k8s.io/v1beta1
kind: AzureManagedControlPlane
metadata:
  name: ${CLUSTER_NAME}
spec:
  fleetsMember:
    group: fleet-update-group
    managerName: fleet-manager-name
    managerResourceGroup: fleet-manager-resource-group
```

## Troubleshooting

1. **Check CAPZ controller logs**:
   ```bash
   kubectl logs -n capz-system deployment/capz-controller-manager -c manager
   ```

2. **Check CAPI controller logs**:
   ```bash
   kubectl logs -n capi-system deployment/capi-controller-manager -c manager
   ```

3. **Check AzureManagedControlPlane status**:
   ```bash
   kubectl describe azuremanagedcontrolplane ${CLUSTER_NAME}
   ```

4. **Check LongRunningOperationStates**:
   If operations seem stuck, check the long-running operation state:
   ```bash
   kubectl get azuremanagedcontrolplane ${CLUSTER_NAME} -o jsonpath='{.status.longRunningOperationStates}'
   ```

## Cleanup

To delete the cluster:

```bash
kubectl delete cluster ${CLUSTER_NAME}
```

This will remove all the cluster resources including the AKS cluster in Azure.

# AKS with Node Auto Provisioning (NAP)

This repository contains configurations for setting up an Azure Kubernetes Service (AKS) cluster with Node Auto Provisioning (NAP) enabled, along with essential components like Cert Manager, External Secrets, and Kyverno.

## Prerequisites

- Azure CLI installed
- `aks-preview` CLI extension (minimum version 0.5.170)
- Azure subscription with appropriate permissions
- Registered `NodeAutoProvisioningPreview` feature flag

## Cluster Setup

1. Register the NAP feature flag:
```bash
az feature register --namespace "Microsoft.ContainerService" --name "NodeAutoProvisioningPreview"
az provider register --namespace Microsoft.ContainerService
```

2. Create the AKS cluster with NAP enabled:
```bash
az aks create \
    --name $CLUSTER_NAME \
    --resource-group $RESOURCE_GROUP_NAME \
    --node-provisioning-mode Auto \
    --network-plugin azure \
    --network-plugin-mode overlay \
    --network-dataplane cilium \
    --generate-ssh-keys
```

## Component Deployment

### 1. Cert Manager

Deploy Cert Manager with system node affinity:
```bash
helm upgrade --install cert-manager jetstack/cert-manager \
    --namespace cert-manager \
    --create-namespace \
    --values manifests/cert-manager-values.yaml
```

### 2. External Secrets

Deploy External Secrets with user node affinity:
```bash
helm upgrade --install external-secrets external-secrets/external-secrets \
    --namespace external-secrets \
    --create-namespace \
    --values manifests/external-secrets-values.yaml
```

### 3. Kyverno

Deploy Kyverno with system node affinity:
```bash
helm upgrade --install kyverno kyverno/kyverno \
    --namespace kyverno \
    --create-namespace \
    --values manifests/kyverno-values.yaml
```

## Node Pool Configuration

The setup uses two types of node pools:

1. System Node Pool (default)
   - Used for system components (cert-manager, kyverno)
   - Configured with `kubernetes.azure.com/scalesetpriority: system`

2. User Node Pool
   - Used for application workloads (external-secrets)
   - Configured with `kubernetes.azure.com/scalesetpriority: user`

## Best Practices Implemented

1. Node Affinity
   - System components pinned to system nodes
   - Application workloads pinned to user nodes

2. Pod Anti-Affinity
   - High availability through pod distribution
   - Prevents single node failures

3. Resource Management
   - CPU and memory requests/limits defined
   - Prevents resource starvation

4. Tolerations
   - CriticalAddonsOnly for system components
   - Node readiness/unreachability handling

## Monitoring

Monitor NAP events:
```bash
kubectl get events -A --field-selector source=karpenter -w
```

## Limitations

- Azure CNI Overlay with Cilium required
- No Windows node pools
- No custom kubelet configurations
- No IPv6 support
- Managed identity required (no service principals)
- No disk encryption sets
- No custom CA trust certificates
- No start/stop mode
- No HTTP proxy
- No OutboundType mutation after creation
- No private cluster support

## Troubleshooting

1. Check pod scheduling:
```bash
kubectl get pods -A -o wide
```

2. Check node pool status:
```bash
kubectl get nodepools
```

3. Check NAP events:
```bash
kubectl get events -A --field-selector source=karpenter
``` 
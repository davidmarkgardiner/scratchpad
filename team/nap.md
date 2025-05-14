# AKS Node AutoProvisioning (NAP) Troubleshooting Guide

## Current Situation

Your AKS cluster has Node AutoProvisioning (NAP) enabled with multiple nodepools defined:
- `default`
- `high-perf-pool`
- `infra-pool`
- `spot-pool`
- `system-surge`
- `uk8score-pool`

However, pods that should be scheduled on nodes with the taint `workload-type=infrastructure:NoSchedule` are failing to be scheduled, despite having the correct tolerations. NAP is attempting to create nodes but they're failing with "LaunchFailed" errors.

## Troubleshooting Steps

### 1. Check Azure Resource Provider Quotas

```bash
# Check for quota limits in your subscription
az vm list-usage --location westeurope --output table
```

Look for any resources at or near their limits.

### 2. Check AKS-managed identity permissions

Ensure the AKS-managed identity has correct RBAC permissions on the node resource group:

```bash
# Get the managed identity used by AKS
az aks show -g <resource-group> -n <cluster-name> --query "identityProfile.kubeletidentity.clientId" -o tsv

# Check role assignments
az role assignment list --assignee <identity-client-id> --scope /subscriptions/<subscription-id>/resourceGroups/MC_*
```

### 3. Check VM SKU availability in your region

```bash
# Check if the VM size is available in your region
az vm list-skus --location westeurope --output table
```

### 4. Check the AKSNodeClass configuration

```bash
# Get detailed information about the node class
kubectl describe aksnodeclass infra-nodes
```

Verify that the VM size, image version, and other configuration are valid.

### 5. Check for resource group locks or policies

```bash
# Check for locks on the node resource group
az lock list --resource-group MC_-weu-dev-d04_uk8s-tsshared-weu-gt025-int-d04_westeurope
```

### 6. Review the Karpenter controller logs

```bash
# Get logs from the Karpenter controller
kubectl logs -n kube-system -l app.kubernetes.io/name=karpenter
```

Look for detailed error messages about the failed node creation.

### 7. Check Azure Activity Logs

Check Azure Activity Logs for the node resource group to see specific errors during VM creation:

```bash
az monitor activity-log list --resource-group MC_-weu-dev-d04_uk8s-tsshared-weu-gt025-int-d04_westeurope --start-time 2025-05-13T00:00:00Z
```

### 8. Verify Network Configuration

NAP requires Azure CNI Overlay with Cilium. Verify the cluster's network configuration:

```bash
az aks show -g <resource-group> -n <cluster-name> --query "networkProfile"
```

Ensure it shows:
- networkPlugin: azure
- networkPluginMode: overlay
- networkDataplane: cilium

## Potential Solutions

1. **Quota Issues**: Request a quota increase if you've hit limits.

2. **Node Class Configuration**: Check if the VM SKU defined in your AKSNodeClass is available. Try using a different VM size.

3. **Permissions**: Ensure the AKS-managed identity has Contributor role on the node resource group.

4. **Network Configuration**: If using a custom VNET, ensure subnet has enough IP addresses available.

5. **Limit Concurrent Node Creation**: Modify NodePool's `spec.limits` to reduce resource requests.

6. **Update NAP Extension**: Ensure you're using the latest aks-preview extension version.

## If All Else Fails

As a temporary workaround, you can:

1. Disable NAP and switch back to manual node pools:
   ```bash
   az aks update --name <cluster-name> --resource-group <resource-group> --node-provisioning-mode Manual
   ```

2. Create a traditional node pool with the required taints:
   ```bash
   az aks nodepool add --name infrapool --cluster-name <cluster-name> --resource-group <resource-group> --node-taints workload-type=infrastructure:NoSchedule
   ```
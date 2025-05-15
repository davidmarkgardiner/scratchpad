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

---

# Analyzing the Policy and Its Impact on NAP

## What This Policy Does

This policy, named "Deny-VMCustomScriptName", is designed to enforce naming conventions for VM Custom Script Extensions in your Azure environment. Specifically:

1. It blocks any CustomScriptExtension (Windows) from Microsoft.Compute publisher unless its name contains "*customscript"

2. It blocks any CustomScript (Linux) from Microsoft.Azure.Extensions publisher unless its name contains "*configure-settings"

The policy has a "deny" effect, meaning it will completely block deployments that don't comply with these naming conventions.

## Why This Is Blocking NAP

Node AutoProvisioning (NAP) in AKS works by using Karpenter to dynamically create Virtual Machines. During VM creation, AKS needs to install a Custom Script Extension on each node to:

1. Configure the VM as a Kubernetes node
2. Install required components (kubelet, container runtime, etc.)
3. Join the node to the AKS cluster

The error logs you shared earlier explicitly show this failure during VM creation:

```
creating instance, creating VM CSE for VM "aks-infra-pool-95ff4", PUT resourceGroups/MC_AT39473-weu-dev-d04_uk8s-tsshared-weu-gt025-int-d04_westeurope/providers/Microsoft.Compute/virtualMachines/aks-infra-pool-95ff4/exte...
```

Here, "CSE" refers to "Custom Script Extension", and AKS is trying to create an extension that doesn't comply with your policy:

- For Linux nodes (which AKS NAP uses), the extension name must contain "*configure-settings"
- However, AKS is likely using a different naming convention for these extensions

## Solution Options

1. **Create a Policy Exemption**:
   Create an exemption for the AKS node resource group:
   ```bash
   az policy exemption create --name "Allow-AKS-NAP-Extensions" \
     --resource-group "MC_AT39473-weu-dev-d04_uk8s-tsshared-weu-gt025-int-d04_westeurope" \
     --policy-assignment-id "<policy-assignment-id>" \
     --exemption-category "Waiver" \
     --display-name "Allow AKS NAP Custom Script Extensions" \
     --description "Exemption to allow AKS Node AutoProvisioning to create VMs with custom extensions"
   ```

2. **Modify the Policy**:
   Update the policy to include exceptions for names used by AKS NAP. You'd need to determine what naming pattern AKS uses for its custom script extensions.

3. **Create a Specific Policy for AKS Resource Groups**:
   Create a modified version of this policy that applies only to non-AKS resource groups by adding a condition to exclude MC_* resource groups.

## Best Approach

The simplest solution is likely creating a policy exemption for the AKS node resource group. This allows your organization to maintain the naming convention policy while enabling NAP to function properly.

To find the exact policy assignment ID:

```bash
az policy assignment list --scope /subscriptions/<subscription-id>/resourceGroups/MC_AT39473-weu-dev-d04_uk8s-tsshared-weu-gt025-int-d04_westeurope --query "[?policyDefinitionId=='<policy-definition-id>'].id" -o tsv
```

Replace `<policy-definition-id>` with the full ID from your policy output.

Would you like me to help you create the policy exemption, or do you have a different approach in mind?
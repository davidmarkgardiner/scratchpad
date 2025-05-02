# Troubleshooting Karpenter LaunchFailed CSE Error in AKS

## Problem

You're seeing the following error when trying to deploy a nodepool using Karpenter in AKS:

```
Last Transition Time:  2025-04-23T14:39:42Z
Message:               creating instance, creating VM CSE for VM "aks-infra-pool-dfc6j"
Reason:                LaunchFailed
Status:                Unknown
Type:                  Launched
```

The error specifically mentions "CSE" (Custom Script Extension), which is the Azure VM extension that runs during node bootstrapping to install Kubernetes components and join nodes to the cluster.

## Root Cause

This error typically occurs due to one of the following issues:

1. **Bootstrap token expiration** - The Kubernetes bootstrap token used for automatically joining nodes to the cluster has expired
2. **Network connectivity issues** - The VM cannot reach the Kubernetes API server
3. **DNS resolution failures** - The VM cannot resolve DNS for the API server
4. **Proxy/firewall issues** - Outbound connectivity is blocked on port 443 or other required ports
5. **Misconfigured AKSNodeClass** - Issues with the VM image or other configuration parameters

## Solution

### 1. Check for Bootstrap Token Expiration

The most common cause is that the bootstrap token used by Karpenter to join nodes to the AKS cluster has expired. This token typically has a limited lifetime (often 24 hours).

**Fix:**
```bash
# Get current tokens
kubectl get secrets -n kube-system | grep bootstrap-token

# Create a new bootstrap token
kubectl create token bootstrap-kubelet --duration=24h

# You may need to update the Karpenter controller or restart it
kubectl rollout restart deployment -n kube-system karpenter
```

### 2. Check Network Configuration

Verify that the network configuration allows nodes to connect to the API server:

```bash
# Check the Node Claim status
kubectl describe nodeclaim <nodeclaim-name>

# Check the Karpenter controller logs
kubectl logs -n kube-system -l app.kubernetes.io/name=karpenter
```

### 3. Check Azure VM Details

Examine the VM that failed to join:

```bash
# Find the VM in Azure
az vm list -g <resource-group> -o table | grep infra-pool

# Check VM extension status
az vm extension list --vm-name <vm-name> -g <resource-group>

# Optional: Check VM diagnostics/boot logs
az vm boot-diagnostics get-boot-log --name <vm-name> -g <resource-group>
```

### 4. Verify AKSNodeClass Configuration

Check your AKSNodeClass configuration:

```bash
kubectl get aksnodeclass infra-nodes -o yaml
```

Ensure:
- The `imageFamily` is correctly set to "AzureLinux" 
- The VM size is available in your region

### 5. Modify Your Nodepool Configuration

Consider modifying your nodepool to address specific issues:

- Add proper startup taints to prevent scheduling before node is ready
- Ensure zones are configured correctly 
- Verify requirements match available VM types

### 6. Check for Resource Constraints

Ensure you have available quota in your Azure subscription for the VM size you're requesting.

## Prevention

To prevent this issue in the future:

1. Set up a CronJob to regularly refresh bootstrap tokens
2. Configure longer-lived bootstrap tokens
3. Ensure proper network connectivity from node subnets to API server
4. Validate VM size availability in your region before deployment

## Example of a Fixed NodePool Configuration

```yaml
apiVersion: karpenter.azure.com/v1alpha2
kind: AKSNodeClass
metadata:
  name: infra-nodes
spec:
  imageFamily: AzureLinux
  osDiskSizeGB: 128
---
apiVersion: karpenter.sh/v1beta1
kind: NodePool
metadata:
  name: infra-pool
spec:
  disruption:
    consolidationPolicy: WhenUnderutilized
    expireAfter: Never  # Infrastructure nodes should be stable
    consolidateAfter: Never  # Prevent consolidation of infrastructure workloads
  template:
    metadata:
      labels:
        node-type: infrastructure
    spec:
      nodeClassRef:
        name: infra-nodes
      taints:
        - key: "workload-type"
          value: "infrastructure"
          effect: "NoSchedule"
      startupTaints:
        - key: "node.kubernetes.io/not-ready"
          effect: "NoSchedule"
      requirements:
        - key: "karpenter.sh/capacity-type"
          operator: In
          values: ["on-demand"]
        - key: "karpenter.azure.com/sku-family"
          operator: In
          values: ["D"]
        - key: "karpenter.azure.com/sku-version"
          operator: In
          values: ["3"]
        - key: "topology.kubernetes.io/zone"  # Specify zone explicitly
          operator: In
          values: ["1"]
``` 
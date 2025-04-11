I'll help you create a comprehensive multi-node pool setup for different workload types. The best practice is to create separate NodePools for each workload type with specific configurations. Let me show you how:

1. First, let's create NodeClasses for different node types:

```yaml:node-classes.yaml
apiVersion: karpenter.azure.com/v1alpha2
kind: AKSNodeClass
metadata:
  name: system-nodes
spec:
  imageFamily: AzureLinux
  osDiskSizeGB: 128
---
apiVersion: karpenter.azure.com/v1alpha2
kind: AKSNodeClass
metadata:
  name: spot-nodes
spec:
  imageFamily: AzureLinux
  osDiskSizeGB: 128
---
apiVersion: karpenter.azure.com/v1alpha2
kind: AKSNodeClass
metadata:
  name: gpu-nodes
spec:
  imageFamily: AzureLinux
  osDiskSizeGB: 256
---
apiVersion: karpenter.azure.com/v1alpha2
kind: AKSNodeClass
metadata:
  name: batch-nodes
spec:
  imageFamily: AzureLinux
  osDiskSizeGB: 128
---
apiVersion: karpenter.azure.com/v1alpha2
kind: AKSNodeClass
metadata:
  name: infra-nodes
spec:
  imageFamily: AzureLinux
  osDiskSizeGB: 128
```

```yaml:node-pools.yaml
apiVersion: karpenter.sh/v1beta1
kind: NodePool
metadata:
  name: system-pool
spec:
  disruption:
    consolidationPolicy: WhenUnderutilized
    expireAfter: Never
  template:
    metadata:
      labels:
        node-type: system
    spec:
      nodeClassRef:
        name: system-nodes
      taints:
        - key: CriticalAddonsOnly
          value: "true"
          effect: NoSchedule
      requirements:
        - key: kubernetes.io/os
          operator: In
          values: ["linux"]
        - key: karpenter.azure.com/sku-family
          operator: In
          values: ["D"]
        - key: karpenter.azure.com/sku-version
          operator: In
          values: ["3"]
---
apiVersion: karpenter.sh/v1beta1
kind: NodePool
metadata:
  name: spot-pool
spec:
  disruption:
    consolidationPolicy: WhenUnderutilized
    expireAfter: 24h
  template:
    metadata:
      labels:
        node-type: spot
    spec:
      nodeClassRef:
        name: spot-nodes
      taints:
        - key: spot
          value: "true"
          effect: NoSchedule
      requirements:
        - key: kubernetes.io/os
          operator: In
          values: ["linux"]
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["spot"]
        - key: karpenter.azure.com/sku-family
          operator: In
          values: ["D"]
---
apiVersion: karpenter.sh/v1beta1
kind: NodePool
metadata:
  name: gpu-pool
spec:
  disruption:
    consolidationPolicy: WhenUnderutilized
    expireAfter: Never
  template:
    metadata:
      labels:
        node-type: gpu
    spec:
      nodeClassRef:
        name: gpu-nodes
      taints:
        - key: nvidia.com/gpu
          value: "true"
          effect: NoSchedule
      requirements:
        - key: kubernetes.io/os
          operator: In
          values: ["linux"]
        - key: karpenter.azure.com/sku-family
          operator: In
          values: ["NC"]
        - key: karpenter.azure.com/sku-gpu-count
          operator: Gt
          values: ["0"]
---
apiVersion: karpenter.sh/v1beta1
kind: NodePool
metadata:
  name: batch-pool
spec:
  disruption:
    consolidationPolicy: WhenUnderutilized
    expireAfter: 12h
  template:
    metadata:
      labels:
        node-type: batch
    spec:
      nodeClassRef:
        name: batch-nodes
      taints:
        - key: workload-type
          value: batch
          effect: NoSchedule
      requirements:
        - key: kubernetes.io/os
          operator: In
          values: ["linux"]
        - key: karpenter.azure.com/sku-family
          operator: In
          values: ["F"]  # Compute optimized
---
apiVersion: karpenter.sh/v1beta1
kind: NodePool
metadata:
  name: infra-pool
spec:
  disruption:
    consolidationPolicy: WhenUnderutilized
    expireAfter: Never
  template:
    metadata:
      labels:
        node-type: infrastructure
    spec:
      nodeClassRef:
        name: infra-nodes
      taints:
        - key: workload-type
          value: infrastructure
          effect: NoSchedule
      requirements:
        - key: kubernetes.io/os
          operator: In
          values: ["linux"]
        - key: karpenter.azure.com/sku-family
          operator: In
          values: ["D"]
        - key: karpenter.azure.com/sku-version
          operator: In
          values: ["3"]
```


Now, let me explain the key aspects of this setup:

1. **System Nodes**:
   - Uses D-series VMs
   - Has `CriticalAddonsOnly` taint
   - Never expires
   - For system workloads only

2. **Spot Nodes**:
   - Uses spot instances for cost savings
   - Has `spot` taint
   - Expires after 24h for rotation
   - Good for fault-tolerant workloads

3. **GPU Nodes**:
   - Uses NC-series VMs with GPUs
   - Has `nvidia.com/gpu` taint
   - Never expires
   - Specifically for GPU workloads

4. **Batch Nodes**:
   - Uses F-series (compute-optimized) VMs
   - Has `workload-type=batch` taint
   - Expires after 12h
   - Good for batch processing jobs

5. **Infrastructure Nodes**:
   - Uses D-series VMs
   - Has `workload-type=infrastructure` taint
   - Never expires
   - For critical infrastructure components

To deploy workloads to specific nodes, you need matching tolerations and affinities. Here's an example for a GPU workload:

```yaml
spec:
  template:
    spec:
      tolerations:
      - key: "nvidia.com/gpu"
        operator: "Equal"
        value: "true"
        effect: "NoSchedule"
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: node-type
                operator: In
                values: ["gpu"]
```

Key benefits of this setup:
1. Clear separation of workloads
2. Cost optimization with spot instances
3. Resource isolation
4. Automatic scaling per workload type
5. Different VM types for different needs

Would you like me to:
1. Show an example workload deployment for any specific node type?
2. Explain how to set up autoscaling limits for each pool?
3. Add any specific requirements to any of the node pools?

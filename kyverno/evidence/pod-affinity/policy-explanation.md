# Pod Affinity Policy Explanation

## Policy Overview
This Kyverno policy (`insert-pod-affinity-spot`) automatically modifies Pod configurations in specific namespaces to enforce scheduling rules for spot instances and critical workloads.

## Critical Workload Strategy
The policy implements a nuanced approach to critical workload placement:
- **Node Access**: Tolerations allow pods to run on nodes marked for critical workloads
- **Workload Separation**: Pod anti-affinity preferences keep pods away from critical addon pods
- **Not Conflicting**: The toleration and anti-affinity work together - allowing pods to use critical infrastructure while avoiding direct co-location with critical pods

## Namespace Targeting
- Only applies to namespaces matching the pattern: `at[0-9]{5}-.*`
- Example matches: `at12345-prod`, `at54321-dev`
- Example non-matches: `default`, `kube-system`, `at123-prod`

## Policy Modifications

### 1. Tolerations
Adds two tolerations to allow pods to run on specific node types:

```yaml
tolerations:
- key: "CriticalAddonsOnly"
  operator: "Exists"
  effect: "NoSchedule"
- key: "kubernetes.azure.com/scalesetpriority"
  operator: "Equal"
  value: "spot"
  effect: "NoSchedule"
```
- First toleration: Allows pods to run on nodes marked for critical addons
- Second toleration: Allows pods to run on Azure spot instance nodes

### 2. Node Affinity
Configures two types of node affinity rules:

#### Required Node Affinity
```yaml
requiredDuringSchedulingIgnoredDuringExecution:
  nodeSelectorTerms:
    - matchExpressions:
        - key: "kubernetes.azure.com/scalesetpriority"
          operator: In
          values:
            - "spot"
```
- **Hard requirement**: Pods MUST be scheduled on spot instance nodes
- `IgnoredDuringExecution`: If node labels change after pod is running, pod won't be evicted

#### Preferred Node Affinity
```yaml
preferredDuringSchedulingIgnoredDuringExecution:
  - weight: 1
    preference:
      matchExpressions:
        - key: worker
          operator: In
          values:
            - "true"
```
- **Soft preference**: Tries to schedule on worker nodes
- Low weight (1) indicates this is a weak preference

### 3. Pod Anti-Affinity
```yaml
podAntiAffinity:
  preferredDuringSchedulingIgnoredDuringExecution:
  - weight: 100
    podAffinityTerm:
      labelSelector:
        matchExpressions:
        - key: CriticalAddonsOnly
          operator: In
          values:
          - "true"
      topologyKey: kubernetes.io/hostname
```
- **High-weight preference** (100) to avoid scheduling with critical addons
- Uses hostname as topology key to spread across nodes
- Helps maintain high availability by avoiding critical workload concentration

## Mutation Strategy
- Uses `patchStrategicMerge` for modifications
- `+(field)` syntax ensures fields are only added if they don't exist
- Preserves any existing configurations that don't conflict

## Impact
1. **Spot Instance Targeting**: Forces pods to run on spot instances for cost optimization
2. **High Availability**: Spreads critical workloads across nodes
3. **Workload Separation**: Keeps regular workloads separate from critical addons
4. **Flexible Worker Placement**: Soft preference for worker nodes

## Use Cases
- Cost optimization by enforcing spot instance usage
- Improving reliability through workload spreading
- Maintaining separation between critical and non-critical workloads
- Standardizing pod scheduling across specific namespaces 
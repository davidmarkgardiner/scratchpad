# Spot Instance Workload Placement Policy

This policy automatically configures optimal workload placement for deployments running on Azure spot instances. It provides cost optimization while maintaining reliability through intelligent pod distribution.

## How It Works

The policy activates when:
- A namespace has the label `worker-type: spot`
- Any deployment is created in that namespace

## Placement Configuration

### 1. Spot Instance Toleration
```yaml
tolerations:
- key: "kubernetes.azure.com/scalesetpriority"
  operator: "Equal"
  value: "spot"
  effect: "NoSchedule"
```
- Allows pods to be scheduled on spot nodes
- Required because spot nodes typically have a taint to prevent regular workloads

### 2. Pod Anti-Affinity
```yaml
podAntiAffinity:
  preferredDuringSchedulingIgnoredDuringExecution:
  - weight: 100
    podAffinityTerm:
      labelSelector:
        matchExpressions:
        - key: app
          operator: In
          values:
          - [app-label]  # Uses the deployment's app label
      topologyKey: kubernetes.io/hostname
```
- Spreads pods across different nodes
- Reduces impact of spot instance preemption
- Uses `preferredDuringScheduling` for flexibility
- High weight (100) makes spreading a strong preference

### 3. Node Affinity
```yaml
nodeAffinity:
  preferredDuringSchedulingIgnoredDuringExecution:
    - weight: 100
      preference:
        matchExpressions:
          - key: "kubernetes.azure.com/scalesetpriority"
            operator: In
            values:
              - "spot"
    - weight: 1
      preference:
        matchExpressions:
          - key: worker
            operator: In
            values:
              - "true"
```
- Primary preference for spot instances (weight: 100)
- Fallback to regular worker nodes (weight: 1)
- Ensures workloads can run if spot capacity is unavailable

## Benefits

1. **Cost Optimization**
   - Preferentially uses spot instances for significant cost savings (up to 90%)
   - Automatic fallback to regular nodes if spot instances unavailable

2. **High Availability**
   - Pod anti-affinity spreads workloads across nodes
   - Reduces blast radius of spot instance preemption
   - Graceful fallback to regular nodes

3. **Zero Application Changes**
   - Works automatically based on namespace labels
   - No need to modify deployment specs
   - Consistent across all workloads in spot namespaces

## Usage

1. Label your namespace for spot instances:
```bash
kubectl label namespace your-namespace worker-type=spot
```

2. Deploy normally - the policy automatically adds the configuration:
```bash
kubectl create deployment example --image=nginx -n your-namespace
```

## Considerations

- **Node Labels**: Requires Azure AKS-specific node labels
- **Application Suitability**: Best for:
  - Stateless applications
  - Batch processing
  - Dev/Test environments
  - Non-critical workloads
- **Resource Requests**: Consider setting appropriate resource requests/limits
- **Monitoring**: Watch for:
  - Preemption rates
  - Scheduling success rates
  - Pod distribution

## Example Values

```yaml
spotNamespaceLabel: "worker-type: spot"
spotNodeLabel: "kubernetes.azure.com/scalesetpriority: spot"
podAntiAffinityWeight: 100
spotPreferenceWeight: 100
regularNodeWeight: 1
```

These values can be customized in your Helm values file to adjust the policy behavior. 
# Pod Affinity Policy - Namespace Label Selection Test

This test suite validates that the pod affinity policy applies to namespaces with specific labels.

## Policy Overview

The policy adds three configurations to deployments:
1. Pod anti-affinity for better pod distribution
2. Node affinity for spot instance scheduling
3. Tolerations for spot instances

## Test Cases

### 1. Matching Namespace Pod
- Namespace must have label: `worker-type: worker|spot|gpu`
- Expected: Policy should apply and add:
  - Pod anti-affinity configuration
  - Node affinity for spot instances
  - Spot instance tolerations
- Command: `kubectl label namespace at12345-dev worker-type=worker`

### 2. Non-Matching Namespace Pod
- Namespace without required labels
- Expected: Policy should not apply any changes

## Verification Steps

1. Label a test namespace:
   ```bash
   kubectl label namespace at12345-dev worker-type=worker
   ```

2. Apply the policy:
   ```bash
   kubectl apply -f ../../policies/base/pod-antiaffinity.yaml
   ```

3. Create a test deployment:
   ```bash
   kubectl apply -f test-deployment.yaml
   ```

4. Verify the results:
   ```bash
   kubectl get deployment test-deployment -n at12345-dev -o yaml
   ```

## Expected Configuration

The deployment should have:

```yaml
spec:
  template:
    spec:
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: app
                  operator: In
                  values:
                  - "{{app-label-value}}"
              topologyKey: kubernetes.io/hostname
        nodeAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            preference:
              matchExpressions:
              - key: kubernetes.azure.com/scalesetpriority
                operator: In
                values:
                - spot
          - weight: 1
            preference:
              matchExpressions:
              - key: worker
                operator: In
                values:
                - "true"
      tolerations:
      - effect: NoSchedule
        key: kubernetes.azure.com/scalesetpriority
        operator: Equal
        value: spot
``` 
# Spot Instance Affinity Test

This test verifies the behavior of the `mutate-ns-deployment-spotaffinity` Kyverno policy which automatically configures pod anti-affinity and node affinity for deployments in spot instance namespaces.

## Test Overview

The test suite verifies that:
1. Deployments in namespaces labeled with `worker-type: spot` receive:
   - Spot instance tolerations
   - Pod anti-affinity for better distribution
   - Node affinity for spot instance preference
2. Deployments in regular namespaces remain unmodified
3. The policy only applies to deployments with an `app` label

## Test Files

- `test.yaml`: Main test configuration with 4 steps
- `namespaces.yaml`: Defines test namespaces (spot and regular)
- `policy.yaml`: The Kyverno mutation policy
- `deployment-spot.yaml`: Test deployment for spot namespace
- `deployment-regular.yaml`: Test deployment for regular namespace
- `assert-spot-deployment.yaml`: Expected state after mutation
- `assert-regular-deployment.yaml`: Expected state (unchanged)

## Test Steps

1. **Create Namespaces**
   - Creates `spot-test` namespace with `worker-type: spot` label
   - Creates `regular-test` namespace without the label

2. **Apply Policy**
   - Applies the Kyverno mutation policy

3. **Test Spot Namespace**
   - Applies deployment to spot namespace
   - Verifies mutation occurred correctly

4. **Test Regular Namespace**
   - Applies deployment to regular namespace
   - Verifies no mutation occurred

## Expected Mutations

For deployments in spot namespaces:

```yaml
tolerations:
- key: "kubernetes.azure.com/scalesetpriority"
  operator: "Equal"
  value: "spot"
  effect: "NoSchedule"
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
            - ${app-label-value}
        topologyKey: kubernetes.io/hostname
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

## Running the Test

```bash
# Run just this test
kubectl chainsaw test ./tests/spot-affinity

# Run as part of all tests
kubectl chainsaw test ./tests
```

## Troubleshooting

If the test fails:

1. Check namespace labels:
   ```bash
   kubectl get ns spot-test --show-labels
   ```

2. Verify policy is applied:
   ```bash
   kubectl get clusterpolicy mutate-ns-deployment-spotaffinity
   ```

3. Check deployment labels:
   ```bash
   kubectl get deploy -n spot-test test-deployment --show-labels
   ```

4. View policy logs:
   ```bash
   kubectl logs -n kyverno -l app=kyverno
   ``` 
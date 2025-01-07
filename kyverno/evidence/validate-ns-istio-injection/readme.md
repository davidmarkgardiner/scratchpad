# Prevent Istio Injection Label Policy

This policy prevents the `istio-injection=enabled` label from being set on any Namespace, Pod, or Deployment resources, ensuring consistent sidecar injection using the revision label approach rather than the legacy injection label.

## Policy Details

- **File**: `validate-ns-istio-injection.yaml`
- **Type**: ClusterPolicy
- **Action**: Validate
- **Target**: All Namespaces, Pods, and Deployments
- **Validation**: Blocks setting `istio-injection=enabled`
- **Operations**: CREATE, UPDATE

## Test Cases

### 1. Compliant Resources

```yaml
# compliant-namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: test-namespace
  labels:
    environment: dev
    # No istio-injection label
```

```yaml
# compliant-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-app
  namespace: test-namespace
  labels:
    app: test
    # No istio-injection label
spec:
  replicas: 1
  selector:
    matchLabels:
      app: test
  template:
    metadata:
      labels:
        app: test
    spec:
      containers:
      - name: nginx
        image: nginx:1.14.2
```

### 2. Non-Compliant Resources

```yaml
# non-compliant-namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: test-namespace-2
  labels:
    environment: prod
    istio-injection: enabled  # This should be blocked
```

```yaml
# non-compliant-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-app-2
  namespace: test-namespace-2
  labels:
    app: test
    istio-injection: enabled  # This should be blocked
spec:
  replicas: 1
  selector:
    matchLabels:
      app: test
  template:
    metadata:
      labels:
        app: test
    spec:
      containers:
      - name: nginx
        image: nginx:1.14.2
```

## Testing Procedure

### Prerequisites
- Access to a Kubernetes cluster
- kubectl CLI tool
- Kyverno installed in the cluster
- Istio installed in the cluster

### Test Steps

1. Apply the policy:
   ```bash
   kubectl apply -f validate-ns-istio-injection.yaml
   ```

2. Test with compliant resources:
   ```bash
   # Apply compliant namespace
   kubectl apply -f compliant-namespace.yaml
   
   # Should succeed
   kubectl get ns test-namespace --show-labels
   ```

3. Test with non-compliant resources:
   ```bash
   # Try to apply non-compliant namespace
   kubectl apply -f non-compliant-namespace.yaml
   
   # Should be rejected with validation error
   ```

4. Test label modification:
   ```bash
   # Try to add istio-injection label to existing namespace
   kubectl label ns test-namespace istio-injection=enabled
   
   # Should be rejected with validation error
   ```

5. Test with deployment:
   ```bash
   # Create test namespace
   kubectl create ns test-ns
   
   # Try to apply deployment with istio-injection label
   kubectl apply -f non-compliant-deployment.yaml
   
   # Should be rejected with validation error
   ```

### Expected Results

1. Resources without istio-injection label should:
   - Be created successfully
   - Allow normal operations

2. Resources with istio-injection=enabled should:
   - Be rejected at creation
   - Be rejected when trying to add the label
   - Generate validation failures with clear message

3. The policy should:
   - Affect all Namespaces, Pods, and Deployments
   - Only trigger on CREATE and UPDATE operations
   - Provide clear error messages about why the operation was rejected

### Cleanup

```bash
# Remove test resources
kubectl delete ns test-namespace
kubectl delete ns test-namespace-2
kubectl delete ns test-ns
```

## Troubleshooting

1. Check Kyverno logs:
   ```bash
   kubectl logs -n kyverno -l app=kyverno
   ```

2. Verify policy status:
   ```bash
   kubectl get clusterpolicy validate-ns-istio-injection -o yaml
   ```

3. Check admission reviews:
   ```bash
   kubectl get admissionreport -A
   ```

## Notes

- The policy runs in enforce mode (`validationFailureAction: enforce`)
- Affects all Namespaces, Pods, and Deployments regardless of their labels
- Prevents use of legacy injection method across the cluster
- Only triggers on CREATE and UPDATE operations due to preconditions
- Helps maintain consistent sidecar injection approach 
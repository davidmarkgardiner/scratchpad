# Resource Quotas Policy Testing

This document demonstrates how to test the Kyverno resource quotas policy that enforces resource limits on Pods.

## Policy Details

The policy (`generate-ns-resourcequota.yaml`) enforces that all Pods in namespaces matching the pattern `at[0-9]{5}-.*` must have both resource requests and limits defined.

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: generate-ns-resourcequota
spec:
  validationFailureAction: Audit
  rules:
    - name: require-resource-limits
      match:
        resources:
          kinds:
            - Pod
          namespaces:
            - "at[0-9]{5}-.*"
```

## Test Cases

### 1. Violating Pod Example
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-no-limits
  namespace: at12345-dev
spec:
  containers:
  - name: nginx
    image: nginx:1.14.2
    # Violation: No resource limits specified
```

### 2. Compliant Pod Example
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-with-limits
  namespace: at12345-dev
spec:
  containers:
  - name: nginx
    image: nginx:1.14.2
    resources:
      limits:
        memory: "256Mi"
        cpu: "500m"
      requests:
        memory: "128Mi"
        cpu: "250m"
```

## Verification Steps

1. Apply the policy:
   ```bash
   kubectl apply -f generate-ns-resourcequota.yaml
   ```

2. Create test pods:
   ```bash
   kubectl apply -f violating-pod.yaml
   kubectl apply -f compliant-pod.yaml
   ```

3. Check policy reports:
   ```bash
   kubectl get policyreport -n at12345-dev
   ```

## Expected Results

- The violating pod will show a policy failure in the report:
  ```
  validation error: Resource limits are required
  ```

- The compliant pod will show a pass result:
  ```
  validation rule 'require-resource-limits' passed
  ```

## Notes

- The policy is currently in `Audit` mode (`validationFailureAction: Audit`)
- It will report violations but not block pod creation
- To enforce blocking, change `validationFailureAction` to `Enforce`
- The policy applies to any namespace matching pattern `at[0-9]{5}-.*` (e.g., at12345-dev, at54321-prod)

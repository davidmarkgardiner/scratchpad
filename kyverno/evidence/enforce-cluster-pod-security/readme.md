# Pod Security Policy Testing

This document demonstrates how to test the Kyverno pod security policy that prevents privileged container execution.

## Policy Details

The policy (`enforce-cluster-pod-security.yaml`) enforces that all Pods in namespaces matching the pattern `at[0-9]{5}-.*` must not run with privileged security context.

## Test Cases

### 1. Violating Pod Example
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-privileged
  namespace: at12345-dev
spec:
  containers:
  - name: nginx
    image: nginx:1.14.2
    securityContext:
      privileged: true
    # Violation: Attempts to run with privileged security context
```

### 2. Compliant Pod Example
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-secure
  namespace: at12345-dev
spec:
  containers:
  - name: nginx
    image: nginx:1.14.2
    securityContext:
      privileged: false
```

## Verification Steps

1. Apply the policy:
   ```bash
   kubectl apply -f enforce-cluster-pod-security.yaml
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
  validation error: Privileged containers are not allowed
  ```

- The compliant pod will show a pass result:
  ```
  validation rule 'restrict-privileged' passed
  ```

## Notes

- The policy is currently in `Audit` mode (`validationFailureAction: Audit`)
- It will report violations but not block resource creation
- To enforce blocking, change `validationFailureAction` to `Enforce`
- The policy applies to any namespace matching pattern `at[0-9]{5}-.*` (e.g., at12345-dev, at54321-prod) 
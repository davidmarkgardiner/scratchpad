# Required Labels Policy Testing

This document demonstrates how to test the Kyverno required labels policy that enforces mandatory labels on resources.

## Policy Details

The policy (`validate-cluster-pod-labels.yaml`) enforces that all Pods, Deployments, and Services in namespaces matching the pattern `at[0-9]{5}-.*` must have the required label: `app.kubernetes.io/name`.

## Test Cases

### 1. Violating Pod Example
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-no-labels
  namespace: at12345-dev
spec:
  containers:
  - name: nginx
    image: nginx:1.14.2
    # Violation: No required labels specified
```

### 2. Compliant Pod Example
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-with-labels
  namespace: at12345-dev
  labels:
    app.kubernetes.io/name: nginx
spec:
  containers:
  - name: nginx
    image: nginx:1.14.2
```

## Verification Steps

1. Apply the policy:
   ```bash
   kubectl apply -f validate-cluster-pod-labels.yaml
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
  validation error: The following labels are required: 'app.kubernetes.io/name'
  ```

- The compliant pod will show a pass result:
  ```
  validation rule 'validate-cluster-pod-labels' passed
  ```

```
k get polr -o yaml | grep labels
    labels:
      name: nginx-with-labels
  - message: validation rule 'validate-cluster-pod-labels' passed.
    policy: validate-cluster-pod-labels
    rule: validate-cluster-pod-labels
    name: nginx-with-labels
    labels:
      name: nginx-no-labels
  - message: 'validation error: The following labels are required: ''app.kubernetes.io/name''.
      rule validate-cluster-pod-labels failed at path /metadata/labels/'
    policy: validate-cluster-pod-labels
    rule: validate-cluster-pod-labels
    name: nginx-no-labels
(base) 

```
## Notes

- The policy is currently in `Audit` mode (`validationFailureAction: Audit`)
- It will report violations but not block resource creation
- To enforce blocking, change `validationFailureAction` to `Enforce`
- The policy applies to any namespace matching pattern `at[0-9]{5}-.*` (e.g., at12345-dev, at54321-prod) 
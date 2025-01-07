# Pod Security Standards for Production

This policy enforces a comprehensive set of Pod Security Standards suitable for production environments, ensuring pods run with minimal privileges and maximum security in namespaces labeled with `pod-security.kubernetes.io/warn`.

## Policy Details

- **File**: `enforce-cluster-pod-security-prod.yaml`
- **Type**: ClusterPolicy
- **Action**: Validate
- **Target**: Pods in namespaces with label `pod-security.kubernetes.io/warn`
- **Security Controls**:
  - Disables privileged containers
  - Enforces read-only root filesystem
  - Prevents privilege escalation
  - Requires non-root user execution
  - Enforces RuntimeDefault seccomp profile
  - Disables service account token automounting

## Test Cases

### 1. Compliant Namespace
```yaml
# compliant-namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: test-namespace
  labels:
    pod-security.kubernetes.io/warn: restricted
    app.kubernetes.io/name: test-ns
```

### 2. Compliant Pod
```yaml
# compliant-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: secure-pod
  namespace: test-namespace
  labels:
    app.kubernetes.io/name: secure-nginx
spec:
  automountServiceAccountToken: false
  containers:
  - name: nginx
    image: nginx:1.14.2
    securityContext:
      privileged: false
      readOnlyRootFilesystem: true
      allowPrivilegeEscalation: false
      runAsNonRoot: true
      runAsUser: 101
      seccompProfile:
        type: RuntimeDefault
```

### 3. Non-Compliant Pod
```yaml
# non-compliant-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: insecure-pod
  namespace: test-namespace
  labels:
    app.kubernetes.io/name: insecure-nginx
spec:
  containers:
  - name: nginx
    image: nginx:1.14.2
    securityContext:
      privileged: true
      readOnlyRootFilesystem: false
      allowPrivilegeEscalation: true
```

## Testing Procedure

### Prerequisites
- Access to a Kubernetes cluster
- kubectl CLI tool
- Kyverno installed in the cluster

### Test Steps

1. Apply the policy:
   ```bash
   kubectl apply -f enforce-cluster-pod-security-prod.yaml
   ```

2. Create test namespace:
   ```bash
   # Create namespace with required label
   kubectl apply -f compliant-namespace.yaml
   
   # Verify namespace labels
   kubectl get ns test-namespace --show-labels
   ```

3. Test with compliant pod:
   ```bash
   # Apply compliant pod
   kubectl apply -f compliant-pod.yaml
   
   # Verify pod creation
   kubectl get pod -n test-namespace secure-pod
   ```

4. Test with non-compliant pod:
   ```bash
   # Try to apply non-compliant pod (should be blocked)
   kubectl apply -f non-compliant-pod.yaml
   ```

5. Test in namespace without label:
   ```bash
   # Create namespace without label
   kubectl create ns test-unlabeled
   
   # Try to create non-compliant pod (should succeed as policy doesn't apply)
   kubectl apply -f non-compliant-pod.yaml -n test-unlabeled
   ```

### Expected Results

1. Compliant pods in labeled namespaces should:
   - Be created successfully
   - Run with all security controls enabled
   - Show no policy violations

2. Non-compliant pods in labeled namespaces should:
   - Be blocked at creation
   - Show clear error messages about security requirements
   - Not appear in pod listing

3. The policy should enforce:
   - No privileged containers
   - Read-only root filesystem
   - No privilege escalation
   - Non-root user execution
   - RuntimeDefault seccomp profile
   - No automounted service account tokens

4. Policy should only apply to namespaces with the label:
   - Pods in unlabeled namespaces should not be affected
   - Adding the label to a namespace should enforce policy on new pods

### Cleanup

```bash
# Remove test resources
kubectl delete ns test-namespace
kubectl delete ns test-unlabeled
```

## Troubleshooting

1. Check Kyverno logs:
   ```bash
   kubectl logs -n kyverno -l app=kyverno
   ```

2. Verify policy status:
   ```bash
   kubectl get clusterpolicy enforce-cluster-pod-security-prod -o yaml
   ```

3. Check namespace labels:
   ```bash
   kubectl get ns --show-labels | grep pod-security.kubernetes.io/warn
   ```

## Notes

- Policy runs in enforce mode (`validationFailureAction: Enforce`)
- Only applies to namespaces with `pod-security.kubernetes.io/warn` label
- Enforces production-grade security settings
- Follows Pod Security Standards (Restricted) profile
- Uses optional pattern matching (`=(field)`) to allow gradual adoption

## Best Practices

1. Security Context:
   - Always specify complete security context
   - Use minimal required privileges
   - Test applications with read-only filesystem
   - Run containers as non-root user (e.g., nginx as user 101)

2. Namespace Management:
   - Document which namespaces should have the security label
   - Regularly audit namespace labels
   - Consider automating label application based on environment

3. Container Images:
   - Use distroless or minimal base images
   - Keep images up to date
   - Verify images work with security restrictions

4. Testing:
   - Validate applications work with all restrictions
   - Test in non-production first
   - Monitor for policy violations 
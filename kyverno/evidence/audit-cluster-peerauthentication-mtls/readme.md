# Audit Istio Strict mTLS Policy

This policy ensures that all PeerAuthentication resources in the cluster have strict mTLS enabled for enhanced security.

## Policy Details

- **File**: `istio-mtls.yaml`
- **Type**: ClusterPolicy
- **Action**: Validate
- **Target**: All PeerAuthentication resources
- **Required Setting**: `spec.mtls.mode: STRICT`

## Test Cases

### 1. Compliant PeerAuthentication
```yaml
# compliant-peerauthentication.yaml
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: at12345-dev
spec:
  mtls:
    mode: STRICT
```

### 2. Non-Compliant PeerAuthentication
```yaml
# non-compliant-peerauthentication.yaml
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: at54321-prod
spec:
  mtls:
    mode: PERMISSIVE
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
   kubectl apply -f istio-mtls.yaml
   ```

2. Test with compliant configuration:
   ```bash
   # Create namespace
   kubectl create ns at12345-dev
   
   # Apply compliant PeerAuthentication
   kubectl apply -f compliant-peerauthentication.yaml
   
   # Verify no policy violations
   kubectl get policyreport -n at12345-dev
   ```

3. Test with non-compliant configuration:
   ```bash
   # Create namespace
   kubectl create ns at54321-prod
   
   # Apply non-compliant PeerAuthentication
   kubectl apply -f non-compliant-peerauthentication.yaml
   
   # Check for policy violations
   kubectl get policyreport -n at54321-prod
   ```

4. Test in different namespace:
   ```bash
   # Create namespace
   kubectl create ns test-namespace
   
   # Apply PeerAuthentication with PERMISSIVE mode
   cat <<EOF | kubectl apply -f -
   apiVersion: security.istio.io/v1beta1
   kind: PeerAuthentication
   metadata:
     name: default
     namespace: test-namespace
   spec:
     mtls:
       mode: PERMISSIVE
   EOF
   
   # Verify policy violations (should show violation)
   kubectl get policyreport -n test-namespace
   ```

### Expected Results

1. Compliant PeerAuthentication should:
   - Be successfully created
   - Generate no policy violations
   - Show PASS in policy reports

2. Non-compliant PeerAuthentication should:
   - Be created (since policy is in audit mode)
   - Generate policy violations
   - Show FAIL in policy reports with message about requiring STRICT mode

3. PeerAuthentications in any namespace should:
   - Be subject to the same validation
   - Generate violations if not using STRICT mode
   - Appear in policy reports if non-compliant

### Cleanup

```bash
# Remove test resources
kubectl delete ns at12345-dev
kubectl delete ns at54321-prod
kubectl delete ns test-namespace
```

## Troubleshooting

1. Check Kyverno logs:
   ```bash
   kubectl logs -n kyverno -l app=kyverno
   ```

2. Verify policy status:
   ```bash
   kubectl get clusterpolicy audit-strict-mtls -o yaml
   ```

3. Check policy reports:
   ```bash
   kubectl get policyreport -A
   ```

## Notes

- The policy runs in audit mode (`validationFailureAction: audit`)
- Affects all PeerAuthentication resources across all namespaces
- Ensures consistent mTLS configuration across the entire cluster
- Does not automatically fix non-compliant resources (validation only)
- Helps maintain security best practices by enforcing strict mTLS 
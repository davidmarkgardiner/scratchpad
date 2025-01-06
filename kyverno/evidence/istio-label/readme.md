# Require Istio Revision Label Policy

This policy finds namespaces with the `istio.io/rev` label and ensures they are using the correct version (`asm-1-23`).

## Policy Details

- **File**: `istio-rev-label.yaml`
- **Type**: ClusterPolicy
- **Actions**: 
  - Mutate: Updates the label value to `asm-1-23`
- **Target**: Any namespace with `istio.io/rev` label
- **Required Label**: `istio.io/rev=asm-1-23`

## Test Cases

### 1. Compliant Namespace
```yaml
# compliant-namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: at12345-dev
  labels:
    istio.io/rev: asm-1-23
```

### 2. Non-Compliant Namespace (Old Version)
```yaml
# non-compliant-namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: at54321-prod
  labels:
    istio.io/rev: asm-1-22  # Old version will be updated
```

## Testing Procedure

### Prerequisites
- Access to a Kubernetes cluster
- kubectl CLI tool
- Kyverno installed in the cluster

### Test Steps

1. Apply the policy:
   ```bash
   kubectl apply -f istio-rev-label.yaml
   ```

2. Test with old version label:
   ```bash
   # Create namespace with old version
   kubectl apply -f non-compliant-namespace.yaml
   
   # Verify label was automatically updated
   kubectl get ns at54321-prod --show-labels
   ```

3. Test with correct version:
   ```bash
   # Create namespace with correct version
   kubectl apply -f compliant-namespace.yaml
   
   # Verify label remains unchanged
   kubectl get ns at12345-dev --show-labels
   ```

4. Test label persistence:
   ```bash
   # Try to change the label to an old version
   kubectl label ns at54321-prod istio.io/rev=asm-1-22 --overwrite
   
   # Verify label was restored to correct version
   kubectl get ns at54321-prod --show-labels
   ```

### Expected Results

1. Namespaces with old version labels should:
   - Have their `istio.io/rev` label automatically updated to `asm-1-23`
   - Have the label restored if changed

2. Namespaces with correct version should:
   - Maintain their existing label
   - Generate no policy violations

### Cleanup

```bash
# Remove test resources
kubectl delete ns at12345-dev
kubectl delete ns at54321-prod
```

## Troubleshooting

1. Check Kyverno logs:
   ```bash
   kubectl logs -n kyverno -l app=kyverno
   ```

2. Verify policy status:
   ```bash
   kubectl get clusterpolicy require-istio-revision-label -o yaml
   ```

3. Check policy reports:
   ```bash
   kubectl get policyreport -A
   ```

## Notes

- The policy runs in audit mode (`validationFailureAction: audit`)
- The policy will update any namespace that has the `istio.io/rev` label, regardless of its name pattern
- The policy ensures consistent Istio sidecar injection version across all labeled namespaces

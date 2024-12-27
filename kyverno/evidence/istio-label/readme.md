# Require Istio Revision Label Policy

This policy ensures that namespaces starting with 'at' have the required Istio revision label for proper sidecar injection.

### Policy Details

- **File**: `require-istio-revision-label.yaml`
- **Type**: ClusterPolicy
- **Action**: Mutate and Validate
- **Target**: Namespaces starting with 'at'
- **Required Label**: `istio.io/rev=asm-1-23`

### Testing Procedure

#### Prerequisites
- Access to the Kubernetes cluster
- kubectl CLI tool
- Kyverno installed in the cluster

#### 1. Pre-Implementation Testing

```bash
# Create test namespaces
kubectl create ns at-test-1
kubectl create ns test-normal  # Control namespace

# Verify initial state
kubectl get ns at-test-1 --show-labels
kubectl get ns test-normal --show-labels
```

#### 2. Apply the Policy

```bash
# Apply the Kyverno policy
kubectl apply -f require-istio-revision-label.yaml

# Wait for Kyverno to process
sleep 5
```

#### 3. Post-Implementation Testing

```bash
# Check if label was added to matching namespace
kubectl get ns at-test-1 --show-labels

# Verify non-matching namespace wasn't modified
kubectl get ns test-normal --show-labels

# Create a new matching namespace to test real-time enforcement
kubectl create ns at-test-2

# Verify label was added automatically
kubectl get ns at-test-2 --show-labels

# Test label persistence by attempting removal
kubectl label ns at-test-1 istio.io/rev-
```

#### Expected Results

1. Before policy:
   - `at-test-1` should have no Istio revision label
   - `test-normal` should have no Istio revision label

2. After policy:
   - `at-test-1` should have `istio.io/rev=asm-1-23`
   - `test-normal` should remain unchanged
   - `at-test-2` should automatically get `istio.io/rev=asm-1-23`
   - The label should be automatically restored if removed

#### Cleanup

```bash
# Remove test resources
kubectl delete ns at-test-1
kubectl delete ns at-test-2
kubectl delete ns test-normal
kubectl delete -f require-istio-revision-label.yaml
```

### Troubleshooting

If the policy doesn't work as expected:

1. Check Kyverno logs:
```bash
kubectl logs -n kyverno -l app=kyverno
```

2. Verify policy status:
```bash
kubectl get clusterpolicy require-istio-revision-label -o yaml
```

3. Check if the namespace matches the policy rules:
```bash
kubectl describe ns <namespace-name>
```

### Additional Notes

- The policy runs in audit mode (`validationFailureAction: audit`)
- Existing namespaces will be mutated when the policy is updated (`mutateExistingOnPolicyUpdate: true`)
- Background scanning is enabled (`background: true`)

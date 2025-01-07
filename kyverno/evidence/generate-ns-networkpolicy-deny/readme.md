# Add Network Policy

This policy automatically generates a default deny NetworkPolicy for namespaces that have the `namespace` label. By default, Kubernetes allows communications across all Pods within a cluster. This policy helps enforce network segmentation by denying all ingress and egress traffic by default.

## Policy Details

- **File**: `network-policies.yaml`
- **Type**: ClusterPolicy
- **Name**: `add-networkpolicy`
- **Action**: Generate with synchronization
- **Target**: Namespaces with `namespace` label
- **Generated Resource**: NetworkPolicy named `default-deny` that blocks all traffic

## Test Cases

### 1. Compliant Namespace (Policy will apply)
```yaml
# compliant-namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: test-namespace
  labels:
    namespace: "true"  # Required label
    environment: dev
```

### 2. Non-Compliant Namespace (Policy won't apply)
```yaml
# non-compliant-namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: test-namespace-2
  labels:
    environment: dev
    # Missing namespace label
```

### 3. Generated NetworkPolicy
```yaml
# Expected generated NetworkPolicy
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny
  namespace: test-namespace
spec:
  # select all pods in the namespace
  podSelector: {}
  # deny all traffic
  policyTypes:
  - Ingress
  - Egress
```

## Testing Procedure

### Prerequisites
- Access to a Kubernetes cluster
- kubectl CLI tool
- Kyverno installed in the cluster
- Network policy controller (e.g., Calico, Cilium) installed

### Test Steps

1. Apply the policy:
   ```bash
   kubectl apply -f network-policies.yaml
   ```

2. Test with compliant namespace:
   ```bash
   # Create namespace with required label
   kubectl apply -f compliant-namespace.yaml
   
   # Verify NetworkPolicy was generated
   kubectl get networkpolicy -n test-namespace default-deny -o yaml
   ```

3. Test with non-compliant namespace:
   ```bash
   # Create namespace without required label
   kubectl apply -f non-compliant-namespace.yaml
   
   # Verify no NetworkPolicy was generated
   kubectl get networkpolicy -n test-namespace-2
   ```

4. Test label addition:
   ```bash
   # Add namespace label to existing namespace
   kubectl label ns test-namespace-2 namespace=true
   
   # Verify NetworkPolicy is generated
   kubectl get networkpolicy -n test-namespace-2
   ```

5. Test network isolation:
   ```bash
   # Create test pods in compliant namespace
   kubectl -n test-namespace create deployment nginx --image=nginx
   kubectl -n test-namespace expose deployment nginx --port=80
   
   # Create test pod in non-compliant namespace
   kubectl -n test-namespace-2 run tmp-shell --rm -i --tty --image nicolaka/netshoot -- /bin/bash
   
   # Try to access nginx (should fail in compliant namespace, succeed in non-compliant)
   curl http://nginx.test-namespace.svc.cluster.local
   ```

### Expected Results

1. Namespaces with `namespace` label should:
   - Have a NetworkPolicy named `default-deny` automatically generated
   - Block all ingress and egress traffic by default
   - Maintain the NetworkPolicy due to synchronization

2. Namespaces without `namespace` label should:
   - Not have any NetworkPolicy generated
   - Allow traffic as normal

3. The generated NetworkPolicy should:
   - Apply to all pods (`podSelector: {}`)
   - Block both ingress and egress traffic
   - Be created in the same namespace as the trigger namespace
   - Be maintained in sync with the policy definition

### Cleanup

```bash
# Remove test resources
kubectl delete ns test-namespace
kubectl delete ns test-namespace-2
```

## Troubleshooting

1. Check Kyverno logs:
   ```bash
   kubectl logs -n kyverno -l app=kyverno
   ```

2. Verify policy status:
   ```bash
   kubectl get clusterpolicy add-networkpolicy -o yaml
   ```

3. Check generated resources:
   ```bash
   kubectl get networkpolicy --all-namespaces
   ```

4. Verify namespace labels:
   ```bash
   kubectl get ns --show-labels | grep namespace
   ```

## Notes

- Policy uses `synchronize: true` to ensure NetworkPolicies stay in sync
- Only generates NetworkPolicy for namespaces with `namespace` label
- Creates a secure-by-default network posture for labeled namespaces
- Additional NetworkPolicies can be created to allow specific traffic
- Policy generation happens automatically after namespace creation or labeling
- The generated policy blocks all traffic by default, requiring explicit policies for communication

## Best Practices

1. Label Management:
   - Document which namespaces should have the `namespace` label
   - Regularly audit namespace labels
   - Consider automating label application based on namespace patterns

2. Network Policy Management:
   - Document all custom NetworkPolicies
   - Use labels for better policy targeting
   - Regularly review and audit network policies

3. Testing:
   - Regularly verify network isolation in labeled namespaces
   - Test both ingress and egress restrictions
   - Validate policy changes in non-production first 
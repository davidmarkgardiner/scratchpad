# Kyverno Spot Instance Configuration and Testing Guide

This guide describes how to implement and test Kyverno policies for enforcing Azure spot instance configurations in Kubernetes deployments using Helm and kro.

## Prerequisites

- Kubernetes cluster with Azure spot instances
- Helm v3+
- Kyverno installed in the cluster
- kro CLI installed
- kubectl configured with cluster access

## Components Overview

### 1. Kyverno Policies

We use two Kyverno policies:
- `audit-cluster-pod-spotconfig`: Audits pods for correct spot instance configuration
- `mutate-cluster-pod-spotconfig`: Automatically adds required spot instance configuration

### 2. WhiskApp Resource

The WhiskApp custom resource defines the application deployment configuration using kro.

### 3. Helm Test

A Helm test that verifies:
- Spot instance tolerations
- Node affinity configuration
- Kyverno policy compliance

## Implementation Steps

1. Create Kyverno Policies:

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: audit-cluster-pod-spotconfig
  # ... [audit policy configuration]

---
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: mutate-cluster-pod-spotconfig
  # ... [mutation policy configuration]
```

2. Define WhiskApp Resource:

```yaml
apiVersion: v1alpha1
kind: WhiskAppNew
metadata:
  name: test-whiskapp
  namespace: test-ns
spec:
  name: test-whiskapp
  namespace: test-ns
  image: nginx:latest
  # ... [remaining configuration]
```

3. Create Helm Test:
Place the following in `templates/tests/spot-config-test.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: "{{ .Release.Name }}-spot-config-test"
  annotations:
    "helm.sh/hook": test
# ... [test pod configuration]
```

## Testing Process

1. Deploy Kyverno Policies:
```bash
kubectl apply -f kyverno-spot-policies.yaml
```

2. Deploy Application:
```bash
kro apply -f whiskapp.yaml
```

3. Run Helm Test:
```bash
helm test <release-name> -n <namespace>
```

## Test Validation Criteria

The Helm test verifies:

1. Deployment Readiness
   - Checks if deployment is available within 120s timeout

2. Spot Configuration
   - Validates presence of spot instance toleration
   - Verifies correct node affinity configuration

3. Kyverno Policy Compliance
   - Confirms audit policy reports no violations

## Troubleshooting

Common issues and solutions:

1. Test Pod Failure
   - Check pod logs: `kubectl logs <test-pod-name> -n <namespace>`
   - Verify RBAC permissions are correct

2. Kyverno Policy Issues
   - Check policy reports: `kubectl get policyreport -A`
   - Verify policy syntax and configuration

3. Deployment Issues
   - Check deployment status: `kubectl describe deployment <name> -n <namespace>`
   - Verify node pool has spot instances available

## Best Practices

1. Policy Management
   - Keep policies in version control
   - Document any customizations
   - Test policies in non-production environment first

2. Testing
   - Run tests after every deployment
   - Monitor policy reports regularly
   - Maintain test coverage for all critical configurations

3. Maintenance
   - Regularly update Kyverno version
   - Keep policies aligned with security requirements
   - Review and update spot instance configurations as needed

## References

- [Kyverno Documentation](https://kyverno.io/docs/)
- [Azure Spot Instances](https://docs.microsoft.com/azure/aks/spot-nodes)
- [Helm Testing](https://helm.sh/docs/topics/chart_tests/)

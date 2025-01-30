# Kyverno Policies

This Helm chart contains a collection of Kyverno policies for Kubernetes cluster governance.

## Prerequisites

- Kubernetes cluster with Kyverno installed
- Helm v3
- `kubectl` configured to access your cluster

## Installation

1. First-time installation:
```bash
helm install policies -n kyverno .
```

2. Upgrade existing installation:
```bash
helm upgrade policies -n kyverno .
```

3. Uninstall:
```bash
helm uninstall policies -n kyverno
```

## Testing

Run all tests:
```bash
helm test policies -n kyverno --logs
```

## Debugging

1. If tests fail, check the policy reports:
```bash
kubectl get policyreport -A
```

2. Check specific policy violations:
```bash
kubectl get policyreport -o json | jq '.items[].results[]'
```

3. View policy details:
```bash
kubectl get clusterpolicy
kubectl describe clusterpolicy <policy-name>
```

4. Common Issues:

   a. Tests failing due to timing:
   - Policy reports take time to generate
   - Increase the sleep time in test pods if needed
   - Default wait time is 20 seconds

   b. Permission issues:
   - Ensure Kyverno has necessary permissions
   - Check ServiceAccount permissions in test files
   - Verify ClusterRole and ClusterRoleBinding are created

   c. Policy not being applied:
   - Check policy syntax
   - Verify resource matches policy criteria
   - Check Kyverno logs:
     ```bash
     kubectl logs -n kyverno -l app.kubernetes.io/name=kyverno
     ```

5. Clean up and retry:
```bash
# Uninstall
helm uninstall policies -n kyverno

# Delete any lingering resources
kubectl delete clusterpolicy -l app.kubernetes.io/instance=policies
kubectl delete policyreport -l app.kubernetes.io/instance=policies

# Reinstall
helm install policies -n kyverno .
```

## Policies

1. `mutate-ns-deployment-spotaffinity`
   - Adds spot instance affinity to deployments
   - Applies to namespaces with `worker-type: spot` label

2. `mutate-cluster-namespace-istiolabel`
   - Ensures proper Istio sidecar injection labels
   - Mutates namespaces with specific criteria

3. `enforce-cluster-pod-security`
   - Enforces pod security standards
   - Prevents privileged containers

4. `audit-cluster-peerauthentication-mtls`
   - Audits Istio PeerAuthentication resources
   - Ensures STRICT mTLS mode is used

## Development

1. Create new policy:
```bash
touch templates/policies/your-new-policy.yaml
```

2. Create corresponding test:
```bash
touch templates/tests/test-your-new-policy.yaml
```

3. Add to setup script:
```bash
./setup.sh
```

# Kyverno Policies Testing Framework

This repository contains integration tests for validating Kyverno policies in a Kubernetes cluster. The tests ensure that our policies are working as expected for various deployment scenarios.

## Overview

The testing framework validates several key policy areas:

1. **Spot Instance Configuration**
   - Verifies correct node affinity for spot instances
   - Ensures appropriate pod anti-affinity for high availability
   - Validates spot instance tolerations

2. **Resource Limits**
   - Checks enforcement of resource limits on deployments
   - Validates policy reports for violations
   - Ensures proper resource specifications

3. **Istio Configuration** (when Istio is installed)
   - Validates Istio injection policies
   - Checks Istio revision label management
   - Verifies PeerAuthentication mTLS requirements

## Prerequisites

- A Kubernetes cluster with Kyverno installed
- `kubectl` configured with cluster access
- Go 1.19 or later
- Optional: Istio installed (for Istio-related tests)

## Running Tests

To run the tests:

```bash
go test -v ./tests/...
```

The tests will:
1. Create a test namespace
2. Apply test resources
3. Verify policy enforcement
4. Clean up all test resources

## Test Structure

The tests are organized in the following structure:

```
tests/
├── policies_test.go   # Main test file containing all policy tests
└── testdata/         # Test fixtures and sample resources
```

### Test Categories

1. `TestKyvernoPolicies`: Main test suite that runs all policy tests
   - `SpotAffinity`: Tests spot instance configuration requirements
   - `ResourceLimits`: Validates resource limit enforcement
   - `IstioInjection`: Checks Istio sidecar injection policies
   - `IstioRevisionLabel`: Verifies Istio revision label management
   - `PeerAuthentication`: Tests mTLS configuration requirements

### Helper Functions

The test suite includes several helper functions for common operations:

- `createTestDeployment`: Creates test deployments
- `verifySpotConfiguration`: Validates spot instance requirements
- `checkIstioInstalled`: Verifies Istio installation status

## Debugging

The tests include detailed logging to help diagnose issues:
- Creation and mutation of resources
- Policy evaluation results
- Verification steps and failures

## Contributing

When adding new tests:
1. Add the test function to `policies_test.go`
2. Add the test to the main `TestKyvernoPolicies` function
3. Include appropriate cleanup in the test
4. Add comprehensive comments explaining the test's purpose

## License

[Add your license information here] 
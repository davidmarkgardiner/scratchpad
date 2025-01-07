## Require Node Selectors Policy

This policy ensures that workloads in 'at-' namespaces have appropriate node selectors for either spot or worker nodes.

### Policy Details

- **File**: `require-node-selectors.yaml`
- **Type**: ClusterPolicy
- **Action**: Validate
- **Target**: Pods, Deployments, StatefulSets, and DaemonSets in 'at-' namespaces
- **Required Selector**: `kubernetes.io/role: spot|worker`
- **Excludes**: kube-system and kyverno namespaces

### Testing Procedure

#### Prerequisites
- Access to the Kubernetes cluster
- kubectl CLI tool
- Kyverno installed in the cluster

#### 1. Pre-Implementation Testing

```bash
# Create test namespace
kubectl create ns at-test-node

# Create a test deployment without node selector (should fail)
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-deploy-no-selector
  namespace: at-test-node
spec:
  replicas: 1
  selector:
    matchLabels:
      app: test
  template:
    metadata:
      labels:
        app: test
    spec:
      containers:
      - name: nginx
        image: nginx:1.19
EOF

# Create a test deployment with spot node selector (should pass)
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-deploy-spot
  namespace: at-test-node
spec:
  replicas: 1
  selector:
    matchLabels:
      app: test-spot
  template:
    metadata:
      labels:
        app: test-spot
    spec:
      nodeSelector:
        kubernetes.io/role: spot
      containers:
      - name: nginx
        image: nginx:1.19
EOF
```

#### 2. Apply the Policy

```bash
# Apply the Kyverno policy
kubectl apply -f require-node-selectors.yaml

# Wait for Kyverno to process
sleep 5
```

#### 3. Post-Implementation Testing

```bash
# Check policy reports
kubectl get policyreport -n at-test-node

# Try to create a deployment without node selector (should be audited)
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-deploy-no-selector-2
  namespace: at-test-node
spec:
  replicas: 1
  selector:
    matchLabels:
      app: test-2
  template:
    metadata:
      labels:
        app: test-2
    spec:
      containers:
      - name: nginx
        image: nginx:1.19
EOF

# Create a deployment with worker node selector (should pass)
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-deploy-worker
  namespace: at-test-node
spec:
  replicas: 1
  selector:
    matchLabels:
      app: test-worker
  template:
    metadata:
      labels:
        app: test-worker
    spec:
      nodeSelector:
        kubernetes.io/role: worker
      containers:
      - name: nginx
        image: nginx:1.19
EOF
```

#### Expected Results

1. Before policy:
   - Deployments without node selectors should be created
   - Deployments with node selectors should be created

2. After policy:
   - Deployments without node selectors should be audited
   - Deployments with `kubernetes.io/role: spot` should pass
   - Deployments with `kubernetes.io/role: worker` should pass
   - Policy reports should show violations for resources without proper selectors

#### Cleanup

```bash
# Remove test resources
kubectl delete ns at-test-node
kubectl delete -f require-node-selectors.yaml
```

### Troubleshooting

If the policy doesn't work as expected:

1. Check policy reports:
```bash
kubectl get policyreport -n at-test-node -o yaml
```

2. Verify policy status:
```bash
kubectl get clusterpolicy require-node-selectors -o yaml
```

3. Check specific resource validation:
```bash
kubectl describe deploy <deployment-name> -n at-test-node
```

### Additional Notes

- The policy runs in audit mode (`validationFailureAction: audit`)
- Policy applies to Pods, Deployments, StatefulSets, and DaemonSets
- Valid node selector values are "spot" or "worker"
- Excludes kube-system and kyverno namespaces

# Node Selector Policy Test Suite

This test suite validates the Kyverno policy that enforces node selector requirements for workloads in `at-` namespaces.

## Policy Overview

The policy (`require-node-selectors.yaml`) ensures that workloads deployed in namespaces starting with `at-` have appropriate node selectors specified. Valid node selectors are:
- `kubernetes.io/role: worker`
- `kubernetes.io/role: spot`

## Test Script

The `test-node-selectors.sh` script performs automated testing of the policy by:

1. Creating test deployments without node selectors (should be audited)
2. Creating test deployments with valid node selectors (should pass)
3. Verifying policy reports for violations
4. Cleaning up test resources

### Prerequisites

- kubectl with cluster admin access
- jq (for JSON parsing)
- A Kubernetes cluster with Kyverno installed

### Usage

```bash
./test-node-selectors.sh
```

### Test Cases

The script tests the following scenarios:

1. Pre-policy deployment tests:
   - Deployment without node selector
   - Deployment with spot node selector

2. Post-policy deployment tests:
   - Deployment without node selector (should be audited)
   - Deployment with worker node selector

### Test Output

The script provides detailed output including:
- Policy violation details
- Deployment status
- Policy report summaries
- Debug information when violations aren't detected

### Cleanup

The script automatically:
- Removes the test namespace
- Deletes the Kyverno policy
- Cleans up any remaining resources

### Exit Codes

- 0: All tests passed
- Non-zero: Test failures occurred

## Troubleshooting

If the test fails to detect violations:
1. Verify Kyverno is running properly
2. Check if the policy is installed correctly
3. Ensure the test namespace name starts with `at-`
4. Review the policy reports manually using:
   ```bash
   kubectl get policyreport -n at-test-node
   ```

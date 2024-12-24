# Kyverno Policies

This directory contains Kubernetes policies Auditd by Kyverno.

## Available Policies

### 1. Required Application Labels (`require-app-labels.yaml`)
- **Category:** Best Practices
- **Severity:** Medium
- **Description:** Ensures all Pods have the required Kubernetes recommended labels
- **Audits:** Requires `app.kubernetes.io/name` label on all Pods
- **Mode:** Audit

### 2. Disallow Latest Tag (`disallow-latest-tag.yaml`)
- **Category:** Best Practices
- **Severity:** Medium
- **Description:** Prevents use of the 'latest' tag in container images
- **Audits:** Requires specific version tags for all container images
- **Mode:** Audit

### 3. Unique Service Selectors (`unique-service-selectors.yaml`)
- **Category:** Best Practices
- **Severity:** Medium
- **Description:** Ensures services have unique selectors to prevent routing conflicts
- **Audits:** Required labels for service selectors including purpose label
- **Mode:** Audit

### 4. Audit Istio mTLS (`Audit-istio-mtls.yaml`)
- **Category:** Security
- **Severity:** Medium
- **Description:** Audits strict mTLS across the service mesh
- **Audits:** Only allows STRICT or UNSET modes for PeerAuthentication
- **Mode:** Audit

### 5. Required Istio Revision Label (`require-istio-revision-label.yaml`)
- **Category:** Istio
- **Severity:** Medium
- **Description:** Ensures all namespaces have the required Istio revision label
- **Audits:** Requires `istio.io/rev=asm-1-23` label on all namespaces
- **Mode:** Audit

### 6. Required Node Selectors (`require-node-selectors.yaml`)
- **Category:** Best Practices
- **Severity:** Medium
- **Description:** Ensures proper node selection for workload placement
- **Audits:** Requires either `spot` or `worker` node selector for all workloads
- **Mode:** Audit
- **Applies to:** 
  - Namespaces: Only those starting with "at-"
  - Resources: Pods, Deployments, StatefulSets, and DaemonSets
- **Excludes:** kube-system and kyverno namespaces

## Usage

### Apply All Policies
```bash
kubectl apply -f apps/kyverno/policies/
```

### Apply Individual Policy
```bash
kubectl apply -f apps/kyverno/policies/<policy-file>.yaml
```

### Check Policy Status
```bash
kubectl get clusterpolicy
```

### View Policy Reports
```bash
# All namespaces
kubectl get policyreport -A
kubectl get policyreport -n kyverno -o yaml
kubectl get clusterpolicyreport -o yaml
# Specific namespace
kubectl get policyreport -n <namespace>
```

```
# get a formatted report for a specific policy:
kubectl get clusterpolicy -o custom-columns="NAME:.metadata.name,BACKGROUND:.spec.background,ACTION:.spec.validationFailureAction,READY:.status.ready"

# more detailed information about specific policy violations:
kubectl get policyreport -A -o custom-columns="NAMESPACE:.metadata.namespace,PASS:.summary.pass,FAIL:.summary.fail,WARN:.summary.warn,ERROR:.summary.error,SKIP:.summary.skip"

# more detailed information about specific policy violations:
kubectl get polr -A -o jsonpath="{range .items[*]}{'\n'}Namespace: {.metadata.namespace}{'\n'}Results: {range .results[*]}{'\n'}  - Policy: {.policy}{'\n'}    Rule: {.rule}{'\n'}    Message: {.message}{'\n'}{end}{end}" | grep -v "^$"
```

## Policy Modes
All policies are currently in `Audit` mode. To Audit them:
1. Change `validationFailureAction` from `Audit` to `Audit`
2. Reapply the policy

## Testing
Test files for various policies are available in:
- `apps/kyverno/test-mtls-policy-valid.yaml`
- `apps/kyverno/test-mtls-policy-invalid.yaml`
- `apps/kyverno/test-mtls-policy-other-ns.yaml` 

# Kyverno Policies for UK8S

## Require Istio Revision Label Policy

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

# Kyverno Policies

This directory contains Kubernetes policies enforced by Kyverno.

## Available Policies

### 1. Required Application Labels (`require-app-labels.yaml`)
- **Category:** Best Practices
- **Severity:** Medium
- **Description:** Ensures all Pods have the required Kubernetes recommended labels
- **Enforces:** Requires `app.kubernetes.io/name` label on all Pods
- **Mode:** Audit

### 2. Disallow Latest Tag (`disallow-latest-tag.yaml`)
- **Category:** Best Practices
- **Severity:** Medium
- **Description:** Prevents use of the 'latest' tag in container images
- **Enforces:** Requires specific version tags for all container images
- **Mode:** Audit

### 3. Unique Service Selectors (`unique-service-selectors.yaml`)
- **Category:** Best Practices
- **Severity:** Medium
- **Description:** Ensures services have unique selectors to prevent routing conflicts
- **Enforces:** Required labels for service selectors including purpose label
- **Mode:** Audit

### 4. Enforce Istio mTLS (`enforce-istio-mtls.yaml`)
- **Category:** Security
- **Severity:** Medium
- **Description:** Enforces strict mTLS across the service mesh
- **Enforces:** Only allows STRICT or UNSET modes for PeerAuthentication
- **Mode:** Audit

### 5. Required Istio Revision Label (`require-istio-revision-label.yaml`)
- **Category:** Istio
- **Severity:** Medium
- **Description:** Ensures all namespaces have the required Istio revision label
- **Enforces:** Requires `istio.io/rev=asm-1-23` label on all namespaces
- **Mode:** Audit

### 6. Required Node Selectors (`require-node-selectors.yaml`)
- **Category:** Best Practices
- **Severity:** Medium
- **Description:** Ensures proper node selection for workload placement
- **Enforces:** Requires either `spot` or `worker` node selector for all workloads
- **Mode:** Audit
- **Applies to:** 
  - Namespaces: Only those starting with "at-"
  - Resources: Pods, Deployments, StatefulSets, and DaemonSets
- **Excludes:** kube-system and kyverno namespaces
- 
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
All policies are currently in `Audit` mode. To enforce them:
1. Change `validationFailureAction` from `Audit` to `Enforce`
2. Reapply the policy

## Testing
Test files for various policies are available in:
- `apps/kyverno/test-mtls-policy-valid.yaml`
- `apps/kyverno/test-mtls-policy-invalid.yaml`
- `apps/kyverno/test-mtls-policy-other-ns.yaml` 
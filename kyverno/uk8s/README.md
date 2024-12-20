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

## Policy Modes
All policies are currently in `Audit` mode. To enforce them:
1. Change `validationFailureAction` from `Audit` to `Enforce`
2. Reapply the policy

## Testing
Test files for various policies are available in:
- `apps/kyverno/test-mtls-policy-valid.yaml`
- `apps/kyverno/test-mtls-policy-invalid.yaml`
- `apps/kyverno/test-mtls-policy-other-ns.yaml` 
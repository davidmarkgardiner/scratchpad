# Kyverno Policies

This directory contains AKS deployment safeguard policies enforced by Kyverno.

## Available Policies

### 1. Resource Limits (`resource-limits.yaml`)
- **Category:** Resource Management
- **Severity:** Medium
- **Description:** Enforces CPU and memory resource limits on containers
- **Enforces:** Sets CPU to 500m and memory to 500Mi if not specified
- **Mode:** Enforce
- **Type:** Mutation

### 2. Anti-Affinity Rules (`anti-affinity.yaml`)
- **Category:** Pod Security
- **Severity:** Medium
- **Description:** Ensures workloads have anti-affinity rules for high availability
- **Enforces:** Pod anti-affinity configuration with `preferredDuringSchedulingIgnoredDuringExecution`
- **Mode:** Enforce
- **Type:** Validation

### 3. Allowed Image Registries (`allowed-images.yaml`)
- **Category:** Container Security
- **Severity:** High
- **Description:** Restricts container images to approved registries
- **Enforces:** Only allows images from mcr.microsoft.com, *.azurecr.io, docker.io/library
- **Mode:** Enforce
- **Type:** Validation

### 4. Health Probes (`require-probes.yaml`)
- **Category:** Pod Security
- **Severity:** Medium
- **Description:** Ensures containers have readiness and liveness probes
- **Enforces:** Both readiness and liveness probes with periodSeconds set
- **Mode:** Enforce
- **Type:** Validation

### 5. CSI Storage (`require-csi-storage.yaml`)
- **Category:** Storage
- **Severity:** Medium
- **Description:** Ensures StorageClasses use Container Storage Interface drivers
- **Enforces:** StorageClass provisioner must contain "csi"
- **Mode:** Enforce
- **Type:** Validation

### 6. Read-Only Root Filesystem (`readonly-root.yaml`)
- **Category:** Pod Security
- **Severity:** High
- **Description:** Sets container root filesystem to read-only
- **Enforces:** readOnlyRootFilesystem: true in container security context
- **Mode:** Enforce
- **Type:** Mutation

### 7. Latest Tag Prevention (`disallow-latest-tag.yaml`)
- **Category:** Container Security
- **Severity:** Medium
- **Description:** Prevents use of the 'latest' tag in container images
- **Enforces:** Explicit version tags required for all container images
- **Mode:** Enforce
- **Type:** Validation

### 8. PreStop Hook (`require-prestop-hook.yaml`)
- **Category:** Pod Lifecycle
- **Severity:** Medium
- **Description:** Ensures containers have preStop hooks for graceful termination
- **Enforces:** Lifecycle preStop hook configuration in containers
- **Mode:** Enforce
- **Type:** Validation

### 9. Pod Disruption Budget (`pod-disruption-budget.yaml`)
- **Category:** Availability
- **Severity:** Medium
- **Description:** Automatically creates PodDisruptionBudgets for workloads
- **Enforces:** PDB with maxUnavailable: 1 for Deployments and StatefulSets
- **Mode:** Enforce
- **Type:** Generation

### 10. Unique Service Selectors (`unique-service-selectors.yaml`)
- **Category:** Service Management
- **Severity:** Medium
- **Description:** Ensures services have unique selectors
- **Enforces:** Required 'purpose' label in service selectors
- **Mode:** Enforce
- **Type:** Validation

## Usage

### Apply All Policies
```bash
kubectl apply -f apps/kyverno/policies/aks-deployment-safeguards/
```

### Apply Individual Policy
```bash
kubectl apply -f apps/kyverno/policies/aks-deployment-safeguards/<policy-file>.yaml
```

### Check Policy Status
```bash
kubectl get clusterpolicy
```

### View Policy Reports
```bash
# All namespaces
kubectl get policyreport -A

# Specific namespace
kubectl get policyreport -n <namespace>

# Cluster-wide policies
kubectl get clusterpolicyreport
```

## Prerequisites
- Kubernetes 1.16+
- Kyverno 1.7.4+
- RBAC permissions for PDB management (see below)

## RBAC Configuration
For the Pod Disruption Budget policy, additional RBAC is required:

```bash
kubectl apply -f apps/kyverno/policies/aks-deployment-safeguards/pdb-rbac.yaml
```

The RBAC configuration provides:
- ClusterRole: `kyverno-pdb-admin`
- Permissions: create, delete, get, list, patch, update, watch
- Resources: poddisruptionbudgets.policy

## Policy Modes
All policies are in `Enforce` mode by default. To switch to audit mode:
1. Change `validationFailureAction` from `Enforce` to `Audit`
2. Reapply the policy

## Notes
- All policies run in background mode for continuous enforcement
- Policies include a mix of:
  - Validating policies (reject non-compliant resources)
  - Mutating policies (modify resources to ensure compliance)
  - Generating policies (create additional resources)
- Some policies may require additional configuration based on your specific AKS environment
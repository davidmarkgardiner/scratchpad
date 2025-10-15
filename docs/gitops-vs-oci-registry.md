# GitOps vs OCI Registry for Infrastructure-as-Code Deployments

## Summary

When deploying Infrastructure-as-Code (IaC) with Azure Service Operator YAML files and Kubernetes manifests, **Git tags + Flux GitOps is the appropriate solution**. OCI registries add unnecessary complexity without providing meaningful benefits for pure IaC scenarios.

## Key Differences

### OCI Registry Approach
**What it provides:**
- Immutable **built artifacts** (container images, compiled binaries)
- Content addressability via digest (sha256:abc123)
- Protection against build-time drift
- Supply chain security tooling (signing, SBOM, attestations)

**When to use:**
- Deploying container images/applications
- Need absolute guarantee of identical binaries across environments
- Regulated industries requiring strict artifact provenance
- Supply chain security is critical

**Drawbacks:**
- Additional infrastructure (registry maintenance, storage)
- Extra packaging/push step in pipeline
- More complex tooling

### Git Tags + Flux GitOps
**What it provides:**
- Immutable **source code references** via Git commit SHA
- Native audit trail through Git history
- Declarative GitOps reconciliation
- Simpler infrastructure (Git is already your source of truth)

**When to use:**
- Pure Infrastructure-as-Code (YAML, Terraform, Bicep)
- No container image builds involved
- Deterministic deployments (YAML is YAML - no compilation)
- Azure Service Operator resources

**Why it works for IaC:**
- Git tag = immutable artifact (YAML doesn't "build" or drift)
- Same commit SHA = exact same manifests deployed
- No build-time variables or dependency resolution

## The Critical Distinction

### Git Tags ARE Immutable for IaC
When you tag a repo:
- Tag points to specific commit SHA
- That commit is immutable
- YAML files are deterministic

**For IaC: Git tag = your artifact**

### OCI Registries Solve a Different Problem
The difference between "same source code" vs "same compiled artifact" only matters when there IS a compilation/build step:

```
# With Container Images (build step matters):
Dev (Jan 1):  v1.2.3 → builds with node:18.12 → image digest abc123
Prod (Jan 15): v1.2.3 → builds with node:18.13 → image digest xyz789
❌ Different artifacts from same code!

# With IaC YAML (no build step):
Dev (Jan 1):  v1.2.3 → deploy YAML manifests
Prod (Jan 15): v1.2.3 → deploy YAML manifests  
✓ Identical deployment from same code!
```

## Recommendation for IaC

**Use Git Tags + Flux GitOps**

Your promotion flow:
1. **Dev Environment:** Deploy `v1.2.3` tag → test Azure Service Operator resources
2. **Prod Environment:** Deploy same `v1.2.3` tag → exact same YAML applied

**Evidence of lower environment testing:**
- Same Git commit SHA deployed
- Same YAML manifests applied
- GitOps reconciliation succeeded
- Git history provides full audit trail

**OCI registries would be overkill** - adding complexity without solving a problem you don't have.

---

## Flux Configuration Examples

### Basic GitRepository with SemVer

```yaml
---
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: infrastructure-manifests
  namespace: flux-system
spec:
  interval: 5m
  url: https://github.com/your-org/infrastructure-repo
  ref:
    # SemVer range reference: https://github.com/Masterminds/semver#checking-version-constraints
    semver: ">=1.0.0 <2.0.0"  # Major version 1.x
```

### Common SemVer Patterns

```yaml
# Exact version
semver: "1.2.3"

# Patch updates only (1.2.x)
semver: "~1.2.0"

# Minor updates (1.x.x)
semver: "^1.0.0"

# Range
semver: ">=1.0.0 <2.0.0"

# Any version in 1.x or 2.x
semver: ">=1.0.0 <3.0.0"
```

### Complete Flux Kustomization Example

```yaml
---
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: azure-service-operator-config
  namespace: flux-system
spec:
  interval: 5m
  url: https://github.com/your-org/aso-infrastructure
  ref:
    semver: ">=1.0.0 <2.0.0"
  secretRef:
    name: git-credentials  # Optional: for private repos
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: azure-infrastructure
  namespace: flux-system
spec:
  interval: 10m
  path: ./clusters/production  # Path within the repo
  prune: true
  sourceRef:
    kind: GitRepository
    name: azure-service-operator-config
  healthChecks:
    - apiVersion: serviceoperator.azure.com/v1beta1
      kind: ResourceGroup
      name: production-rg
      namespace: default
```

### Environment-Specific Promotions

```yaml
# Dev environment - automatically picks up latest patch
---
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: infra-dev
  namespace: flux-system
spec:
  interval: 2m
  url: https://github.com/your-org/infrastructure
  ref:
    semver: "~1.2.0"  # Auto-update to 1.2.x patches
---
# Production environment - strict version control
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: infra-prod
  namespace: flux-system
spec:
  interval: 10m
  url: https://github.com/your-org/infrastructure
  ref:
    semver: "1.2.3"  # Explicit version, manual promotion
```

### Azure Service Operator YAML Example

What you're deploying with Flux:

```yaml
# Example ASO resource that Flux would deploy
apiVersion: serviceoperator.azure.com/v1beta1
kind: ResourceGroup
metadata:
  name: production-rg
  namespace: default
spec:
  location: eastus
  tags:
    environment: production
    managed-by: flux
---
apiVersion: serviceoperator.azure.com/v1beta1
kind: VirtualNetwork
metadata:
  name: production-vnet
  namespace: default
spec:
  location: eastus
  owner:
    name: production-rg
  addressSpace:
    addressPrefixes:
      - 10.0.0.0/16
```

### Promotion Workflow

```bash
# 1. Test in dev environment
git tag v1.2.3
git push origin v1.2.3

# Dev Flux picks up the tag (semver: "~1.2.0")
# ASO resources deploy to dev cluster
# Validate resources created successfully

# 2. Promote to production
# Update production GitRepository to use v1.2.3
kubectl edit gitrepository infra-prod -n flux-system
# Change semver: "1.2.2" to semver: "1.2.3"

# Or use Flux's built-in automation:
# Production GitRepository with semver: "^1.0.0" 
# will automatically pick up v1.2.3 once validated
```

---

## Conclusion

For Infrastructure-as-Code deployments without container images:
- ✅ **Git tags are your immutable artifacts**
- ✅ **Flux + SemVer provides GitOps best practices**
- ✅ **Git history = audit trail**
- ❌ **OCI registries add no value** for pure YAML/IaC

Focus on:
- Strong tagging conventions
- Clear promotion processes
- Git-based audit trails
- Flux health checks and reconciliation

Save OCI registries for when you're actually building and distributing container images or compiled artifacts.

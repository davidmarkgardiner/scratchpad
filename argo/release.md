# Semantic Versioning Release Strategy for Kubernetes Deployments

## Overview

This document outlines our SemVer-based release strategy to ensure reproducible deployments, clear version tracking, and safe rollback capabilities across all environments while enabling continuous feature development.

## Problem Statement

Currently, we deploy from branches without clear version tracking, making it difficult to:
- Know exactly what code is running in each environment
- Reproduce specific deployments
- Rollback to previous versions safely
- Continue development while maintaining stable production releases

## Solution: Semantic Versioning with FluxCD

We will implement a tag-based deployment strategy using Semantic Versioning (SemVer) that provides:
- **Single version tag** (e.g., `v1.2.3`) across all three components
- **Environment-specific update policies** via SemVer ranges
- **Clear rollback path** using exact version pinning
- **Automated deployment** through FluxCD GitOps

## Architecture Components

### 1. Three Synchronized Repositories
- **Infrastructure** - ARM templates and cluster configuration
- **Helm Charts** - Core application deployments via FluxCD
- **Config** - Namespace configurations and resource groups

### 2. Version Control Strategy
All three repositories will be tagged with the same version number during releases:
```
infrastructure: v1.2.3
helm-charts:    v1.2.3
config:         v1.2.3
```

### 3. Environment Configuration

| Environment | SemVer Range | Update Policy | Example |
|------------|--------------|---------------|---------|
| Development | `^1.0.0` | Minor + Patch updates | Gets 1.2.3, 1.3.0, 1.3.1 automatically |
| Staging | `~1.2.0` | Patch updates only | Gets 1.2.3, 1.2.4 but not 1.3.0 |
| Production | `1.2.3` | Exact version | Only specified version, no auto-updates |

## Implementation

### Azure Flux Extension Configuration

The infrastructure pipeline will deploy Flux configurations using ARM templates with environment-specific SemVer ranges:

```json
{
  "gitRepository": {
    "repositoryRef": {
      "semver": "~1.2.3"  // Controlled by environment variable
    }
  }
}
```

### Pipeline Variables

Each environment uses variable groups in Azure DevOps:
```yaml
# Production Variables
RELEASE_VERSION: 1.2.3
SEMVER_RANGE: exact

# Staging Variables  
RELEASE_VERSION: 1.2.3
SEMVER_RANGE: patch

# Development Variables
RELEASE_VERSION: 1.2.3
SEMVER_RANGE: minor
```

## Release Process

### 1. Feature Development
- Developers work on feature branches
- Merge to `main` branch via PR
- No impact on deployed environments

### 2. Release Creation
```bash
# When ready to release
VERSION=1.2.3

# Pipeline automatically:
# 1. Tags all three repos with v1.2.3
# 2. Updates Flux configuration with appropriate SemVer range
# 3. Deploys to target environment
```

### 3. Environment Promotion
- **Dev**: Automatically gets new minor/patch versions
- **Staging**: Automatically gets patch versions after testing
- **Production**: Manual promotion with exact version

### 4. Rollback Process
To rollback, simply redeploy with previous version:
```bash
# Rollback production to v1.2.2
RELEASE_VERSION=1.2.2
SEMVER_RANGE=exact
```

## Benefits

✅ **Version Visibility**: Always know what's deployed where  
✅ **Reproducible Deployments**: Any version can be redeployed exactly  
✅ **Safe Rollbacks**: Quick reversion to previous versions  
✅ **Continuous Development**: Feature work continues without affecting releases  
✅ **Automated Updates**: Non-breaking changes flow automatically to lower environments  
✅ **Single Source of Truth**: One version number controls all components  

## Example Scenarios

### Scenario 1: Hotfix
```
Current Production: v1.2.3
Hotfix needed: Create v1.2.4
- Tag all repos with v1.2.4
- Staging (with ~1.2.0) automatically gets update
- Production manually updated to exact v1.2.4
```

### Scenario 2: Feature Release
```
Current Production: v1.2.3
New features ready: Create v1.3.0
- Tag all repos with v1.3.0
- Dev (with ^1.0.0) automatically gets update
- Staging/Production updated after testing
```

### Scenario 3: Emergency Rollback
```
Current Production: v1.3.0 (has issues)
Rollback needed: Redeploy v1.2.3
- Run pipeline with VERSION=1.2.3, SEMVER_RANGE=exact
- Production immediately reverts to stable version
```

## Key Commands

### Check Current Deployments
```bash
# View what version Flux has deployed
kubectl get gitrepository -n flux-system -o wide

# Check specific environment status
flux get sources git --all-namespaces
```

### Manual Version Verification
```bash
# List available tags
git tag -l "v*" --sort=-version:refname

# See what each environment would select
# Dev (^1.0.0): Latest 1.x version
# Staging (~1.2.0): Latest 1.2.x version  
# Prod (1.2.3): Exactly v1.2.3
```

## Migration Path

1. **Week 1**: Tag current main branch as v1.0.0
2. **Week 2**: Deploy Flux configurations to Dev with SemVer
3. **Week 3**: Extend to Staging environment
4. **Week 4**: Production cutover with exact versions

## Success Criteria

- ✅ Any team member can identify what version is running in each environment
- ✅ Rollback to any previous version takes < 5 minutes
- ✅ Development continues uninterrupted during production freezes
- ✅ Audit trail shows clear version progression through environments

## Next Steps

1. Review and approve approach
2. Create Azure DevOps variable groups
3. Update ARM templates with SemVer support
4. Test in development environment
5. Document runbook for operations team

---

**Questions?** Contact the Platform Team

**Documentation**: [Internal Wiki Link]

**Pipeline**: [Azure DevOps Pipeline Link]
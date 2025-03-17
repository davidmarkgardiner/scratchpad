# Kyverno Policies with Kustomize for GitOps

This repository demonstrates how to manage Kyverno policies across different environments using Kustomize and GitOps principles.

## Directory Structure

```
kyverno-policies/
├── base/                      # Base policies (shared across all environments)
│   ├── require-labels.yaml
│   ├── restrict-image-registries.yaml
│   └── kustomization.yaml
│
└── overlays/                  # Environment-specific overlays
    ├── dev/                   # Development environment
    │   ├── require-labels-patch.yaml
    │   ├── restrict-image-registries-patch.yaml
    │   └── kustomization.yaml
    │
    ├── staging/               # Staging environment
    │   ├── require-labels-patch.yaml
    │   ├── restrict-image-registries-patch.yaml
    │   └── kustomization.yaml
    │
    └── prod/                  # Production environment
        ├── require-labels-patch.yaml
        ├── restrict-image-registries-patch.yaml
        ├── require-pod-security.yaml     # Production-only policy
        └── kustomization.yaml
```

## Policy Progression Across Environments

This setup demonstrates policy progression from dev to production:

1. **Development**: Policies are in "audit" mode with minimal requirements
2. **Staging**: Stricter validations with "enforce" mode but still flexible
3. **Production**: Most stringent policies with additional security policies

## Using with GitOps

In a GitOps workflow with a tool like Flux or ArgoCD:

1. This repository structure would be committed to Git
2. Your GitOps controller would be configured to sync specific environment overlays to their respective clusters
3. Changes would follow your normal PR workflow with approval gates

## Applying Policies

To test/preview the policies for each environment:

```bash
# Development
kubectl kustomize kyverno-policies/overlays/dev

# Staging  
kubectl kustomize kyverno-policies/overlays/staging

# Production
kubectl kustomize kyverno-policies/overlays/prod
```

To apply the policies:

```bash
# Development
kubectl apply -k kyverno-policies/overlays/dev

# Staging
kubectl apply -k kyverno-policies/overlays/staging

# Production
kubectl apply -k kyverno-policies/overlays/prod
```

## Key Benefits

1. **Single Source of Truth**: All policies defined once in the base
2. **Progressive Controls**: Gradually increasing policy strictness by environment
3. **DRY Policy Management**: Only override what changes between environments
4. **Environment-Specific Requirements**: Production-only additional policies
5. **Consistent Deployment**: Same GitOps process across all environments 
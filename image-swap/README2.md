# Kyverno Policies GitOps Deployment

This repository contains Kyverno policies that are deployed using Flux GitOps across multiple environments.

## Structure

```
.
├── flux/                      # Flux GitOps configuration
│   ├── gitrepository.yaml     # Git repository source
│   ├── kustomization.yaml     # Main kustomization file
│   ├── kyverno-policies-eng.yaml    # Engineering environment
│   ├── kyverno-policies-dev.yaml    # Development environment
│   ├── kyverno-policies-preprod.yaml # Pre-production environment
│   └── kyverno-policies-prod.yaml   # Production environment
│
├── kustomize/                 # Kustomize configuration
│   ├── base/                  # Base policies
│   │   ├── kustomization.yaml
│   │   ├── resource-limits-policy.yaml
│   │   ├── prevent-istio-injection-policy.yaml
│   │   └── ...
│   │
│   └── overlays/              # Environment-specific overlays
│       ├── eng/               # Engineering environment
│       │   ├── kustomization.yaml
│       │   └── patches/
│       │       ├── policy-mode-audit.yaml
│       │       ├── resource-limits-values.yaml
│       │       ├── istio-revision-label.yaml
│       │       ├── image-registry-settings.yaml
│       │       └── spot-affinity-settings.yaml
│       │
│       ├── dev/               # Development environment
│       │   ├── kustomization.yaml
│       │   └── patches/
│       │       ├── policy-mode-mixed.yaml
│       │       ├── policy-mode-audit.yaml
│       │       ├── resource-limits-values.yaml
│       │       ├── istio-revision-label.yaml
│       │       ├── image-registry-settings.yaml
│       │       └── spot-affinity-settings.yaml
│       │
│       ├── preprod/           # Pre-production environment
│       │   ├── kustomization.yaml
│       │   └── patches/
│       │       ├── policy-mode-enforce.yaml
│       │       ├── policy-mode-audit.yaml
│       │       ├── resource-limits-values.yaml
│       │       ├── istio-revision-label.yaml
│       │       ├── image-registry-settings.yaml
│       │       └── spot-affinity-settings.yaml
│       │
│       └── prod/              # Production environment
│           ├── kustomization.yaml
│           └── patches/
│               ├── policy-mode-enforce.yaml
│               ├── resource-limits-values.yaml
│               ├── istio-revision-label.yaml
│               ├── image-registry-settings.yaml
│               └── spot-affinity-settings.yaml
│
└── test/                      # Test configuration
    ├── flux-gitops-test.yaml  # Test for Flux GitOps deployment
    ├── flux-values.yaml       # Values for tests
    └── resources/             # Test resources
        ├── flux-gitrepository.yaml
        ├── flux-kustomization.yaml
        ├── flux-helmrelease.yaml
        └── flux-kyverno-policy.yaml
```

## Environment Configuration

### Engineering (eng)
- All policies are in `audit` mode
- Used for initial testing and development
- Resource limits: Low (CPU: 250m, Memory: 512Mi)
- Istio revision: istio.io/rev: asm-1-23 (latest testing version)

### Development (dev)
- Mixed mode: Some policies in `enforce` mode, others in `audit` mode
- Resource limits and Istio injection policies are enforced
- Other policies are in audit mode
- Resource limits: Medium (CPU: 500m, Memory: 1Gi)
- Istio revision:  istio.io/rev: asm-1-23

### Pre-production (preprod)
- Most policies in `enforce` mode
- Only audit-specific policies remain in `audit` mode
- Resource limits: High (CPU: 1000m, Memory: 2Gi)
- Istio revision:  istio.io/rev: asm-1-23

### Production (prod)
- All policies in `enforce` mode
- Resource limits: Highest (CPU: 2000m, Memory: 4Gi)
- Istio revision: istio.io/rev: asm-1-23


## Environment-Specific Overrides

### Resource Limits
Each environment has different resource limit requirements:
- Engineering: Lower limits for development workloads
- Development: Medium limits for testing
- Pre-production: Higher limits for performance testing
- Production: Highest limits for production workloads



## Deployment

The policies are deployed using Flux GitOps. Each environment has its own Kustomization resource that points to the corresponding overlay.

Environment-specific variables can be provided using ConfigMaps:
- `kyverno-env-vars-eng`
- `kyverno-env-vars-dev`
- `kyverno-env-vars-preprod`
- `kyverno-env-vars-prod` 
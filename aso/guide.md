I'll create a setup guide for managing AKS clusters using Azure Service Operator with GitOps.

# AKS Cluster Management with GitOps - Setup Guide

## Prerequisites
- Azure CLI installed and logged in
- Kubectl configured
- Git installed
- ASO (Azure Service Operator) installed
- Flux installed
- Working AKS cluster (management cluster)
- Visual Studio Code (recommended)

## Initial Setup

1. Install Required VS Code Extensions:
```bash
# Install these extensions in VS Code
- YAML (Red Hat)
- Kubernetes (Microsoft)
- GitLens (optional but recommended)
```

2. Setup Local Repository:
```bash
# Clone your organization's repository or create a new one
git clone <your-repo-url>
cd <your-repo>

# Create the basic directory structure
mkdir -p {base/{cluster-template,addons},clusters/{dev,prod}/cluster-config/patches}
```

3. Configure YAML Validation:
```bash
# Create .yamllint file in root directory
cat > .yamllint <<EOF
extends: default

rules:
  line-length: 
    max: 120
    level: warning
  indentation:
    spaces: 2
    indent-sequences: true
  document-start: disable
EOF

# Create .editorconfig for consistent formatting
cat > .editorconfig <<EOF
root = true

[*]
indent_style = space
indent_size = 2
end_of_line = lf
charset = utf-8
trim_trailing_whitespace = true
insert_final_newline = true

[*.{yaml,yml}]
indent_size = 2
EOF
```

## Directory Structure Setup

```bash
# Create all required files
touch base/cluster-template/{managed-cluster.yaml,variables-template.yaml,kustomization.yaml}
touch clusters/dev/cluster-config/{variables.yaml,patches/cluster-overrides.yaml}
touch clusters/prod/cluster-config/{variables.yaml,patches/cluster-overrides.yaml}
touch clusters/{dev,prod}/kustomization.yaml
```

## Configuration Steps

1. Copy Base Templates:
```bash
# Copy the provided base templates from earlier into:
# - base/cluster-template/managed-cluster.yaml
# - base/cluster-template/variables-template.yaml
```

2. Setup Environment Variables:
```bash
# Copy environment-specific variables into:
# - clusters/dev/cluster-config/variables.yaml
# - clusters/prod/cluster-config/variables.yaml
```

3. Create Base Kustomization:
```yaml
# base/cluster-template/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - managed-cluster.yaml
```

4. Create Environment Kustomizations:
```yaml
# clusters/dev/kustomization.yaml and clusters/prod/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ../../base/cluster-template
configMapGenerator:
  - name: cluster-vars
    behavior: merge
    files:
      - cluster-config/variables.yaml
```

## Validation Steps

1. Install kubeval for Kubernetes manifest validation:
```bash
# Install kubeval
brew install kubeval  # macOS
# or
wget https://github.com/instrumenta/kubeval/releases/latest/download/kubeval-linux-amd64.tar.gz  # Linux
```

2. Create validation script:
```bash
# Create scripts/validate.sh
mkdir -p scripts
cat > scripts/validate.sh <<EOF
#!/bin/bash
set -e

echo "Running YAML lint..."
yamllint .

echo "Running Kustomize build validation..."
for env in dev prod; do
  echo "Validating $env environment..."
  kustomize build clusters/$env | kubeval --ignore-missing-schemas
done

echo "Checking for ASO CRD validation..."
kubectl get crd managedclusters.containerservice.azure.com -o yaml > aso-crd.yaml
kustomize build clusters/dev | kubectl apply --dry-run=client -f -

echo "All validations passed!"
EOF

chmod +x scripts/validate.sh
```

## Local Development Workflow

1. Make changes:
```bash
# 1. Edit variables for your environment
vim clusters/dev/cluster-config/variables.yaml

# 2. Validate changes
./scripts/validate.sh

# 3. Preview the generated manifest
kustomize build clusters/dev > preview.yaml

# 4. Review the preview
kubectl diff -f preview.yaml
```

2. Test locally:
```bash
# Build and apply to test cluster
kustomize build clusters/dev | kubectl apply --dry-run=client -f -

# If everything looks good, apply the changes
kustomize build clusters/dev | kubectl apply -f -
```

## Best Practices

1. Always validate before committing:
```bash
# Run all validations
./scripts/validate.sh

# Check kustomize output
kustomize build clusters/dev
```

2. Use git hooks for validation:
```bash
# Create .git/hooks/pre-commit
cat > .git/hooks/pre-commit <<EOF
#!/bin/bash
./scripts/validate.sh
EOF

chmod +x .git/hooks/pre-commit
```

3. Document changes:
```bash
# Create good commit messages
git commit -m "cluster: update dev node pool size

- Increased min count to 3 for high availability
- Updated max count to 5 for scalability
- Changed VM size to Standard_D4s_v3 for better performance"
```

## Common Tasks

1. Update Kubernetes version:
```bash
# Edit variables.yaml
K8S_VERSION: "1.28.3"
```

2. Scale node pools:
```bash
# Edit variables.yaml
SYSTEM_NODEPOOL:
  COUNT: 3
  MIN_COUNT: 3
  MAX_COUNT: 5
```

3. Add/modify addons:
```bash
# Edit variables.yaml
ADDONS:
  KEYVAULT:
    ENABLED: true
```

## Troubleshooting

1. Check ASO logs:
```bash
kubectl logs -n azure-service-operator-system deployment/azureserviceoperator-controller-manager
```

2. Validate CRD:
```bash
kubectl get managedclusters.containerservice.azure.com
```

3. Check Flux status:
```bash
flux get all
```

## Key Commands Reference

```bash
# Validate YAML
yamllint .

# Build Kustomize
kustomize build clusters/dev

# Validate against Kubernetes
kustomize build clusters/dev | kubectl apply --dry-run=client -f -

# Apply changes
kustomize build clusters/dev | kubectl apply -f -

# Check status
kubectl get managedclusters.containerservice.azure.com
```

## Notes
- Always run validation before committing changes
- Use meaningful commit messages
- Keep variables.yaml up to date
- Review changes carefully in dev before promoting to prod
- Use git branches for significant changes
- Regularly update base templates with new best practices

Remember to replace placeholder values in variables.yaml with your actual Azure subscription, resource group, and other environment-specific values.

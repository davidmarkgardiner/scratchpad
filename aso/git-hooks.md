I'll create a comprehensive Git hooks setup to help enforce quality and validation across your GitOps workflows.

```bash
mkdir -p .github/hooks
```

1. Create a hooks installation script:
```bash
# scripts/install-hooks.sh
#!/bin/bash
set -e

HOOK_DIR=.github/hooks
GIT_HOOK_DIR=.git/hooks

echo "Installing git hooks..."

# Create git hooks directory if it doesn't exist
mkdir -p $GIT_HOOK_DIR

# Symlink all hooks
for hook in $HOOK_DIR/*; do
  if [ -f "$hook" ]; then
    hook_name=$(basename "$hook")
    ln -sf "../../$HOOK_DIR/$hook_name" "$GIT_HOOK_DIR/$hook_name"
    chmod +x "$GIT_HOOK_DIR/$hook_name"
    echo "Installed: $hook_name"
  fi
done

echo "Git hooks installed successfully!"
```

2. Create the pre-commit hook:
```bash
# .github/hooks/pre-commit
#!/bin/bash
set -e

echo "Running pre-commit checks..."

# Check for yaml files that will be committed
files=$(git diff --cached --name-only --diff-filter=ACMR | grep ".*\.ya\?ml$" || true)
if [ -n "$files" ]; then
    echo "Validating YAML files..."
    
    # Run yamllint
    echo "Running yamllint..."
    yamllint $files

    # Validate kustomize builds for changed environments
    environments=$(echo "$files" | grep "clusters/" | cut -d'/' -f2 | sort -u || true)
    if [ -n "$environments" ]; then
        echo "Validating Kustomize builds for environments: $environments"
        for env in $environments; do
            echo "Building kustomize for $env..."
            kustomize build "clusters/$env" > /dev/null
        done
    fi
fi

# Check for Kubernetes manifests
if echo "$files" | grep -q "\.ya\?ml$"; then
    echo "Validating Kubernetes manifests..."
    for file in $files; do
        if grep -q "kind:" "$file"; then
            echo "Validating $file..."
            kubeval --ignore-missing-schemas "$file"
        fi
    done
fi

echo "All pre-commit checks passed!"
```

3. Create the commit-msg hook:
```bash
# .github/hooks/commit-msg
#!/bin/bash

commit_msg_file=$1
commit_msg=$(cat "$commit_msg_file")

# Define valid commit types
valid_types="cluster|infra|config|security|addon|fix|docs|chore|test"

# Commit message format
format_regex="^($valid_types)(\([a-z0-9-]+\))?: .+$"

if ! [[ "$commit_msg" =~ $format_regex ]]; then
    echo "Invalid commit message format. Please use:"
    echo "type(scope): message"
    echo ""
    echo "Valid types: ${valid_types//|/, }"
    echo ""
    echo "Examples:"
    echo "cluster(dev): update node pool size"
    echo "security(prod): enable Azure Defender"
    echo "addon(istio): upgrade to version 1.20"
    echo "config(network): update service CIDR"
    exit 1
fi
```

4. Create the pre-push hook:
```bash
# .github/hooks/pre-push
#!/bin/bash
set -e

echo "Running pre-push checks..."

# Validate all environments
for env in clusters/*; do
    if [ -d "$env" ]; then
        env_name=$(basename "$env")
        echo "Validating $env_name environment..."
        
        # Build and validate kustomize
        echo "Building kustomize..."
        kustomize build "clusters/$env_name" > "clusters/$env_name/preview.yaml"
        
        # Validate with kubeval
        echo "Validating Kubernetes manifests..."
        kubeval --ignore-missing-schemas "clusters/$env_name/preview.yaml"
        
        # Check ASO CRDs
        echo "Validating against ASO CRDs..."
        kubectl apply --dry-run=client -f "clusters/$env_name/preview.yaml"
        
        # Cleanup
        rm "clusters/$env_name/preview.yaml"
    fi
done

# Check for sensitive data
echo "Checking for sensitive data..."
if git grep -l 'password\|secret\|key\|token' -- '*.yaml' '*.yml'; then
    echo "Warning: Potential sensitive data detected in YAML files"
    echo "Please review the files above"
    exit 1
fi

echo "All pre-push checks passed!"
```

5. Create a post-checkout hook for environment setup:
```bash
# .github/hooks/post-checkout
#!/bin/bash

# Run only when switching branches
if [ $3 -eq 1 ]; then
    echo "Switched branches, checking environment..."
    
    # Check if yamllint is installed
    if ! command -v yamllint >/dev/null 2>&1; then
        echo "Warning: yamllint is not installed"
    fi
    
    # Check if kubeval is installed
    if ! command -v kubeval >/dev/null 2>&1; then
        echo "Warning: kubeval is not installed"
    fi
    
    # Check if kubectl is configured
    if ! kubectl cluster-info >/dev/null 2>&1; then
        echo "Warning: kubectl is not configured properly"
    fi
    
    # Check for ASO CRDs
    if ! kubectl get crd managedclusters.containerservice.azure.com >/dev/null 2>&1; then
        echo "Warning: ASO CRDs not found in cluster"
    fi
fi
```

6. Add hook descriptions in a README:
```markdown
# Git Hooks

This repository uses the following Git hooks:

## Pre-commit
- Validates YAML syntax
- Checks Kustomize builds
- Validates Kubernetes manifests

## Commit-msg
- Enforces commit message format: type(scope): message
- Valid types: cluster, infra, config, security, addon, fix, docs, chore, test

## Pre-push
- Validates all environments
- Checks for sensitive data
- Validates against ASO CRDs

## Post-checkout
- Verifies development environment setup
- Checks required tools installation

## Installation

Run:
```bash
./scripts/install-hooks.sh
```

Add this to your README:
```markdown
## Development Setup

1. Install required tools:
```bash
# macOS
brew install yamllint kubeval kubectl

# Linux
# Add installation commands for your distro
```

2. Install git hooks:
```bash
./scripts/install-hooks.sh
```

3. Test the hooks:
```bash
# Should trigger pre-commit hook
git add clusters/dev/cluster-config/variables.yaml
git commit -m "cluster(dev): update node pool size"

# Should trigger pre-push hook
git push
```
```

These hooks will help:
- Enforce consistent commit messages
- Catch YAML syntax errors early
- Validate Kubernetes manifests
- Prevent sensitive data commits
- Ensure proper environment setup
- Validate changes before push

Developers can bypass hooks if needed with:
```bash
git commit --no-verify
git push --no-verify
```
But this should be used sparingly and documented.

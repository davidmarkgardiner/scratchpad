# Managing Kyverno Policies with GitOps using Flux and Azure DevOps

## Overview
This guide describes how to manage Kyverno policies across multiple environments and clusters using GitOps principles with Flux and Azure DevOps pipelines.

## Repository Structure
```
├── clusters/
│   ├── dev/
│   │   ├── flux-system/
│   │   └── kyverno-policies/
│   │       ├── kustomization.yaml
│   │       └── policies.yaml
│   ├── staging/
│   └── prod/
├── policies/
│   ├── base/
│   │   ├── common-policies/
│   │   │   ├── require-labels.yaml
│   │   │   └── pod-security.yaml
│   ├── overlays/
│   │   ├── dev/
│   │   │   ├── kustomization.yaml
│   │   │   └── policies-dev.yaml
│   │   ├── staging/
│   │   └── prod/
├── helm/
│   └── kyverno-policies/
│       ├── Chart.yaml
│       ├── values.yaml
│       └── templates/
└── azure-pipelines/
    ├── validate-policies.yaml
    └── sync-policies.yaml
```

## Flux Configuration

### 1. Install Flux in Each Cluster
```bash
# Install Flux CLI
brew install fluxcd/tap/flux

# Bootstrap Flux in cluster
flux bootstrap git \
  --url=ssh://git@ssh.dev.azure.com/v3/{org}/{project}/{repo} \
  --branch=main \
  --path=clusters/dev
```

### 2. Configure Kyverno Policies Source
```yaml
# clusters/dev/flux-system/kyverno-source.yaml
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: GitRepository
metadata:
  name: kyverno-policies
  namespace: flux-system
spec:
  interval: 1m
  url: ssh://git@ssh.dev.azure.com/v3/{org}/{project}/{repo}
  ref:
    branch: main
  secretRef:
    name: flux-system
```

### 3. Configure Kyverno Policies Kustomization
```yaml
# clusters/dev/kyverno-policies/kustomization.yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1beta2
kind: Kustomization
metadata:
  name: kyverno-policies
  namespace: flux-system
spec:
  interval: 5m
  path: ./policies/overlays/dev
  prune: true
  sourceRef:
    kind: GitRepository
    name: kyverno-policies
  validation: client
  healthChecks:
    - apiVersion: kyverno.io/v1
      kind: ClusterPolicy
      name: require-labels
```

## Azure DevOps Pipeline Configuration

### 1. Policy Validation Pipeline
```yaml
# azure-pipelines/validate-policies.yaml
trigger:
  branches:
    include:
      - main
  paths:
    include:
      - 'policies/**'

pool:
  vmImage: 'ubuntu-latest'

steps:
- task: Bash@3
  inputs:
    targetType: 'inline'
    script: |
      # Install Kyverno CLI
      curl -LO https://github.com/kyverno/kyverno/releases/download/v1.11.0/kyverno-cli_v1.11.0_linux_x86_64.tar.gz
      tar -xvf kyverno-cli_v1.11.0_linux_x86_64.tar.gz
      sudo mv kyverno /usr/local/bin/
      
      # Validate Policies
      for policy in policies/base/common-policies/*.yaml; do
        kyverno validate ${policy}
      done

- task: HelmInstaller@0
  inputs:
    helmVersion: '3.12.0'

- task: Bash@3
  inputs:
    targetType: 'inline'
    script: |
      # Validate Helm Charts
      helm lint helm/kyverno-policies
```

### 2. Policy Testing and Verification
```yaml
# helm/kyverno-policies/templates/tests/test-policies.yaml
apiVersion: v1
kind: Pod
metadata:
  name: "{{ .Release.Name }}-test"
  annotations:
    "helm.sh/hook": test
spec:
  containers:
    - name: test
      image: bitnami/kubectl
      command: ["/bin/sh", "-c"]
      args:
        - |
          # Test policy enforcement
          kubectl create ns test-kyverno
          
          # Try to create non-compliant pod
          cat <<EOF | kubectl apply -f - || true
          apiVersion: v1
          kind: Pod
          metadata:
            name: test-pod
            namespace: test-kyverno
          spec:
            containers:
            - name: nginx
              image: nginx
          EOF
          
          # Verify policy violation
          if kubectl get events -n test-kyverno --field-selector reason=PolicyViolation | grep -q "policy violation"; then
            echo "Policy enforcement verified"
            exit 0
          else
            echo "Policy verification failed"
            exit 1
          fi
```

## Policy Management Workflow

### 1. Development Process
1. Create feature branch
2. Add/modify policies in `policies/base` or environment overlays
3. Create Pull Request
4. Azure DevOps pipeline validates policies
5. Review and merge

### 2. Deployment Process
1. Flux detects changes in Git repository
2. Applies changes to respective clusters based on path
3. Runs health checks to verify policy deployment
4. Monitors for policy violations

### 3. Verification Steps
```bash
# Check Flux status
flux get kustomizations
flux get sources git

# Verify policy deployment
kubectl get clusterpolicies
kubectl get policyreports -A

# Check policy violations
kubectl get events --field-selector reason=PolicyViolation -A
```

## Best Practices

1. **Policy Organization**
   - Keep base policies generic
   - Use overlays for environment-specific modifications
   - Document policy exceptions

2. **Version Control**
   - Use semantic versioning for policies
   - Tag releases for production deployments
   - Maintain changelog

3. **Testing**
   - Include both positive and negative test cases
   - Test policies in dev environment first
   - Implement gradual rollout for strict policies

4. **Monitoring**
   - Set up alerts for policy violations
   - Monitor policy performance impact
   - Track policy effectiveness metrics

## Troubleshooting

### Common Issues and Solutions

1. **Policy Not Syncing**
   ```bash
   # Check Flux logs
   kubectl logs -n flux-system deploy/source-controller
   kubectl logs -n flux-system deploy/kustomize-controller
   ```

2. **Policy Validation Failures**
   ```bash
   # Debug policy
   kyverno validate --debug policy.yaml
   ```

3. **Cluster Sync Issues**
   ```bash
   # Check Flux status
   flux reconcile source git flux-system
   flux reconcile kustomization flux-system
   ```

## Additional Resources

- [Flux Documentation](https://fluxcd.io/docs/)
- [Kyverno Documentation](https://kyverno.io/docs/)
- [Azure DevOps Pipelines](https://learn.microsoft.com/en-us/azure/devops/pipelines/)

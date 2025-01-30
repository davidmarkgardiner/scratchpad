# GitOps Deployment Guide for Kyverno Policies

This guide demonstrates how to deploy and test Kyverno policies using GitOps with Flux and HelmRelease.

## Prerequisites

- Kubernetes cluster with Flux v2 installed
- Kyverno installed via Flux HelmRelease
- Git repository configured as a Flux source
- `kubectl` and `flux` CLI tools

## Deployment Structure

Your GitOps repository should have a structure similar to:

```
clusters/
└── production/
    ├── infrastructure/
    │   └── kyverno/
    │       ├── kustomization.yaml
    │       ├── helmrelease.yaml
    │       └── values.yaml
    └── policies/
        └── kyverno-policies/
            ├── kustomization.yaml
            └── helmrelease.yaml
```

## Deployment Steps

1. Create a HelmRelease for Kyverno policies:

```yaml
# clusters/production/policies/kyverno-policies/helmrelease.yaml
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: kyverno-policies
  namespace: kyverno
spec:
  interval: 5m
  chart:
    spec:
      chart: ./
      sourceRef:
        kind: GitRepository
        name: kyverno-policies
        namespace: flux-system
  values:
    # Your values here, can be referenced from values.yaml
  dependsOn:
    - name: kyverno
      namespace: kyverno
```

2. Create a Kustomization to manage the policies:

```yaml
# clusters/production/policies/kyverno-policies/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - helmrelease.yaml
```

## Testing in Production

### 1. Pre-deployment Testing

Before merging to your production branch:

```bash
# Clone your policies repository
git clone <your-repo-url>
cd kyverno-policies

# Test policies locally
helm template . | kyverno test .
```

### 2. Staged Rollout

Use Flux's Kustomize features for staged rollouts:

```yaml
# clusters/production/policies/kyverno-policies/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - helmrelease.yaml
patches:
  - patch: |
      - op: add
        path: /spec/values/policies/audit
        value: true
    target:
      kind: HelmRelease
      name: kyverno-policies
```

### 3. Production Validation

Monitor policy effectiveness:

```bash
# Check PolicyReports
kubectl get policyreport -A

# Monitor policy violations
kubectl get clusterpolicyreport -o json | jq '.items[].results[]'

# View Kyverno admission reviews
kubectl logs -n kyverno -l app.kubernetes.io/name=kyverno
```

## Continuous Testing with Flux

### 1. Add Test Jobs

Create a test suite that runs automatically:

```yaml
# templates/tests/production-validation.yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: policy-validation
  namespace: kyverno
spec:
  schedule: "0 */6 * * *"
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: policy-test
            image: kubectl
            command:
            - /bin/sh
            - -c
            - |
              kubectl get policyreport -A
              # Add your validation logic here
          restartPolicy: OnFailure
```

### 2. Monitor Test Results

Set up monitoring and alerts:

```yaml
# templates/tests/alerts.yaml
apiVersion: notification.toolkit.fluxcd.io/v1beta2
kind: Alert
metadata:
  name: policy-violations
  namespace: flux-system
spec:
  providerRef:
    name: slack
  eventSeverity: error
  eventSources:
    - kind: HelmRelease
      name: kyverno-policies
```

## Rollback Procedures

If issues are detected:

1. Use Flux to rollback:
```bash
flux suspend helmrelease kyverno-policies -n kyverno
flux reconcile helmrelease kyverno-policies -n kyverno --revision previous
```

2. Or revert to previous version in Git:
```bash
git revert <commit-hash>
git push
```

## Best Practices

1. Always use policy reporter:
```yaml
values:
  policyReporter:
    enabled: true
    metrics:
      enabled: true
```

2. Implement gradual policy enforcement:
   - Start with `audit` mode
   - Monitor violations
   - Switch to `enforce` mode after validation

3. Use policy exceptions for legitimate cases:
```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-labels
spec:
  validationFailureAction: enforce
  background: true
  rules:
    - name: check-for-labels
      exclude:
        any:
        - resources:
            namespaces: ["kube-system"]
```

## Troubleshooting

1. Check Flux status:
```bash
flux get helmreleases -A
flux get kustomizations -A
```

2. Verify policy synchronization:
```bash
kubectl get clusterpolicies
```

3. Debug policy issues:
```bash
kubectl describe clusterpolicy <policy-name>
kubectl logs -n kyverno -l app.kubernetes.io/name=kyverno
```

## Metrics and Monitoring

Enable Prometheus metrics:

```yaml
values:
  policyReporter:
    metrics:
      enabled: true
      serviceMonitor:
        enabled: true
```

Example Grafana dashboard queries:
```promql
sum(kyverno_policy_results_total{result="fail"}) by (policy)
rate(kyverno_admission_reviews_total[5m])
``` 
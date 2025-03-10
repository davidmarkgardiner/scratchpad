# Flux HelmRelease Deployment Plan

This repository contains a deployment plan for multiple Helm charts using Flux CD on AKS. The deployment is structured to ensure proper ordering based on dependencies between applications.

## Deployment Architecture

The deployment uses a tiered approach with multiple Flux HelmReleases to ensure strict ordering of deployments:

1. Each tier has its own HelmRelease that explicitly depends on the previous tier
2. Flux will not start deploying a tier until all the HelmReleases it depends on are ready
3. This guarantees that tier4 (frontend) will never deploy before tier1 (database) is fully ready

## Deployment Plan

<deployment_plan>
The deployment follows a tiered approach based on dependencies:

### Tier 1 (Foundation)
- **Database**: PostgreSQL database with persistent storage
  - No dependencies
  - Must be fully operational before Tier 2 components

### Tier 2 (Infrastructure Services)
- **Cache**: Redis cache service
  - Depends on: Database (Tier 1)
  - Must be fully operational before Tier 3 components

### Tier 3 (Application Core)
- **API**: Backend API service
  - Depends on: Database (Tier 1), Cache (Tier 2)
  - Must be fully operational before Tier 4 components

### Tier 4 (User-Facing Services)
- **Frontend**: Web frontend application
  - Depends on: API (Tier 3)

### Independent Services
- **Monitoring**: Prometheus monitoring stack
  - No strict dependencies, can be deployed in parallel
- **Kyverno**: Policy engine for Kubernetes
  - No strict dependencies, can be deployed in parallel
</deployment_plan>

## Implementation Details

### Master Chart

The master chart (`master-chart/`) contains:
- All application components as subcharts
- Global and component-specific values in `values.yaml`
- Pre-install and post-install hooks to verify deployment health

### Flux Resources

The Flux resources (`flux-resources/`) include:
- `GitRepository` to track the Git repository containing the charts
- Multiple `HelmRelease` resources, one for each tier:
  - `tier1-helmrelease.yaml`: Deploys the database
  - `tier2-helmrelease.yaml`: Deploys the cache (depends on tier1)
  - `tier3-helmrelease.yaml`: Deploys the API (depends on tier2)
  - `tier4-helmrelease.yaml`: Deploys the frontend (depends on tier3)
  - `monitoring-helmrelease.yaml`: Deploys monitoring (independent)
  - `kyverno-helmrelease.yaml`: Deploys Kyverno policy engine (independent)
- Namespace definition and Kustomization file

### Strict Ordering with Flux

The key to ensuring strict ordering is the `dependsOn` field in the HelmRelease resources:

```yaml
# Example from tier2-helmrelease.yaml
spec:
  dependsOn:
    - name: tier1-database
```

This tells Flux to wait until the tier1-database HelmRelease is fully reconciled and ready before starting to deploy tier2. This creates a strict dependency chain:

```
tier1-database → tier2-cache → tier3-api → tier4-frontend
```

Monitoring and Kyverno have no dependencies and can deploy in parallel.

### CRD Management

The deployment includes pre-install hooks that check for required CRDs before installation:

1. **General CRD Check**: Verifies CRDs for most components
2. **Kyverno-specific CRD Check**: Dedicated check for Kyverno CRDs

Each component can specify its required CRDs in the values.yaml file. The pre-install hooks check if these CRDs exist in the cluster. If CRDs are missing, the hooks can either:
- Fail the installation (default)
- Automatically install the missing CRDs (if `global.autoInstallCRDs=true`)

This ensures that all necessary CRDs are available before the Helm charts are installed, preventing errors during deployment.

The deployment checks for the following CRDs:

#### Prometheus CRDs (via pre-crd-check.yaml)
```
prometheuses.monitoring.coreos.com
servicemonitors.monitoring.coreos.com
podmonitors.monitoring.coreos.com
alertmanagers.monitoring.coreos.com
prometheusrules.monitoring.coreos.com
```

#### Kyverno CRDs (via kyverno-crd-check.yaml)
```
admissionreports.kyverno.io
backgroundscanreports.kyverno.io
cleanuppolicies.kyverno.io
clusteradmissionreports.kyverno.io
clusterbackgroundscanreports.kyverno.io
clustercleanuppolicies.kyverno.io
clusterpolicies.kyverno.io
policies.kyverno.io
policyexceptions.kyverno.io
updaterequests.kyverno.io
```

Example CRD configuration in values.yaml:

```yaml
kyverno:
  requiresCRDs: true
  requiredCRDs:
    - "admissionreports.kyverno.io"
    - "backgroundscanreports.kyverno.io"
    - "cleanuppolicies.kyverno.io"
    # ... and more
```

### Deployment Hooks

The deployment includes several important hooks:

1. **Pre-CRD Check**: Verifies that general CRDs exist before installation
2. **Kyverno CRD Check**: Dedicated check for Kyverno CRDs
3. **Pre-install Hook**: Verifies that dependencies are properly configured
4. **Post-install Hook**: Checks for non-running pods after deployment and can automatically fix issues

## Handling Non-Running Pods

The post-install hook includes logic to:
1. Detect non-running pods after deployment
2. Gather diagnostic information (logs, pod details)
3. Optionally restart problematic pods (controlled by `global.autoFixPods` setting)
4. Verify the fix was successful

## Deployment Commands

<helm_commands>
# Bootstrap Flux on the cluster (if not already installed)
flux bootstrap github \
  --owner=mycompany \
  --repository=app-charts \
  --branch=main \
  --path=clusters/production \
  --personal

# Apply the Flux resources
kubectl apply -k flux-resources/

# Monitor the deployment
flux get helmreleases -A
flux get helmreleases -n apps

# Check the status of the pods
kubectl get pods -n apps

# View logs from the pre-CRD check
kubectl logs -n apps job/tier1-database-pre-crd-check

# View logs from the Kyverno CRD check
kubectl logs -n apps job/kyverno-kyverno-crd-check

# View logs from the post-install check
kubectl logs -n apps job/tier1-database-post-install-check

# Check if Kyverno CRDs are installed
kubectl get crd | grep kyverno
</helm_commands>

## Troubleshooting

If pods are not running correctly after deployment:

1. Check the logs of the pre-CRD check:
   ```
   kubectl logs -n apps job/tier1-database-pre-crd-check
   ```

2. Check the logs of the Kyverno CRD check:
   ```
   kubectl logs -n apps job/kyverno-kyverno-crd-check
   ```

3. Check the logs of the post-install hook:
   ```
   kubectl logs -n apps job/tier1-database-post-install-check
   ```

4. Manually inspect problematic pods:
   ```
   kubectl describe pod -n apps <pod-name>
   kubectl logs -n apps <pod-name>
   ```

5. If needed, manually trigger a reconciliation:
   ```
   flux reconcile helmrelease tier1-database -n apps
   ```

6. If Kyverno CRDs are missing, you can install them manually:
   ```
   kubectl apply -f https://raw.githubusercontent.com/kyverno/kyverno/main/config/install.yaml
   
# Flux HelmRelease Deployment Plan

This repository contains a deployment plan for multiple Helm charts using Flux CD on AKS. The deployment is structured to ensure proper ordering based on dependencies between applications.

## Deployment Architecture

The deployment uses a master Helm chart that includes all individual application charts as dependencies. This approach allows for:

1. Proper ordering of deployments based on dependencies
2. Centralized configuration management
3. Simplified GitOps workflow with Flux CD

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
</deployment_plan>

## Implementation Details

### Master Chart

The master chart (`master-chart/`) contains:
- Dependencies configuration in `Chart.yaml`
- Global and component-specific values in `values.yaml`
- Pre-install and post-install hooks to ensure proper ordering and verify deployment health

### Flux Resources

The Flux resources (`flux-resources/`) include:
- `GitRepository` to track the Git repository containing the charts
- `HelmRelease` to deploy the master chart with proper configuration
- Namespace definition and Kustomization file

### Deployment Hooks

The deployment includes two important hooks:

1. **Pre-install Hook**: Verifies that dependencies are properly configured before installation
2. **Post-install Hook**: Checks for non-running pods after deployment and can automatically fix issues

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
flux get helmreleases master-release -n apps

# Check the status of the pods
kubectl get pods -n apps

# View logs from the post-install check
kubectl logs -n apps job/master-release-post-install-check
</helm_commands>

## Troubleshooting

If pods are not running correctly after deployment:

1. Check the logs of the post-install hook:
   ```
   kubectl logs -n apps job/master-release-post-install-check
   ```

2. Manually inspect problematic pods:
   ```
   kubectl describe pod -n apps <pod-name>
   kubectl logs -n apps <pod-name>
   ```

3. If needed, manually trigger a reconciliation:
   ```
   flux reconcile helmrelease master-release -n apps
   
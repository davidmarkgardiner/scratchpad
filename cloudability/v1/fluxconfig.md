# FluxConfiguration Examples

## Simple Example (Based on Official ASO Pattern)

This shows the minimal FluxConfiguration setup using Azure Service Operator pattern.

## Prerequisites

1. Azure Service Operator (ASO) installed in your cluster
2. A ManagedCluster resource created via ASO
3. kubectl access to your cluster

## Simple Example - Public Repository

```yaml
# simple-flux-config.yaml
apiVersion: kubernetesconfiguration.azure.com/v1api20241101
kind: FluxConfiguration
metadata:
  name: my-simple-flux
  namespace: default
spec:
  gitRepository:
    provider: Generic
    repositoryRef:
      branch: main
    url: https://github.com/your-username/your-k8s-manifests
  kustomizations:
    apps: {}
  namespace: flux-system
  owner:
    group: containerservice.azure.com
    kind: ManagedCluster
    name: your-cluster-name  # Must match your ASO ManagedCluster resource name
  sourceKind: GitRepository
```

Deploy with:
```bash
kubectl apply -f simple-flux-config.yaml
```

## Example with Protected Settings

For private repositories, here's how to add authentication:

### Step 1: Create Secret for Authentication

```yaml
# flux-auth-secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: git-auth
  namespace: flux-system
type: Opaque
stringData:
  username: your-github-username
  password: your-github-token  # Personal Access Token
```

### Step 2: FluxConfiguration with Protected Settings

```yaml
# private-flux-config.yaml
apiVersion: kubernetesconfiguration.azure.com/v1api20241101
kind: FluxConfiguration
metadata:
  name: my-private-flux
  namespace: default
spec:
  gitRepository:
    provider: Generic
    repositoryRef:
      branch: main
    url: https://github.com/your-username/your-private-repo
    httpsUser: your-github-username
    localAuthRef: git-auth  # References the secret above
  kustomizations:
    infrastructure:
      path: "./infrastructure"
    apps:
      path: "./apps"
      dependsOn: ["infrastructure"]
  namespace: flux-system
  owner:
    group: containerservice.azure.com
    kind: ManagedCluster
    name: your-cluster-name
  sourceKind: GitRepository
  configurationProtectedSettings:
    name: git-auth
```

Deploy with:
```bash
kubectl apply -f flux-auth-secret.yaml
kubectl apply -f private-flux-config.yaml
```

## Verification and Troubleshooting

```bash
# Check FluxConfiguration status
kubectl get fluxconfigurations -A

# Describe the configuration
kubectl describe fluxconfiguration my-simple-flux

# Check Flux resources created
kubectl get gitrepositories -n flux-system
kubectl get kustomizations -n flux-system

# Check logs if needed
kubectl logs -n flux-system deployment/source-controller
kubectl logs -n flux-system deployment/kustomize-controller
```

## Key Takeaways from Official Example

1. **ASO Integration**: Uses `group/kind/name` owner reference instead of ARM ID
2. **Minimal Configuration**: Only essential fields, relying on sensible defaults
3. **Simple Kustomizations**: Empty kustomization object `{}` uses defaults
4. **No Authentication**: Perfect for public repositories and testing
5. **Clean Structure**: Much more readable than complex configurations

The official example shows that FluxConfiguration can be very simple when you don't need advanced features like custom sync intervals, authentication, or complex dependency management.
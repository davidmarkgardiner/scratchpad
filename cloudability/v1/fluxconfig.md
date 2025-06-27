# FluxConfiguration with Protected Settings Example

This example shows how to deploy a FluxConfiguration that uses protected settings to authenticate with a private Git repository.

## Prerequisites

1. AKS cluster with Flux extension installed
2. A GitHub repository (can be public for this example)
3. GitHub Personal Access Token (for private repos)
4. kubectl access to your cluster

## Step 1: Install Flux Extension (if not already installed)

```bash
# Install the Flux extension on your AKS cluster
az k8s-extension create \
  --resource-group myResourceGroup \
  --cluster-name myAKSCluster \
  --cluster-type managedClusters \
  --extension-type microsoft.flux \
  --name flux
```

## Step 2: Create Kubernetes Secret with Protected Settings

```yaml
# flux-secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: flux-auth-secret
  namespace: flux-system
type: Opaque
data:
  # Base64 encoded GitHub Personal Access Token
  # Generate with: echo -n "your_github_token" | base64
  httpsPassword: Z2hwX3lvdXJfdG9rZW5faGVyZQ==
stringData:
  # Or use stringData for plain text (kubectl will encode it)
  httpsUser: "your-github-username"
```

## Step 3: Create FluxConfiguration YAML

```yaml
# flux-configuration.yaml
apiVersion: kubernetesconfiguration.azure.com/v1api20241101
kind: FluxConfiguration
metadata:
  name: my-app-config
  namespace: default
spec:
  # Reference to your AKS cluster
  owner:
    armId: /subscriptions/YOUR_SUBSCRIPTION_ID/resourceGroups/YOUR_RG/providers/Microsoft.ContainerService/managedClusters/YOUR_CLUSTER_NAME
  
  # Scope of the configuration
  scope: namespace
  namespace: flux-system
  
  # Source configuration
  sourceKind: GitRepository
  gitRepository:
    url: https://github.com/your-username/your-repo
    repositoryRef:
      branch: main
    syncIntervalInSeconds: 300
    timeoutInSeconds: 180
    httpsUser: your-github-username
    localAuthRef: flux-auth-secret
  
  # Kustomizations to apply
  kustomizations:
    infrastructure:
      path: "./infrastructure"
      syncIntervalInSeconds: 600
      retryIntervalInSeconds: 300
      prune: true
      wait: true
    apps:
      path: "./apps"
      dependsOn: ["infrastructure"]
      syncIntervalInSeconds: 600
      retryIntervalInSeconds: 300
      prune: true
      wait: true
  
  # Protected settings reference
  configurationProtectedSettings:
    name: flux-auth-secret
  
  # Wait for reconciliation
  waitForReconciliation: true
  reconciliationWaitDuration: "PT10M"
```

## Step 4: Create Sample Repository Structure

Create a GitHub repository with this structure:

```
your-repo/
├── infrastructure/
│   ├── kustomization.yaml
│   └── namespace.yaml
└── apps/
    ├── kustomization.yaml
    └── sample-app.yaml
```

### infrastructure/namespace.yaml
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: sample-app
```

### infrastructure/kustomization.yaml
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - namespace.yaml
```

### apps/sample-app.yaml
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  namespace: sample-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.21
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
  namespace: sample-app
spec:
  selector:
    app: nginx
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
```

### apps/kustomization.yaml
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - sample-app.yaml
```

## Step 5: Deploy Everything

```bash
# Apply the secret first
kubectl apply -f flux-secret.yaml

# Apply the FluxConfiguration
kubectl apply -f flux-configuration.yaml
```

## Step 6: Verify Deployment

```bash
# Check FluxConfiguration status
kubectl get fluxconfigurations -A

# Check if the configuration is reconciling
kubectl describe fluxconfiguration my-app-config

# Check the created resources
kubectl get all -n sample-app

# Check Flux resources
kubectl get gitrepositories -n flux-system
kubectl get kustomizations -n flux-system
```

## Troubleshooting

```bash
# Check Flux controller logs
kubectl logs -n flux-system deployment/source-controller
kubectl logs -n flux-system deployment/kustomize-contr
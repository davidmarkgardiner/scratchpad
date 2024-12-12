# Kubernetes Namespace Node Selector Guide

## Setting Node Selectors at Namespace Level

### 1. Using NamespaceNodeSelector (Alpha Feature)
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: your-namespace
  annotations:
    scheduler.alpha.kubernetes.io/node-selector: "worker=true"
```

### 2. Modern Approach Using Pod Node Selector
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: your-namespace
  labels:
    pod-security.kubernetes.io/enforce: baseline
spec:
  nodeSelector:
    worker: "true"
```

## Labeling AKS Nodes

### Using Azure ARM Template
```json
{
    "type": "Microsoft.ContainerService/managedClusters/agentPools",
    "apiVersion": "2023-07-02-preview",
    "name": "[concat(parameters('clusterName'), '/yourpoolname')]",
    "properties": {
        "nodeLabels": {
            "worker": "true"
        }
    }
}
```

### Using Azure CLI
```bash
az aks nodepool update \
  --cluster-name your-cluster-name \
  --name your-nodepool-name \
  --resource-group your-resource-group \
  --labels worker=true
```

## Example Deployment with Node Selector
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: your-deployment
spec:
  template:
    spec:
      nodeSelector:
        worker: "true"
      containers:
      - name: your-container
```

## Important Notes

* The NamespaceNodeSelector is an alpha feature and may not be available in all Kubernetes versions
* All pods created in the namespace will inherit the nodeSelector unless explicitly overridden
* Pod Security Admission (PSA) is the recommended approach for modern Kubernetes clusters
* Node selectors can be enforced using admission controllers or mutating webhooks
* AKS supports both methods of node selection

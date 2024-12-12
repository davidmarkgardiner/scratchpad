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




```

Yes, you can use Node Affinity instead, which is the more modern and flexible approach. Here are two ways to do it:

1. Using Required Node Affinity (hard requirement):
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: your-namespace
spec:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: worker
            operator: In
            values:
            - "true"
```

2. Using Preferred Node Affinity (soft requirement):
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: your-namespace
spec:
  affinity:
    nodeAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 1
        preference:
          matchExpressions:
          - key: worker
            operator: In
            values:
            - "true"
```

However, if you want to enforce node selection at the namespace level, you might want to consider using a `LimitRange` or `ResourceQuota`:

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: node-selector-quota
  namespace: your-namespace
spec:
  hard:
    pods: "0"
  scopeSelector:
    matchExpressions:
    - operator: NotIn
      scopeName: Node
      values: ["worker=true"]
```

You could also use a Mutating Admission Webhook to automatically add node selectors to pods in specific namespaces. Would you like me to provide an example of how to implement that?

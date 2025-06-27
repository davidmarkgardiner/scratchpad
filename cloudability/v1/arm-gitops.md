Here's how to deploy ARM templates to AKS using Flux for GitOps:

## 1. Install Flux on Your AKS Cluster

```bash
# Install Flux CLI
curl -s https://fluxcd.io/install.sh | sudo bash

# Bootstrap Flux to your AKS cluster
flux bootstrap github \
  --owner=your-github-username \
  --repository=your-flux-repo \
  --branch=main \
  --path=./clusters/production \
  --personal
```

## 2. Create Git Repository Structure

```
your-flux-repo/
├── clusters/
│   └── production/
│       ├── flux-system/
│       └── infrastructure/
│           ├── sources/
│           │   └── infrastructure-repo.yaml
│           └── arm-templates/
│               ├── kustomization.yaml
│               └── aks-resources.yaml
└── infrastructure/
    └── arm-templates/
        ├── aks-template.json
        ├── aks-parameters.json
        └── deploy-script.sh
```

## 3. Configure Git Source

Create `clusters/production/infrastructure/sources/infrastructure-repo.yaml`:

```yaml
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: GitRepository
metadata:
  name: infrastructure-repo
  namespace: flux-system
spec:
  interval: 1m
  ref:
    branch: main
  url: https://github.com/your-org/your-flux-repo
```

## 4. Create ARM Template Deployment Job

Create `clusters/production/infrastructure/arm-templates/aks-resources.yaml`:

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: deploy-arm-template
  namespace: flux-system
spec:
  template:
    spec:
      serviceAccountName: arm-deployer
      containers:
      - name: azure-cli
        image: mcr.microsoft.com/azure-cli:latest
        command: ["/bin/bash"]
        args:
          - -c
          - |
            az login --service-principal \
              --username $AZURE_CLIENT_ID \
              --password $AZURE_CLIENT_SECRET \
              --tenant $AZURE_TENANT_ID
            
            az deployment group create \
              --resource-group $RESOURCE_GROUP \
              --template-file /templates/aks-template.json \
              --parameters /templates/aks-parameters.json
        env:
        - name: AZURE_CLIENT_ID
          valueFrom:
            secretKeyRef:
              name: azure-credentials
              key: client-id
        - name: AZURE_CLIENT_SECRET
          valueFrom:
            secretKeyRef:
              name: azure-credentials
              key: client-secret
        - name: AZURE_TENANT_ID
          valueFrom:
            secretKeyRef:
              name: azure-credentials
              key: tenant-id
        - name: RESOURCE_GROUP
          value: "your-aks-rg"
        volumeMounts:
        - name: arm-templates
          mountPath: /templates
      volumes:
      - name: arm-templates
        configMap:
          name: arm-templates
      restartPolicy: OnFailure
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: arm-templates
  namespace: flux-system
data:
  aks-template.json: |
    {
      "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
      "contentVersion": "1.0.0.0",
      "parameters": {
        "clusterName": {
          "type": "string"
        },
        "nodeCount": {
          "type": "int",
          "defaultValue": 3
        }
      },
      "resources": [
        {
          "type": "Microsoft.ContainerService/managedClusters",
          "apiVersion": "2023-05-01",
          "name": "[parameters('clusterName')]",
          "location": "[resourceGroup().location]",
          "properties": {
            "dnsPrefix": "[parameters('clusterName')]",
            "agentPoolProfiles": [
              {
                "name": "nodepool1",
                "count": "[parameters('nodeCount')]",
                "vmSize": "Standard_DS2_v2"
              }
            ]
          }
        }
      ]
    }
  aks-parameters.json: |
    {
      "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
      "contentVersion": "1.0.0.0",
      "parameters": {
        "clusterName": {
          "value": "my-aks-cluster"
        },
        "nodeCount": {
          "value": 3
        }
      }
    }
```

## 5. Create Kustomization for ARM Templates

Create `clusters/production/infrastructure/arm-templates/kustomization.yaml`:

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1beta2
kind: Kustomization
metadata:
  name: arm-templates
  namespace: flux-system
spec:
  interval: 10m
  sourceRef:
    kind: GitRepository
    name: infrastructure-repo
  path: "./clusters/production/infrastructure/arm-templates"
  prune: true
  validation: client
  healthChecks:
  - apiVersion: batch/v1
    kind: Job
    name: deploy-arm-template
    namespace: flux-system
```

## 6. Create Azure Service Principal Secret

```bash
# Create Azure service principal
az ad sp create-for-rbac --name flux-arm-deployer --role Contributor

# Create Kubernetes secret
kubectl create secret generic azure-credentials \
  --namespace flux-system \
  --from-literal=client-id=your-client-id \
  --from-literal=client-secret=your-client-secret \
  --from-literal=tenant-id=your-tenant-id
```

## 7. Create Service Account and RBAC

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: arm-deployer
  namespace: flux-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: arm-deployer
rules:
- apiGroups: [""]
  resources: ["configmaps", "secrets"]
  verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: arm-deployer
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: arm-deployer
subjects:
- kind: ServiceAccount
  name: arm-deployer
  namespace: flux-system
```

## 8. Alternative: Using Flux with External Secrets

For better secret management, you can use External Secrets Operator:

```yaml
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: azure-keyvault
  namespace: flux-system
spec:
  provider:
    azurekv:
      url: "https://your-keyvault.vault.azure.net"
      authType: ServicePrincipal
      serviceAccountKeyRef:
        clientId:
          name: azure-credentials
          key: client-id
        clientSecret:
          name: azure-credentials
          key: client-secret
      tenantId: "your-tenant-id"
```

## How It Works

1. **Git Push**: You push ARM template changes to your Git repository
2. **Flux Detection**: Flux detects changes and syncs the Kustomization
3. **Job Creation**: Kubernetes Job is created with Azure CLI container
4. **ARM Deployment**: Job authenticates with Azure and deploys ARM template
5. **Reconciliation**: Flux continuously monitors and maintains desired state

This approach gives you full GitOps workflow with ARM template deployments triggered by Git commits, complete audit trails, and rollback capabilities.
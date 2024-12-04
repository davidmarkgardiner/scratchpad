# Azure AKS Workload Identity Configuration Guide

This guide demonstrates how to configure a DaemonSet in Azure Kubernetes Service (AKS) using Workload Identity to securely access Azure Blob Storage.

## Prerequisites

- Azure CLI installed
- kubectl configured to your AKS cluster
- Appropriate permissions to create and manage:
  - Azure Managed Identities
  - Role Assignments
  - AKS resources
  - Storage accounts

## Step 1: Create Required Azure Resources

First, create the necessary Azure resources using the Azure CLI:

```bash
# Create Managed Identity
az identity create --name metrics-agent-identity \
  --resource-group <your-resource-group> \
  --location <your-location>

# Get the AKS OIDC issuer URL
OIDC_ISSUER=$(az aks show -n <your-cluster-name> -g <your-resource-group> --query "oidcIssuerProfile.issuerUrl" -o tsv)

# Create federation with AKS cluster
az identity federated-credential create \
  --name metrics-agent-federated-identity \
  --identity-name metrics-agent-identity \
  --resource-group <your-resource-group> \
  --issuer $OIDC_ISSUER \
  --subject system:serviceaccount:metrics-agent:cloudability

# Assign Storage Blob permissions
MANAGED_IDENTITY_ID=$(az identity show --name metrics-agent-identity --resource-group <your-resource-group> --query id -o tsv)

az role assignment create \
  --role "Storage Blob Data Contributor" \
  --assignee-object-id $(az identity show --name metrics-agent-identity --resource-group <your-resource-group> --query principalId -o tsv) \
  --scope /subscriptions/<subscription-id>/resourceGroups/<resource-group>/providers/Microsoft.Storage/storageAccounts/<storage-account-name>
```

## Step 2: Kubernetes Configuration Files

### Service Account Configuration
Create a file named `service-account.yaml`:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: cloudability
  namespace: metrics-agent
  labels:
    azure.workload.identity/use: "true"
  annotations:
    azure.workload.identity/client-id: "${AZURE_CLIENT_ID}"    # Replace with your managed identity client ID
    azure.workload.identity/tenant-id: "${AZURE_TENANT_ID}"    # Replace with your Azure tenant ID
```

### RBAC Configuration
Create a file named `rbac.yaml`:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: cloudability
rules:
  - apiGroups: ["*"]
    resources: ["*"]
    verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: cloudability
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cloudability
subjects:
  - kind: ServiceAccount
    name: cloudability
    namespace: metrics-agent
```

### DaemonSet Configuration
Create a file named `daemonset.yaml`:

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: metrics-agent
  namespace: metrics-agent
  labels:
    app: metrics-agent
spec:
  selector:
    matchLabels:
      app: metrics-agent
  template:
    metadata:
      labels:
        app: metrics-agent
        azure.workload.identity/use: "true"
    spec:
      serviceAccountName: cloudability
      containers:
      - name: metrics-agent
        image: cloudability/metrics-agent:latest
        imagePullPolicy: Always
        env:
        - name: CLOUDABILITY_API_KEY
          valueFrom:
            secretKeyRef:
              name: cloudability-api-key
              key: api-key
        - name: CLOUDABILITY_CLUSTER_NAME
          value: "${CLUSTER_NAME}"
        - name: AZURE_CLIENT_ID
          value: "${AZURE_CLIENT_ID}"
        - name: STORAGE_ACCOUNT_NAME
          value: "${STORAGE_ACCOUNT_NAME}"
        - name: CONTAINER_NAME
          value: "${CONTAINER_NAME}"
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi
        volumeMounts:
        - name: proc
          mountPath: /host/proc
          readOnly: true
        - name: sys
          mountPath: /host/sys
          readOnly: true
      volumes:
      - name: proc
        hostPath:
          path: /proc
      - name: sys
        hostPath:
          path: /sys
```

## Step 3: Deployment

1. Replace the following variables in all YAML files:
   - ${AZURE_CLIENT_ID}: Your managed identity client ID
   - ${AZURE_TENANT_ID}: Your Azure tenant ID
   - ${CLUSTER_NAME}: Your AKS cluster name
   - ${STORAGE_ACCOUNT_NAME}: Your storage account name
   - ${CONTAINER_NAME}: Your blob container name

2. Create the namespace:
```bash
kubectl create namespace metrics-agent
```

3. Apply the configurations:
```bash
kubectl apply -f service-account.yaml
kubectl apply -f rbac.yaml
kubectl apply -f daemonset.yaml
```

## Verification

1. Check if the pods are running:
```bash
kubectl get pods -n metrics-agent
```

2. Check pod logs:
```bash
kubectl logs -n metrics-agent <pod-name>
```

3. Verify workload identity setup:
```bash
kubectl describe serviceaccount cloudability -n metrics-agent
```

## Troubleshooting

1. If pods are not starting, check the events:
```bash
kubectl get events -n metrics-agent
```

2. Verify the managed identity assignment:
```bash
az identity show --name metrics-agent-identity --resource-group <your-resource-group>
```

3. Check federation setup:
```bash
az identity federated-credential list --identity-name metrics-agent-identity --resource-group <your-resource-group>
```

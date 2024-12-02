# Setting up Azure DevOps Agent on Kubernetes

This guide walks through the process of deploying self-hosted Azure DevOps agents on a Kubernetes cluster using Service Principal authentication.

## Prerequisites

- An Azure Kubernetes Service (AKS) cluster or any Kubernetes cluster
- Azure DevOps organization
- Azure subscription
- kubectl configured to access your cluster
- Helm 3.x installed

## Step 1: Create Service Principal

Create a Service Principal in Azure AD for agent authentication:

```bash
az ad sp create-for-rbac --name "azure-devops-agent-sp" --role contributor \
    --scopes /subscriptions/{subscription-id}
```

Save the output containing:
- appId (client_id)
- password (client_secret)
- tenant

## Step 2: Create Azure DevOps Personal Access Token (PAT)

1. Go to Azure DevOps Organization Settings
2. User Settings → Personal Access Tokens
3. Create new token with following permissions:
   - Agent Pools: Read & manage
   - Deployment Groups: Read & manage

## Step 3: Create Kubernetes Secret

Create a secret containing the Azure DevOps PAT and Service Principal credentials:

```bash
kubectl create namespace azure-devops-agents

kubectl create secret generic azdevops-agent-secret \
  --namespace azure-devops-agents \
  --from-literal=AZP_TOKEN=<your-pat-token> \
  --from-literal=AZP_URL=https://dev.azure.com/<your-organization> \
  --from-literal=AZURE_CLIENT_ID=<service-principal-client-id> \
  --from-literal=AZURE_CLIENT_SECRET=<service-principal-client-secret> \
  --from-literal=AZURE_TENANT_ID=<azure-tenant-id>
```

## Step 4: Create Agent Deployment Configuration

Create a file named `azure-pipelines-agent-deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: azure-pipelines-agent
  namespace: azure-devops-agents
spec:
  replicas: 2  # Adjust based on your needs
  selector:
    matchLabels:
      app: azure-pipelines-agent
  template:
    metadata:
      labels:
        app: azure-pipelines-agent
    spec:
      containers:
      - name: azure-pipelines-agent
        image: mcr.microsoft.com/azure-pipelines/vsts-agent:ubuntu-20.04
        env:
        - name: AZP_TOKEN
          valueFrom:
            secretKeyRef:
              name: azdevops-agent-secret
              key: AZP_TOKEN
        - name: AZP_URL
          valueFrom:
            secretKeyRef:
              name: azdevops-agent-secret
              key: AZP_URL
        - name: AZURE_CLIENT_ID
          valueFrom:
            secretKeyRef:
              name: azdevops-agent-secret
              key: AZURE_CLIENT_ID
        - name: AZURE_CLIENT_SECRET
          valueFrom:
            secretKeyRef:
              name: azdevops-agent-secret
              key: AZURE_CLIENT_SECRET
        - name: AZURE_TENANT_ID
          valueFrom:
            secretKeyRef:
              name: azdevops-agent-secret
              key: AZURE_TENANT_ID
        volumeMounts:
        - name: docker-socket
          mountPath: /var/run/docker.sock
        resources:
          requests:
            cpu: "1"
            memory: "2Gi"
          limits:
            cpu: "2"
            memory: "4Gi"
      volumes:
      - name: docker-socket
        hostPath:
          path: /var/run/docker.sock
```

## Step 5: Deploy the Agents

Apply the deployment configuration:

```bash
kubectl apply -f azure-pipelines-agent-deployment.yaml
```

## Step 6: Verify Agent Registration

1. Go to Azure DevOps Organization Settings
2. Agent Pools → Default
3. Verify that the new agents appear in the pool

## Monitoring and Maintenance

### Check Agent Status
```bash
kubectl get pods -n azure-devops-agents
kubectl logs -f <pod-name> -n azure-devops-agents
```

### Scale Agents
To adjust the number of agents:
```bash
kubectl scale deployment azure-pipelines-agent -n azure-devops-agents --replicas=<number>
```

## Troubleshooting

Common issues and solutions:

1. Agent Connection Issues
   - Verify PAT token hasn't expired
   - Check network connectivity from cluster to Azure DevOps
   - Verify service principal credentials

2. Pod Startup Issues
   - Check pod events: `kubectl describe pod <pod-name> -n azure-devops-agents`
   - Verify secret values are correct
   - Check resource constraints

## Security Considerations

1. Regularly rotate:
   - Service Principal credentials
   - Azure DevOps PAT
   - Kubernetes secrets

2. Use network policies to restrict pod communication
3. Implement RBAC for agent pods
4. Consider using Azure Key Vault for secret management

## Clean Up

To remove the deployment:

```bash
kubectl delete deployment azure-pipelines-agent -n azure-devops-agents
kubectl delete secret azdevops-agent-secret -n azure-devops-agents
kubectl delete namespace azure-devops-agents
```
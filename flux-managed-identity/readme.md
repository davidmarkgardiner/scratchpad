Here's an example ARM template for deploying Flux GitOps with Azure DevOps repository using managed identity:Here's also a complete example with parameter file and additional resources for a full setup:## Parameter File Example

Create a `parameters.json` file:

```json
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "resourceGroupName": {
      "value": "my-aks-rg"
    },
    "clusterName": {
      "value": "my-aks-cluster"
    },
    "fluxConfigurationName": {
      "value": "gitops-config"
    },
    "gitRepositoryUrl": {
      "value": "https://dev.azure.com/myorg/myproject/_git/k8s-manifests"
    },
    "gitBranch": {
      "value": "main"
    },
    "managedIdentityName": {
      "value": "flux-identity"
    },
    "namespace": {
      "value": "flux-system"
    },
    "kustomizationPath": {
      "value": "./clusters/production"
    }
  }
}
```

## Deployment Commands

```bash
# Deploy the template
az deployment group create \
  --resource-group my-aks-rg \
  --template-file flux-configuration.json \
  --parameters @parameters.json

# Or deploy to cluster scope
az deployment group create \
  --resource-group my-aks-rg \
  --template-file flux-configuration.json \
  --parameters @parameters.json \
  --mode Incremental
```

## Additional Setup Required

After deploying the ARM template, you'll still need to:

1. **Create the authentication secret** in your AKS cluster:
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: ado-pat-secret
  namespace: flux-system
type: Opaque
data:
  username: <base64-encoded-managed-identity-client-id>
  password: <base64-encoded-ado-pat-token>
```

2. **Configure workload identity** (if using workload identity federation):
```bash
# Create federated identity credential
az identity federated-credential create \
  --name flux-federated-credential \
  --identity-name flux-identity \
  --resource-group my-aks-rg \
  --issuer $(az aks show --name my-aks-cluster --resource-group my-aks-rg --query "oidcIssuerProfile.issuerUrl" -o tsv) \
  --subject system:serviceaccount:flux-system:flux-controller
```

This ARM template creates a managed identity and configures Flux to use it for Azure DevOps authentication, providing a more secure alternative to username/password authentication.
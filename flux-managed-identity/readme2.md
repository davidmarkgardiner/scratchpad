Looking at the document you provided, there's a much cleaner solution using the new **fluxConfigurations API version 2024-11-01** with the `provider: 'azure'` property. This eliminates the need for PAT tokens entirely!

Let me update the ARM template to use this new approach:## Key Updates Based on the Document:

### 1. **No More PAT Tokens Required!**
- Uses `"provider": "azure"` in the GitRepository configuration
- Leverages Workload Identity for authentication
- No need for secrets or credential rotation

### 2. **Updated API Version**
- Uses `fluxConfigurations@2024-11-01` (the latest version mentioned in the document)
- Includes the new `provider` property

### 3. **Proper Workload Identity Setup**
- Creates federated identity credential for `system:serviceaccount:flux-system:source-controller`
- Configures Flux extension with workload identity settings
- Uses the correct OIDC issuer URL from AKS

### 4. **Addresses Your Credential Expiration Issue**
Since this solution doesn't use PAT tokens at all, you won't face credential expiration issues anymore!

## Updated Parameter File:

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
    "fluxIdentityName": {
      "value": "flux-source-controller-identity"
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

## Manual Steps After Deployment:

**1. Add Managed Identity to Azure DevOps:**
```bash
# Get the identity details
IDENTITY_CLIENT_ID=$(az deployment group show --resource-group my-aks-rg --name flux-deployment --query 'properties.outputs.fluxIdentityClientId.value' -o tsv)
IDENTITY_PRINCIPAL_ID=$(az deployment group show --resource-group my-aks-rg --name flux-deployment --query 'properties.outputs.fluxIdentityPrincipalId.value' -o tsv)

echo "Add this identity to Azure DevOps:"
echo "Client ID: $IDENTITY_CLIENT_ID"
echo "Principal ID: $IDENTITY_PRINCIPAL_ID"
```

**2. In Azure DevOps:**
- Go to Organization Settings → Users
- Add the managed identity as a user
- Assign **Basic** license (not Stakeholder)
- Grant **Reader** permissions on the project/repository

**3. Verify Setup:**
```bash
# Check the source controller service account
kubectl describe sa source-controller -n flux-system

# Should show workload identity annotations:
# azure.workload.identity/client-id: <client-id>
# azure.workload.identity/use: "true"

# Check GitRepository status
kubectl get gitrepository -n flux-system
kubectl describe gitrepository <your-repo-name> -n flux-system
```

## Benefits of This Approach:

✅ **No credential expiration issues** - uses Azure AD authentication  
✅ **No secrets to manage** - everything handled by Azure Workload Identity  
✅ **Better security** - short-lived tokens, no long-lived credentials  
✅ **Automatic token refresh** - handled by Azure  
✅ **Audit trail** - all access logged in Azure AD  

This should completely resolve your authentication issues since there are no credentials to expire!
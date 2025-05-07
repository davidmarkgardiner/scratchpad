# Azure Workload Identity Deployment Architecture

## Architecture Diagram

```
┌─────────────────────────────────────────────┐
│                                             │
│             Azure DevOps Pipeline           │
│                                             │
└───────────────────────┬─────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────┐
│                                             │
│         Azure Resource Manager API          │
│                                             │
└───┬───────────────────┬───────────────┬─────┘
    │                   │               │
    ▼                   ▼               ▼
┌─────────┐      ┌────────────┐   ┌──────────┐
│         │      │            │   │          │
│  AKS 1  │      │   AKS 2    │   │  AKS N   │
│         │      │            │   │          │
└────┬────┘      └─────┬──────┘   └────┬─────┘
     │                 │                │
     ▼                 ▼                ▼
┌─────────┐      ┌────────────┐   ┌──────────┐
│Identity1│      │ Identity2  │   │IdentityN │
└────┬────┘      └─────┬──────┘   └────┬─────┘
     │                 │                │
     │                 ▼                │
     │          ┌────────────┐         │
     └─────────►│            │◄────────┘
                │ Key Vault  │
                │            │
                └────────────┘
```

## Architecture Components

1. **Azure DevOps Pipeline**
   - Triggers on commits to main branch
   - Uses the variable group containing deployment configuration
   - Orchestrates the entire deployment process

2. **Azure Resource Manager (ARM) API**
   - Interface used by the pipeline to manage Azure resources
   - Requires proper service principal permissions

3. **AKS Clusters (1...N)**
   - Target Kubernetes clusters where applications will be deployed
   - Must have OIDC issuer enabled to support workload identity

4. **User-Assigned Managed Identities**
   - One identity created per AKS cluster
   - Configured with federated credentials to trust the Kubernetes service account

5. **Azure Key Vault**
   - Central secret store containing application credentials
   - Access granted to each managed identity with appropriate permissions

## Authentication Flow

1. The pipeline executes, deploying the application to Kubernetes using a service account
2. The service account is annotated with the managed identity's client ID
3. When the application accesses Key Vault:
   - It obtains a token from the OIDC provider in the AKS cluster
   - This token is exchanged for an Azure AD token via the federated identity
   - The Azure AD token is used to authenticate to Key Vault

## Security Considerations

- Cluster-specific managed identities ensure isolation between environments
- Federated credentials eliminate the need to manage secrets for service principal authentication
- Key Vault access is scoped to only the secrets needed by each application
- Managed identity access can be revoked centrally if needed

## Deployment Workflow

1. For each cluster in the list:
   - Enable workload identity if not already enabled
   - Create or reuse a managed identity
   - Set up federated credential mapping
   - Configure Key Vault access for the identity
   - Deploy the Helm chart with identity configuration
   - Verify deployment success 
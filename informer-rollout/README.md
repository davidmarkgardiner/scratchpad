# AKS Multi-Cluster Helm Deployment Pipeline

This Azure DevOps pipeline deploys a Helm chart to multiple AKS clusters with workload identity setup for Azure Key Vault access.

## Prerequisites

- Azure DevOps project with Azure Resource Manager service connection
- AKS clusters with OIDC issuer enabled
- Azure Key Vault containing the required secrets
- Helm chart compatible with Azure Workload Identity

## Setup Instructions

1. Create a service connection in Azure DevOps:
   - Name: `AzureServiceConnection`
   - Type: Azure Resource Manager
   - Grant access to all pipelines
   - **Required Permissions** for the service principal:
     - **Recommended approach**: Assign the **Contributor** role on resource groups containing AKS clusters and Key Vault
     - **Granular approach** (if needed):
       - **AKS Admin** role on AKS clusters
       - **Managed Identity Operator** role on resource groups for identity management
       - **Key Vault Administrator** (or at least **Key Vault Access Policy Administrator**) on the Key Vault
       - Individual permissions needed:
         - AKS: read, write, listClusterAdminCredential/action
         - Managed Identities: create, read, update
         - Federated Credentials: create, read, update
         - Key Vault: read, accessPolicies/write

2. Create a variable group in Azure DevOps Library:
   - Name: `AKSDeploymentVariables`
   - Variables:
     - `HELM_CHART_URL`: URL to the Helm chart repository
     - `KEYVAULT_NAME`: Name of your Azure Key Vault
     - `KEYVAULT_SECRET_NAME`: Name of the secret in Key Vault to be accessed
     - `AKS_CLUSTER_LIST`: Comma-separated list of AKS cluster names

3. Import the `azure-pipelines.yml` file into your Azure DevOps project

## How It Works

The pipeline:

1. Iterates through each AKS cluster in the provided list
2. Ensures workload identity is enabled on each cluster
3. Creates a user-assigned managed identity for each cluster
4. Sets up federated identity credentials for Kubernetes service accounts
5. Grants the managed identity permission to access Key Vault secrets
6. Deploys the Helm chart with the necessary identity configuration
7. Verifies that the deployment was successful
8. Generates a deployment report

## Helm Chart Requirements

Your Helm chart should be configured to use Azure workload identity. The pipeline sets the following values:

- `azure.workload.identity.clientId`: The client ID of the managed identity
- `azure.keyvault.name`: Name of the Key Vault
- `azure.keyvault.secretName`: Name of the secret to access
- `serviceAccount.name`: Set to "workload-identity-sa"
- `serviceAccount.create`: Set to false (the pipeline creates it)

## Troubleshooting

If the deployment fails:

1. Check the deployment logs in the published artifacts
2. Verify that the AKS clusters exist and are in the expected resource groups
3. Ensure the service principal has sufficient permissions:
   - Check Azure role assignments in the Azure portal
   - Verify Key Vault access policies include the service principal
   - Ensure the service principal has the necessary credentials management permissions
4. Confirm that the Helm chart URL is accessible and the chart supports workload identity 
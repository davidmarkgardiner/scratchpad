#!/bin/bash

# One-time setup script for shared managed identities per environment
# Run this once to create shared identities that all clusters in each environment will use

set -e

# Configuration
SUBSCRIPTION_ID="your-subscription-id"
SHARED_IDENTITY_RG="shared-identities-rg"
LOCATION="eastus"
ENVIRONMENTS=("dev" "test" "staging" "prod")
ADO_ORGANIZATION="your-ado-org"
ADO_PROJECT="your-ado-project"

echo "🚀 Setting up shared managed identities for GitOps..."

# Set subscription
az account set --subscription $SUBSCRIPTION_ID

# Create resource group for shared identities if it doesn't exist
echo "📁 Creating resource group for shared identities..."
az group create --name $SHARED_IDENTITY_RG --location $LOCATION

# Create managed identities for each environment
declare -A IDENTITY_CLIENT_IDS
declare -A IDENTITY_PRINCIPAL_IDS

for ENV in "${ENVIRONMENTS[@]}"; do
    IDENTITY_NAME="flux-gitops-${ENV}-shared"
    
    echo "🔐 Creating managed identity for environment: $ENV"
    
    # Create managed identity
    az identity create \
        --name $IDENTITY_NAME \
        --resource-group $SHARED_IDENTITY_RG \
        --location $LOCATION \
        --tags environment=$ENV purpose=flux-gitops shared=true
    
    # Get client ID and principal ID
    CLIENT_ID=$(az identity show --name $IDENTITY_NAME --resource-group $SHARED_IDENTITY_RG --query clientId -o tsv)
    PRINCIPAL_ID=$(az identity show --name $IDENTITY_NAME --resource-group $SHARED_IDENTITY_RG --query principalId -o tsv)
    
    IDENTITY_CLIENT_IDS[$ENV]=$CLIENT_ID
    IDENTITY_PRINCIPAL_IDS[$ENV]=$PRINCIPAL_ID
    
    echo "✅ Created identity for $ENV:"
    echo "   Name: $IDENTITY_NAME"
    echo "   Client ID: $CLIENT_ID"
    echo "   Principal ID: $PRINCIPAL_ID"
done

echo ""
echo "🔧 Setting up Azure DevOps permissions..."

# Add identities to Azure DevOps (requires Azure DevOps CLI extension)
# Install if not present: az extension add --name azure-devops

for ENV in "${ENVIRONMENTS[@]}"; do
    echo "👤 Adding $ENV identity to Azure DevOps..."
    
    # Note: You may need to do this step manually in ADO UI
    # The CLI approach depends on your ADO setup and permissions
    
    echo "Manual step required:"
    echo "1. Go to https://dev.azure.com/$ADO_ORGANIZATION/_settings/users"
    echo "2. Add user with Principal ID: ${IDENTITY_PRINCIPAL_IDS[$ENV]}"
    echo "3. Assign Basic license (not Stakeholder)"
    echo "4. Grant Reader permissions on project: $ADO_PROJECT"
    echo ""
done

echo "📝 Generating ARM template parameters for each environment..."

# Create parameter files for each environment
for ENV in "${ENVIRONMENTS[@]}"; do
    IDENTITY_NAME="flux-gitops-${ENV}-shared"
    IDENTITY_RESOURCE_ID="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$SHARED_IDENTITY_RG/providers/Microsoft.ManagedIdentity/userAssignedIdentities/$IDENTITY_NAME"
    
    cat > "flux-${ENV}-parameters.json" << EOF
{
  "\$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "environment": {
      "value": "$ENV"
    },
    "sharedManagedIdentityResourceId": {
      "value": "$IDENTITY_RESOURCE_ID"
    },
    "gitRepositoryUrl": {
      "value": "https://dev.azure.com/$ADO_ORGANIZATION/$ADO_PROJECT/_git/k8s-manifests"
    },
    "gitBranch": {
      "value": "$ENV"
    },
    "syncIntervalSeconds": {
      "value": $([ "$ENV" = "prod" ] && echo "600" || echo "300")
    }
  }
}
EOF

    echo "✅ Created parameter file: flux-${ENV}-parameters.json"
done

echo ""
echo "🎯 Summary - Resource IDs to use in ARM deployments:"
echo "=================================================================="

for ENV in "${ENVIRONMENTS[@]}"; do
    IDENTITY_NAME="flux-gitops-${ENV}-shared"
    IDENTITY_RESOURCE_ID="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$SHARED_IDENTITY_RG/providers/Microsoft.ManagedIdentity/userAssignedIdentities/$IDENTITY_NAME"
    
    echo "Environment: $ENV"
    echo "  Resource ID: $IDENTITY_RESOURCE_ID"
    echo "  Client ID: ${IDENTITY_CLIENT_IDS[$ENV]}"
    echo ""
done

echo "📋 Next Steps:"
echo "1. Complete Azure DevOps user additions manually (see above)"
echo "2. Deploy to clusters using: az deployment group create --template-file flux-template.json --parameters @flux-ENV-parameters.json"
echo "3. Each cluster deployment will create its own federated credential automatically"

echo ""
echo "🔄 To deploy to a cluster:"
cat << 'EOF'
# Example deployment command:
az deployment group create \
  --resource-group your-cluster-rg \
  --template-file flux-shared-mi-template.json \
  --parameters @flux-prod-parameters.json \
  --parameters clusterName=your-cluster-name
EOF
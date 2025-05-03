# Kubernetes Image Copier

A script to copy container images from Docker Hub to a private Azure Container Registry (ACR).

## Description

This script scans a Kubernetes cluster for all images coming from a specific source registry (Docker Hub by default) and copies them to a private Azure Container Registry. It helps with:

- Mitigating Docker Hub rate limits
- Ensuring image availability during external registry outages
- Creating a private mirror of your public dependencies
- Setting up air-gapped environments

## Prerequisites

- `kubectl` - Connected to your cluster
- `oras` - For OCI registry operations ([Installation Guide](https://oras.land/docs/installation))
- `az` - Azure CLI (if using Azure authentication methods)
- Access to an Azure Container Registry

## Setup

1. Create an Azure Container Registry if you don't have one:

```bash
# Create a resource group if needed
az group create --name myResourceGroup --location eastus

# Create the ACR
az acr create --resource-group myResourceGroup --name mytestacrregistry --sku Basic
```

2. Set up a service principal with AcrPush permissions:

```bash
# Create service principal with AcrPush role
SP_PASSWORD=$(az ad sp create-for-rbac --name "acr-service-principal" \
  --scopes $(az acr show --name mytestacrregistry --query id --output tsv) \
  --role AcrPush --query "password" --output tsv)

SP_APP_ID=$(az ad sp list --display-name "acr-service-principal" --query "[].appId" --output tsv)
TENANT_ID=$(az account show --query tenantId --output tsv)

# Save these values for later use
echo "Service Principal ID: $SP_APP_ID"
echo "Service Principal Password: $SP_PASSWORD"
echo "Tenant ID: $TENANT_ID"
```

3. Edit the script to set your ACR:

```bash
# Replace with your actual ACR name
DESTINATION_REGISTRY="mytestacrregistry.azurecr.io"
```

## Usage

The script supports multiple authentication methods:

### Method 1: Service Principal

```bash
export SP_CLIENT_ID=<your-sp-app-id>
export SP_CLIENT_SECRET=<your-sp-password>
export ACR_TENANT_ID=<your-tenant-id>
./production-script.sh
```

### Method 2: Managed Identity (when running in Azure)

```bash
export USE_MANAGED_IDENTITY=true
./production-script.sh
```

### Method 3: Username/Password

```bash
export ACR_USERNAME=<username>
export ACR_PASSWORD=<password>
./production-script.sh
```

### Method 4: Token File

Place the token in a file at `/token/acr-token` and run:

```bash
./production-script.sh
```

## How It Works

1. The script scans your Kubernetes cluster for all container images
2. It filters for images from the source registry (Docker Hub by default)
3. For each image found:
   - It checks if the image already exists in your ACR
   - If not, it copies the image to your ACR
   - If it exists but the manifest differs, it updates the image

## Customization

- Change the source registry by modifying the `SOURCE_REGISTRY` variable
- Adjust logging by modifying the `log()` function
- Add additional resources to scan by modifying the image collection sections 
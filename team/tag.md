I'll show you how to add and remove tags on an Azure Kubernetes Service (AKS) cluster using the Azure CLI.

## Adding a Tag to an AKS Cluster

```bash
# Add a tag to an AKS cluster
az aks update \
  --resource-group <RESOURCE_GROUP_NAME> \
  --name <CLUSTER_NAME> \
  --tags "Status=InUse" "Owner=YourName" "Team=Engineering"
```

## Removing a Tag from an AKS Cluster

```bash
# Remove a specific tag (e.g., Status)
az aks update \
  --resource-group <RESOURCE_GROUP_NAME> \
  --name <CLUSTER_NAME> \
  --remove-tags "Status"

# Alternatively, to remove all tags
az aks update \
  --resource-group <RESOURCE_GROUP_NAME> \
  --name <CLUSTER_NAME> \
  --tags ""
```

Replace `<RESOURCE_GROUP_NAME>` and `<CLUSTER_NAME>` with your actual resource group and AKS cluster names. You can add multiple tags in a single command as shown in the first example.

Would you like me to explain any part of these commands?
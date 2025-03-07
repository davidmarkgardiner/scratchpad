az deployment group create \
  --resource-group YOUR_RESOURCE_GROUP \
  --template-file rules-arm.json \
  --parameters \
    workspaceResourceId="/subscriptions/YOUR_SUBSCRIPTION_ID/resourceGroups/YOUR_RESOURCE_GROUP/providers/microsoft.monitor/accounts/YOUR_AZURE_MONITOR_WORKSPACE" \
    clusterResourceId="/subscriptions/YOUR_SUBSCRIPTION_ID/resourceGroups/YOUR_RESOURCE_GROUP/providers/microsoft.containerservice/managedClusters/YOUR_AKS_CLUSTER" \
    clusterName="YOUR_AKS_CLUSTER_NAME" \
    actionGroupResourceId="/subscriptions/YOUR_SUBSCRIPTION_ID/resourceGroups/YOUR_RESOURCE_GROUP/providers/microsoft.insights/actionGroups/YOUR_ACTION_GROUP"
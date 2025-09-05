I'll modify the script to handle clusters in different resource groups within the same subscription. The script will now discover clusters across all resource groups.I've updated the script to handle clusters in different resource groups within the same subscription. Here are the key changes:

## Key Updates:

### 1. **Removed single RESOURCE_GROUP variable**
   - The script now discovers clusters across ALL resource groups in the subscription

### 2. **Added cluster discovery and caching**
   - `list_all_matching_clusters()` - Lists all clusters with your prefix across the entire subscription
   - `build_cluster_cache()` - Caches cluster names with their resource groups for efficient lookup
   - `get_cluster_resource_group()` - Retrieves a cluster's resource group from cache or API

### 3. **Enhanced status checking**
   - `check_cluster_status()` now accepts an optional resource group parameter
   - If not provided, it automatically discovers the cluster's resource group

### 4. **Improved output formatting**
   - Shows clusters grouped by resource group
   - Shows UAMIs grouped by resource group
   - Displays resource group information in all log messages

## How to use:

### 1. **Update configuration** (only need cluster prefix and optionally subscription):
```bash
CLUSTER_NAME_PREFIX="aks-cluster-"  # Your actual prefix
SUBSCRIPTION_ID="your-subscription-id"  # Optional
DRY_RUN=true
```

### 2. **Test the multi-resource group functionality**:
```bash
# This will show all clusters across all resource groups
./script.sh test-clusters
```

Example output:
```
Clusters by resource group:
  Resource Group: rg-eastus
    - aks-cluster-01: Running
    - aks-cluster-02: Stopped
  Resource Group: rg-westus
    - aks-cluster-03: Running
    - aks-cluster-04: Stopped
```

### 3. **Run the analysis** to see what would be deleted:
```bash
./script.sh analyze
```

The script will now:
- Find all clusters with your prefix across ALL resource groups
- Build a cache of cluster-to-resource-group mappings
- Check federation credentials and match them to clusters regardless of resource group
- Show you exactly which federations would be deleted, including the resource group information

This approach is more efficient as it builds a cache once and reuses it throughout the script execution, minimizing API calls while handling clusters spread across multiple resource groups.
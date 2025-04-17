I'll create a Bash script that checks if a lock is on an AKS cluster and provides advice about removing it if found:

```bash
#!/bin/bash

# Script to check if an Azure AKS cluster has a resource lock
# and provide guidance on removing it

# Colors for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;36m'
NC='\033[0m' # No Color

# Check if required parameters are provided
if [ "$#" -lt 2 ]; then
    echo -e "${RED}Error: Missing required parameters.${NC}"
    echo "Usage: $0 <resource-group-name> <aks-cluster-name>"
    exit 1
fi

RESOURCE_GROUP=$1
AKS_CLUSTER_NAME=$2

echo -e "${BLUE}Checking for resource locks on AKS cluster '${AKS_CLUSTER_NAME}' in resource group '${RESOURCE_GROUP}'...${NC}"

# Check if the user is logged in to Azure
az account show &>/dev/null
if [ $? -ne 0 ]; then
    echo -e "${YELLOW}You are not logged in to Azure. Please run 'az login' first.${NC}"
    exit 1
fi

# Get all locks on the AKS resource
LOCKS=$(az lock list --resource-group $RESOURCE_GROUP --resource-name $AKS_CLUSTER_NAME --resource-type "Microsoft.ContainerService/managedClusters" -o json)

# Check if any locks were found
LOCK_COUNT=$(echo $LOCKS | jq '. | length')

if [ "$LOCK_COUNT" == "0" ]; then
    echo -e "${GREEN}No resource locks found on AKS cluster '${AKS_CLUSTER_NAME}'.${NC}"
    echo -e "${GREEN}You should be able to delete the cluster without removing any locks.${NC}"
else
    echo -e "${RED}Found ${LOCK_COUNT} resource lock(s) on AKS cluster '${AKS_CLUSTER_NAME}'.${NC}"
    echo -e "${YELLOW}Unable to delete the cluster while locks are in place.${NC}"
    
    # Process each lock and provide removal instructions
    echo $LOCKS | jq -c '.[]' | while read -r lock; do
        LOCK_NAME=$(echo $lock | jq -r '.name')
        LOCK_LEVEL=$(echo $lock | jq -r '.properties.level')
        LOCK_ID=$(echo $lock | jq -r '.id')
        
        echo -e "${BLUE}Lock details:${NC}"
        echo -e "  Name: ${LOCK_NAME}"
        echo -e "  Level: ${LOCK_LEVEL}"
        echo -e "  ID: ${LOCK_ID}"
        echo
        echo -e "${YELLOW}To remove this lock, run the following command:${NC}"
        echo -e "  az lock delete --ids \"${LOCK_ID}\""
        echo
        # Alternative command using lock name and resource group
        echo -e "${YELLOW}Or alternatively:${NC}"
        echo -e "  az lock delete --name \"${LOCK_NAME}\" --resource-group \"${RESOURCE_GROUP}\""
        echo
    done
    
    echo -e "${BLUE}After removing all locks, you should be able to delete the AKS cluster.${NC}"
fi
```

To use this script:

1. Save it to a file, for example `check_aks_locks.sh`
2. Make it executable: `chmod +x check_aks_locks.sh`
3. Run it with your resource group and AKS cluster name:
   ```
   ./check_aks_locks.sh YourResourceGroup YourAKSClusterName
   ```

The script will:
- Check if you're logged into Azure
- Look for any locks on your AKS cluster
- If no locks are found, it will confirm that you can delete the cluster
- If locks are found, it will provide detailed information about each lock and the exact commands to remove them

Note: This script requires the `jq` command-line JSON processor. If you don't have it installed, you can install it with `apt-get install jq` on Ubuntu/Debian or `brew install jq` on macOS.
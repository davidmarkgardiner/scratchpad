# check for number clusters per RG

# only 1 cluster per RG

 

az account set --subscription $SUBSCRIPTION --output none

 

# Check for required parameters

if [[ -z "$resourceGroupName" ]] || [[ -z "$location" ]]; then

    echo "[ERROR] Missing required parameters"

    exit 1

fi

 

EXISTING_RG=$(az group exists --name ${resourceGroupName})

 

if [[ ${EXISTING_RG} == true ]]; then

 

    echo "[INFO] RG $resourceGroupName found in the subscription. Proceeding to check number of clusters in the RG "

 

    CLUSTER_COUNT=$(az aks list --resource-group ${resourceGroupName} --query "length(@)" --output tsv)

    EXISTING_CLUSTER_NAME=$(az aks list --resource-group ${resourceGroupName} --query "[].name" --output tsv)

 

    if [ -f "env/$ENV-$CLUSTER_SUFFIX.yml" ]; then

        VAR_FILE=env/$(ls env | grep -i -E "^$ENV.*$CLUSTER_SUFFIX\.yml$")

        echo "[INFO] Using old naming convention for the cluster"

        echo "[INFO] Validating old Clustername"

 

        OP_ENV=$(az group show --name ${resourceGroupName} --query "tags.opEnvironment" -o tsv | tr '[:upper:]' '[:lower:]' | cut -c-1)

        SUB_ID=$(az account show --query "id" -otsv | cut -c1-4)

        AT_NUM=$(az group show --name ${resourceGroupName} --query "tags.cmdbReference" -o tsv  | grep -o '[0-9]\{5\}')

        if [ "$CI" == "true" ]; then

        SUFFIX=$(/root/.local/bin/yq -r '.[].variables.common_oldClusterNameSuffix' $VAR_FILE)

        echo $SUFFIX is from gitlab

        else

        SUFFIX=$(/root/.local/bin/yq -r '.[].common_oldClusterNameSuffix' $VAR_FILE)

        echo $SUFFIX is from ADO

        fi

 

        NEW_CLUSTER_NAME="k${OP_ENV}${SUB_ID}${AT_NUM}${SUFFIX}"

    else

        NEW_CLUSTER_NAME=$(grep "^config_newClusterName=" .env | cut -d'=' -f2)

    fi

 

    # Validate NEW_CLUSTER_NAME against EXISTING_CLUSTER_NAME

    if [ "$NEW_CLUSTER_NAME" == "$EXISTING_CLUSTER_NAME" ]; then

        SAME_CLUSTER=true

    else

        SAME_CLUSTER=false

    fi

 

    if [ "$CLUSTER_COUNT" -lt 1 ] || [ "$SAME_CLUSTER" == "true" ]; then

        echo "[INFO] Number of clusters in the RG ${resourceGroupName}: $CLUSTER_COUNT"

        echo "[INFO] Proceeding further as the Clustername matches with the config."

  

        # Create an Prometheus resource group

        ## todo pass this var from config

        # az group create --name RG-NEU-DEV-UK8SCORE \

        #     --location northeurope \

        #     --tags "billingReference=${billingReference}" "opEnvironment=${opEnvironment}" "cmdbReference=${cmdbReference}"

 

        # [ $? -eq 0 ] && echo "[SUCCESS] ${prom_prom_clusterResourceGroup_value} created." || { echo "[ERROR] Failed to create ${prom_prom_clusterResourceGroup_value}"; exit 1; }

 

    else

        echo "[ERROR] ❌ The new cluster name does not match the existing cluster name."

        echo "[INFO] New Cluster Name: $NEW_CLUSTER_NAME"

        echo "[INFO] Existing Cluster Name: $EXISTING_CLUSTER_NAME"

        echo "[ERROR] 🚫 Aborting... RG already has an UK8S cluster. Clusternames do not match as per config. Can create only 1 cluster per RG"

        exit 1

    fi

else

    echo "[INFO] Creating new Rg: ${resourceGroupName}"

     if [[ -z "$billingReference" ]] || [[ -z "$opEnvironment" ]] || [[ -z "$cmdbReference" ]]; then

        echo "[INFO] No tag defined - assuming inheritance"

        az group create --name ${resourceGroupName} \

        --location ${location} \

        exit 0

    fi

 

    # Create an Azure resource group

    az group create --name ${resourceGroupName} \

        --location ${location} \

        --tags "billingReference=${billingReference}" "opEnvironment=${opEnvironment}" "cmdbReference=${cmdbReference}"

    [ $? -eq 0 ] && echo "[SUCCESS] ✅ ${resourceGroupName} created." || { echo "[ERROR] ❌ Failed to create ${resourceGroupName}"; exit 1; }

fi


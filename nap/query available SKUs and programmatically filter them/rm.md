Yes! You can query available SKUs and programmatically filter them. Here's how:

## 1. Query Available SKUs in Your Region

```bash
# Get all available D-series SKUs in your region
az vm list-skus \
  --location eastus \
  --size Standard_D \
  --all \
  --output table \
  --query "[?restrictions.length(@) == \`0\`].[name, capabilities[?name=='vCPUs'].value | [0], capabilities[?name=='MemoryGB'].value | [0]]"
```

## 2. Get JSON Output for Scripting

```bash
# Get unrestricted D-series SKUs as JSON
az vm list-skus \
  --location eastus \
  --size Standard_D \
  --all \
  --output json \
  --query "[?restrictions.length(@) == \`0\`].name" > available-d-series.json
```

## 3. Filter by Multiple Criteria

```bash
# Get available SKUs with specific constraints
az vm list-skus \
  --location eastus \
  --all \
  --output json \
  --query "[?starts_with(name, 'Standard_D') && restrictions.length(@) == \`0\`].{
    name: name,
    vCPUs: capabilities[?name=='vCPUs'].value | [0],
    memoryGB: capabilities[?name=='MemoryGB'].value | [0],
    maxDataDiskCount: capabilities[?name=='MaxDataDiskCount'].value | [0]
  }"
```

## 4. Automated Script to Update Your YAML

Here's a script to automatically update your NodePool YAML:

```bash
#!/bin/bash

LOCATION="eastus"  # Change to your region
YAML_FILE="nodepool.yaml"

# Get available D-series SKUs (unrestricted only)
AVAILABLE_SKUS=$(az vm list-skus \
  --location $LOCATION \
  --size Standard_D \
  --all \
  --output json \
  --query "[?restrictions.length(@) == \`0\`].name" -o tsv)

echo "Available D-series SKUs in $LOCATION:"
echo "$AVAILABLE_SKUS"

# Extract unique D-series family suffixes (D, Ds_v3, Ds_v4, Ds_v5, etc.)
FAMILIES=$(echo "$AVAILABLE_SKUS" | sed -n 's/Standard_\([^0-9]*\).*/\1/p' | sort -u | tr '\n' ', ' | sed 's/,$//')

echo ""
echo "Detected D-series families: $FAMILIES"
echo ""
echo "Update your YAML with:"
echo "        - key: karpenter.azure.com/sku-family"
echo "          operator: In"
echo "          values: [$(echo $FAMILIES | sed 's/,/, /g')]"
```

## 5. More Specific SKU Filtering

If you want to use specific SKU sizes instead of families:

```bash
#!/bin/bash

LOCATION="eastus"
MIN_VCPUS=2
MAX_VCPUS=8

# Get available SKUs with vCPU constraints
az vm list-skus \
  --location $LOCATION \
  --all \
  --output json \
  --query "[?starts_with(name, 'Standard_D') && 
            restrictions.length(@) == \`0\`].{
              name: name,
              vCPUs: to_number(capabilities[?name=='vCPUs'].value | [0])
            } | [?vCPUs >= \`$MIN_VCPUS\` && vCPUs <= \`$MAX_VCPUS\`].name" \
  -o tsv
```

## 6. Updated YAML with Specific SKUs

Instead of using family, you can specify exact SKUs:

```yaml
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: default
spec:
  template:
    metadata:
      labels:
        intent: apps
    spec:
      requirements:
        - key: karpenter.sh/capacity-type
          operator: In
          values: [spot, on-demand]
        - key: karpenter.azure.com/sku-family
          operator: In
          values: [D]  # Or be more specific: [Ds_v5, Dsv4, Ds_v3]
        - key: node.kubernetes.io/instance-type
          operator: In
          values: [Standard_D2s_v5, Standard_D4s_v5, Standard_D8s_v5]  # Specific SKUs
        - key: karpenter.azure.com/sku-cpu
          operator: Gt
          values: ["1"]
        - key: karpenter.azure.com/sku-memory
          operator: Gt
          values: ["2Gi"]
  limits:
    cpu: 100
  disruption:
    consolidationPolicy: WhenEmptyOrUnderutilized
    consolidateAfter: 0s
```

## 7. Check Why F-Series Failed

For your original F-series issue:

```bash
# Check F-series availability
az vm list-skus \
  --location eastus \
  --size Standard_F \
  --all \
  --output table \
  --query "[?restrictions.length(@) == \`0\`]"

# Check if there are restrictions
az vm list-skus \
  --location eastus \
  --size Standard_F \
  --all \
  --output json \
  --query "[].{name: name, restrictions: restrictions}"
```

## 8. Complete Automation Script

```bash
#!/bin/bash

LOCATION="eastus"
FAMILIES=("D" "E" "F")

for FAMILY in "${FAMILIES[@]}"; do
  echo "Checking ${FAMILY}-series availability..."
  
  AVAILABLE=$(az vm list-skus \
    --location $LOCATION \
    --size Standard_${FAMILY} \
    --all \
    --output json \
    --query "[?restrictions.length(@) == \`0\`].name" -o tsv | wc -l)
  
  if [ $AVAILABLE -gt 0 ]; then
    echo "✓ ${FAMILY}-series: $AVAILABLE SKUs available"
  else
    echo "✗ ${FAMILY}-series: No unrestricted SKUs available - REMOVE FROM YAML"
  fi
done
```

Given your UBS Edinburgh setup, I'd recommend using **D-series (Ds_v5 or Ds_v4)** as they're generally well-balanced and widely available. The F-series restriction is likely due to capacity constraints in your region or quota limits on compute-optimized VMs.

Would you like me to help check the specific SKUs available in your Azure region?
Here are several CLI commands to diagnose Azure policy issues that might be blocking AKS cluster deployment:

## Check Azure Policy Assignments

First, identify what policies are applied to your subscription or resource group:

```bash
# List all policy assignments in subscription
az policy assignment list --query "[].{Name:displayName, PolicyDefinition:policyDefinitionId, Scope:scope}" -o table

# Check policy assignments for specific resource group
az policy assignment list --resource-group <resource-group-name> -o table

# Get details of a specific policy assignment
az policy assignment show --name <policy-assignment-name>
```

## Check Policy Compliance and Violations

```bash
# Check policy compliance state for your subscription
az policy state list --query "[?complianceState=='NonCompliant']" -o table

# Check compliance for specific resource group
az policy state list --resource-group <resource-group-name> --query "[?complianceState=='NonCompliant']" -o table

# Get detailed compliance information
az policy state list --filter "ResourceType eq 'Microsoft.ContainerService/managedClusters'" -o table
```

## Simulate AKS Deployment (What-If Analysis)

Use Azure Resource Manager what-if to preview what would happen:

```bash
# Create a basic AKS template file (aks-template.json)
# Then run what-if analysis
az deployment group what-if \
  --resource-group <resource-group-name> \
  --template-file aks-template.json \
  --parameters clusterName=<cluster-name> location=<location>
```

## Check Specific Policy Restrictions

Common policies that block AKS deployments:

```bash
# Check for allowed locations policy
az policy state list --filter "PolicyDefinitionName eq 'e56962a6-4747-49cd-b67b-bf8b01975c4c'" -o table

# Check for allowed resource types policy
az policy state list --filter "PolicyDefinitionName eq 'a08ec900-254a-4555-9bf5-e42af04b5c5c'" -o table

# Check for required tags policy
az policy state list --filter "PolicyDefinitionName eq '1e30110a-5ceb-460c-a204-c1c3969c6d62'" -o table
```

## Check Resource Provider Registration

Sometimes the issue isn't policy but missing resource provider registration:

```bash
# Check if required providers are registered
az provider show --namespace Microsoft.ContainerService --query "registrationState"
az provider show --namespace Microsoft.Network --query "registrationState"
az provider show --namespace Microsoft.Storage --query "registrationState"

# Register if needed
az provider register --namespace Microsoft.ContainerService
```

## Test AKS Creation with Detailed Error Output

```bash
# Attempt AKS creation with verbose output to see specific policy violations
az aks create \
  --resource-group <resource-group-name> \
  --name <cluster-name> \
  --node-count 1 \
  --node-vm-size Standard_DS2_v2 \
  --location <location> \
  --debug \
  --verbose
```

## Check Activity Log for Policy Violations

```bash
# Check recent activity log for policy-related errors
az monitor activity-log list \
  --resource-group <resource-group-name> \
  --start-time 2023-01-01T00:00:00Z \
  --query "[?contains(operationName.value, 'Policy')]" \
  -o table

# More specific search for deployment failures
az monitor activity-log list \
  --resource-group <resource-group-name> \
  --status Failed \
  --query "[].{Time:eventTimestamp, Operation:operationName.value, Status:status.value, Error:properties.statusMessage}" \
  -o table
```

## Get Policy Definition Details

If you find a blocking policy, get its full details:

```bash
# Get policy definition details
az policy definition show --name <policy-definition-id>

# Search for built-in policies related to AKS
az policy definition list --query "[?contains(displayName, 'Kubernetes')]" -o table
```

## Troubleshooting Tips

1. **Check exemptions**: See if you can create a policy exemption for testing:
```bash
az policy exemption create \
  --name test-aks-exemption \
  --policy-assignment <assignment-id> \
  --resource-group <resource-group-name> \
  --exemption-category Waiver
```

2. **Use different regions**: Some policies restrict deployment to specific regions.

3. **Check naming conventions**: Policies might enforce specific naming patterns.

4. **Verify VM sizes**: Policies might restrict which VM SKUs can be used.

The most common policy blocks for AKS are location restrictions, required tags, allowed VM sizes, and network security requirements. Start with checking policy assignments and compliance states to identify the specific policy causing issues.
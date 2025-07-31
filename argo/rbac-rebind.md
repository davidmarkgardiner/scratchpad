Thanks for the clarification! Here's a revised plan focused on Azure RBAC integration with AKS, not Kubernetes native RBAC:

## Pre-Rebuild Documentation and Baseline

**Current Azure RBAC State Capture:**
- Document existing Azure role assignments on the AKS cluster (`az role assignment list --scope /subscriptions/{sub-id}/resourceGroups/{rg}/providers/Microsoft.ContainerService/managedClusters/{cluster-name}`)
- Export Azure AD group memberships and their cluster access
- Document current webhook payload structure for Azure RBAC assignments
- Capture Azure DevOps pipeline configuration for Azure role assignments
- List all Azure AD users/groups and their assigned Azure roles per namespace

## Rebuild Execution Plan

**Phase 1: Cluster Rebuild**
- Deploy new AKS cluster with Azure RBAC enabled (`--enable-azure-rbac`)
- Verify Azure AD integration is properly configured
- Ensure Azure DevOps service principal has necessary permissions for role assignments

**Phase 2: Azure RBAC Rebind Testing**

*Step 1: Trigger Webhook Job*
- Execute the job that sends payload to webhook
- Capture webhook request/response logs
- Verify payload contains Azure AD principals, role definitions, and namespace scopes

*Step 2: Pipeline Execution Validation*
- Monitor Azure DevOps pipeline trigger and execution
- Validate pipeline creates Azure role assignments using `az role assignment create`
- Confirm assignments are scoped to correct namespaces on the AKS cluster
- Check for any Azure RBAC API failures or throttling

## Evidence Gathering and Validation

**Azure RBAC Verification Tests:**

*Namespace-Level Validation:*
```bash
# Verify Azure role assignments per namespace
az role assignment list --scope /subscriptions/{sub-id}/resourceGroups/{rg}/providers/Microsoft.ContainerService/managedClusters/{cluster-name}/namespaces/{namespace}

# Test access with Azure AD credentials
az aks get-credentials --resource-group {rg} --name {cluster} --overwrite-existing
kubectl auth can-i get pods --namespace {namespace} # Will use Azure AD token
```

*Cluster-Level Validation:*
```bash
# List all Azure role assignments on cluster
az role assignment list --scope /subscriptions/{sub-id}/resourceGroups/{rg}/providers/Microsoft.ContainerService/managedClusters/{cluster-name} --output table

# Verify specific user/group assignments
az role assignment list --assignee {user-object-id} --scope {cluster-scope}
```

**Functional Testing:**
- Test Azure AD user login to cluster (`az aks get-credentials` + `kubectl` operations)
- Verify users can only access their assigned namespaces
- Test Azure AD group-based access works correctly
- Validate conditional access policies (if configured)

**Evidence Collection:**
- Document successful Azure role assignment creation via pipeline
- Screenshot Azure portal showing role assignments on AKS cluster
- Capture successful kubectl operations using Azure AD authentication
- Log Azure AD sign-in events for cluster access
- Export final Azure role assignments and compare against baseline

## Validation Checklist

**Infrastructure Validation:**
- [ ] AKS cluster deployed with `--enable-azure-rbac` flag
- [ ] Azure AD integration functioning properly
- [ ] Azure DevOps service principal has Role Based Access Control Administrator role

**Azure RBAC Validation:**
- [ ] All expected Azure role assignments created on cluster
- [ ] Namespace-scoped role assignments working correctly
- [ ] Azure AD users/groups can authenticate to cluster
- [ ] Cross-namespace access properly restricted via Azure roles
- [ ] Webhook job processes Azure AD principals correctly
- [ ] Azure DevOps pipeline creates role assignments without errors

**End-to-End Process Validation:**
- [ ] Webhook receives payload with Azure AD principal information
- [ ] Pipeline creates Azure role assignments via Azure CLI/REST API
- [ ] Role assignments scoped correctly to cluster and namespaces
- [ ] Azure AD authentication to cluster works for assigned users
- [ ] Azure Activity Log shows successful role assignment operations

## Risk Mitigation

**Monitoring Setup:**
- Configure Azure Activity Log alerts for role assignment changes
- Monitor Azure AD sign-in logs for cluster access attempts
- Set up alerts for Azure RBAC API failures in the pipeline
- Track webhook endpoint availability and Azure AD token validation

**Rollback Preparation:**
- Backup current Azure role assignments (`az role assignment list` export)
- Document procedure to remove incorrect role assignments
- Test emergency access via cluster admin credentials
- Prepare break-glass access for Azure DevOps pipeline issues

The key difference here is that you're managing Azure role assignments that grant access to Kubernetes resources, rather than managing Kubernetes RBAC directly. The validation focuses on Azure AD authentication and Azure role-based authorization.

Would you like me to detail any specific aspect of the Azure RBAC testing or help with the Azure CLI commands for validation?
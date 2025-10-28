# Azure Service Operator: SPN to Workload Identity Migration Guide

## Table of Contents

1. [Pre-Migration Checklist](#pre-migration-checklist)
2. [Phase 1: Backup and Documentation](#phase-1-backup-and-documentation)
3. [Phase 2: Prerequisites Validation](#phase-2-prerequisites-validation)
4. [Phase 3: Infrastructure Setup](#phase-3-infrastructure-setup)
5. [Phase 4: Migration Execution](#phase-4-migration-execution)
6. [Phase 5: Validation and Testing](#phase-5-validation-and-testing)
7. [Phase 6: Cleanup](#phase-6-cleanup)
8. [Rollback Procedures](#rollback-procedures)
9. [Post-Migration Tasks](#post-migration-tasks)

---

## Pre-Migration Checklist

Complete this checklist before beginning the migration:

- [ ] Change request approved and scheduled
- [ ] Maintenance window scheduled (recommend 2-hour window)
- [ ] Stakeholders notified
- [ ] Backup procedures reviewed
- [ ] Rollback plan reviewed and understood
- [ ] Required Azure CLI version installed (>= 2.47.0)
- [ ] kubectl access to AKS cluster verified
- [ ] Azure permissions verified (see Prerequisites in README)
- [ ] Migration team briefed
- [ ] Communication channels established
- [ ] Monitoring dashboards prepared

### Required Information Checklist

Gather the following information before starting:

```bash
# Fill these in before proceeding
export AKS_CLUSTER_NAME=""           # Your AKS cluster name
export AKS_RESOURCE_GROUP=""         # Resource group containing AKS cluster
export AZURE_SUBSCRIPTION_ID=""      # Azure subscription ID
export AZURE_TENANT_ID=""            # Azure tenant ID
export MI_NAME="aso-workload-id"     # Name for new Managed Identity (or reuse existing SPN)
export MI_RESOURCE_GROUP=""          # Resource group for Managed Identity
export ASO_NAMESPACE="azureserviceoperator-system"  # ASO namespace
export ASO_SERVICE_ACCOUNT="azureserviceoperator-default"  # ASO service account
```

---

## Phase 1: Backup and Documentation

### 1.1 Document Current State

```bash
# Create backup directory
mkdir -p aso-migration-backup-$(date +%Y%m%d-%H%M%S)
cd aso-migration-backup-$(date +%Y%m%d-%H%M%S)

# Save this directory path
export BACKUP_DIR=$(pwd)
echo "Backup directory: $BACKUP_DIR"
```

### 1.2 Backup Current ASO Configuration

```bash
# Export current Helm values
helm get values aso2 -n azureserviceoperator-system > helm-values-current.yaml

# Export full Helm release
helm get all aso2 -n azureserviceoperator-system > helm-release-full.yaml

# Backup aso-controller-settings secret
kubectl get secret aso-controller-settings \
  -n azureserviceoperator-system \
  -o yaml > aso-controller-settings-backup.yaml

# List all ASO CRDs
kubectl get crds | grep azure.com > crd-list.txt

# Count existing ASO resources
echo "Current ASO resources by type:" > aso-resources-count.txt
for crd in $(kubectl get crds -o name | grep azure.com); do
  count=$(kubectl get $crd --all-namespaces --no-headers 2>/dev/null | wc -l)
  echo "$crd: $count" >> aso-resources-count.txt
done
cat aso-resources-count.txt

# Export sample of ASO resources for validation
kubectl get resourcegroups.resources.azure.com --all-namespaces -o yaml > resourcegroups-backup.yaml 2>/dev/null || true
```

### 1.3 Verify Current ASO Health

```bash
# Check ASO controller status
kubectl get deployments -n azureserviceoperator-system

# Check current pods
kubectl get pods -n azureserviceoperator-system

# Check recent logs for baseline
kubectl logs -n azureserviceoperator-system \
  -l app.kubernetes.io/name=azure-service-operator \
  --tail=100 > pre-migration-logs.txt

# Verify current authentication (should show SPN)
kubectl logs -n azureserviceoperator-system \
  -l app.kubernetes.io/name=azure-service-operator \
  --tail=500 | grep -i "auth" > pre-migration-auth-logs.txt
```

### 1.4 Document Current Service Principal

```bash
# Get current client ID from secret
export CURRENT_CLIENT_ID=$(kubectl get secret aso-controller-settings \
  -n azureserviceoperator-system \
  -o jsonpath='{.data.AZURE_CLIENT_ID}' | base64 -d)

echo "Current Client ID: $CURRENT_CLIENT_ID"

# Save SPN details
az ad sp show --id $CURRENT_CLIENT_ID > current-spn-details.json 2>/dev/null || \
  echo "Could not retrieve SPN details - may be using MI already" > current-spn-details.json

# Document current role assignments
az role assignment list --assignee $CURRENT_CLIENT_ID --all > current-role-assignments.json
```

**CHECKPOINT:** Verify all backups are created and readable before proceeding.

---

## Phase 2: Prerequisites Validation

### 2.1 Verify Azure CLI Version

```bash
# Check Azure CLI version
az version

# Should be >= 2.47.0
# If not, update: https://docs.microsoft.com/cli/azure/install-azure-cli
```

### 2.2 Verify AKS OIDC Issuer

```bash
# Check if OIDC issuer is enabled
az aks show \
  --resource-group $AKS_RESOURCE_GROUP \
  --name $AKS_CLUSTER_NAME \
  --query "oidcIssuerProfile" \
  -o json

# Expected output should show: "enabled": true and issuerUrl
```

**If OIDC is NOT enabled:**

```bash
# Enable OIDC issuer (this is non-disruptive but takes a few minutes)
az aks update \
  --resource-group $AKS_RESOURCE_GROUP \
  --name $AKS_CLUSTER_NAME \
  --enable-oidc-issuer

# Wait for update to complete
az aks show \
  --resource-group $AKS_RESOURCE_GROUP \
  --name $AKS_CLUSTER_NAME \
  --query "oidcIssuerProfile.issuerUrl" \
  -o tsv
```

### 2.3 Get and Validate OIDC Issuer URL

```bash
# Get OIDC issuer URL
export SERVICE_ACCOUNT_ISSUER=$(az aks show \
  --resource-group $AKS_RESOURCE_GROUP \
  --name $AKS_CLUSTER_NAME \
  --query "oidcIssuerProfile.issuerUrl" \
  -o tsv)

echo "OIDC Issuer URL: $SERVICE_ACCOUNT_ISSUER"

# Validate issuer is accessible
curl -s ${SERVICE_ACCOUNT_ISSUER}.well-known/openid-configuration | jq .

# Should return JSON with issuer, jwks_uri, etc.
```

### 2.4 Verify Workload Identity is Enabled on AKS

```bash
# Check if workload identity is enabled
az aks show \
  --resource-group $AKS_RESOURCE_GROUP \
  --name $AKS_CLUSTER_NAME \
  --query "securityProfile.workloadIdentity" \
  -o json
```

**If Workload Identity is NOT enabled:**

```bash
# Enable workload identity on AKS
az aks update \
  --resource-group $AKS_RESOURCE_GROUP \
  --name $AKS_CLUSTER_NAME \
  --enable-workload-identity

# This will trigger node pool updates - may take 10-30 minutes
# Monitor progress:
az aks show \
  --resource-group $AKS_RESOURCE_GROUP \
  --name $AKS_CLUSTER_NAME \
  --query "securityProfile.workloadIdentity.enabled" \
  -o tsv
```

### 2.5 Verify Workload Identity Webhook

```bash
# Check if workload identity webhook is running
kubectl get pods -n kube-system -l app=workload-identity-webhook

# Should see pods in Running state
# If not present, workload identity may not be fully enabled
```

**CHECKPOINT:** All prerequisites must be met before proceeding. If any checks fail, resolve issues first.

---

## Phase 3: Infrastructure Setup

### 3.1 Determine Identity Strategy

**Option A: Create New Managed Identity (Recommended)**

```bash
# Create new user-assigned managed identity
az identity create \
  --name $MI_NAME \
  --resource-group $MI_RESOURCE_GROUP \
  --location $(az group show --name $MI_RESOURCE_GROUP --query location -o tsv)

# Get the client ID
export AZURE_CLIENT_ID=$(az identity show \
  --name $MI_NAME \
  --resource-group $MI_RESOURCE_GROUP \
  --query clientId \
  -o tsv)

echo "New Managed Identity Client ID: $AZURE_CLIENT_ID"
```

**Option B: Reuse Existing Service Principal**

```bash
# Use existing SPN client ID
export AZURE_CLIENT_ID=$CURRENT_CLIENT_ID
echo "Reusing existing identity: $AZURE_CLIENT_ID"
```

### 3.2 Assign Required Azure RBAC Roles

```bash
# Get the principal ID (object ID) of the identity
export PRINCIPAL_ID=$(az identity show \
  --name $MI_NAME \
  --resource-group $MI_RESOURCE_GROUP \
  --query principalId \
  -o tsv)

# Assign Contributor role at subscription level
# (adjust scope as needed for your environment)
az role assignment create \
  --assignee-object-id $PRINCIPAL_ID \
  --assignee-principal-type ServicePrincipal \
  --role Contributor \
  --scope /subscriptions/$AZURE_SUBSCRIPTION_ID

# For more restrictive permissions, assign specific roles:
# Examples:
# - Network Contributor
# - Storage Account Contributor
# - etc.

# Verify role assignments
az role assignment list \
  --assignee $AZURE_CLIENT_ID \
  --all \
  -o table
```

**Important:** Ensure the managed identity has all the same permissions that the current SPN has. Reference the `current-role-assignments.json` backup file.

### 3.3 Create Federated Identity Credential

```bash
# Create federated identity credential for ASO service account
az identity federated-credential create \
  --name aso-federated-credential \
  --identity-name $MI_NAME \
  --resource-group $MI_RESOURCE_GROUP \
  --issuer $SERVICE_ACCOUNT_ISSUER \
  --subject "system:serviceaccount:${ASO_NAMESPACE}:${ASO_SERVICE_ACCOUNT}" \
  --audiences "api://AzureADTokenExchange"

# Verify the credential was created
az identity federated-credential list \
  --identity-name $MI_NAME \
  --resource-group $MI_RESOURCE_GROUP \
  -o table
```

**CRITICAL:** The `--subject` must exactly match: `system:serviceaccount:<namespace>:<service-account-name>`

### 3.4 Verify Federated Credential Details

```bash
# Get detailed view of federated credential
az identity federated-credential show \
  --name aso-federated-credential \
  --identity-name $MI_NAME \
  --resource-group $MI_RESOURCE_GROUP \
  -o json

# Verify:
# - issuer matches OIDC URL
# - subject matches expected service account
# - audiences contains "api://AzureADTokenExchange"
```

**CHECKPOINT:** Verify federated credential is properly configured before proceeding.

---

## Phase 4: Migration Execution

### 4.1 Prepare Updated Secret Configuration

First, get current values that should be preserved:

```bash
# Extract current non-auth settings from aso-controller-settings
kubectl get secret aso-controller-settings \
  -n azureserviceoperator-system \
  -o json | jq -r '.data | to_entries[] | select(.key | test("AZURE_CLIENT_SECRET") | not) | "\(.key)=\(.value | @base64d)"' > current-settings.env

# Review what will be preserved
cat current-settings.env
```

### 4.2 Create Updated aso-controller-settings Secret

```bash
# Create new secret manifest with workload identity configuration
cat <<EOF > aso-controller-settings-new.yaml
apiVersion: v1
kind: Secret
metadata:
  name: aso-controller-settings
  namespace: azureserviceoperator-system
type: Opaque
stringData:
  AZURE_SUBSCRIPTION_ID: "$AZURE_SUBSCRIPTION_ID"
  AZURE_TENANT_ID: "$AZURE_TENANT_ID"
  AZURE_CLIENT_ID: "$AZURE_CLIENT_ID"
  USE_WORKLOAD_IDENTITY_AUTH: "true"
  # Add any other settings from current-settings.env that are not auth-related
  # For example:
  # AZURE_RESOURCE_MANAGER_ENDPOINT: "https://management.azure.com/"
  # AZURE_RESOURCE_MANAGER_AUDIENCE: "https://management.core.windows.net/"
EOF

# Review the new secret
cat aso-controller-settings-new.yaml

# IMPORTANT: Manually add any custom settings from current-settings.env
# that are not auth-related to the yaml above before proceeding
```

### 4.3 Update Helm Release with Workload Identity

```bash
# Get current Helm values
helm get values aso2 -n azureserviceoperator-system > current-helm-values.yaml

# Prepare new values file with workload identity settings
cat <<EOF > helm-values-workload-identity.yaml
# Workload Identity Configuration
azureSubscriptionID: $AZURE_SUBSCRIPTION_ID
azureTenantID: $AZURE_TENANT_ID
azureClientID: $AZURE_CLIENT_ID
useWorkloadIdentityAuth: true

# Preserve other existing settings from current-helm-values.yaml
# Copy them here...

EOF

# Review and merge any custom values from current-helm-values.yaml
# into helm-values-workload-identity.yaml

# IMPORTANT: Edit helm-values-workload-identity.yaml to include all
# your custom settings (CRD patterns, resource limits, etc.)
```

### 4.4 Execute Helm Upgrade

**⚠️ CRITICAL STEP: This will restart the ASO controller**

```bash
# Dry-run first to validate
helm upgrade aso2 aso2/azure-service-operator \
  --namespace azureserviceoperator-system \
  --values helm-values-workload-identity.yaml \
  --dry-run --debug

# Review the diff output carefully

# If dry-run looks good, execute the upgrade
helm upgrade aso2 aso2/azure-service-operator \
  --namespace azureserviceoperator-system \
  --values helm-values-workload-identity.yaml \
  --wait \
  --timeout 10m

# Monitor the upgrade
watch kubectl get pods -n azureserviceoperator-system
```

### 4.5 Alternative: Manual Secret Update (if not using Helm values)

If your current deployment doesn't use Helm for credential management:

```bash
# Apply the new secret
kubectl apply -f aso-controller-settings-new.yaml

# Restart the ASO controller to pick up new configuration
kubectl rollout restart deployment -n azureserviceoperator-system \
  -l app.kubernetes.io/name=azure-service-operator

# Monitor the rollout
kubectl rollout status deployment -n azureserviceoperator-system \
  -l app.kubernetes.io/name=azure-service-operator
```

### 4.6 Verify Pod Configuration

```bash
# Wait for pods to be running
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/name=azure-service-operator \
  -n azureserviceoperator-system \
  --timeout=300s

# Get new pod name
export ASO_POD=$(kubectl get pods -n azureserviceoperator-system \
  -l app.kubernetes.io/name=azure-service-operator \
  -o jsonpath='{.items[0].metadata.name}')

echo "New ASO Pod: $ASO_POD"

# Verify workload identity annotations on pod
kubectl get pod $ASO_POD -n azureserviceoperator-system -o yaml | grep -A 5 "workload.identity"

# Should see annotations like:
# azure.workload.identity/inject-proxy-sidecar: "true"
# azure.workload.identity/service-account-token-expiration: "3600"

# Verify projected token volume exists
kubectl get pod $ASO_POD -n azureserviceoperator-system \
  -o jsonpath='{.spec.volumes[?(@.name=="azure-identity-token")]}' | jq .

# Verify token file is mounted in pod
kubectl exec -n azureserviceoperator-system $ASO_POD -- \
  ls -la /var/run/secrets/azure/tokens/

# Should show azure-identity-token file
```

**CHECKPOINT:** Verify pod is running and has workload identity configuration before proceeding.

---

## Phase 5: Validation and Testing

### 5.1 Check Controller Logs

```bash
# Check for successful authentication
kubectl logs -n azureserviceoperator-system $ASO_POD --tail=100 | grep -i auth

# Look for successful token acquisition
kubectl logs -n azureserviceoperator-system $ASO_POD --tail=100 | grep -i token

# Check for any errors
kubectl logs -n azureserviceoperator-system $ASO_POD --tail=100 | grep -i error

# Save post-migration logs
kubectl logs -n azureserviceoperator-system $ASO_POD --tail=500 > post-migration-logs.txt
```

**Expected:** Logs should show successful authentication using workload identity, no errors about missing secrets or authentication failures.

### 5.2 Verify Existing Resources Still Reconcile

```bash
# Check status of existing ASO resources
kubectl get resourcegroups.resources.azure.com --all-namespaces

# Look at a specific resource's conditions
kubectl get resourcegroup <resource-name> -n <namespace> -o yaml | grep -A 10 conditions

# Trigger reconciliation by adding an annotation
kubectl annotate resourcegroup <resource-name> -n <namespace> \
  test-reconcile="$(date +%s)" --overwrite

# Watch for reconciliation
kubectl get resourcegroup <resource-name> -n <namespace> -w
```

### 5.3 Test Creating New Resources

```bash
# Create a test resource group
cat <<EOF | kubectl apply -f -
apiVersion: resources.azure.com/v1api20200601
kind: ResourceGroup
metadata:
  name: aso-migration-test-rg
  namespace: default
spec:
  location: westeurope
  tags:
    environment: test
    purpose: aso-workload-identity-migration-validation
EOF

# Watch the resource
kubectl get resourcegroup aso-migration-test-rg -n default -w

# Check detailed status
kubectl describe resourcegroup aso-migration-test-rg -n default

# Verify in Azure
az group show --name aso-migration-test-rg

# Clean up test resource
kubectl delete resourcegroup aso-migration-test-rg -n default
```

### 5.4 Test Namespace-Scoped Credentials (if applicable)

If you use namespace-scoped credentials, update them:

```bash
# Create workload identity credential for namespace
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: aso-credential
  namespace: <your-namespace>
type: Opaque
stringData:
  AZURE_SUBSCRIPTION_ID: "$AZURE_SUBSCRIPTION_ID"
  AZURE_TENANT_ID: "$AZURE_TENANT_ID"
  AZURE_CLIENT_ID: "$AZURE_CLIENT_ID"
EOF

# Test resource creation in that namespace
# (follow similar pattern to 5.3)
```

### 5.5 Performance and Metrics Check

```bash
# Check controller metrics (if metrics are exposed)
kubectl port-forward -n azureserviceoperator-system \
  svc/azureserviceoperator-controller-manager-metrics-service 8443:8443

# In another terminal:
curl -k https://localhost:8443/metrics | grep azure

# Check resource quotas and limits
kubectl describe deployment -n azureserviceoperator-system \
  -l app.kubernetes.io/name=azure-service-operator

# Verify no resource exhaustion
kubectl top pods -n azureserviceoperator-system
```

### 5.6 Comprehensive Validation Checklist

- [ ] ASO controller pod is running
- [ ] Pod has workload identity annotations
- [ ] Token volume is mounted in pod
- [ ] Controller logs show successful authentication
- [ ] No authentication errors in logs
- [ ] Existing resources show "Ready" status
- [ ] Can create new test resources successfully
- [ ] Test resource appears in Azure
- [ ] Can update existing resources
- [ ] Can delete test resources
- [ ] Namespace-scoped credentials work (if applicable)
- [ ] Metrics endpoint accessible
- [ ] No performance degradation observed

**CHECKPOINT:** All validation checks must pass before proceeding to cleanup.

---

## Phase 6: Cleanup

### 6.1 Remove Client Secret from Secrets

**⚠️ Only proceed if all validation passed**

```bash
# Backup current secret one more time
kubectl get secret aso-controller-settings \
  -n azureserviceoperator-system \
  -o yaml > aso-controller-settings-final-backup.yaml

# Verify no AZURE_CLIENT_SECRET in current secret
kubectl get secret aso-controller-settings \
  -n azureserviceoperator-system \
  -o jsonpath='{.data.AZURE_CLIENT_SECRET}' | base64 -d

# Should be empty or not present

# If you still see CLIENT_SECRET, manually remove it:
kubectl get secret aso-controller-settings \
  -n azureserviceoperator-system \
  -o json | \
  jq 'del(.data.AZURE_CLIENT_SECRET)' | \
  kubectl apply -f -
```

### 6.2 Update Documentation

```bash
# Document the migration
cat <<EOF > migration-summary.md
# ASO Workload Identity Migration Summary

**Migration Date:** $(date)
**Performed By:** $(whoami)

## Configuration Changes

### Before:
- Authentication Method: Service Principal with Client Secret
- Client ID: $CURRENT_CLIENT_ID

### After:
- Authentication Method: Workload Identity (Managed Identity)
- Client ID: $AZURE_CLIENT_ID
- Managed Identity Name: $MI_NAME
- Managed Identity Resource Group: $MI_RESOURCE_GROUP
- Federated Credential: aso-federated-credential
- OIDC Issuer: $SERVICE_ACCOUNT_ISSUER

## Validation Results
- Migration Date: $(date)
- ASO Controller Version: $(helm list -n azureserviceoperator-system -o json | jq -r '.[0].app_version')
- Test Resource Created: ✓
- Existing Resources Reconciling: ✓
- No Authentication Errors: ✓

## Backup Location
$BACKUP_DIR

## Rollback Available
Yes - for 30 days (see rollback procedures)
EOF

cat migration-summary.md
```

### 6.3 Optional: Rotate or Remove Old Service Principal

**⚠️ Wait at least 24-48 hours after migration before removing SPN**

```bash
# If you created a NEW managed identity and want to clean up old SPN:

# First verify SPN is not used elsewhere
az ad sp show --id $CURRENT_CLIENT_ID

# List all role assignments
az role assignment list --assignee $CURRENT_CLIENT_ID --all

# If safe to remove, delete the SPN
# az ad sp delete --id $CURRENT_CLIENT_ID

# OR rotate the secret if keeping SPN for other purposes
# az ad sp credential reset --id $CURRENT_CLIENT_ID
```

### 6.4 Update Monitoring and Alerts

```bash
# Update any monitoring dashboards or alerts that referenced:
# - AZURE_CLIENT_SECRET expiration
# - Service Principal credentials
# - Authentication failures related to SPN

# Add new monitoring for:
# - Workload identity token acquisition
# - Federated credential health
# - OIDC issuer availability
```

**CHECKPOINT:** Migration complete! Proceed to post-migration tasks.

---

## Rollback Procedures

### When to Rollback

Rollback if any of these conditions occur:
- ASO controller fails to start after migration
- Authentication errors persist after 5 minutes
- Cannot create or update resources
- Critical production resources showing errors
- Validation tests failing

### Rollback Steps

#### Option 1: Quick Rollback via Helm

```bash
# Rollback to previous Helm release
helm rollback aso2 -n azureserviceoperator-system

# Monitor rollback
kubectl rollout status deployment -n azureserviceoperator-system \
  -l app.kubernetes.io/name=azure-service-operator

# Verify pods are running
kubectl get pods -n azureserviceoperator-system
```

#### Option 2: Manual Rollback

```bash
# Restore original secret
kubectl apply -f $BACKUP_DIR/aso-controller-settings-backup.yaml

# Restart controller
kubectl rollout restart deployment -n azureserviceoperator-system \
  -l app.kubernetes.io/name=azure-service-operator

# Monitor restart
kubectl rollout status deployment -n azureserviceoperator-system \
  -l app.kubernetes.io/name=azure-service-operator
```

### Post-Rollback Validation

```bash
# Verify controller is healthy
kubectl get pods -n azureserviceoperator-system

# Check logs for SPN authentication
kubectl logs -n azureserviceoperator-system \
  -l app.kubernetes.io/name=azure-service-operator \
  --tail=100 | grep -i auth

# Test resource reconciliation
kubectl get resourcegroups.resources.azure.com --all-namespaces

# Create test resource to verify functionality
```

### Root Cause Analysis

If rollback was necessary, investigate:

```bash
# Capture logs from failed pod
kubectl logs -n azureserviceoperator-system $ASO_POD --previous > failed-pod-logs.txt

# Check events
kubectl get events -n azureserviceoperator-system --sort-by='.lastTimestamp'

# Verify prerequisites were met
# - OIDC issuer URL correct?
# - Federated credential subject correct?
# - Managed identity has required permissions?
# - Workload identity webhook running?
```

---

## Post-Migration Tasks

### Immediate Tasks (Day 1)

- [ ] Update runbook documentation with new authentication method
- [ ] Update disaster recovery procedures
- [ ] Notify stakeholders of successful migration
- [ ] Close change request with summary
- [ ] Archive backup files to secure location
- [ ] Update team wiki/confluence with new configuration
- [ ] Remove old SPN credentials from password managers/vaults

### Short-term Tasks (Week 1)

- [ ] Monitor ASO logs daily for any authentication issues
- [ ] Review Azure AD sign-in logs for workload identity
- [ ] Validate all ASO resources across all namespaces
- [ ] Update any CI/CD pipelines that reference ASO configuration
- [ ] Update infrastructure-as-code repositories
- [ ] Conduct team knowledge sharing session
- [ ] Update standard operating procedures

### Long-term Tasks (Month 1)

- [ ] Schedule review of managed identity permissions (least privilege)
- [ ] Evaluate and implement advanced monitoring for workload identity
- [ ] Consider migrating other workloads to workload identity
- [ ] Document lessons learned
- [ ] Update security compliance documentation
- [ ] Plan for removal of old Service Principal (if not already done)
- [ ] Quarterly review of federated identity credentials

### Continuous Tasks

- [ ] Monitor token acquisition metrics
- [ ] Review Azure AD audit logs quarterly
- [ ] Verify federated credential configuration quarterly
- [ ] Update documentation as ASO evolves
- [ ] Keep team trained on workload identity troubleshooting

---

## Frequently Asked Questions

### Q: Will there be downtime during migration?

**A:** Brief downtime of 1-2 minutes during the Helm upgrade when the controller pod restarts. Existing resources are not affected, but new reconciliation requests will be queued during the restart.

### Q: Can I test this in a non-production environment first?

**A:** Yes, strongly recommended! Follow this guide in a dev/test environment first to identify any environment-specific issues.

### Q: What if my cluster doesn't have OIDC enabled?

**A:** You must enable OIDC first. The `az aks update --enable-oidc-issuer` command is non-disruptive and can be run during business hours.

### Q: How long does the Helm upgrade take?

**A:** Typically 2-5 minutes, including pod restart and health checks.

### Q: What if authentication fails after migration?

**A:** Follow the rollback procedures immediately. Most authentication failures are due to incorrect federated credential configuration (issuer or subject mismatch).

### Q: Can I use the same Service Principal with Workload Identity?

**A:** Yes, you can configure federated credentials on an existing SPN. However, using a Managed Identity is recommended for better Azure integration.

### Q: Will namespace-scoped credentials need updates?

**A:** Yes, any namespace-scoped `aso-credential` secrets will need to be updated to remove `AZURE_CLIENT_SECRET` and rely on workload identity.

### Q: How do I verify the migration was successful?

**A:** Check logs for authentication success, verify existing resources reconcile, create a test resource, and ensure no authentication errors appear.

### Q: What happens to existing ASO resources during migration?

**A:** They are unaffected. ASO continues to manage them once authentication is restored after the controller restart.

### Q: How often are tokens refreshed with Workload Identity?

**A:** Azure AD automatically handles token refresh. Tokens are typically valid for 1 hour and automatically renewed before expiration.

---

## Troubleshooting Common Issues

### Issue: AADSTS70021 Error

**Symptom:** Logs show "AADSTS70021: No matching federated identity record found"

**Cause:** Subject mismatch in federated identity credential

**Solution:**
```bash
# Verify exact subject format
az identity federated-credential show \
  --name aso-federated-credential \
  --identity-name $MI_NAME \
  --resource-group $MI_RESOURCE_GROUP \
  --query subject -o tsv

# Should be exactly: system:serviceaccount:azureserviceoperator-system:azureserviceoperator-default

# If wrong, delete and recreate
az identity federated-credential delete \
  --name aso-federated-credential \
  --identity-name $MI_NAME \
  --resource-group $MI_RESOURCE_GROUP

# Recreate with correct subject (see Phase 3.3)
```

### Issue: Token Volume Not Mounted

**Symptom:** Pod doesn't have `/var/run/secrets/azure/tokens/` directory

**Cause:** Workload identity webhook not injecting volume

**Solution:**
```bash
# Verify workload identity webhook is running
kubectl get pods -n kube-system -l app=workload-identity-webhook

# Check service account has correct annotations
kubectl get sa $ASO_SERVICE_ACCOUNT -n $ASO_NAMESPACE -o yaml

# Should have: azure.workload.identity/client-id annotation

# If missing, update via Helm with correct values
```

### Issue: Permission Denied Errors

**Symptom:** ASO can authenticate but gets 403 errors creating resources

**Cause:** Managed identity lacks required Azure RBAC permissions

**Solution:**
```bash
# List current role assignments
az role assignment list --assignee $AZURE_CLIENT_ID --all -o table

# Compare with old SPN permissions
# Add missing roles
az role assignment create \
  --assignee $AZURE_CLIENT_ID \
  --role <required-role> \
  --scope <required-scope>
```

### Issue: High Token Acquisition Failures

**Symptom:** Metrics or logs show frequent token acquisition failures

**Cause:** Network issues reaching OIDC endpoint or Azure AD

**Solution:**
```bash
# Test OIDC endpoint connectivity from pod
kubectl exec -n $ASO_NAMESPACE $ASO_POD -- \
  curl -v $SERVICE_ACCOUNT_ISSUER.well-known/openid-configuration

# Test Azure AD connectivity
kubectl exec -n $ASO_NAMESPACE $ASO_POD -- \
  curl -v https://login.microsoftonline.com/$AZURE_TENANT_ID/v2.0/.well-known/openid-configuration

# Check network policies or firewalls
```

---

## Support and Contact Information

**Internal Support:**
- DevSecOps Team: [contact details]
- Platform Team: [contact details]
- Security Team: [contact details]

**External Resources:**
- ASO GitHub: https://github.com/Azure/azure-service-operator
- ASO Slack: https://kubernetes.slack.com/messages/azure-service-operator
- Azure Support: Portal or Azure CLI

**Escalation Path:**
1. Check this troubleshooting guide
2. Review ASO GitHub issues
3. Contact internal DevSecOps team
4. Engage Azure support if needed

---

**Document Version:** 1.0  
**Last Updated:** October 2025  
**Next Review:** Quarterly  
**Owner:** DevSecOps Engineering Team
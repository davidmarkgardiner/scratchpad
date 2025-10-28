# Azure Service Operator - Workload Identity Migration

## Overview

This repository contains documentation and procedures for migrating Azure Service Operator (ASO) from Service Principal Name (SPN) authentication to Workload Identity authentication. Workload Identity is the recommended authentication mode for production use cases as it eliminates the need to manage and rotate client secrets.

## Table of Contents

- [Why Migrate to Workload Identity](#why-migrate-to-workload-identity)
- [Architecture Overview](#architecture-overview)
- [Prerequisites](#prerequisites)
- [Migration Approach](#migration-approach)
- [Security Considerations](#security-considerations)
- [References](#references)

## Why Migrate to Workload Identity

### Benefits of Workload Identity

1. **Enhanced Security**
   - Eliminates long-lived client secrets in Kubernetes
   - Short-lived tokens automatically rotated by Azure AD
   - Reduces secret sprawl and management overhead
   - Complies with zero-trust security principles

2. **Simplified Operations**
   - No manual secret rotation required
   - Reduces risk of expired credentials causing outages
   - Native integration with AKS OIDC issuer
   - Better audit trail through federated identity credentials

3. **Cost Efficiency**
   - Reduced operational overhead
   - Fewer incidents related to credential expiration
   - Simplified compliance and security reviews

### Comparison: SPN vs Workload Identity

| Aspect | Service Principal (SPN) | Workload Identity |
|--------|------------------------|-------------------|
| Secret Management | Manual rotation required | Automatic token rotation |
| Secret Storage | Stored in Kubernetes secrets | No secrets stored |
| Token Lifetime | Long-lived (months/years) | Short-lived (hours) |
| Security Posture | Higher risk of compromise | Lower risk (zero trust) |
| Operational Overhead | High (rotation, monitoring) | Low (automated) |
| AKS Integration | Basic | Native OIDC integration |

## Architecture Overview

### Current Architecture (SPN)

```
┌─────────────────────────────────────────┐
│           AKS Cluster                    │
│                                          │
│  ┌────────────────────────────────────┐ │
│  │  ASO Controller Pod                 │ │
│  │                                     │ │
│  │  Reads aso-controller-settings     │ │
│  │  Secret containing:                │ │
│  │  - AZURE_CLIENT_ID                 │ │
│  │  - AZURE_CLIENT_SECRET  ⚠️         │ │
│  │  - AZURE_TENANT_ID                 │ │
│  │  - AZURE_SUBSCRIPTION_ID           │ │
│  └────────────────────────────────────┘ │
│           │                              │
└───────────┼──────────────────────────────┘
            │
            │ Authenticates using
            │ Client ID + Secret
            ▼
┌─────────────────────────────────────────┐
│         Azure Active Directory           │
│                                          │
│  Service Principal                       │
│  - Client Secret (Long-lived)            │
└─────────────────────────────────────────┘
            │
            ▼
┌─────────────────────────────────────────┐
│         Azure Resource Manager           │
│                                          │
│  - Manages Azure Resources               │
└─────────────────────────────────────────┘
```

### Target Architecture (Workload Identity)

```
┌─────────────────────────────────────────┐
│           AKS Cluster                    │
│                                          │
│  ┌────────────────────────────────────┐ │
│  │  ASO Controller Pod                 │ │
│  │                                     │ │
│  │  Service Account:                  │ │
│  │  azureserviceoperator-default      │ │
│  │                                     │ │
│  │  Labels/Annotations:               │ │
│  │  - azure.workload.identity/use     │ │
│  │  - azure.workload.identity/        │ │
│  │    client-id: <CLIENT_ID>          │ │
│  │                                     │ │
│  │  Reads aso-controller-settings     │ │
│  │  Secret containing:                │ │
│  │  - AZURE_CLIENT_ID                 │ │
│  │  - AZURE_TENANT_ID                 │ │
│  │  - AZURE_SUBSCRIPTION_ID           │ │
│  │  - USE_WORKLOAD_IDENTITY_AUTH      │ │
│  └────────────────────────────────────┘ │
│           │                              │
│           │ Projects service account     │
│           │ token to pod                 │
│           │                              │
│  ┌────────▼────────────────────────────┐│
│  │  Projected Volume                    ││
│  │  /var/run/secrets/azure/tokens/     ││
│  │  azure-identity-token                ││
│  └──────────────────────────────────────┘│
│           │                              │
└───────────┼──────────────────────────────┘
            │
            │ OIDC Token Exchange
            │ (Kubernetes SA → Azure AD)
            ▼
┌─────────────────────────────────────────┐
│    AKS OIDC Issuer Endpoint              │
│    https://oidc.prod-aks.azure.com/     │
│    {tenant-id}/                          │
└─────────────────────────────────────────┘
            │
            │ Validates OIDC token
            ▼
┌─────────────────────────────────────────┐
│         Azure Active Directory           │
│                                          │
│  Federated Identity Credential           │
│  - Issuer: AKS OIDC URL                  │
│  - Subject: system:serviceaccount:...    │
│  - Audience: api://AzureADTokenExchange  │
│                                          │
│  Returns short-lived token ✓             │
└─────────────────────────────────────────┘
            │
            ▼
┌─────────────────────────────────────────┐
│         Azure Resource Manager           │
│                                          │
│  - Manages Azure Resources               │
└─────────────────────────────────────────┘
```

### Key Components

1. **AKS OIDC Issuer**
   - Must be enabled on the AKS cluster
   - Provides OpenID Connect discovery endpoint
   - Signs service account tokens

2. **Federated Identity Credential**
   - Links AKS service account to Azure AD identity
   - Defines trust relationship between Kubernetes and Azure AD
   - Specifies issuer, subject, and audience

3. **Workload Identity Webhook**
   - Automatically injected by AKS
   - Mutates pods to add necessary environment variables
   - Projects service account token as volume

4. **Service Account**
   - Must have specific annotations for Workload Identity
   - Token projected into pod at runtime
   - Used for OIDC token exchange

## Prerequisites

### Infrastructure Requirements

1. **AKS Cluster with OIDC Issuer Enabled**
   ```bash
   # Check if OIDC is enabled
   az aks show --resource-group <rg-name> --name <cluster-name> \
     --query "oidcIssuerProfile.enabled"
   
   # Enable OIDC if needed
   az aks update --resource-group <rg-name> --name <cluster-name> \
     --enable-oidc-issuer
   ```

2. **Workload Identity Enabled on AKS**
   ```bash
   # Check workload identity status
   az aks show --resource-group <rg-name> --name <cluster-name> \
     --query "securityProfile.workloadIdentity.enabled"
   
   # Enable workload identity if needed
   az aks update --resource-group <rg-name> --name <cluster-name> \
     --enable-workload-identity
   ```

3. **Azure CLI Version**
   - Minimum version: 2.47.0 or higher
   ```bash
   az --version
   ```

### Required Information

Before starting the migration, gather:

1. **Current ASO Configuration**
   - Helm release name (typically `aso2`)
   - Namespace (typically `azureserviceoperator-system`)
   - Current Helm values
   - CRD patterns in use

2. **Azure Identity Information**
   - Subscription ID
   - Tenant ID
   - Current Service Principal Client ID (can be reused or create new Managed Identity)
   - Resource Group for Managed Identity (if creating new)

3. **AKS Cluster Information**
   - Cluster name
   - Resource group
   - OIDC issuer URL

### Permissions Required

The person performing the migration needs:

1. **Azure Permissions**
   - `Microsoft.ManagedIdentity/userAssignedIdentities/write` - Create/update Managed Identity
   - `Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials/write` - Create federated credentials
   - `Microsoft.Authorization/roleAssignments/write` - Assign RBAC roles
   - OR `Application.ReadWrite.All` - If using Service Principal instead of MI

2. **Kubernetes Permissions**
   - Cluster admin or sufficient RBAC to:
     - Update Helm releases
     - Create/update secrets in `azureserviceoperator-system` namespace
     - Restart deployments

## Migration Approach

### Migration Strategy Options

#### Option 1: In-Place Update (Recommended for Production)

**Pros:**
- Minimal downtime
- Existing ASO resources unaffected
- Can quickly rollback if issues occur

**Cons:**
- Brief reconciliation pause during update
- Requires careful validation

**Best for:** Production environments, large-scale deployments

#### Option 2: Blue-Green Deployment

**Pros:**
- Zero downtime
- Full validation before cutover
- Easy rollback

**Cons:**
- More complex
- Requires duplicate infrastructure temporarily
- Resource overhead

**Best for:** Mission-critical environments where zero downtime is mandatory

#### Option 3: Parallel Testing

**Pros:**
- Can test in parallel with existing setup
- No impact to production
- Thorough validation possible

**Cons:**
- Requires test environment
- May not catch environment-specific issues

**Best for:** Initial testing and validation

### Migration Phases

1. **Preparation Phase**
   - Backup current configuration
   - Document current state
   - Verify prerequisites
   - Create migration checklist

2. **Infrastructure Setup Phase**
   - Enable OIDC issuer on AKS
   - Create/configure Managed Identity
   - Establish federated identity credential
   - Assign required Azure RBAC roles

3. **ASO Configuration Phase**
   - Update Helm values
   - Update secrets
   - Restart ASO controller
   - Verify authentication

4. **Validation Phase**
   - Test existing resources
   - Create test resources
   - Verify reconciliation
   - Check logs

5. **Cleanup Phase**
   - Remove old secrets
   - Update documentation
   - Clean up old Service Principal (if desired)

## Security Considerations

### Secret Management

1. **During Migration**
   - Keep SPN credentials until migration validated
   - Use separate kubeconfig context for migration testing
   - Audit access to secrets before removal

2. **Post-Migration**
   - Remove AZURE_CLIENT_SECRET from all secrets
   - Rotate Service Principal secret if keeping SPN for other purposes
   - Update secret scanning tools to exclude expected Workload Identity configuration

### RBAC Best Practices

1. **Managed Identity Permissions**
   - Follow principle of least privilege
   - Assign only required Azure RBAC roles
   - Document all role assignments
   - Regular access reviews

2. **Federated Identity Credentials**
   - One credential per ASO instance/namespace
   - Specific subject matching (no wildcards)
   - Document trust relationships
   - Regular audit of federated credentials

### Compliance Considerations

1. **Audit Requirements**
   - All authentication attempts logged by Azure AD
   - ASO controller logs authentication method
   - Enable Azure Activity Log for identity operations
   - Monitor for failed authentication attempts

2. **Change Management**
   - Document migration in change tickets
   - Follow organizational change control process
   - Maintain before/after configuration records
   - Update disaster recovery documentation

## Monitoring and Operations

### Health Checks

Monitor these metrics post-migration:

1. **ASO Controller Health**
   ```bash
   kubectl get pods -n azureserviceoperator-system
   kubectl logs -n azureserviceoperator-system -l app.kubernetes.io/name=azure-service-operator
   ```

2. **Authentication Status**
   ```bash
   # Check for authentication errors in logs
   kubectl logs -n azureserviceoperator-system -l app.kubernetes.io/name=azure-service-operator | grep -i auth
   ```

3. **Resource Reconciliation**
   ```bash
   # Check ASO resource status
   kubectl get azureserviceoperator --all-namespaces
   ```

### Common Monitoring Queries

If using Azure Monitor/Log Analytics:

```kusto
// Failed authentication attempts
AzureActivity
| where OperationNameValue contains "MICROSOFT.MANAGEDIDENTITY"
| where ActivityStatusValue == "Failure"
| project TimeGenerated, Caller, OperationNameValue, ActivityStatusValue, Properties

// Successful token exchanges
AzureActivity
| where OperationNameValue contains "MICROSOFT.MANAGEDIDENTITY/USERASSIGNEDIDENTITIES/FEDERATEDIDENTITYCREDENTIALS"
| where ActivityStatusValue == "Success"
| summarize count() by bin(TimeGenerated, 1h)
```

## Troubleshooting

### Common Issues

1. **OIDC Issuer Not Enabled**
   - Symptom: Cannot create federated identity credential
   - Solution: Enable OIDC issuer on AKS cluster
   - Validation: Check `oidcIssuerProfile.issuerUrl` on cluster

2. **Incorrect Subject in Federated Credential**
   - Symptom: Authentication fails with "AADSTS70021" error
   - Solution: Verify subject matches exactly: `system:serviceaccount:azureserviceoperator-system:azureserviceoperator-default`
   - Common mistake: Wrong namespace or service account name

3. **Missing Workload Identity Annotations**
   - Symptom: Pod doesn't get projected token volume
   - Solution: Ensure Helm values set `useWorkloadIdentityAuth=true`
   - Validation: Check pod annotations and volume mounts

4. **Insufficient RBAC Permissions**
   - Symptom: ASO can authenticate but cannot create/update resources
   - Solution: Verify Managed Identity has required Azure RBAC roles
   - Validation: Test with manual Azure CLI commands using the identity

### Debug Commands

```bash
# Get OIDC issuer URL
az aks show --resource-group <rg-name> --name <cluster-name> \
  --query "oidcIssuerProfile.issuerUrl" -o tsv

# Check workload identity webhook is running
kubectl get pods -n kube-system -l app=workload-identity-webhook

# Verify service account configuration
kubectl get serviceaccount azureserviceoperator-default \
  -n azureserviceoperator-system -o yaml

# Check projected token exists in pod
kubectl exec -n azureserviceoperator-system <pod-name> -- \
  cat /var/run/secrets/azure/tokens/azure-identity-token

# Verify federated identity credential
az identity federated-credential list \
  --identity-name <identity-name> \
  --resource-group <rg-name>

# Test authentication with Azure CLI using workload identity
# (from within ASO pod)
kubectl exec -n azureserviceoperator-system <pod-name> -- \
  az login --service-principal \
    -u <client-id> \
    -t <tenant-id> \
    --federated-token $(cat /var/run/secrets/azure/tokens/azure-identity-token)
```

## References

### Official Documentation

- [Azure Service Operator - Workload Identity](https://azure.github.io/azure-service-operator/guide/authentication/credential-format/#managed-identity-via-workload-identity)
- [Azure Workload Identity](https://azure.github.io/azure-workload-identity/)
- [AKS Workload Identity Overview](https://learn.microsoft.com/azure/aks/workload-identity-overview)
- [Use OIDC Issuer on AKS](https://learn.microsoft.com/azure/aks/use-oidc-issuer)

### Related Documentation

- [ASO Credential Scopes](https://azure.github.io/azure-service-operator/guide/authentication/credential-scope/)
- [ASO Controller Settings](https://azure.github.io/azure-service-operator/guide/aso-controller-settings-options/)
- [Azure Federated Identity Credentials](https://learn.microsoft.com/entra/workload-id/workload-identity-federation)

### Internal Documentation

- Migration Guide: `MIGRATION-GUIDE.md`
- Runbook: TBD
- Change Request Template: TBD

## Support

### Internal Contacts

- DevSecOps Team: [Contact Info]
- Cloud Architecture Team: [Contact Info]
- Security Team: [Contact Info]

### External Support

- Azure Support: https://azure.microsoft.com/support/
- ASO GitHub Issues: https://github.com/Azure/azure-service-operator/issues
- ASO Slack: https://kubernetes.slack.com/messages/azure-service-operator

---

**Document Version:** 1.0  
**Last Updated:** October 2025  
**Owner:** DevSecOps Engineering Team  
**Review Date:** Quarterly

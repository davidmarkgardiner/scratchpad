# Azure AKS Cross-Management Group Access Strategy

## Overview

Our investigation confirms we can leverage Workload Identity Federation to enable cross-management group access between our development and production environments while maintaining proper security boundaries.

## Key Findings

1. **Cross-Management Group Access**: Despite the management group separation, User-Assigned Managed Identities (UAMIs) can be configured to work across group boundaries through Workload Identity Federation.

2. **Shared Azure AD Tenant**: Since all management groups (Dev, Test, PreProd, Prod) exist within the same Azure AD tenant, identity federation is technically feasible.

3. **RBAC Assignment**: The Prod service workload client identity can be assigned to Dev clusters using client ID and workload identity federation while maintaining proper security boundaries.

## Implementation Strategy

### UAMI Configuration

We will use two User-Assigned Managed Identities:
- **Dev/Test UAMI**: For development and testing environments
- **PPD/PRD UAMI**: For pre-production and production environments

### ACR Access Configuration

For our two Azure Container Registries:
1. **Dev ACR**: Grant `AcrPush` permission to the Dev/Test UAMI
2. **Prod ACR**: Grant `AcrPush` permission to the PPD/PRD UAMI

### Cross-Environment Access

To enable the required cross-management group access:

1. Configure Workload Identity Federation between environments
2. Use the client ID of the service principal to establish trust
3. Apply specific RBAC permissions to limit scope of access

## Potential Concerns

- **Security Boundaries**: While technically possible, we must ensure proper governance around this access
- **Policy Compliance**: Verify no tenant-level policies prohibit this configuration
- **Audit Trail**: Implement thorough logging for cross-boundary access events
- **Least Privilege**: Ensure permissions are limited to only what's required

## Next Steps

1. Configure federation between the service principals and clusters
2. Test the ACR push functionality across management groups
3. Document the implementation for security review
4. Implement monitoring for cross-group access activity

This approach allows us to maintain our management group structure while addressing the immediate operational needs for container image deployment.
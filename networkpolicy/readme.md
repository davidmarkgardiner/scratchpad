# NetworkPolicy Update Process Guide

## Overview
This guide outlines the process for updating NetworkPolicy configurations to allow access between namespaces or SWCs (Software Components) in Kubernetes clusters.

## Prerequisites
- Access to ADO repository containing NetworkPolicy configurations
- Knowledge of target namespace/SWC details
- SWC Manager contact information from iSAC

## Process Steps

### 1. Identify Required Approvals
Before making any NetworkPolicy changes, you must obtain written approvals from:
- **Both SWC Managers** as defined in iSAC
- If the same person owns both SWCs, **one email approval is sufficient**

### 2. Request Approvals
Send an email request to the relevant SWC Manager(s) including:
- Description of the NetworkPolicy change
- Source and destination namespaces/SWCs
- Business justification for the access requirement
- Expected duration (if temporary)

### 3. Submit Change Request
Once approvals are obtained:
- Create a RITM (Request Item) for the change
- Include the approval email(s) in the RITM
- Provide clear description of the NetworkPolicy modification needed

### 4. C8S Team Validation
The C8S team will:
- Verify approvals match iSAC ownership records
- Add approval email(s) to the RITM
- Schedule the change implementation

### 5. Technical Implementation

#### NetworkPolicy Configuration
The NetworkPolicy will be updated in the ADO repository using the following template:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-atxxxxx
  namespace: atxxxx-ns
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          namespace: atxxxxx # will allow access from all swci with label
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: atxxxxx-allowed-ns # allowed ns name
```

#### Access Types
- **SWC-level access**: Use `namespace: atxxxxx` label to allow access from all namespaces within that SWC
- **Specific namespace access**: Use `kubernetes.io/metadata.name: atxxxxx-allowed-ns` for individual namespace access

### 6. Deployment
- Update the NetworkPolicy configuration in the ADO repository
- GitOps will automatically sync the changes with the cluster
- No manual cluster intervention required

## Important Notes

### Approval Requirements
- **Always** obtain written approval before proceeding
- Approvals must be from SWC Managers as defined in iSAC
- C8S team will validate ownership before implementation

### Technical Considerations
- Changes are applied through GitOps automation
- Updates to ADO repository trigger automatic cluster synchronization
- Both SWC-wide and namespace-specific access patterns are supported

### Best Practices
- Clearly document the business need for access
- Use least-privilege principle when defining access rules
- Include expected duration for temporary access requirements
- Maintain audit trail through RITM process

## Contact Information
For questions or issues with this process, contact:
- C8S Team for technical implementation
- iSAC for SWC ownership verification
- SWC Managers for approval requirements

## Revision History
- Initial version: Created from process documentation
- Last updated: [Current Date]
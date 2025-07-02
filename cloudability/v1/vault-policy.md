```
apiVersion: keyvault.azure.com/v1api20210401preview
kind: Vault
metadata:
  name: keyvault-basic-access-policies
  namespace: default
spec:
  location: eastus
  owner:
    name: sample-resource-group
  properties:
    tenantId: "12345678-1234-1234-1234-123456789012"
    sku:
      family: A
      name: standard
    # Basic Access Policy Examples
    accessPolicies:
      # Service Principal with full permissions
      - objectId: "87654321-4321-4321-4321-210987654321"
        tenantId: "12345678-1234-1234-1234-123456789012"
        permissions:
          keys:
            - get
            - list
            - create
            - delete
            - update
            - import
            - backup
            - restore
            - recover
            - purge
            - encrypt
            - decrypt
            - wrapKey
            - unwrapKey
            - sign
            - verify
          secrets:
            - get
            - list
            - set
            - delete
            - backup
            - restore
            - recover
            - purge
          certificates:
            - get
            - list
            - create
            - delete
            - update
            - import
            - backup
            - restore
            - recover
            - purge
            - managecontacts
            - manageissuers
            - getissuers
            - listissuers
            - setissuers
            - deleteissuers

      # User identity with read-only permissions
      - objectId: "11111111-2222-3333-4444-555555555555"
        tenantId: "12345678-1234-1234-1234-123456789012"
        permissions:
          keys:
            - get
            - list
          secrets:
            - get
            - list
          certificates:
            - get
            - list

      # Application with specific key operations
      - objectId: "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
        applicationId: "ffffffff-0000-1111-2222-333333333333"
        tenantId: "12345678-1234-1234-1234-123456789012"
        permissions:
          keys:
            - encrypt
            - decrypt
            - sign
            - verify
          secrets:
            - get
          certificates: []

---
apiVersion: keyvault.azure.com/v1api20210401preview
kind: Vault
metadata:
  name: keyvault-configmap-references
  namespace: default
spec:
  location: eastus
  owner:
    name: sample-resource-group
  properties:
    tenantId: "12345678-1234-1234-1234-123456789012"
    sku:
      family: A
      name: standard
    # Access Policies using ConfigMap References
    accessPolicies:
      # Service Principal with ObjectId from ConfigMap
      - objectIdFromConfig:
          name: sp-config
          key: objectId
        tenantIdFromConfig:
          name: tenant-config
          key: tenantId
        permissions:
          keys:
            - get
            - list
            - create
            - delete
            - update
          secrets:
            - get
            - list
            - set
            - delete
          certificates:
            - get
            - list
            - create
            - delete

      # Application with ApplicationId from ConfigMap
      - objectIdFromConfig:
          name: app-config
          key: servicePrincipalObjectId
        applicationIdFromConfig:
          name: app-config
          key: applicationId
        tenantId: "12345678-1234-1234-1234-123456789012"
        permissions:
          keys:
            - encrypt
            - decrypt
            - wrapKey
            - unwrapKey
          secrets:
            - get
            - set
          certificates: []

---
apiVersion: keyvault.azure.com/v1api20210401preview
kind: Vault
metadata:
  name: keyvault-role-based-access
  namespace: default
spec:
  location: eastus
  owner:
    name: sample-resource-group
  properties:
    tenantId: "12345678-1234-1234-1234-123456789012"
    sku:
      family: A
      name: premium
    # Role-Based Access Policy Matrix
    accessPolicies:
      # DevOps Team - Full Administrative Access
      - objectId: "devops-team-group-id-123456789"
        tenantId: "12345678-1234-1234-1234-123456789012"
        permissions:
          keys:
            - get
            - list
            - create
            - delete
            - update
            - import
            - backup
            - restore
            - recover
            - purge
            - encrypt
            - decrypt
            - wrapKey
            - unwrapKey
            - sign
            - verify
          secrets:
            - get
            - list
            - set
            - delete
            - backup
            - restore
            - recover
            - purge
          certificates:
            - get
            - list
            - create
            - delete
            - update
            - import
            - backup
            - restore
            - recover
            - purge
            - managecontacts
            - manageissuers
            - getissuers
            - listissuers
            - setissuers
            - deleteissuers

      # Development Team - Read/Write Access (No Delete)
      - objectId: "dev-team-group-id-987654321"
        tenantId: "12345678-1234-1234-1234-123456789012"
        permissions:
          keys:
            - get
            - list
            - create
            - update
            - encrypt
            - decrypt
            - wrapKey
            - unwrapKey
            - sign
            - verify
          secrets:
            - get
            - list
            - set
          certificates:
            - get
            - list
            - create
            - update

      # Production Application - Minimal Required Access
      - objectId: "prod-app-sp-id-555666777"
        applicationId: "prod-app-client-id-888999000"
        tenantId: "12345678-1234-1234-1234-123456789012"
        permissions:
          keys:
            - get
            - decrypt
            - verify
          secrets:
            - get
          certificates:
            - get

      # Backup Service - Backup/Restore Only
      - objectId: "backup-service-sp-id-111222333"
        tenantId: "12345678-1234-1234-1234-123456789012"
        permissions:
          keys:
            - backup
            - restore
            - list
          secrets:
            - backup
            - restore
            - list
          certificates:
            - backup
            - restore
            - list

      # Monitoring Service - Read-Only Access
      - objectId: "monitoring-sp-id-444555666"
        tenantId: "12345678-1234-1234-1234-123456789012"
        permissions:
          keys:
            - get
            - list
          secrets:
            - get
            - list
          certificates:
            - get
            - list

---
apiVersion: keyvault.azure.com/v1api20210401preview
kind: Vault
metadata:
  name: keyvault-encryption-focused
  namespace: default
spec:
  location: eastus
  owner:
    name: sample-resource-group
  properties:
    tenantId: "12345678-1234-1234-1234-123456789012"
    sku:
      family: A
      name: premium
    # Encryption-Focused Access Policies
    accessPolicies:
      # HSM Administrator - Premium Tier Features
      - objectId: "hsm-admin-id-123abc456def"
        tenantId: "12345678-1234-1234-1234-123456789012"
        permissions:
          keys:
            - get
            - list
            - create
            - delete
            - update
            - import
            - backup
            - restore
            - recover
            - purge
            - encrypt
            - decrypt
            - wrapKey
            - unwrapKey
            - sign
            - verify
            - release  # Premium tier only
            - rotate   # Premium tier only
            - getrotationpolicy
            - setrotationpolicy
          secrets:
            - get
            - list
            - set
            - delete
            - backup
            - restore
            - recover
            - purge
          certificates:
            - get
            - list
            - create
            - delete
            - update
            - import
            - backup
            - restore
            - recover
            - purge
            - managecontacts
            - manageissuers
            - getissuers
            - listissuers
            - setissuers
            - deleteissuers

      # Encryption Service - Key Operations Only
      - objectId: "encryption-service-sp-id-789xyz"
        applicationId: "encryption-app-client-id-abc123"
        tenantId: "12345678-1234-1234-1234-123456789012"
        permissions:
          keys:
            - encrypt
            - decrypt
            - wrapKey
            - unwrapKey
            - get
          secrets: []
          certificates: []

      # Signing Service - Digital Signatures
      - objectId: "signing-service-sp-id-456def"
        tenantId: "12345678-1234-1234-1234-123456789012"
        permissions:
          keys:
            - sign
            - verify
            - get
            - list
          secrets: []
          certificates:
            - get
            - list
            - sign

---
apiVersion: keyvault.azure.com/v1api20210401preview
kind: Vault
metadata:
  name: keyvault-certificate-management
  namespace: default
spec:
  location: eastus
  owner:
    name: sample-resource-group
  properties:
    tenantId: "12345678-1234-1234-1234-123456789012"
    sku:
      family: A
      name: standard
    # Certificate Management Access Policies
    accessPolicies:
      # Certificate Authority Administrator
      - objectId: "ca-admin-id-cert123456"
        tenantId: "12345678-1234-1234-1234-123456789012"
        permissions:
          keys:
            - get
            - list
            - create
            - delete
            - update
            - sign
            - veri
```

I'll create comprehensive examples for the **AccessPolicyEntry** configuration for Azure Key Vault, showing different scenarios and identity types.I've created comprehensive examples for **AccessPolicyEntry** configurations that demonstrate:

## Key Components of AccessPolicyEntry:

### **Required Fields:**
- **`objectId`**: Unique identifier for the user, service principal, or security group
- **`tenantId`**: Must match the Key Vault's tenant ID
- **`permissions`**: Defines what the identity can do with keys, secrets, and certificates

### **Optional Fields:**
- **`applicationId`**: For service principals acting on behalf of applications
- **`*FromConfig`**: References to ConfigMaps for dynamic configuration

## Access Policy Patterns:

**1. Role-Based Access Matrix**
- DevOps teams get full administrative access
- Development teams get read/write (no delete)
- Production apps get minimal required permissions
- Monitoring services get read-only access

**2. Encryption-Focused Policies**
- HSM administrators with premium tier features
- Encryption services with key operations only
- Signing services for digital signatures

**3. Certificate Management**
- CA administrators with full certificate lifecycle
- Web applications with SSL certificate access
- Certificate renewal services with update permissions

**4. Principle of Least Privilege**
- Database apps only get connection string secrets
- API clients only get specific API keys
- No unnecessary permissions granted

## Important Considerations:

**Tenant Restriction**: All identities in the access policies array must use the same tenant ID as the Key Vault's tenant ID.

**Permission Granularity**: You can specify exactly which operations are allowed for keys, secrets, and certificates independently.

**Premium Features**: Some permissions like `release` and `rotate` are only available with Premium tier Key Vaults.

**ConfigMap Integration**: Use `*FromConfig` properties to reference identities stored in ConfigMaps for better secret management.

The examples show real-world scenarios from basic access patterns to enterprise-grade security configurations with HSM integration and multi-role access matrices.
# AKS Authentication Guide: Service Principal Authentication

## Prerequisites
- `kubelogin` CLI tool installed
- Valid Azure Service Principal with appropriate permissions
- Access to AKS cluster with AAD integration enabled

## Important Notes
1. This authentication method only works with AKS clusters using managed Azure Active Directory
2. Service principals are limited to membership in maximum 200 AAD groups
3. Token will not be cached on the filesystem

## Authentication Methods

### 1. Using Client Secret via Environment Variables

#### Option A: AAD Environment Variables
```bash
# Set kubeconfig path
export KUBECONFIG=/path/to/kubeconfig

# Convert kubeconfig for service principal login
kubelogin convert-kubeconfig -l spn

# Set credentials
export AAD_SERVICE_PRINCIPAL_CLIENT_ID=<spn client id>
export AAD_SERVICE_PRINCIPAL_CLIENT_SECRET=<spn secret>

# Test connection
kubectl get nodes
```

#### Option B: Azure Environment Variables
```bash
# Set kubeconfig path
export KUBECONFIG=/path/to/kubeconfig

# Convert kubeconfig for service principal login
kubelogin convert-kubeconfig -l spn

# Set credentials
export AZURE_CLIENT_ID=<spn client id>
export AZURE_CLIENT_SECRET=<spn secret>

# Test connection
kubectl get nodes
```

### 2. Using Client Secret via Command Line
```bash
# Set kubeconfig path
export KUBECONFIG=/path/to/kubeconfig

# Convert kubeconfig and provide credentials
kubelogin convert-kubeconfig -l spn --client-id <spn client id> --client-secret <spn client secret>

# Test connection
kubectl get nodes
```

⚠️ **WARNING**: Using command line flags will expose secrets in the kubeconfig file

### 3. Using Client Certificate

#### Option A: AAD Environment Variables
```bash
# Set kubeconfig path
export KUBECONFIG=/path/to/kubeconfig

# Convert kubeconfig for service principal login
kubelogin convert-kubeconfig -l spn

# Set certificate credentials
export AAD_SERVICE_PRINCIPAL_CLIENT_ID=<spn client id>
export AAD_SERVICE_PRINCIPAL_CLIENT_CERTIFICATE=/path/to/cert.pfx
export AAD_SERVICE_PRINCIPAL_CLIENT_CERTIFICATE_PASSWORD=<pfx password>

# Test connection
kubectl get nodes
```

#### Option B: Azure Environment Variables
```bash
# Set kubeconfig path
export KUBECONFIG=/path/to/kubeconfig

# Convert kubeconfig for service principal login
kubelogin convert-kubeconfig -l spn

# Set certificate credentials
export AZURE_CLIENT_ID=<spn client id>
export AZURE_CLIENT_CERTIFICATE_PATH=/path/to/cert.pfx
export AZURE_CLIENT_CERTIFICATE_PASSWORD=<pfx password>

# Test connection
kubectl get nodes
```

### 4. Using Proof-of-Possession (PoP) Token
```bash
# Set kubeconfig path
export KUBECONFIG=/path/to/kubeconfig

# Convert kubeconfig with PoP settings
kubelogin convert-kubeconfig -l spn --pop-enabled --pop-claims "u=/ARM/ID/OF/CLUSTER"

# Set credentials
export AAD_SERVICE_PRINCIPAL_CLIENT_ID=<spn client id>
export AAD_SERVICE_PRINCIPAL_CLIENT_SECRET=<spn secret>

# Test connection
kubectl get nodes
```

## Troubleshooting

1. If authentication fails, verify:
   - Service principal credentials are correct
   - Service principal has appropriate RBAC permissions in AKS
   - KUBECONFIG path is correctly set
   - AAD integration is enabled on your AKS cluster

2. Common errors:
   - "Error: unable to get token": Check if credentials are correctly set
   - "Error: forbidden": Verify service principal has appropriate RBAC roles
   - "Error: certificate not found": Verify certificate path for client certificate auth

## Best Practices

1. Always use environment variables instead of command line flags for secrets
2. Rotate service principal credentials regularly
3. Use client certificates when possible instead of client secrets
4. Implement proper secret management in production environments
5. Monitor service principal access and audit logs regularly

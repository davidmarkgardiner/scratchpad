# Azure Key Vault PFX Certificate Sync with External Secrets Operator

This guide demonstrates how to sync PFX (PKCS#12) certificates from Azure Key Vault to Kubernetes using External Secrets Operator (ESO). This solution automatically extracts both certificates and their private keys from PFX files and creates standard Kubernetes TLS secrets.

## Prerequisites

- Kubernetes cluster with kubectl access
- Helm (for ESO installation)
- Azure subscription with Key Vault
- Permission to create Service Principals in Azure
- PFX certificate uploaded to Azure Key Vault

## Installation

### 1. Install External Secrets Operator

```bash
# Add the External Secrets helm repository
helm repo add external-secrets https://charts.external-secrets.io

# Install External Secrets Operator
helm install external-secrets external-secrets/external-secrets \
  --namespace external-secrets \
  --create-namespace
```

### 2. Create Azure Service Principal

```bash
# Set variables
AZURE_SUBSCRIPTION_ID="your-subscription-id"
KEYVAULT_NAME="your-keyvault-name"
RESOURCE_GROUP="your-resource-group"
SERVICE_PRINCIPAL_NAME="eso-keyvault-sp"

# Create Service Principal
SP_PASSWORD=$(az ad sp create-for-rbac --name $SERVICE_PRINCIPAL_NAME --query password --output tsv)
SP_APP_ID=$(az ad sp list --display-name $SERVICE_PRINCIPAL_NAME --query [].appId --output tsv)
TENANT_ID=$(az account show --query tenantId --output tsv)

# Store these values securely - you'll need them later
echo "Service Principal App ID: $SP_APP_ID"
echo "Service Principal Password: $SP_PASSWORD"
echo "Tenant ID: $TENANT_ID"

# Grant permissions to Key Vault
az keyvault set-policy --name $KEYVAULT_NAME --resource-group $RESOURCE_GROUP \
  --spn $SP_APP_ID \
  --secret-permissions get list \
  --certificate-permissions get list
```

## Configuration

### 1. Create Kubernetes Secret for Azure Credentials

Create a file named `azure-credentials.yaml`:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: azure-credentials
  namespace: default  # Adjust as needed
type: Opaque
data:
  # Base64 encoded values (use 'echo -n "value" | base64')
  clientId: <base64-encoded-client-id>
  clientSecret: <base64-encoded-client-secret>
```

Apply the secret:

```bash
kubectl apply -f azure-credentials.yaml
```

### 2. Create a SecretStore for Azure Key Vault

Create a file named `azure-secretstore.yaml`:

```yaml
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: azure-store
  namespace: default  # Adjust as needed
spec:
  provider:
    azurekv:
      authType: ServicePrincipal
      vaultUrl: https://<your-keyvault-name>.vault.azure.net
      tenantId: <your-tenant-id>
      authSecretRef:
        clientId:
          name: azure-credentials
          key: clientId
        clientSecret:
          name: azure-credentials
          key: clientSecret
```

Apply the SecretStore:

```bash
kubectl apply -f azure-secretstore.yaml
```

### 3. Create an ExternalSecret for your PFX Certificate

Create a file named `certificate-external-secret.yaml`:

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: pfx-certificate
  namespace: default  # Adjust as needed
spec:
  refreshInterval: 1h
  secretStoreRef:
    kind: SecretStore
    name: azure-store
  target:
    name: tls-certificate  # The name of the K8s Secret to be created
    template:
      type: kubernetes.io/tls
      engineVersion: v2
      data:
        tls.crt: "{{ .pfxcert | b64dec | pkcs12cert }}"
        tls.key: "{{ .pfxcert | b64dec | pkcs12key }}"
  data:
    - secretKey: pfxcert
      remoteRef:
        # IMPORTANT: Use "secret/" prefix for certificates in Azure Key Vault
        key: secret/my-certificate-name  # Replace with your certificate name
```

Apply the ExternalSecret:

```bash
kubectl apply -f certificate-external-secret.yaml
```

## Verification

Check if your ExternalSecret has been processed successfully:

```bash
kubectl get externalsecret pfx-certificate
```

If successful, it should show `SecretSynced` in the STATUS column.

Check the created Kubernetes Secret:

```bash
kubectl get secret tls-certificate
kubectl describe secret tls-certificate
```

## Usage

### Using as TLS Secret for Ingress

The created Secret can be used in your Kubernetes resources like Ingress, TLS-enabled services, etc:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: tls-example-ingress
  namespace: default
spec:
  tls:
  - hosts:
      - example.com
    secretName: tls-certificate  # The Secret created by ESO
  rules:
  - host: example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: example-service
            port:
              number: 80
```

### Mounting Secret Data as Files in a Pod

You can also mount the certificate and private key as files in your pods:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: certificate-consumer
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: certificate-consumer
  template:
    metadata:
      labels:
        app: certificate-consumer
    spec:
      containers:
      - name: app
        image: your-application-image
        volumeMounts:
        - name: certificate-volume
          mountPath: /etc/certs
          readOnly: true
      volumes:
      - name: certificate-volume
        secret:
          secretName: tls-certificate  # The Secret created by ESO
```

This will mount the certificate and key as files under `/etc/certs/`:
- `/etc/certs/tls.crt` - The certificate in PEM format
- `/etc/certs/tls.key` - The private key in PEM format

### Mounting the Secret as a PFX File

If you need to mount the original PFX file format instead of the extracted PEM files, you can modify your ExternalSecret to preserve the PFX format:

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: pfx-certificate-raw
  namespace: default
spec:
  refreshInterval: 1h
  secretStoreRef:
    kind: SecretStore
    name: azure-store
  target:
    name: pfx-certificate-raw
  data:
    - secretKey: certificate.pfx  # This will be the filename when mounted
      remoteRef:
        key: secret/my-certificate-name
```

Then mount it in your pod:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: pfx-certificate-consumer
spec:
  template:
    spec:
      containers:
      - name: app
        volumeMounts:
        - name: pfx-volume
          mountPath: /etc/certs
          readOnly: true
      volumes:
      - name: pfx-volume
        secret:
          secretName: pfx-certificate-raw
```

This will create a file at `/etc/certs/certificate.pfx` containing the raw PFX data.

## Password-Protected PFX Files

If your PFX file is password-protected, modify the ExternalSecret to use the password-enabled functions:

```yaml
template:
  data:
    tls.crt: "{{ .pfxcert | b64dec | pkcs12certPass \"your-pfx-password\" }}"
    tls.key: "{{ .pfxcert | b64dec | pkcs12keyPass \"your-pfx-password\" }}"
```

## Troubleshooting

### Common Issues

1. **Secret Not Created**: Check the ESO controller logs:
   ```bash
   kubectl logs -n external-secrets -l app.kubernetes.io/name=external-secrets
   ```

2. **Authentication Failures**: Verify your Service Principal has proper permissions on the Key Vault.

3. **Certificate Not Found**: Ensure you're using the correct `secret/` prefix for certificates in Azure Key Vault.

4. **Invalid PFX Format**: Ensure your PFX file is correctly formatted. You may need to recreate it.

5. **Volume Mount Issues**: If the mounted files are empty or incorrect, check that the Secret was created properly:
   ```bash
   kubectl get secret tls-certificate -o yaml
   ```
   
6. **Permission Issues with Mounted Files**: The default permissions for mounted Secret files are 0644. If you need different permissions, use the `defaultMode` field in your volume definition:
   ```yaml
   volumes:
   - name: certificate-volume
     secret:
       secretName: tls-certificate
       defaultMode: 0600  # More restrictive permissions
   ```

### Testing Certificate Access

To verify ESO can access your certificate, check the Azure Service Principal permissions:

```bash
az keyvault list-permissions -n <your-keyvault-name> --query "[?principalId=='<service-principal-object-id>']"
```

## Benefits

- **Automated Sync**: Certificates are automatically synced based on the refresh interval
- **Format Conversion**: Automatic conversion from PFX to PEM format
- **Secret Rotation**: Certificates are updated in Kubernetes when renewed in Key Vault
- **Centralized Management**: Manage certificates in Azure Key Vault, consume in Kubernetes
- **Flexible Usage**: Can be used as TLS secrets for ingress or mounted as files in pods
- **Format Options**: Mount as PEM files or preserve the original PFX format

## Additional Resources

- [External Secrets Operator Documentation](https://external-secrets.io/latest/)
- [Azure Key Vault Provider for ESO](https://external-secrets.io/latest/provider/azure-key-vault/)
- [Kubernetes TLS Secrets](https://kubernetes.io/docs/concepts/configuration/secret/#tls-secrets)
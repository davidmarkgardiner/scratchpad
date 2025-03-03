# Kubernetes Gateway API with Azure Private DNS

This README explains how to deploy a dedicated Gateway API configuration with HTTPRoute, ReferenceGrant, secrets, and certificates to allow application access using Azure Private DNS. We use External Secrets and cert-manager to help manage certificates and secrets.

## Architecture Overview

Our setup uses the following components:
- **Gateway API**: For traffic routing and load balancing
- **HTTPRoute**: For HTTP-specific routing rules
- **ReferenceGrant**: For cross-namespace references
- **cert-manager**: For certificate management and issuance
- **External Secrets**: For secure secrets management from external providers
- **Azure Private DNS**: For private DNS resolution

## Components Explained

### 1. Gateway API

The Gateway API consists of three main resource types:

- **GatewayClass**: Defines the controller implementation to use (similar to IngressClass)
- **Gateway**: Defines the actual gateway deployment for traffic handling
- **HTTPRoute**: Defines HTTP routing rules to direct traffic

### 2. cert-manager

cert-manager handles certificate issuance and renewal. It:
- Requests certificates from a Certificate Authority (CA)
- Stores them as Kubernetes secrets
- Handles automatic renewal before expiration

### 3. External Secrets

External Secrets fetches secrets from external providers like Azure Key Vault and makes them available as Kubernetes secrets. This provides:
- Centralized secret management
- Improved security
- Version control for secrets

### 4. Azure Private DNS

Azure Private DNS provides:
- Private DNS resolution within your Azure Virtual Network
- Integration with your Kubernetes services
- Name resolution that isn't publicly accessible

## Deployment Steps

### 1. Install Required Controllers

```bash
# Install Gateway API CRDs
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.0.0/standard-install.yaml

# Install cert-manager
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set installCRDs=true

# Install External Secrets Operator
helm repo add external-secrets https://charts.external-secrets.io
helm repo update
helm install external-secrets external-secrets/external-secrets \
  --namespace external-secrets \
  --create-namespace
```

### 2. Configure External Secrets Provider

This connects External Secrets to Azure Key Vault:

```yaml
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: azure-secret-store
  namespace: your-app-namespace
spec:
  provider:
    azurekv:
      tenantId: "${AZURE_TENANT_ID}"
      vaultUrl: "https://your-keyvault.vault.azure.net/"
      authSecretRef:
        clientId:
          name: azure-secret-creds
          key: client-id
        clientSecret:
          name: azure-secret-creds
          key: client-secret
```

### 3. Create External Secret Reference

This pulls your TLS certificate information from Azure Key Vault:

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: tls-cert-secret
  namespace: your-app-namespace
spec:
  secretStoreRef:
    name: azure-secret-store
    kind: SecretStore
  target:
    name: tls-cert-secret
  data:
  - secretKey: tls.crt
    remoteRef:
      key: app-tls-cert
  - secretKey: tls.key
    remoteRef:
      key: app-tls-key
```

### 4. Configure cert-manager Issuer (Alternative to External Secrets)

If you prefer to generate certificates with cert-manager:

```yaml
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: letsencrypt-issuer
  namespace: your-app-namespace
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@example.com
    privateKeySecretRef:
      name: letsencrypt-account-key
    solvers:
    - http01:
        ingress:
          class: gateway-api
```

### 5. Create Certificate Resource

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: app-tls-cert
  namespace: your-app-namespace
spec:
  secretName: tls-cert-secret
  issuerRef:
    name: letsencrypt-issuer
    kind: Issuer
  dnsNames:
  - app.internal.example.com
```

### 6. Create GatewayClass

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: azure-gateway-class
spec:
  controllerName: azure.com/gateway-controller
```

### 7. Create Gateway

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: app-gateway
  namespace: gateway-system
spec:
  gatewayClassName: azure-gateway-class
  listeners:
  - name: https
    protocol: HTTPS
    port: 443
    tls:
      mode: Terminate
      certificateRefs:
      - name: tls-cert-secret
        namespace: your-app-namespace
```

### 8. Create ReferenceGrant

This allows the Gateway in one namespace to reference secrets in your app namespace:

```yaml
apiVersion: gateway.networking.k8s.io/v1beta1
kind: ReferenceGrant
metadata:
  name: allow-gateway-cert-access
  namespace: your-app-namespace
spec:
  from:
  - group: gateway.networking.k8s.io
    kind: Gateway
    namespace: gateway-system
  to:
  - group: ""
    kind: Secret
    name: tls-cert-secret
```

### 9. Create HTTPRoute

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: app-route
  namespace: your-app-namespace
spec:
  parentRefs:
  - name: app-gateway
    namespace: gateway-system
  hostnames:
  - "app.internal.example.com"
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
    - name: app-service
      port: 8080
```

### 10. Configure Azure Private DNS

Create a Private DNS Zone in Azure and link it to your Virtual Network:

```bash
# Create Private DNS Zone
az network private-dns zone create \
  --resource-group your-resource-group \
  --name internal.example.com

# Link to VNet
az network private-dns link vnet create \
  --resource-group your-resource-group \
  --zone-name internal.example.com \
  --name dns-link \
  --virtual-network your-vnet \
  --registration-enabled false

# Add DNS record
az network private-dns record-set a add-record \
  --resource-group your-resource-group \
  --zone-name internal.example.com \
  --record-set-name app \
  --ipv4-address $(kubectl get gateway app-gateway -n gateway-system -o jsonpath='{.status.addresses[0].value}')
```

## Troubleshooting

- Verify Gateway status: `kubectl get gateway -A`
- Check HTTPRoute status: `kubectl get httproute -A`
- Inspect certificate: `kubectl get certificate -n your-app-namespace`
- Verify secret creation: `kubectl get secret tls-cert-secret -n your-app-namespace`
- Check External Secret: `kubectl get externalsecret -n your-app-namespace`
- View Gateway events: `kubectl describe gateway app-gateway -n gateway-system`
- View HTTPRoute events: `kubectl describe httproute app-route -n your-app-namespace`

## Additional Resources

- [Gateway API Documentation](https://gateway-api.sigs.k8s.io/)
- [cert-manager Documentation](https://cert-manager.io/docs/)
- [External Secrets Operator](https://external-secrets.io/latest/)
- [Azure Private DNS Documentation](https://docs.microsoft.com/en-us/azure/dns/private-dns-overview)
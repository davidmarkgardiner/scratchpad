# Kubernetes Gateway API with Istio on AKS and Azure Private DNS

This README explains how to deploy a dedicated Gateway API configuration with Istio on AKS, including HTTPRoute, ReferenceGrant, secrets, and certificates to allow application access using Azure Private DNS. We use External Secrets and cert-manager to help manage certificates and secrets.

## Architecture Overview

Our setup uses the following components:
- **Gateway API**: For traffic routing and load balancing
- **Istio**: As the Gateway API implementation (via AKS add-on)
- **HTTPRoute**: For HTTP-specific routing rules
- **ReferenceGrant**: For cross-namespace references
- **cert-manager**: For certificate management and issuance
- **External Secrets**: For secure secrets management from external providers
- **Azure Private DNS**: For private DNS resolution

### Istio Integration

Specifying `gatewayClassName: istio` in your Gateway resource means:
- You're using Istio's implementation of the Gateway API specification
- The AKS Istio add-on provides the controller that watches and implements these resources
- Under the hood, Istio creates its own resources (VirtualServices, Gateways) that correspond to your Gateway API resources
- You get all the benefits of Istio's service mesh capabilities alongside standard Gateway API resources

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

# Enable Istio add-on for AKS
az aks mesh enable --resource-group myResourceGroup --name myAKSCluster 

# Verify Istio installation
kubectl get pods -n aks-istio-system

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

> **Note**: The `az aks mesh enable` command enables the AKS Istio add-on, which provides the Istio-based Gateway API implementation.

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

### 6. Using the Istio GatewayClass

When using the AKS Istio add-on, the `istio` GatewayClass is automatically created for you. You can verify it with:

```bash
kubectl get gatewayclass istio -o yaml
```

You should see output like:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: istio
spec:
  controllerName: istio.io/gateway-controller
  description: The Istio GatewayClass
status:
  conditions:
  - lastTransitionTime: "2023-01-01T00:00:00Z"
    message: "Accepted"
    reason: "Accepted"
    status: "True"
    type: "Accepted"
```

### 7. Create Gateway Using Istio

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: app-gateway
  namespace: gateway-system
spec:
  gatewayClassName: istio # Use Istio's Gateway implementation
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

> **How this works**: When you create this Gateway, the Istio controller automatically creates an Istio Gateway resource and sets up the necessary Envoy proxies to handle traffic. It will also create an Azure Load Balancer to expose your Gateway externally.

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

> **Behind the scenes**: When this HTTPRoute is created, Istio creates a corresponding VirtualService resource that configures the Envoy proxies to route traffic according to these rules. You can see this Istio resource with:
> 
> ```bash
> kubectl get virtualservices -n your-app-namespace
> ```

### 9.1 Advanced Istio-specific Routing (Optional)

For more advanced use cases that might not be fully covered by the Gateway API standard, you can add Istio-specific annotations:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: app-route-advanced
  namespace: your-app-namespace
  annotations:
    istio.io/service-account: "app-service-account"
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
        value: /api
    backendRefs:
    - name: api-service
      port: 8080
      weight: 90
    - name: api-service-canary
      port: 8080
      weight: 10
```

This example shows traffic splitting between production and canary versions, which is fully supported by Istio's implementation.

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

### Gateway API Resources
- Verify Gateway status: `kubectl get gateway -A`
- Check HTTPRoute status: `kubectl get httproute -A`
- View Gateway events: `kubectl describe gateway app-gateway -n gateway-system`
- View HTTPRoute events: `kubectl describe httproute app-route -n your-app-namespace`

### Istio Resources
- Check Istio Gateway status: `kubectl get istio-gateway -A`
- Check Istio VirtualServices: `kubectl get virtualservices -A`
- Check Istio pods: `kubectl get pods -n aks-istio-system`
- View Istio logs: `kubectl logs -n aks-istio-system deploy/istiod`
- Check Envoy configuration: `istioctl proxy-config routes deploy/app-deployment`

### Certificate and Secret Resources
- Inspect certificate: `kubectl get certificate -n your-app-namespace`
- Verify secret creation: `kubectl get secret tls-cert-secret -n your-app-namespace`
- Check External Secret: `kubectl get externalsecret -n your-app-namespace`

## Additional Resources

- [Gateway API Documentation](https://gateway-api.sigs.k8s.io/)
- [Istio Documentation](https://istio.io/latest/docs/)
- [AKS Istio Add-on Documentation](https://learn.microsoft.com/en-us/azure/aks/istio-about)
- [cert-manager Documentation](https://cert-manager.io/docs/)
- [External Secrets Operator](https://external-secrets.io/latest/)
- [Azure Private DNS Documentation](https://docs.microsoft.com/en-us/azure/dns/private-dns-overview)

## Istio vs Other Gateway API Implementations

When choosing `gatewayClassName: istio` on AKS, you're selecting Istio's implementation of the Gateway API. Here's how it compares to alternatives:

| Feature | Istio Gateway | Azure Application Gateway | NGINX Gateway |
|---------|---------------|---------------------------|---------------|
| AKS Add-on | Yes (AKS Istio add-on) | Yes (AGIC add-on) | No (needs manual install) |
| Service Mesh | Full mesh functionality | No | No |
| Advanced Traffic Management | Rich traffic splitting, mirroring | Basic | Basic |
| Azure Integration | Uses Azure Load Balancer | Deep integration with WAF, etc. | Uses Azure Load Balancer |
| Performance | Lightweight | Higher resource usage | Lightweight |

Choose Istio when you need advanced service mesh capabilities beyond basic Gateway functionality.
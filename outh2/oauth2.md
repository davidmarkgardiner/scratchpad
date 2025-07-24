# OAuth2-Proxy Integration with AKS, Workload Identity & Istio

This guide demonstrates how to deploy OAuth2-proxy on Azure Kubernetes Service (AKS) using Azure AD Workload Identity and Istio service mesh for secure application authentication.

## Prerequisites

- AKS cluster with Workload Identity enabled
- Istio service mesh installed and configured
- Azure AD tenant with application registration permissions
- `kubectl` and `helm` CLI tools configured
- Azure CLI installed and authenticated

## Architecture Overview

```
Internet → Istio Gateway → OAuth2-Proxy → Protected Application
                    ↓
            Azure AD (Authentication)
```

OAuth2-proxy handles authentication with Azure AD using Workload Identity (no stored secrets), while Istio manages traffic routing and security policies.

## Step 1: Enable Required Features

### Enable Workload Identity on AKS
```bash
# Create resource group
az group create --name myResourceGroup --location eastus

# Create AKS cluster with Workload Identity
az aks create \
    --resource-group myResourceGroup \
    --name myAKSCluster \
    --enable-oidc-issuer \
    --enable-workload-identity \
    --generate-ssh-keys

# Get cluster credentials
az aks get-credentials --resource-group myResourceGroup --name myAKSCluster
```

### Install Istio
```bash
# Install Istio using istioctl
curl -L https://istio.io/downloadIstio | sh -
export PATH=$PWD/istio-*/bin:$PATH

# Install Istio
istioctl install --set values.defaultRevision=default

# Enable Istio injection for default namespace
kubectl label namespace default istio-injection=enabled
```

## Step 2: Azure AD Configuration

### Create Azure AD Application
```bash
# Create Azure AD application
az ad app create \
    --display-name "oauth2-proxy-aks" \
    --web-redirect-uris "https://your-domain.com/oauth2/callback"

# Get application details
APP_ID=$(az ad app list --display-name "oauth2-proxy-aks" --query "[0].appId" -o tsv)
TENANT_ID=$(az account show --query tenantId -o tsv)

# Create client secret (note: we'll replace this with Workload Identity)
az ad app credential reset --id $APP_ID --query password -o tsv
```

### Create Managed Identity
```bash
# Create managed identity
az identity create --name oauth2-proxy-identity --resource-group myResourceGroup

# Get identity details
IDENTITY_CLIENT_ID=$(az identity show --name oauth2-proxy-identity --resource-group myResourceGroup --query clientId -o tsv)
IDENTITY_OBJECT_ID=$(az identity show --name oauth2-proxy-identity --resource-group myResourceGroup --query principalId -o tsv)

# Get OIDC issuer URL
OIDC_ISSUER=$(az aks show --resource-group myResourceGroup --name myAKSCluster --query "oidcIssuerProfile.issuerUrl" -o tsv)
```

### Configure Federated Identity Credential
```bash
# Create federated identity credential
az identity federated-credential create \
    --name oauth2-proxy-federated-credential \
    --identity-name oauth2-proxy-identity \
    --resource-group myResourceGroup \
    --issuer $OIDC_ISSUER \
    --subject system:serviceaccount:default:oauth2-proxy-sa
```

## Step 3: Deploy OAuth2-Proxy

### Create Service Account
```yaml
# oauth2-proxy-serviceaccount.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: oauth2-proxy-sa
  namespace: default
  annotations:
    azure.workload.identity/client-id: "${IDENTITY_CLIENT_ID}"
  labels:
    azure.workload.identity/use: "true"
```

### Create ConfigMap
```yaml
# oauth2-proxy-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: oauth2-proxy-config
data:
  oauth2_proxy.cfg: |
    provider = "azure"
    azure_tenant = "${TENANT_ID}"
    client_id = "${APP_ID}"
    oidc_issuer_url = "https://login.microsoftonline.com/${TENANT_ID}/v2.0"
    redirect_url = "https://your-domain.com/oauth2/callback"
    upstreams = ["http://sample-app:80"]
    http_address = "0.0.0.0:4180"
    email_domains = ["*"]
    cookie_secure = true
    cookie_httponly = true
    cookie_samesite = "lax"
    set_xauthrequest = true
    pass_access_token = true
    pass_user_headers = true
```

### Create Secret for Cookie
```bash
# Generate random cookie secret
kubectl create secret generic oauth2-proxy-secret \
    --from-literal=cookie-secret=$(python3 -c 'import secrets,base64; print(base64.b64encode(secrets.token_bytes(32)).decode())')
```

### Deploy OAuth2-Proxy
```yaml
# oauth2-proxy-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: oauth2-proxy
  labels:
    app: oauth2-proxy
spec:
  replicas: 2
  selector:
    matchLabels:
      app: oauth2-proxy
  template:
    metadata:
      labels:
        app: oauth2-proxy
        azure.workload.identity/use: "true"
    spec:
      serviceAccountName: oauth2-proxy-sa
      containers:
      - name: oauth2-proxy
        image: quay.io/oauth2-proxy/oauth2-proxy:v7.4.0
        args:
        - --config=/etc/oauth2_proxy/oauth2_proxy.cfg
        env:
        - name: OAUTH2_PROXY_CLIENT_SECRET
          value: "not-needed-with-workload-identity"
        - name: OAUTH2_PROXY_COOKIE_SECRET
          valueFrom:
            secretKeyRef:
              name: oauth2-proxy-secret
              key: cookie-secret
        ports:
        - containerPort: 4180
          name: http
        volumeMounts:
        - name: config
          mountPath: /etc/oauth2_proxy
        livenessProbe:
          httpGet:
            path: /ping
            port: http
          initialDelaySeconds: 30
        readinessProbe:
          httpGet:
            path: /ping
            port: http
          initialDelaySeconds: 5
      volumes:
      - name: config
        configMap:
          name: oauth2-proxy-config
---
apiVersion: v1
kind: Service
metadata:
  name: oauth2-proxy
spec:
  selector:
    app: oauth2-proxy
  ports:
  - port: 4180
    targetPort: 4180
    name: http
```

## Step 4: Configure Istio

### Create Gateway
```yaml
# istio-gateway.yaml
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: oauth2-proxy-gateway
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 443
      name: https
      protocol: HTTPS
    tls:
      mode: SIMPLE
      credentialName: your-tls-secret
    hosts:
    - your-domain.com
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - your-domain.com
    redirect:
      httpsRedirect: true
```

### Create Virtual Service
```yaml
# istio-virtualservice.yaml
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: oauth2-proxy-vs
spec:
  hosts:
  - your-domain.com
  gateways:
  - oauth2-proxy-gateway
  http:
  # OAuth2-proxy authentication endpoints
  - match:
    - uri:
        prefix: /oauth2
    route:
    - destination:
        host: oauth2-proxy
        port:
          number: 4180
  # Protected application routes
  - match:
    - uri:
        prefix: /
    route:
    - destination:
        host: oauth2-proxy
        port:
          number: 4180
```

### Create Authorization Policy
```yaml
# istio-authz-policy.yaml
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: oauth2-proxy-authz
spec:
  selector:
    matchLabels:
      app: sample-app
  rules:
  - from:
    - source:
        principals: ["cluster.local/ns/default/sa/oauth2-proxy-sa"]
  - when:
    - key: request.headers[x-forwarded-user]
      values: ["*"]
```

## Step 5: Deploy Sample Application

```yaml
# sample-app.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sample-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: sample-app
  template:
    metadata:
      labels:
        app: sample-app
    spec:
      containers:
      - name: sample-app
        image: nginx:alpine
        ports:
        - containerPort: 80
        volumeMounts:
        - name: html
          mountPath: /usr/share/nginx/html
      volumes:
      - name: html
        configMap:
          name: sample-app-html
---
apiVersion: v1
kind: Service
metadata:
  name: sample-app
spec:
  selector:
    app: sample-app
  ports:
  - port: 80
    targetPort: 80
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: sample-app-html
data:
  index.html: |
    <!DOCTYPE html>
    <html>
    <head><title>Protected App</title></head>
    <body>
      <h1>Hello! You are authenticated!</h1>
      <p>User: <span id="user"></span></p>
      <script>
        // OAuth2-proxy sets user info in headers
        fetch('/oauth2/userinfo')
          .then(r => r.json())
          .then(data => document.getElementById('user').textContent = data.email);
      </script>
    </body>
    </html>
```

## Step 6: Deploy All Resources

```bash
# Apply all configurations (replace environment variables first)
envsubst < oauth2-proxy-serviceaccount.yaml | kubectl apply -f -
envsubst < oauth2-proxy-config.yaml | kubectl apply -f -
kubectl apply -f oauth2-proxy-deployment.yaml
kubectl apply -f istio-gateway.yaml
kubectl apply -f istio-virtualservice.yaml
kubectl apply -f istio-authz-policy.yaml
kubectl apply -f sample-app.yaml
```

## Step 7: Configure DNS and TLS

```bash
# Get Istio ingress gateway external IP
kubectl get svc istio-ingressgateway -n istio-system

# Create TLS secret (replace with your certificate)
kubectl create secret tls your-tls-secret \
    --cert=path/to/cert.pem \
    --key=path/to/key.pem
```

## Verification

1. **Check pod status:**
   ```bash
   kubectl get pods
   kubectl logs -l app=oauth2-proxy
   ```

2. **Verify Workload Identity:**
   ```bash
   kubectl describe pod -l app=oauth2-proxy
   # Look for azure.workload.identity annotations and environment variables
   ```

3. **Test authentication:**
   ```bash
   curl -I https://your-domain.com/
   # Should redirect to Azure AD login
   ```

4. **Check Istio configuration:**
   ```bash
   istioctl proxy-config cluster oauth2-proxy-deployment.default
   istioctl analyze
   ```

## Troubleshooting

### Common Issues

1. **Authentication failures:**
   - Verify Azure AD app registration redirect URLs
   - Check federated identity credential configuration
   - Ensure OIDC issuer URL is correct

2. **Workload Identity not working:**
   - Verify service account annotations
   - Check pod has correct labels
   - Ensure federated credential subject matches exactly

3. **Istio routing issues:**
   - Check gateway and virtual service configuration
   - Verify authorization policies
   - Use `istioctl proxy-config` to debug

### Useful Commands

```bash
# Check Workload Identity
kubectl describe federatedidentity

# Debug OAuth2-proxy
kubectl logs -l app=oauth2-proxy -f

# Istio debugging
istioctl proxy-status
istioctl proxy-config listener oauth2-proxy-deployment.default

# Check authentication flow
kubectl port-forward svc/oauth2-proxy 4180:4180
```

## Security Considerations

- Regular rotation of cookie secrets
- Proper TLS certificate management
- Network policies for traffic restriction
- Resource limits and requests
- Regular security updates for all components
- Monitor authentication logs for suspicious activity

## Monitoring

Consider integrating with:
- Azure Monitor for AKS
- Istio observability features (Grafana, Jaeger, Kiali)
- Prometheus for custom metrics
- Azure AD audit logs

## References

- [Azure AD Workload Identity](https://azure.github.io/azure-workload-identity/)
- [OAuth2-proxy Documentation](https://oauth2-proxy.github.io/oauth2-proxy/)
- [Istio Security](https://istio.io/latest/docs/concepts/security/)
- [AKS Documentation](https://docs.microsoft.com/en-us/azure/aks/)
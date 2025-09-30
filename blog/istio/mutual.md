Perfect! Now I can see your setup clearly. You're using **cert-manager** with a custom `ClusterIssuer` called `ubs-issuer`. This changes everything.

## The Solution for Your Setup

Since you're using cert-manager with a custom issuer, you need to get the **CA certificate from your `ubs-issuer`**. Here's how:

### Step 1: Find Your ClusterIssuer Configuration

```bash
kubectl get clusterissuer ubs-issuer -o yaml
```

Look for the CA certificate reference. It's typically stored in a Secret. You might see something like:

```yaml
spec:
  ca:
    secretName: ubs-ca-secret  # <-- This contains your CA cert
```

### Step 2: Extract the CA Certificate

Once you find the CA secret name from the ClusterIssuer:

```bash
# Replace 'ubs-ca-secret' with the actual secret name from your ClusterIssuer
kubectl get secret ubs-ca-secret -n <namespace> -o jsonpath='{.data.tls\.crt}' | base64 -d > ca-cert.pem

# Or it might be under 'ca.crt' key:
kubectl get secret ubs-ca-secret -n <namespace> -o jsonpath='{.data.ca\.crt}' | base64 -d > ca-cert.pem
```

### Step 3: Create the New Secret with CA

```bash
# Extract your existing server cert and key
kubectl get secret wildcard-cert -n aks-istio-ingress -o jsonpath='{.data.tls\.crt}' | base64 -d > server-cert.pem
kubectl get secret wildcard-cert -n aks-istio-ingress -o jsonpath='{.data.tls\.key}' | base64 -d > server-key.pem

# Create new secret with CA included
kubectl create secret generic wildcard-cert-with-ca \
  -n aks-istio-ingress \
  --from-file=tls.key=server-key.pem \
  --from-file=tls.crt=server-cert.pem \
  --from-file=cacert=ca-cert.pem
```

### Step 4: Update Gateway to Use New Secret

```yaml
apiVersion: networking.istio.io/v1
kind: Gateway
metadata:
  name: gateway-wildcard
  namespace: aks-istio-ingress
spec:
  selector:
    istio: aks-istio-ingressgateway-internal
  servers:
  - hosts:
    - "*"
    port:
      name: https
      number: 443
      protocol: HTTPS
    tls:
      mode: OPTIONAL_MUTUAL
      credentialName: wildcard-cert-with-ca  # Changed from wildcard-cert
```

## Important Consideration

**Question for you:** Are your client certificates also issued by the same `ubs-issuer` CA? 

- **If YES**: The above solution will work perfectly
- **If NO**: You need to add the CA certificate that **issued your client certificates** instead

This is critical because the `cacert` must be the CA that signed the **client** certificates, not necessarily the same CA that signed your server certificate.

**Can you confirm:**
1. What's the namespace where your `ubs-issuer` ClusterIssuer stores its CA secret?
2. Are the clients presenting certificates also issued by this same UBS CA, or from a different source?
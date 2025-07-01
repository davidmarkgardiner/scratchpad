Looking at your Gateway configuration, I can see that it's stuck in a "Waiting for controller" state, which suggests the Istio control plane isn't properly recognizing or processing the Gateway resource in ASM versions 124 and 125.

Here are the most likely causes and troubleshooting steps:

## Check Istio Control Plane Status

First, verify the Istio control plane is healthy:
```bash
kubectl get pods -n aks-istio-system
kubectl logs -n aks-istio-system deployment/istiod
```

## Common Issues with ASM 124/125

**Gateway API Version Compatibility**: ASM 124/125 might have stricter validation or different Gateway API support. Check if your cluster has the correct Gateway API CRDs:
```bash
kubectl get crd gateways.gateway.networking.k8s.io -o yaml | grep -A5 -B5 version
```

**Cross-Namespace Certificate Reference**: Your Gateway references a certificate in namespace `at39473-dev-app` while the Gateway is in `aks-istio-ingress`. This might be causing issues in newer ASM versions due to enhanced security policies.

## Potential Solutions

**1. Move the certificate to the same namespace:**
```bash
kubectl get secret tls-certificate -n at39473-dev-app -o yaml | \
  sed 's/namespace: at39473-dev-app/namespace: aks-istio-ingress/' | \
  kubectl apply -f -
```

**2. Use a ReferenceGrant (if supported):**
```yaml
apiVersion: gateway.networking.k8s.io/v1beta1
kind: ReferenceGrant
metadata:
  name: allow-gateway-cert-ref
  namespace: at39473-dev-app
spec:
  from:
  - group: gateway.networking.k8s.io
    kind: Gateway
    namespace: aks-istio-ingress
  to:
  - group: ""
    kind: Secret
```

**3. Check for ASM-specific configuration requirements:**
```bash
kubectl describe gatewayclass istio
kubectl get pods -n aks-istio-system -l app=istiod -o yaml | grep -i version
```

**4. Verify the internal load balancer service exists:**
```bash
kubectl get svc aks-istio-ingressgateway-internal -n aks-istio-ingress
```

The fact that it works in ASM 123 but not 124/125 suggests a breaking change or stricter validation was introduced. The cross-namespace certificate reference is the most likely culprit, as this is a common area where security policies get tightened in newer versions.

What do you see when you check the Istio control plane logs and the certificate location?
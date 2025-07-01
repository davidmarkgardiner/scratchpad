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



---

Since moving the secret didn't help and there's nothing in the logs, let's dig deeper into the specific differences between ASM versions and check some other potential issues.

## Check Gateway API CRD Versions

The Gateway API CRDs might have changed between ASM versions:

```bash
# Check what Gateway API version is installed
kubectl get crd gateways.gateway.networking.k8s.io -o jsonpath='{.spec.versions[*].name}'

# Compare with what's expected for ASM 124/125
kubectl get crd gateways.gateway.networking.k8s.io -o yaml | grep -A10 -B5 "v1\|v1beta1"
```

## Check GatewayClass Status

```bash
kubectl describe gatewayclass istio
kubectl get gatewayclass istio -o yaml
```

## Verify Istio Controller Recognition

```bash
# Check if the istiod controller is watching Gateways
kubectl logs -n aks-istio-system deployment/istiod | grep -i gateway

# Check istiod configuration
kubectl get configmap istio -n aks-istio-system -o yaml | grep -A5 -B5 "gateway\|controller"
```

## Try a Minimal Gateway Test

Create a simple test Gateway to isolate the issue:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: test-gateway
  namespace: aks-istio-ingress
spec:
  gatewayClassName: istio
  listeners:
  - name: http
    port: 80
    protocol: HTTP
    allowedRoutes:
      namespaces:
        from: All
```

```bash
kubectl apply -f test-gateway.yaml
kubectl describe gateway test-gateway -n aks-istio-ingress
```

## Check ASM-Specific Requirements

ASM 124/125 might have new requirements:

```bash
# Check if there are ASM-specific annotations or labels needed
kubectl get gateway -n aks-istio-ingress sbh-gateway -o yaml | grep -A10 -B10 "annotation\|label"

# Check for ASM add-on specific configuration
kubectl get pods -n aks-istio-system -o wide
kubectl describe nodes | grep -i istio
```

## Compare Working vs Non-Working

Since it works on ASM 123, can you:

1. **Export the working Gateway from ASM 123:**
   ```bash
   kubectl get gateway sbh-gateway -n aks-istio-ingress -o yaml > working-gateway.yaml
   ```

2. **Check ASM version differences:**
   ```bash
   # On ASM 123 cluster
   kubectl get pods -n aks-istio-system -l app=istiod -o jsonpath='{.items[0].spec.containers[0].image}'
   
   # On ASM 124/125 cluster  
   kubectl get pods -n aks-istio-system -l app=istiod -o jsonpath='{.items[0].spec.containers[0].image}'
   ```

The "Waiting for controller" message with no events suggests the Istio controller isn't even picking up the Gateway resource, which points to either:
- Gateway API CRD version mismatch
- GatewayClass configuration issue  
- Istio controller configuration change in ASM 124/125

What do you see when you run the GatewayClass and minimal Gateway tests?
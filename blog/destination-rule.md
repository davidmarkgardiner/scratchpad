When using Istio on AKS, you can control traffic routing to bypass company proxies and go directly to your target endpoints using several approaches. A **DestinationRule** can indeed be part of the solution, but you'll likely need a combination of Istio resources.

Here are the main approaches:

## 1. ServiceEntry + DestinationRule
First, define the external service with a ServiceEntry:

```yaml
apiVersion: networking.istio.io/v1beta1
kind: ServiceEntry
metadata:
  name: external-service
spec:
  hosts:
  - your-target-endpoint.com
  ports:
  - number: 443
    name: https
    protocol: HTTPS
  location: MESH_EXTERNAL
  resolution: DNS
```

Then use a DestinationRule to control connection behavior:

```yaml
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: external-service-dr
spec:
  host: your-target-endpoint.com
  trafficPolicy:
    tls:
      mode: SIMPLE  # Direct TLS connection
```

## 2. VirtualService for Traffic Control
Use a VirtualService to ensure traffic goes directly to your endpoint:

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: direct-routing
spec:
  hosts:
  - your-target-endpoint.com
  http:
  - match:
    - uri:
        prefix: /
    route:
    - destination:
        host: your-target-endpoint.com
```

## 3. Bypass Proxy at Network Level
Configure Istio to bypass the proxy for specific traffic:

```yaml
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
metadata:
  name: istio-control-plane
spec:
  values:
    global:
      proxy:
        excludeIPRanges: "10.0.0.0/8,172.16.0.0/12,192.168.0.0/16"
        excludeOutboundPorts: "443,80"  # If needed
```

## 4. Sidecar Configuration
Use Sidecar resource to control egress:

```yaml
apiVersion: networking.istio.io/v1beta1
kind: Sidecar
metadata:
  name: default
spec:
  egress:
  - hosts:
    - "./*"
    - "istio-system/*"
    - "your-target-endpoint.com"
```

The **DestinationRule** alone typically won't be sufficient - you'll need it combined with ServiceEntry and potentially VirtualService to ensure traffic flows directly to your target endpoint without going through company proxies.

Would you like me to elaborate on any of these approaches or help you configure them for your specific use case?
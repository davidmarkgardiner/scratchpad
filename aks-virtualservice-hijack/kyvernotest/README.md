# Kyverno Policies for HTTPRoute and VirtualService Hostname Protection

This directory contains Kyverno policies to prevent hostname hijacking in Kubernetes Gateway API HTTPRoutes and Istio VirtualServices.

## Policies

### Validation Policies
- `prevent-httproute-hostname-hijack.yaml`: Ensures HTTPRoute hostnames start with namespace name
- `prevent-vs-hostname-hijack.yaml`: Ensures VirtualService hosts start with namespace name

### Mutation Policies
- `mutate-httproute-hostname.yaml`: Automatically prepends namespace name to HTTPRoute hostnames
- `mutate-vs-hostname.yaml`: Automatically prepends namespace name to VirtualService hosts

## How it Works

### Validation
The validation policies enforce that all hostnames must be prefixed with the namespace name:
- HTTPRoute example: namespace `foo` can only use hostnames like `foo-*`
- VirtualService example: namespace `bar` can only use hosts like `bar-*`

### Mutation
The mutation policies automatically prepend the namespace name to hostnames:
- Input hostname: `example.com`
- Namespace: `test-ns`
- Result: `test-ns-example.com`

## Testing

1. Apply the policies:
```bash
kubectl apply -f prevent-httproute-hostname-hijack.yaml
kubectl apply -f prevent-vs-hostname-hijack.yaml
kubectl apply -f mutate-httproute-hostname.yaml
kubectl apply -f mutate-vs-hostname.yaml
```

2. Test with sample resources:
```bash
kubectl apply -f test/mutation-test.yaml
```

3. Verify mutations:
```bash
kubectl get virtualservice -n test-mutation vs-test1 -o yaml
kubectl get httproute -n test-mutation route-test1 -o yaml
```

## Examples

### HTTPRoute
```yaml
apiVersion: gateway.networking.k8s.io/v1beta1
kind: HTTPRoute
metadata:
  name: example
  namespace: test-ns
spec:
  hostnames:
    - "example.com"    # Will be mutated to: test-ns-example.com
```

### VirtualService
```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: example
  namespace: test-ns
spec:
  hosts:
    - "example.com"    # Will be mutated to: test-ns-example.com
``` 
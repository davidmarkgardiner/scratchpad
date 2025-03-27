# HTTPRoute Hostname Hijacking Prevention

This directory contains a Kyverno policy and test files to prevent hostname hijacking in HTTPRoute resources.

## Policy Overview

The `prevent-httproute-hostname-hijack.yaml` policy enforces that HTTPRoute hostnames must be prefixed with their namespace name. This prevents namespace conflicts and hostname hijacking.

## Files

- `prevent-httproute-hostname-hijack.yaml`: The Kyverno policy that enforces namespace-prefixed hostnames
- `test-httproute.yaml`: A compliant HTTPRoute example in the app1 namespace
- `test-httproute2.yaml`: A compliant HTTPRoute example in the app2 namespace
- `bad-httproute.yaml`: A non-compliant HTTPRoute example that should be blocked

## Policy Details

The policy uses a regex pattern to ensure that hostnames start with the namespace name:

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: prevent-httproute-hostname-hijack
spec:
  validationFailureAction: Enforce
  background: false
  rules:
  - name: enforce-namespace-hostname
    match:
      any:
      - resources:
          kinds:
          - HTTPRoute.gateway.networking.k8s.io
    validate:
      message: "HTTPRoute hostname must start with the namespace name"
      deny:
        conditions:
        - key: "{{ regex_match('^{{request.object.metadata.namespace}}-.*', request.object.spec.hostnames[0]) }}"
          operator: Equals
          value: false
```

## Examples

### Compliant HTTPRoute (will be allowed):
```yaml
apiVersion: gateway.networking.k8s.io/v1beta1
kind: HTTPRoute
metadata:
  name: test-route
  namespace: app1
spec:
  hostnames:
    - "app1-myapp.example.com"
```

### Non-compliant HTTPRoute (will be blocked):
```yaml
apiVersion: gateway.networking.k8s.io/v1beta1
kind: HTTPRoute
metadata:
  name: bad-route
  namespace: app2
spec:
  hostnames:
    - "myapp.example.com"
```

## Testing

To test the policy:

1. Apply the policy:
   ```bash
   kubectl apply -f prevent-httproute-hostname-hijack.yaml
   ```

2. Try creating a compliant HTTPRoute:
   ```bash
   kubectl apply -f test-httproute.yaml
   ```

3. Try creating a non-compliant HTTPRoute:
   ```bash
   kubectl apply -f bad-httproute.yaml
   ```
   This should be blocked with an error message. 
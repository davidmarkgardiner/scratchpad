# Istio Gateway TLS Configuration

This repository demonstrates Istio Gateway configuration with different TLS modes for securing ingress traffic.

## TLS Modes

### SIMPLE TLS
- One-way TLS authentication
- Server presents certificate to client
- Client verifies server identity
- Used for standard HTTPS traffic

```yaml
tls:
  mode: SIMPLE
  credentialName: my-cert-secret
```

### MUTUAL TLS (mTLS)
- Two-way TLS authentication
- Both server and client present certificates
- Mutual verification of identities
- Enhanced security for sensitive traffic

```yaml
tls:
  mode: MUTUAL
  credentialName: my-cert-secret
```

## Full Configuration Example

```yaml
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: example-gateway
  namespace: default
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 443
      name: https
      protocol: HTTPS
    tls:
      mode: SIMPLE  # or MUTUAL for mTLS
      credentialName: my-cert-secret
    hosts:
    - "example.com"
```

## Certificate Management

1. Create TLS secret:
```bash
kubectl create secret tls my-cert-secret \
  --key=path/to/key.pem \
  --cert=path/to/cert.pem \
  -n istio-system
```

2. Reference in Gateway configuration using `credentialName`

## Security Considerations

- SIMPLE TLS suitable for most web applications
- MUTUAL TLS recommended for:
  - Service-to-service communication
  - Zero-trust environments
  - Regulatory compliance requirements

## Additional Resources
- [Istio Security](https://istio.io/latest/docs/concepts/security/)
- [Gateway TLS Configuration](https://istio.io/latest/docs/ops/configuration/traffic-management/tls-configuration/)

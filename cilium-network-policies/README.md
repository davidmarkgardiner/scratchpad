# Cilium Network Policies for AKS with APIM and OpenAI Integration

This directory contains comprehensive Cilium network policies designed for Azure Kubernetes Service (AKS) clusters that integrate with Azure API Management (APIM) Gateway and OpenAI endpoints.

## 📋 Overview

These policies provide a defense-in-depth security approach with:
- **Zero-trust networking** with default deny-all baseline
- **Granular traffic control** for APIM and OpenAI endpoints
- **Azure PaaS integration** (Key Vault, Storage, etc.)
- **Security hardening** against common attack vectors
- **Observability** with L7 visibility support

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────┐
│                  AKS Cluster                        │
│                                                     │
│  ┌──────────────┐      ┌──────────────┐           │
│  │  Frontend    │─────▶│  Backend     │           │
│  │  Service     │      │  Service     │           │
│  └──────────────┘      └──────┬───────┘           │
│                                │                    │
│                                ▼                    │
│                        ┌───────────────┐           │
│                        │ Egress Gateway│           │
│                        └───────┬───────┘           │
└────────────────────────────────┼────────────────────┘
                                 │
                    ┌────────────┼────────────┐
                    │            │            │
                    ▼            ▼            ▼
            ┌──────────┐  ┌──────────┐  ┌──────────┐
            │   APIM   │  │  OpenAI  │  │  Azure   │
            │ Gateway  │  │ Endpoint │  │   PaaS   │
            └──────────┘  └──────────┘  └──────────┘
```

## 📁 Policy Files

### `aks-apim-openai-policies.yaml`
Contains 15 comprehensive network policies:

1. **Default Deny All** - Baseline zero-trust policy
2. **DNS Resolution** - Essential DNS access for name resolution
3. **AKS System Traffic** - Required for cluster health
4. **App to APIM** - Controlled egress to Azure APIM
5. **App to OpenAI** - Restricted OpenAI API access
6. **APIM Ingress Control** - Gateway access management
7. **Block Malicious Egress** - Threat intelligence integration
8. **Rate Limiting** - DDoS protection foundation
9. **Inter-Service Communication** - Internal service mesh
10. **Azure Services Access** - PaaS integration (Key Vault, Storage)
11. **Monitoring Access** - Prometheus/Grafana metrics collection
12. **Prevent Lateral Movement** - Restrict internal scanning
13. **Egress Gateway** - Source IP preservation for APIM whitelisting
14. **Cluster-Wide Security** - Cross-namespace baseline
15. **OpenAI Audit Logging** - Enhanced visibility for AI API calls

## 🚀 Quick Start

### Prerequisites

```bash
# Ensure Cilium is installed in your AKS cluster
kubectl get pods -n kube-system -l k8s-app=cilium

# Enable Hubble for L7 visibility (recommended)
cilium hubble enable
```

### Installation

```bash
# Apply all policies
kubectl apply -f cilium-network-policies/aks-apim-openai-policies.yaml

# Verify policies are created
kubectl get cnp,ccnp -A
```

### Verification

```bash
# Check policy status
kubectl get ciliumnetworkpolicies -A

# View policy endpoints
kubectl get cep -A

# Check Hubble flows (if enabled)
hubble observe --namespace default
```

## ⚙️ Configuration

### 1. Customize Pod Labels

Update the pod label selectors to match your applications:

```yaml
# In app-to-apim policy
endpointSelector:
  matchLabels:
    app: backend-service    # Change to your app label
    tier: api-client        # Add your custom labels
```

### 2. Configure APIM Domains

Replace wildcard patterns with your specific APIM domains:

```yaml
# In app-to-apim policy
toFQDNs:
  - matchPattern: "*.azure-api.net"              # Generic pattern
  - matchName: "myapim.azure-api.net"            # Your specific domain
  - matchName: "mycompany-prod.azure-api.net"    # Additional domains
```

### 3. Set OpenAI Endpoints

Update OpenAI endpoint patterns:

```yaml
# In app-to-openai policy
toFQDNs:
  - matchPattern: "*.openai.azure.com"           # Azure OpenAI
  - matchName: "myopenai.openai.azure.com"       # Your specific endpoint
  - matchName: "api.openai.com"                  # Direct OpenAI (if needed)
```

### 4. Configure Egress Gateway

Set up nodes for egress gateway functionality:

```bash
# Label nodes for egress gateway
kubectl label nodes <node-name> egress-gateway=true

# Update the policy with your APIM public IP range
# In apim-egress-gateway policy
destinationCIDRs:
  - 52.151.0.0/16  # Replace with your APIM public IP range
```

### 5. Azure PaaS Services

Customize Azure service access patterns:

```yaml
# In allow-azure-services policy
toFQDNs:
  - matchName: "mykeyvault.vault.azure.net"      # Specific Key Vault
  - matchName: "mystorage.blob.core.windows.net" # Specific Storage Account
```

## 🔐 Security Best Practices

### 1. Default Deny Approach
- All policies build upon the default deny-all baseline
- Only explicitly allowed traffic is permitted
- Reduces attack surface significantly

### 2. Least Privilege Access
- Grant minimum required permissions
- Use specific FQDN matches over wildcards when possible
- Restrict HTTP methods and paths

### 3. Secrets Management
- Store API keys and credentials in Azure Key Vault
- Use Azure Workload Identity or Managed Identities
- Never hardcode secrets in policies

```yaml
# Example: Using secrets with policies
headerMatches:
  - name: api-key
    secret:
      name: openai-secret      # Kubernetes Secret
      namespace: default
```

### 4. Enable L7 Visibility

```bash
# Enable Hubble for HTTP/gRPC visibility
cilium hubble enable --ui

# View HTTP flows
hubble observe --protocol http

# Filter by pod
hubble observe --from-pod backend-service
```

### 5. Monitor Policy Violations

```bash
# Check denied flows
hubble observe --verdict DROPPED

# Monitor specific policy
kubectl describe cnp app-to-apim -n default
```

## 📊 Monitoring and Observability

### Hubble UI

```bash
# Access Hubble UI
kubectl port-forward -n kube-system svc/hubble-ui 12000:80

# Open in browser
open http://localhost:12000
```

### Prometheus Metrics

Key metrics to monitor:
- `cilium_policy_l3_denied` - L3/L4 policy denials
- `cilium_policy_l7_denied` - L7 policy denials
- `cilium_endpoint_policy_enforcement_status` - Policy enforcement status

### Grafana Dashboards

Import Cilium dashboards:
1. Network Policy (ID: 16611)
2. Hubble L7 HTTP Metrics (ID: 16612)
3. Hubble DNS Metrics (ID: 16613)

## 🧪 Testing

### Test DNS Resolution

```bash
# Deploy test pod
kubectl run test-dns --image=busybox --restart=Never -- sleep 3600

# Test DNS
kubectl exec test-dns -- nslookup kubernetes.default.svc.cluster.local

# Clean up
kubectl delete pod test-dns
```

### Test APIM Connectivity

```bash
# Deploy test pod with appropriate labels
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: test-apim
  labels:
    app: backend-service
    tier: api-client
spec:
  containers:
  - name: curl
    image: curlimages/curl:latest
    command: ['sleep', '3600']
EOF

# Test APIM endpoint
kubectl exec test-apim -- curl -v https://myapim.azure-api.net/health

# Check Hubble logs
hubble observe --from-pod test-apim --protocol http
```

### Test OpenAI Connectivity

```bash
# Deploy AI service pod
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: test-openai
  labels:
    app: ai-service
    tier: ml-client
spec:
  containers:
  - name: curl
    image: curlimages/curl:latest
    command: ['sleep', '3600']
EOF

# Test OpenAI endpoint
kubectl exec test-openai -- curl -v https://myopenai.openai.azure.com/v1/models
```

## 🔧 Troubleshooting

### Policy Not Applied

```bash
# Check if Cilium is running
kubectl get pods -n kube-system -l k8s-app=cilium

# Verify policy syntax
kubectl apply -f aks-apim-openai-policies.yaml --dry-run=server

# Check policy status
kubectl describe cnp <policy-name> -n <namespace>
```

### Connection Blocked

```bash
# View denied flows
hubble observe --verdict DROPPED --last 100

# Check endpoint identity
kubectl get cep -A

# Verify pod labels match policy selectors
kubectl get pod <pod-name> -o yaml | grep -A 10 labels
```

### DNS Issues

```bash
# Verify CoreDNS is running
kubectl get pods -n kube-system -l k8s-app=kube-dns

# Test DNS policy
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: test-dns-policy
spec:
  containers:
  - name: busybox
    image: busybox
    command: ['sh', '-c', 'nslookup kubernetes.default && sleep 3600']
EOF

# Check logs
kubectl logs test-dns-policy
```

### FQDN Policy Not Working

```bash
# Ensure DNS proxy is enabled
kubectl exec -n kube-system cilium-xxxxx -- cilium status | grep DNS

# Check FQDN cache
kubectl exec -n kube-system cilium-xxxxx -- cilium fqdn cache list

# Verify selector matches pods
kubectl get pods --show-labels
```

## 📚 Additional Resources

### Cilium Documentation
- [Network Policy](https://docs.cilium.io/en/stable/security/policy/)
- [L7 Policy](https://docs.cilium.io/en/stable/security/policy/language/#layer-7-examples)
- [FQDN-based Policy](https://docs.cilium.io/en/stable/security/policy/language/#dns-based)
- [Hubble Observability](https://docs.cilium.io/en/stable/observability/hubble/)

### Azure Integration
- [Azure CNI Powered by Cilium](https://learn.microsoft.com/en-us/azure/aks/azure-cni-powered-by-cilium)
- [Azure API Management](https://learn.microsoft.com/en-us/azure/api-management/)
- [Azure OpenAI Service](https://learn.microsoft.com/en-us/azure/ai-services/openai/)

### Best Practices
- [Zero Trust Networking](https://www.cncf.io/blog/2021/06/22/zero-trust-networking-with-cilium/)
- [Kubernetes Network Policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/)

## 🤝 Contributing

To contribute improvements or report issues:

1. Test policies in a non-production environment
2. Document any changes in this README
3. Include examples and test cases
4. Verify with `kubectl apply --dry-run=server`

## 📝 License

These policies are provided as-is for use in your AKS clusters. Customize according to your security requirements.

## ⚠️ Important Notes

- **Always test in a non-production environment first**
- **Backup existing network policies before applying**
- **Monitor Hubble flows after deployment to verify expected traffic**
- **Update FQDN patterns to match your specific domains**
- **Review and adjust security controls based on your threat model**
- **Consider using Cilium 1.14+ for latest features**

---

**Last Updated:** October 2025  
**Cilium Version:** 1.14+  
**AKS Compatibility:** Azure CNI Powered by Cilium
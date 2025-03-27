# AKS HTTPRoute Hostname Hijacking Prevention

This repository demonstrates how to prevent HTTPRoute hostname hijacking in Azure Kubernetes Service (AKS) using Kyverno policies.

## Prerequisites

- Azure Kubernetes Service (AKS) cluster with Gateway API enabled
- Kyverno installed in the cluster
- `kubectl` configured to access your cluster

## Setup

1. Install Kyverno (if not already installed):
```bash
helm repo add kyverno https://kyverno.github.io/kyverno/
helm repo update
helm install kyverno kyverno/kyverno --namespace kyverno --create-namespace
```

2. Install Gateway API CRDs (if not already installed):
```bash
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.0.0/standard-install.yaml
```

3. Apply the Kyverno policy:
```bash
kubectl apply -f prevent-httproute-hostname-hijack.yaml
```

## Testing

1. Create the legitimate HTTPRoutes:
```bash
kubectl create ns app1
kubectl apply -f app1.yaml  # Base application
kubectl apply -f app1-httproute.yaml
kubectl create ns app2
kubectl apply -f app2.yaml  # Base application
kubectl apply -f app2-httproute.yaml
```

2. Try to create a malicious HTTPRoute that attempts to hijack the hostname:
```bash
kubectl apply -f bad-httproute.yaml
```

The last command should fail with a policy violation error, demonstrating that the policy successfully prevents hostname hijacking.

## Files

- `prevent-httproute-hostname-hijack.yaml`: Kyverno policy that enforces namespace-specific hostnames
- `gateway.yaml`: Gateway API Gateway configuration
- `app1-httproute.yaml`: First application's HTTPRoute with correct hostname pattern (`app1-myapp`)
- `app2-httproute.yaml`: Second application's HTTPRoute with correct hostname pattern (`app2-myapp`)
- `bad-httproute.yaml`: Example of a malicious HTTPRoute that tries to hijack app1's hostname

## How it Works

The policy enforces that HTTPRoute hostnames must start with their namespace name (e.g., `app1-*` for the `app1` namespace). This prevents services in one namespace from using hostnames that belong to other namespaces.

You can customize the hostname pattern by modifying the policy in `prevent-httproute-hostname-hijack.yaml`. The current policy requires hostnames to start with the namespace name followed by a hyphen, but you can adjust this pattern based on your cluster's requirements.

## Cleanup

To remove everything:
```bash
kubectl delete -f prevent-httproute-hostname-hijack.yaml
kubectl delete -f app1-httproute.yaml
kubectl delete -f app2-httproute.yaml
kubectl delete -f bad-httproute.yaml
kubectl delete -f gateway.yaml
kubectl delete ns app1 app2
``` 
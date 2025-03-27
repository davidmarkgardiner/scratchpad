# AKS VirtualService Hostname Hijacking Prevention

This repository demonstrates how to prevent VirtualService hostname hijacking in Azure Kubernetes Service (AKS) using Kyverno policies.

## Prerequisites

- Azure Kubernetes Service (AKS) cluster with Istio enabled
- Kyverno installed in the cluster
- `kubectl` configured to access your cluster

## Setup

1. Install Kyverno (if not already installed):
```bash
helm repo add kyverno https://kyverno.github.io/kyverno/
helm repo update
helm install kyverno kyverno/kyverno --namespace kyverno --create-namespace
```

2. Apply the RBAC configuration:
```bash
kubectl apply -f kyverno-virtualservice-role.yaml
```

3. Apply the Kyverno policy:
```bash
kubectl apply -f prevent-vs-hostname-hijack.yaml
```

## Testing

1. Create the legitimate VirtualServices:
```bash
kubectl create ns app1
kubectl apply -f app1.yaml
kubectl create ns app2
kubectl apply -f app2.yaml
```

2. Try to create a malicious VirtualService that attempts to hijack the hostname:
```bash
kubectl apply -f bad-vs.yaml
```

The last command should fail with a policy violation error, demonstrating that the policy successfully prevents hostname hijacking.

## Files

- `prevent-vs-hostname-hijack.yaml`: Kyverno policy that enforces namespace-specific hostnames
- `kyverno-virtualservice-role.yaml`: RBAC configuration for Kyverno
- `app1.yaml`: First application with correct hostname pattern (`app1-myapp`)
- `app2.yaml`: Second application with correct hostname pattern (`app2-myapp`)
- `bad-vs.yaml`: Example of a malicious VirtualService that tries to hijack app1's hostname
- `gateway.yaml`: Istio Gateway configuration

## How it Works

The policy enforces that VirtualService hostnames must start with their namespace name (e.g., `app1-*` for the `app1` namespace). This prevents services in one namespace from using hostnames that belong to other namespaces.

You can customize the hostname pattern by modifying the policy in `prevent-vs-hostname-hijack.yaml`. The current policy requires hostnames to start with the namespace name followed by a hyphen, but you can adjust this pattern based on your cluster's requirements.

## Cleanup

To remove everything:
```bash
kubectl delete -f prevent-vs-hostname-hijack.yaml
kubectl delete -f kyverno-virtualservice-role.yaml
kubectl delete -f app1.yaml
kubectl delete -f app2.yaml
kubectl delete -f bad-vs.yaml
kubectl delete ns app1 app2
``` 
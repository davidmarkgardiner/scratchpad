#!/bin/bash

# Add Helm repos
helm repo add jetstack https://charts.jetstack.io
helm repo add external-secrets https://charts.external-secrets.io
helm repo add kyverno https://kyverno.github.io/kyverno/
helm repo update

# Apply system workloads configuration
kubectl apply -f manifests/system-workloads.yaml

# Install cert-manager
helm upgrade --install cert-manager jetstack/cert-manager \
    --namespace cert-manager \
    --create-namespace \
    --values manifests/cert-manager-values.yaml

# Install external-secrets
helm upgrade --install external-secrets external-secrets/external-secrets \
    --namespace external-secrets \
    --create-namespace \
    --values manifests/external-secrets-values.yaml

# Install kyverno
helm upgrade --install kyverno kyverno/kyverno \
    --namespace kyverno \
    --create-namespace \
    --values manifests/kyverno-values.yaml

# Wait for deployments
echo "Waiting for deployments to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment -n cert-manager cert-manager
kubectl wait --for=condition=available --timeout=300s deployment -n external-secrets external-secrets
kubectl wait --for=condition=available --timeout=300s deployment -n kyverno kyverno 
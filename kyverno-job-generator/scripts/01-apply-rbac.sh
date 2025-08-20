#!/bin/bash

echo "Applying RBAC configuration..."

# Create kyverno namespace if it doesn't exist
kubectl create namespace kyverno --dry-run=client -o yaml | kubectl apply -f -

# Apply RBAC configuration
kubectl apply -f rbac/kyverno-rbac.yaml

echo "RBAC configuration applied successfully"
echo "Checking RBAC resources..."

kubectl get serviceaccount -n kyverno kyverno-sa
kubectl get clusterrole kyverno-generate-jobs
kubectl get clusterrolebinding kyverno-generate-jobs-binding
kubectl get role -n default kyverno-job-generator
kubectl get rolebinding -n default kyverno-job-generator-binding
#!/bin/bash

echo "Starting cleanup process..."

echo "Deleting test deployments..."
kubectl delete -f test/test-deployment.yaml --ignore-not-found=true

echo "Deleting generated jobs..."
kubectl delete jobs -n default --all

echo "Deleting Kyverno policy..."
kubectl delete clusterpolicy image-job-generator-test --ignore-not-found=true

echo "Deleting RBAC resources..."
kubectl delete -f rbac/kyverno-rbac.yaml --ignore-not-found=true

echo "Checking remaining resources..."
echo "Deployments:"
kubectl get deployments -n default

echo "Jobs:"
kubectl get jobs -n default

echo "Pods:"
kubectl get pods -n default

echo "Cleanup complete!"
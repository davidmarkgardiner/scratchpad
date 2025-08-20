#!/bin/bash

echo "Deploying Kyverno policy..."

# Apply the policy
kubectl apply -f policy/1-job-generator-policy.yaml

echo "Policy deployed successfully"
echo "Checking policy status..."

kubectl get clusterpolicy image-job-generator-test
kubectl describe clusterpolicy image-job-generator-test
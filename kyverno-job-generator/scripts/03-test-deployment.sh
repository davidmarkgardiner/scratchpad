#!/bin/bash

echo "Creating test deployments..."

# Apply test deployments
kubectl apply -f test/test-deployment.yaml

echo "Waiting for deployments to be created..."
sleep 5

echo "Checking deployments..."
kubectl get deployments -n default

echo "Checking pods..."
kubectl get pods -n default

echo "Waiting for Kyverno to process and create jobs..."
sleep 10

echo "Checking generated jobs..."
kubectl get jobs -n default

echo "Detailed job information:"
kubectl describe jobs -n default

echo "Job logs (if any):"
for job in $(kubectl get jobs -n default -o name); do
  echo "Logs for $job:"
  kubectl logs -n default $job
done
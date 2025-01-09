#!/bin/bash

# Create main directories
mkdir -p kyverno-policies/templates/policies
mkdir -p kyverno-policies/templates/tests
mkdir -p kyverno-policies/archive

# Create empty files
touch kyverno-policies/Chart.yaml
touch kyverno-policies/values.yaml

# Create policy files
touch kyverno-policies/templates/policies/mutate-ns-deployment-spotaffinity.yaml
touch kyverno-policies/templates/policies/mutate-cluster-namespace-istiolabel.yaml
touch kyverno-policies/templates/policies/enforce-cluster-pod-security.yaml
touch kyverno-policies/templates/policies/audit-cluster-peerauthentication-mtls.yaml

# Create test files
touch kyverno-policies/templates/tests/test-spot-affinity-mutation.yaml
touch kyverno-policies/templates/tests/test-istio-label-mutation.yaml
touch kyverno-policies/templates/tests/test-mtls-audit.yaml

# Make script executable
chmod +x setup.sh 
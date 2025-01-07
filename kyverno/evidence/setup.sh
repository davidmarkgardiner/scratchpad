#!/bin/bash

# Create base directory
mkdir -p kyverno/evidence

# Create subdirectories
cd kyverno/evidence

# Create list.md
touch list.md

# Create directories and their files
mkdir -p generate-ns-resourcequota
touch generate-ns-resourcequota/generate-ns-resourcequota.yaml
touch generate-ns-resourcequota/readme.md
touch generate-ns-resourcequota/compliant-pod.yaml
touch generate-ns-resourcequota/violating-pod.yaml

mkdir -p validate-cluster-pod-labels
touch validate-cluster-pod-labels/validate-cluster-pod-labels.yaml
touch validate-cluster-pod-labels/readme.md
touch validate-cluster-pod-labels/compliant-pod.yaml
touch validate-cluster-pod-labels/violating-pod.yaml

mkdir -p validate-ns-istio-injection
touch validate-ns-istio-injection/validate-ns-istio-injection.yaml
touch validate-ns-istio-injection/readme.md
touch validate-ns-istio-injection/compliant-namespace.yaml
touch validate-ns-istio-injection/non-compliant-namespace.yaml

mkdir -p enforce-cluster-pod-security-prod
touch enforce-cluster-pod-security-prod/enforce-cluster-pod-security-prod.yaml
touch enforce-cluster-pod-security-prod/readme.md
touch enforce-cluster-pod-security-prod/compliant-namespace.yaml
touch enforce-cluster-pod-security-prod/non-compliant-namespace.yaml
touch enforce-cluster-pod-security-prod/compliant-pod.yaml
touch enforce-cluster-pod-security-prod/non-compliant-pod.yaml

mkdir -p enforce-cluster-pod-security
touch enforce-cluster-pod-security/enforce-cluster-pod-security.yaml
touch enforce-cluster-pod-security/readme.md
touch enforce-cluster-pod-security/compliant-pod.yaml
touch enforce-cluster-pod-security/violating-pod.yaml

mkdir -p mutate-ns-deployment-affinity
touch mutate-ns-deployment-affinity/mutate-ns-deployment-antiaffinity.yaml
touch mutate-ns-deployment-affinity/mutate-ns-deployment-spotaffinity.yaml
touch mutate-ns-deployment-affinity/readme.md
touch mutate-ns-deployment-affinity/policy-explanation.md
touch mutate-ns-deployment-affinity/expected-affinity.yaml
touch mutate-ns-deployment-affinity/output.yaml
touch mutate-ns-deployment-affinity/matching-namespace-pod.yaml
touch mutate-ns-deployment-affinity/non-matching-namespace-pod.yaml
touch mutate-ns-deployment-affinity/test-deployment.yaml

mkdir -p audit-and-mutate-cluster-pod-spotconfig
touch audit-and-mutate-cluster-pod-spotconfig/audit-and-mutate-cluster-pod-spotconfig.yaml
touch audit-and-mutate-cluster-pod-spotconfig/readme.md
touch audit-and-mutate-cluster-pod-spotconfig/script.sh

mkdir -p generate-ns-networkpolicy-deny
touch generate-ns-networkpolicy-deny/generate-ns-networkpolicy-deny.yaml
touch generate-ns-networkpolicy-deny/readme.md
touch generate-ns-networkpolicy-deny/compliant-namespace.yaml
touch generate-ns-networkpolicy-deny/non-compliant-namespace.yaml

mkdir -p audit-cluster-peerauthentication-mtls
touch audit-cluster-peerauthentication-mtls/audit-cluster-peerauthentication-mtls.yaml
touch audit-cluster-peerauthentication-mtls/readme.md
touch audit-cluster-peerauthentication-mtls/compliant-peerauthentication.yaml
touch audit-cluster-peerauthentication-mtls/non-compliant-peerauthentication.yaml

mkdir -p mutate-cluster-namespace-istiolabel
touch mutate-cluster-namespace-istiolabel/mutate-cluster-namespace-istiolabel.yaml
touch mutate-cluster-namespace-istiolabel/readme.md
touch mutate-cluster-namespace-istiolabel/compliant-namespace.yaml
touch mutate-cluster-namespace-istiolabel/non-compliant-namespace.yaml

echo "Directory structure and files created successfully!" 
#!/bin/bash

# Move policy files to policies directory
mv audit-cluster-peerauthentication-mtls-policy.yaml policies/
mv check-deprecated-apis-policy.yaml policies/
mv mutate-cluster-namespace-istiolabel-policy.yaml policies/
mv mutate-ns-deployment-spotaffinity-policy.yaml policies/
mv prevent-istio-injection-policy.yaml policies/
mv resource-limits-policy.yaml policies/
mv validate-virtualservice-policy.yaml policies/

# Move resource files to resources directory
mv resource.yaml resources/
mv istio-resources.yaml resources/
mv istio-label-resources.yaml resources/
mv spot-affinity-resources.yaml resources/
mv mtls-resources.yaml resources/
mv deprecated-api-resources.yaml resources/
mv virtual-service.yaml resources/

# Move patched files to patched directory
mv patched-deployment-1.yaml patched/
mv patched-namespace-1.yaml patched/
mv patched-namespace-2.yaml patched/

# Move test file to tests directory
mv all-tests.yaml tests/

# Keep values.yaml in the root directory as it's referenced directly 
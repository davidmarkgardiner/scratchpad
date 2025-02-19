#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}Setting up Kyverno Policy Test Environment...${NC}"

# Create directory structure
mkdir -p kyverno-policies/tests/policies

# Change to the policies directory
cd kyverno-policies/tests/policies

# Create all policy files
echo -e "${GREEN}Creating policy files...${NC}"

# 1. Resource Limits Policy
cat > resource-limits-policy.yaml << 'EOL'
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-resource-limits
  annotations:
    policies.kyverno.io/title: Require Resource Limits and Requests
    policies.kyverno.io/category: Resource Constraints
    policies.kyverno.io/severity: medium
    policies.kyverno.io/description: >-
      Requires all containers in Deployments to have memory and CPU resource requests and limits set.
spec:
  validationFailureAction: Enforce
  background: true
  rules:
  - name: check-resource-limits
    match:
      any:
      - resources:
          kinds:
          - Deployment
    exclude:
      any:
      - resources:
          namespaces:
          - policies-test-spot
          - policies-test-istio-rev
    validate:
      message: "Resource requests and limits are required for all containers in Deployments"
      pattern:
        spec:
          template:
            spec:
              containers:
                - resources:
                    limits:
                      memory: "*"
                      cpu: "*"
EOL

# 2. Prevent Istio Injection Policy
cat > prevent-istio-injection-policy.yaml << 'EOL'
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: validate-ns-istio-injection
  annotations:
    policies.kyverno.io/title: Prevent Istio Injection Label
    policies.kyverno.io/category: Security
    policies.kyverno.io/severity: medium
    policies.kyverno.io/description: >-
      This policy prevents the istio-injection=enabled label from being set on any
      Namespace, Pod, or Deployment resources.
spec:
  validationFailureAction: Enforce
  background: true
  rules:
    - name: check-istio-injection-label
      match:
        any:
        - resources:
            kinds:
            - Namespace
            - Pod
            - Deployment
      exclude:
        any:
        - resources:
            namespaces:
            - "policies-test-spot"
            - "policies-test-istio-rev"
      validate:
        message: "Setting the istio-injection=enabled label is not allowed"
        pattern:
          metadata:
            labels:
              =(istio-injection): "!enabled"
EOL

# 3. Mutate Cluster Namespace Istio Label Policy
cat > mutate-cluster-namespace-istiolabel-policy.yaml << 'EOL'
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: mutate-cluster-namespace-istiolabel
  annotations:
    policies.kyverno.io/category: Istio
    policies.kyverno.io/description: This policy ensures namespaces starting with
      'at' have the required Istio revision label for proper sidecar injection.
    policies.kyverno.io/severity: medium
    policies.kyverno.io/title: Required Istio Revision Label
spec:
  validationFailureAction: Enforce
  rules:
  - name: add-istio-revision-label
    match:
      any:
      - resources:
          kinds:
          - Namespace
          selector:
            matchExpressions:
            - key: istio.io/rev
              operator: Exists
    mutate:
      patchStrategicMerge:
        metadata:
          labels:
            istio.io/rev: asm-1-23
EOL

# 4. Spot Affinity Policy
cat > mutate-ns-deployment-spotaffinity-policy.yaml << 'EOL'
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: mutate-ns-deployment-spotaffinity
  annotations:
    policies.kyverno.io/title: Add Pod Anti-Affinity and Node Affinity
    policies.kyverno.io/category: Workload Distribution
    policies.kyverno.io/subject: Deployment
    policies.kyverno.io/description: >-
      This policy adds both pod anti-affinity and node affinity configurations to ensure better pod distribution
      across nodes and spot instance scheduling.
    policies.kyverno.io/debug: "true"
spec:
  validationFailureAction: Enforce
  rules:
    - name: insert-pod-antiaffinity
      match:
        any:
        - resources:
            kinds:
              - Deployment
            namespaceSelector:
              matchExpressions:
                - key: worker-type
                  operator: In
                  values:
                    - spot
      preconditions:
        all:
        - key: "{{ request.object.spec.template.metadata.labels.app || '' }}"
          operator: NotEquals
          value: ""
      mutate:
        patchStrategicMerge:
          spec:
            template:
              spec:
                +(tolerations):
                  - key: "kubernetes.azure.com/scalesetpriority"
                    operator: "Equal"
                    value: "spot"
                    effect: "NoSchedule" 
                +(affinity):
                  podAntiAffinity:
                    preferredDuringSchedulingIgnoredDuringExecution:
                    - weight: 100
                      podAffinityTerm:
                        labelSelector:
                          matchExpressions:
                          - key: app
                            operator: In
                            values:
                            - "{{ request.object.spec.template.metadata.labels.app }}"
                        topologyKey: kubernetes.io/hostname
                  nodeAffinity:
                    preferredDuringSchedulingIgnoredDuringExecution:
                      - weight: 100
                        preference:
                          matchExpressions:
                            - key: "kubernetes.azure.com/scalesetpriority"
                              operator: In
                              values:
                                - "spot"
                      - weight: 1
                        preference:
                          matchExpressions:
                            - key: worker
                              operator: In
                              values:
                                - "true"
EOL

# 5. mTLS Policy
cat > audit-cluster-peerauthentication-mtls-policy.yaml << 'EOL'
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  annotations:
    kyverno.io/kubernetes-version: "1.24"
    kyverno.io/kyverno-version: 1.8.0
    policies.kyverno.io/category: Security
    policies.kyverno.io/description: Strict mTLS requires that mutual TLS be enabled
      across the entire service mesh, which can be set using a PeerAuthentication
      resource. This policy audits all PeerAuthentication resources to ensure they use strict mTLS.
    policies.kyverno.io/minversion: 1.6.0
    policies.kyverno.io/severity: medium
    policies.kyverno.io/subject: PeerAuthentication
    policies.kyverno.io/title: Audit Istio Strict mTLS
  name: audit-cluster-peerauthentication-mtls
spec:
  validationFailureAction: Audit
  background: true
  rules:
  - name: validate-mtls
    match:
      resources:
        kinds:
        - PeerAuthentication
    validate:
      message: PeerAuthentication resources must use STRICT mode
      pattern:
        spec:
          mtls:
            mode: STRICT
EOL

# Create test resources
echo -e "${GREEN}Creating test resource files...${NC}"

# 6. Istio Resources
cat > istio-resources.yaml << 'EOL'
apiVersion: v1
kind: Namespace
metadata:
  name: test-namespace-pass
  labels:
    istio-injection: "disabled"
---
apiVersion: v1
kind: Namespace
metadata:
  name: test-namespace-fail
  labels:
    istio-injection: enabled
EOL

# 7. Istio Label Resources
cat > istio-label-resources.yaml << 'EOL'
apiVersion: v1
kind: Namespace
metadata:
  name: test-namespace-1
  labels:
    istio.io/rev: ""
---
apiVersion: v1
kind: Namespace
metadata:
  name: test-namespace-2
  labels:
    istio.io/rev: "old-version"
EOL

# 8. Spot Affinity Resources
cat > spot-affinity-resources.yaml << 'EOL'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-deployment-1
  namespace: spot-namespace
  labels:
    app: nginx
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:latest
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-deployment-2
  namespace: non-spot-namespace
  labels:
    app: nginx
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:latest
EOL

# 9. mTLS Resources
cat > mtls-resources.yaml << 'EOL'
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: test-peer-auth-pass
  namespace: istio-system
spec:
  mtls:
    mode: STRICT
---
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: test-peer-auth-fail
  namespace: istio-system
  annotations:
    policies.kyverno.io/scored: "false"
spec:
  mtls:
    mode: PERMISSIVE
EOL

# 10. Create complete test configuration
cat > all-tests.yaml << 'EOL'
apiVersion: cli.kyverno.io/v1alpha1
kind: Test
metadata:
  name: test-all-policies
policies:
  - resource-limits-policy.yaml
  - prevent-istio-injection-policy.yaml
  - mutate-cluster-namespace-istiolabel-policy.yaml
  - mutate-ns-deployment-spotaffinity-policy.yaml
  - audit-cluster-peerauthentication-mtls-policy.yaml
resources:
  - resource.yaml
  - istio-resources.yaml
  - istio-label-resources.yaml
  - spot-affinity-resources.yaml
  - mtls-resources.yaml
variables: values.yaml
results:
  # Resource Limits Tests
  - policy: require-resource-limits
    rule: check-resource-limits
    resources:
      - test-deployment-pass
    kind: Deployment
    result: pass

  # Prevent Istio Injection Tests
  - policy: validate-ns-istio-injection
    rule: check-istio-injection-label
    resources:
      - test-namespace-pass
    kind: Namespace
    result: pass
  - policy: validate-ns-istio-injection
    rule: check-istio-injection-label
    resources:
      - test-namespace-fail
    kind: Namespace
    result: fail

  # Istio Label Mutation Tests
  - policy: mutate-cluster-namespace-istiolabel
    rule: add-istio-revision-label
    resources:
      - test-namespace-1
    kind: Namespace
    result: pass
    patchedResource: patched-namespace-1.yaml
  - policy: mutate-cluster-namespace-istiolabel
    rule: add-istio-revision-label
    resources:
      - test-namespace-2
    kind: Namespace
    result: pass
    patchedResource: patched-namespace-2.yaml

  # Spot Affinity Tests
  - policy: mutate-ns-deployment-spotaffinity
    rule: insert-pod-antiaffinity
    resources:
      - test-deployment-1
    kind: Deployment
    result: pass
    patchedResource: patched-deployment-1.yaml
  - policy: mutate-ns-deployment-spotaffinity
    rule: insert-pod-antiaffinity
    resources:
      - test-deployment-2
    kind: Deployment
    result: skip

  # mTLS Tests
  - policy: audit-cluster-peerauthentication-mtls
    rule: validate-mtls
    resources:
      - test-peer-auth-pass
    kind: PeerAuthentication
    result: pass
  - policy: audit-cluster-peerauthentication-mtls
    rule: validate-mtls
    resources:
      - test-peer-auth-fail
    kind: PeerAuthentication
    result: fail
EOL

# 11. Create patched resources for mutation tests
cat > patched-namespace-1.yaml << 'EOL'
apiVersion: v1
kind: Namespace
metadata:
  name: test-namespace-1
  labels:
    istio.io/rev: asm-1-23
EOL

cat > patched-namespace-2.yaml << 'EOL'
apiVersion: v1
kind: Namespace
metadata:
  name: test-namespace-2
  labels:
    istio.io/rev: asm-1-23
EOL

cat > patched-deployment-1.yaml << 'EOL'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-deployment-1
  namespace: spot-namespace
  labels:
    app: nginx
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      tolerations:
        - key: "kubernetes.azure.com/scalesetpriority"
          operator: "Equal"
          value: "spot"
          effect: "NoSchedule"
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: app
                  operator: In
                  values:
                  - nginx
              topologyKey: kubernetes.io/hostname
        nodeAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 100
              preference:
                matchExpressions:
                  - key: "kubernetes.azure.com/scalesetpriority"
                    operator: In
                    values:
                      - "spot"
            - weight: 1
              preference:
                matchExpressions:
                  - key: worker
                    operator: In
                    values:
                      - "true"
      containers:
      - name: nginx
        image: nginx:latest
EOL

# Create README
cat > README.md << 'EOL'
# Kyverno Policies Test Suite

This directory contains a collection of Kyverno policies and their associated tests. The test suite validates various Kubernetes resource policies including resource limits, Istio configurations, and deployment strategies.

## Policies Overview

### 1. Resource Limits Policy
- **File**: `resource-limits-policy.yaml`
- **Purpose**: Ensures Deployments have proper resource limits configured
- **Test**: Validates that containers in Deployments have memory and CPU limits set
- **Sample Test Case**: Deployment with proper resource limits (memory: 512Mi, cpu: 500m)

### 2. Prevent Istio Injection Policy
- **File**: `prevent-istio-injection-policy.yaml`
- **Purpose**: Prevents unauthorized Istio sidecar injection
- **Test**: Validates that resources don't have the `istio-injection=enabled` label
- **Test Cases**: 
  - Pass: Resources without Istio injection label
  - Fail: Resources with `istio-injection=enabled` label

### 3. Istio Label Mutation Policy
- **File**: `mutate-cluster-namespace-istiolabel-policy.yaml`
- **Purpose**: Manages Istio revision labels on namespaces
- **Test**: Verifies automatic addition of Istio revision labels
- **Test Cases**: Namespaces with empty or outdated Istio revision labels

### 4. Spot Affinity Policy
- **File**: `mutate-ns-deployment-spotaffinity-policy.yaml`
- **Purpose**: Configures pod and node affinity for spot instance deployments
- **Test**: Validates proper affinity rules for spot instance deployments
- **Test Cases**:
  - Pass: Deployment in spot namespace gets proper affinity rules
  - Skip: Deployment in non-spot namespace

### 5. mTLS Policy
- **File**: `audit-cluster-peerauthentication-mtls-policy.yaml`
- **Purpose**: Enforces strict mTLS in service mesh
- **Test**: Validates PeerAuthentication resources use STRICT mode
- **Test Cases**:
  - Pass: PeerAuthentication with STRICT mode
  - Fail: PeerAuthentication with PERMISSIVE mode

## Test Structure
- Main test configuration: `all-tests.yaml`
- Individual test resources in separate YAML files
- Patched resources for mutation tests
- Variables file for namespace configurations

## Running Tests
To run all tests:
```bash
kyverno test .
```

To run tests with JUnit output:
```bash
kyverno test . --junit-path=kyverno-test-results.xml
```
EOL

# Make the script executable
chmod +x setup.sh

echo -e "${GREEN}Setup complete! The following files have been created:${NC}"
ls -la

echo -e "\n${BLUE}To run the tests, execute:${NC}"
echo "kyverno test ."
echo -e "\n${BLUE}To run tests with JUnit output:${NC}"
echo "kyverno test . --junit-path=kyverno-test-results.xml"
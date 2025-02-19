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

## Test Results
The test suite validates:
- Resource configuration compliance
- Security policies
- Mutation rules
- Namespace configurations
- Service mesh settings 
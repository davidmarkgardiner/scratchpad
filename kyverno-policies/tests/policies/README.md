# Kyverno Policies Test Directory

This directory contains tests for Kyverno policies. The structure has been organized as follows:

## Directory Structure

- `policies/`: Contains all Kyverno policy definitions
  - `resource-limits-policy.yaml`
  - `prevent-istio-injection-policy.yaml`
  - `mutate-cluster-namespace-istiolabel-policy.yaml`
  - `mutate-ns-deployment-spotaffinity-policy.yaml`
  - `audit-cluster-peerauthentication-mtls-policy.yaml`
  - `check-deprecated-apis-policy.yaml`
  - `validate-virtualservice-policy.yaml`
  - `image-mutator-policy.yaml`
  - `job-generator-policy.yaml`

- `resources/`: Contains all test resources
  - `resource.yaml`
  - `istio-resources.yaml`
  - `istio-label-resources.yaml`
  - `spot-affinity-resources.yaml`
  - `mtls-resources.yaml`
  - `deprecated-api-resources.yaml`
  - `virtual-service.yaml`
  - `pod-container-registry.yaml`
  - `pod-docker-io.yaml`
  - `pod-init-container.yaml`
  - `pod-my-registry.yaml`
  - `pod-skip-verify.yaml`

- `patched/`: Contains patched resources for mutation tests
  - `patched-deployment-1.yaml`
  - `patched-namespace-1.yaml`
  - `patched-namespace-2.yaml`
  - `patched-pod-container-registry.yaml`
  - `patched-pod-docker-io.yaml`
  - `patched-pod-init-container.yaml`
  - `generated-job.yaml`

- `tests/`: Contains test definitions
  - `all-tests.yaml`: Main test file that references all policies and resources
  - `image-swap-test.yaml`: Test file for image-swap policies

- `values.yaml`: Variables used in tests

## Scripts

- `setup.sh`: Creates the directory structure and all necessary files for testing
- `move_files.sh`: Utility script to move files to their respective directories

## Running Tests

To run all tests, use the following command:

```bash
kyverno test tests/all-tests.yaml
```

To run the image-swap tests, use:

```bash
kyverno test tests/image-swap-test.yaml
```

## Test Categories

The tests cover various policy types:
- VirtualService validation
- Resource limits enforcement
- Istio injection validation
- Namespace label mutation
- Pod anti-affinity mutation
- mTLS validation
- Deprecated API validation
- Image registry mutation
- Job generation based on image information 
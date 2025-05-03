# Kyverno Policy Tests

This directory contains tests for validating the Kyverno policies in this repository. The tests are designed to ensure that policies behave as expected when applied to different Kubernetes resources.

## Test Structure

The test suite consists of:

- `kyverno-test.yaml` - The main test definition file
- `variables.yaml` - Variables and contexts for the test environment

## Test Cases Explained

### Image Mutator Tests

These tests verify that the image mutator policy correctly transforms container images:

1. **Container Registry to Docker Hub Transformation**
   ```yaml
   - policy: image-mutator
     rule: mutate-container-images
     resources:
       - test-image-policy-pod
     kind: Pod
     result: pass
   ```
   This test verifies that images from `container-registry.xxx.net` are correctly transformed to use `docker.io`.

2. **Docker Hub to Custom Registry Transformation**
   ```yaml
   - policy: image-mutator
     rule: mutate-docker-images
     resources:
       - test-image-policy-pod2
     kind: Pod
     result: pass
   ```
   This test verifies that images from `docker.io` are correctly transformed to use `my.registry.com`.

3. **Multi-Container Pod Handling**
   ```yaml
   - policy: image-mutator
     rule: mutate-container-images
     resources:
       - test-multi-container-pod
     kind: Pod
     result: pass
   ```
   This test ensures that pods with multiple containers and init containers are properly transformed.

4. **Policy Exception Handling**
   ```yaml
   - policy: image-mutator
     rule: mutate-container-images
     resources:
       - exempted-pod
     kind: Pod
     result: skip
   ```
   This test verifies that the policy correctly skips resources that match a policy exception.

### Job Generator Tests

This test verifies that the job generator policy correctly creates jobs for applicable pods:

```yaml
- policy: image-job-generator
  rule: generate-push-job
  resources:
    - test-image-policy-pod
  kind: Pod
  result: pass
  generatedResource: ../patched/generated-job.yaml
```

The `generatedResource` field specifies the expected output job manifest, which is compared against the actual generated job during testing.

### Assertion Checks

The test includes pattern validation using the `checks` element:

```yaml
checks:
- match:
    resource:
      kind: Pod
      name: test-image-policy-pod
  assert:
    pattern:
      spec:
        containers:
        - image: my.registry.com/*
```

This check ensures that the resulting Pod has a container with an image that matches the expected pattern after policy application.

## Variables Configuration

The `variables.yaml` file defines:

```yaml
apiVersion: cli.kyverno.io/v1alpha1
kind: Values
metadata:
  name: values
globalValues:
  request.operation: CREATE
namespaceSelector:
  - name: default
    labels:
      environment: staging
```

This configuration:
- Sets the default operation context to `CREATE` (simulating resource creation)
- Defines a namespace selector for the `default` namespace with the label `environment: staging`

## Running the Tests

To run these tests:

```bash
# From the repository root
kyverno test tests/

# With specific test case selectors
kyverno test tests/ --test-case-selector "policy=image-mutator, rule=mutate-container-images"

# For detailed results
kyverno test tests/ --detailed-results
```

## Extending the Tests

To add new tests:

1. Add new resources to the `../resources/` directory
2. Update or add new policy definitions in `../policies/`
3. Add new test cases to `kyverno-test.yaml`
4. For generate rules, create expected output files in `../patched/`
5. For exceptions, define them in `../exceptions/`

## Troubleshooting

If tests fail, the most common issues are:

- Mismatch between expected and actual results
- Missing or incorrect resource definitions
- Policy rule names don't match what's being tested
- For generated resources, the expected output doesn't match what's actually generated

Check the test output for detailed information about which tests failed and why. 
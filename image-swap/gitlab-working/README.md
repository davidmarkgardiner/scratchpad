# Kyverno Image Swap Policies

This repository contains Kyverno policies for managing container images and automatically generating jobs based on image information. The policies provide automated container image mutation and related job generation for Kubernetes workloads.

## Overview

This project implements two Kyverno policies:

1. **Image Mutator Policy**: Automatically transforms container image references between different registries
2. **Job Generator Policy**: Generates Kubernetes jobs to process images discovered in pods

These policies help automate the management of container images across different environments, ensuring consistency and enabling additional processing when images are deployed.

## Policies Explained

### Image Mutator Policy (`image-mutator`)

This policy automatically transforms container image references by:

- Converting `container-registry.xxx.net/` images to `docker.io/`
- Converting `docker.io/` images to `my.registry.com/`
- Handling both regular containers and init containers
- Supporting multi-container pods

The policy contains multiple rules for different transformation scenarios:
- `mutate-container-images` - Transforms container registry images to Docker Hub images
- `mutate-init-container-images` - Same as above, but for init containers
- `mutate-docker-images` - Transforms Docker Hub images to custom registry images
- `mutate-docker-init-container-images` - Same as above, but for init containers

### Job Generator Policy (`image-job-generator`) 

This policy automatically generates Kubernetes jobs for image processing:

- Creates a job whenever an image from `my.registry.com/` is deployed in a pod
- Extracts image information and makes it available to the job
- Provides a script to process image metadata and perform additional operations
- Enables automatic image transformation and processing

## Resources

The project uses several test Kubernetes resources to validate the policies:

- `test-pod.yaml` - Basic pod with a single container for testing image mutation
- `test-pod2.yaml` - Another pod with different configuration for testing
- `test-pod-multi.yaml` - Pod with multiple containers and init containers for testing multi-container handling
- `exempted-pod.yaml` - Pod that should be exempted from policy application via policy exception

## Tests

The repository includes comprehensive Kyverno tests to verify policy behavior using the Kyverno CLI. The tests validate:

1. **Basic Image Mutation** 
   - Verifies that image references are correctly transformed
   - Tests both container-registry → docker.io and docker.io → custom registry paths

2. **Job Generation**
   - Confirms that jobs are generated for applicable pods
   - Validates the job specification, including labels, env variables, and script content

3. **Multi-container Handling**
   - Tests that mutation works correctly for pods with multiple containers
   - Ensures init containers are properly handled

4. **Policy Exceptions**
   - Verifies that pods matching an exception definition are not mutated
   - Tests the skipping behavior via the `exempted-pod` resource

5. **Pattern Validation**
   - Uses assertion checks to validate the structure of resulting resources
   - Ensures the expected image format is present in the processed resources

### Test Cases

The `kyverno-test.yaml` file defines the following test cases:

```yaml
# Image Mutator Tests
- policy: image-mutator
  rule: mutate-container-images
  resources:
    - test-image-policy-pod
  kind: Pod
  result: pass

- policy: image-mutator
  rule: mutate-docker-images
  resources:
    - test-image-policy-pod2
  kind: Pod
  result: pass

# Job Generator Tests
- policy: image-job-generator
  rule: generate-push-job
  resources:
    - test-image-policy-pod
  kind: Pod
  result: pass
  generatedResource: ../patched/generated-job.yaml

# Multi-container handling test
- policy: image-mutator
  rule: mutate-container-images
  resources:
    - test-multi-container-pod
  kind: Pod
  result: pass

# Exception test
- policy: image-mutator
  rule: mutate-container-images
  resources:
    - exempted-pod
  kind: Pod
  result: skip
```

Additionally, the test uses the `checks` section to validate specific patterns:

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

## Variable Configuration

The test suite uses a `variables.yaml` file to define:

- Operation context (CREATE, UPDATE) for testing policy behavior with different operations
- Namespace selectors to simulate different environment contexts
- Global values for simulating API server behavior

## Running Tests

To run the tests locally:

```bash
# Install Kyverno CLI
# For macOS:
brew install kyverno

# For Linux (download from GitHub):
wget https://github.com/kyverno/kyverno/releases/download/v1.13.4/kyverno-cli_v1.13.4_linux_x86_64.tar.gz
tar -xvf kyverno-cli_v1.13.4_linux_x86_64.tar.gz
mv kyverno /usr/local/bin/

# Run the tests
cd image-swap
kyverno test tests/
```

## CI/CD Integration

The project includes GitLab CI configuration (`.gitlab-ci.yml`) that:

1. Sets up a test environment with the Kyverno CLI
2. Runs all policy tests
3. Captures test results for reporting
4. Generates test artifacts for review

The CI pipeline ensures that policies are continuously validated whenever changes are made to the codebase.

## How to Use These Policies

To use these policies in your Kubernetes cluster:

1. Install Kyverno in your cluster
   ```bash
   kubectl create -f https://github.com/kyverno/kyverno/releases/download/v1.13.4/install.yaml
   ```

2. Apply the policies
   ```bash
   kubectl apply -f policies/
   ```

3. Deploy your workloads and observe:
   - Images will be automatically transformed based on the registry
   - Jobs will be generated for applicable images

## Project Structure

```
image-swap/
├── .gitlab-ci.yml              # CI configuration
├── policies/                   # Kyverno policies
│   ├── image-mutator-policy.yaml
│   └── job-generator-policy.yaml
├── resources/                  # Test Kubernetes resources
│   ├── test-pod.yaml
│   ├── test-pod2.yaml
│   ├── test-pod-multi.yaml
│   └── exempted-pod.yaml
├── patched/                    # Expected output resources
│   └── generated-job.yaml
├── exceptions/                 # Policy exceptions
│   └── image-exception.yaml
└── tests/                      # Kyverno tests
    ├── kyverno-test.yaml
    └── variables.yaml
```

## Contributing

Contributions to improve these policies or add new features are welcome. Please ensure that:

1. All policies include comprehensive tests
2. Any changes maintain backward compatibility where possible
3. Documentation is updated to reflect changes

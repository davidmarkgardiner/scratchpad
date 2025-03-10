# Kyverno CLI Tests for Image Swap Policies

This directory contains test cases for the Kyverno policies in the `tag` directory.

## Prerequisites

- Kyverno CLI installed (version 1.7.2 or later)
- kubectl installed

## Test Files

- `resources/`: Directory containing sample Pod resources and expected outputs
- `run-tests.sh`: Script to run the tests
- `yaml/`: Directory where test results are saved

## Running the Tests

The easiest way to run the tests is to use the provided script:

```bash
# From the image-swap directory
./test/run-tests.sh

# Or from the test directory
cd test
./run-tests.sh
```

The script will:
1. Apply the image-mutator policy to the sample Pod resources
2. Apply the job-generator policy to the sample Pod resources
3. Display the results
4. Save test results in the `yaml` directory
5. Provide a summary of test results

## Test Resources

The `resources` directory contains:

- Sample Pod resources with different image registries
- Expected patched resources after mutation
- Expected generated Job resource

## Manual Testing

You can also manually test the policies using the Kyverno CLI:

```bash
# Test the image-mutator policy
kyverno apply ../tag/2-image-mutator-policy.yaml --resource resources/pod-container-registry.yaml

# Test the job-generator policy
kyverno apply ../tag/5-job-generator-policy.yaml --resource resources/pod-my-registry.yaml
```

## Test Cases

### Image Mutator Policy Tests

1. Mutate container images from container-registry.xxx.net to docker.io
2. Skip mutation for resources with skip-verify label
3. Mutate container images from docker.io to container-registry.xxx.net
4. Mutate initContainer images

### Job Generator Policy Tests

1. Generate a Job for Pods with my.registry.com images
2. Skip job generation for resources with skip-verify label 
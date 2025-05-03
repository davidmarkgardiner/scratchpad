# Kyverno Image Policy Tests

This directory contains test files for validating the Kyverno image identification and processing policies.

## Directory Structure

- `tests/`: Contains test definitions and resource files
  - `resources/`: Sample Kubernetes resources for testing
  - `image-identification-test.yaml`: Comprehensive test for all policies
  - `variables.yaml`: Variables used in tests
- `patched/`: Contains expected generated resource files
- `exceptions/`: Contains policy exceptions
- `job/`: Contains additional job-related examples

## Test Resources

The test resources include:

### Pod Resources
- `test-pod.yaml`: Simple Pod with a single container
- `test-pod-multi.yaml`: Pod with multiple containers including init containers
- `test-pod2.yaml`: Alternative Pod for testing

### Job Resources
- `test-job.yaml`: Basic Job with a single container
- `test-job-init.yaml`: Job with an init container

### CronJob Resources
- `test-cronjob.yaml`: Basic CronJob with a single container
- `test-cronjob-init.yaml`: CronJob with an init container

## Running Tests

Run all tests with:

```bash
kyverno test .
```

Run a specific test with:

```bash
kyverno test tests/image-identification-test.yaml
```

## Test Verification

The tests verify:

1. **Policy Triggers**: Confirm policies trigger on appropriate resources
2. **Job Generation**: Verify Jobs are created with correct parameters
3. **Resource Processing**: Ensure all container types are processed
4. **Exclusions**: Verify resources with exclusion labels are not processed

## Expected Results

Each test specifies expected results, including:

- Whether the rule should pass, fail, or be skipped
- The expected generated resources
- Specific assertions about the resources

## Troubleshooting

If tests fail, check:

1. Policy preconditions match the test resources
2. Resources use the correct image patterns (e.g., `my.registry.com/...`)
3. Generated resource names match what's expected in the test
4. Namespaces match the policy match/exclude conditions 
# Kyverno Image Identification and Management

This project provides Kyverno policies for identifying and managing container images across different Kubernetes resource types including Pods, Jobs, and CronJobs.

## Features

- Identifies container images in Pods, Jobs, and CronJobs
- Handles regular containers, init containers, and ephemeral containers
- Generates Jobs that process identified images
- Provides detailed information about images for auditing and management
- Supports transformations like replicating images across registries

## Policy Components

The project includes the following policies:

- **Pod Image Identification** (`pod-job-generator-policy.yaml`)
- **Job Image Identification** (`job-job-generator-policy.yaml`)
- **CronJob Image Identification** (`cronjob-job-generator-policy.yaml`)

## Installation

Apply the policies to your Kubernetes cluster using kubectl:

```bash
kubectl apply -f policies/
```

## Testing

Use the Kyverno CLI to test the policies:

```bash
# Run all tests
kyverno test .

# Run specific test
kyverno test kyvernotests/tests/image-identification-test.yaml
```

## Examples

The test resources directory contains example manifests for:

- Pods with various container configurations
- Jobs with regular and init containers
- CronJobs with regular and init containers

## Configuration

The policies are configured to:

1. Match resources in the `default` namespace and namespaces starting with `a`
2. Exclude resources in `kube-system` and `kyverno` namespaces
3. Exclude resources with the label `skip-verify: "true"`
4. Process only images from `my.registry.com` registry

## Documentation

For more details, see:

- [Image Policies Documentation](image-policies.md) - Detailed policy description
- [Test Scenarios](../kyvernotests/README.md) - Description of test cases

## License

This project is licensed under the [Apache License 2.0](LICENSE). 
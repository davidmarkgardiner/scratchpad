# Kyverno Unique Job Per Container Image

This directory contains a Kyverno ClusterPolicy implementation that generates truly unique jobs per container image, ensuring that each unique container image results in only one job being created regardless of how many pods use that image.

## Overview

The policy uses Kyverno's built-in hashing functionality to create deterministic, unique job names based on container images. This prevents duplicate job creation while ensuring proper RFC 1123 compliance for Kubernetes resource names.

## Key Features

- **Image-based Uniqueness**: Jobs are generated based on container image hashes, not pod names
- **RFC 1123 Compliance**: Job names are truncated and prefixed to ensure Kubernetes naming compliance
- **Namespace Isolation**: Jobs are created in the same namespace as the triggering pod
- **Duplicate Prevention**: Uses `synchronize: false` to prevent recreation of existing jobs
- **Comprehensive Labeling**: Jobs include metadata for tracking and debugging
- **System Namespace Exclusion**: Automatically excludes kyverno and kube-system namespaces

## Files

### Core Implementation
- `clusterpolicy.yaml` - Main Kyverno ClusterPolicy with image-based job generation
- `test-pods.yaml` - Comprehensive test cases demonstrating functionality
- `cleanup.sh` - Cleanup script for removing test resources
- `README.md` - This documentation file

## Policy Details

### Hash-Based Naming Strategy

The policy uses the following naming convention:
```yaml
name: "img-{{ hash(request.object.spec.containers[0].image) | truncate(@, `8`) }}"
```

This approach:
1. **Hashes the image name**: Creates a deterministic hash of the full image string
2. **Truncates for compliance**: Limits to 8 characters to ensure RFC 1123 compliance
3. **Adds prefix**: Uses "img-" prefix to ensure the name starts with a letter
4. **Ensures uniqueness**: Same image always produces the same hash

### Job Generation Logic

```yaml
generate:
  synchronize: false  # Prevents recreation of existing jobs
  apiVersion: batch/v1
  kind: Job
  name: "img-{{ hash(request.object.spec.containers[0].image) | truncate(@, `8`) }}"
  namespace: "{{ request.object.metadata.namespace }}"
```

### Preconditions

The policy includes several preconditions to ensure proper operation:

1. **Image existence check**: Ensures the pod has at least one container with an image
2. **Namespace exclusions**: Prevents execution in kyverno and kube-system namespaces
3. **Owner reference check**: Only triggers for pods without owner references (direct pod creation)

## Test Cases

The `test-pods.yaml` file includes comprehensive test cases:

### Test Case 1: Same Image, Multiple Pods
- **Scenario**: 3 pods using `nginx:1.21`
- **Expected Result**: Only 1 job created with name `img-<hash>`
- **Validates**: Core uniqueness functionality

### Test Case 2: Different Image Versions
- **Scenario**: Pods using `nginx:latest` and `nginx:alpine`
- **Expected Result**: 2 separate jobs with different hashes
- **Validates**: Version sensitivity

### Test Case 3: Completely Different Images
- **Scenario**: Pods using `redis:6.2` and `postgres:13`
- **Expected Result**: 2 separate jobs with different hashes
- **Validates**: Image type differentiation

### Test Case 4: Same Image, Different Namespace
- **Scenario**: `nginx:1.21` in default and test-namespace
- **Expected Result**: 2 jobs (one per namespace)
- **Validates**: Namespace isolation

### Test Case 5: Complex Image Names
- **Scenario**: Registry with path `gcr.io/google-containers/busybox:1.27.2`
- **Expected Result**: Proper handling of complex image strings
- **Validates**: Registry path handling

### Test Case 6: Image with Digest
- **Scenario**: Image specified with SHA256 digest
- **Expected Result**: Job creation with digest-based hash
- **Validates**: Digest-based image references

## Installation and Testing

### Prerequisites
- Kyverno 1.8.0 or later installed in your cluster
- kubectl configured with cluster access
- Appropriate RBAC permissions for Kyverno to generate jobs

### Installation Steps

1. **Apply the ClusterPolicy**:
   ```bash
   kubectl apply -f clusterpolicy.yaml
   ```

2. **Verify policy installation**:
   ```bash
   kubectl get clusterpolicy generate-unique-job-per-image
   ```

3. **Deploy test pods**:
   ```bash
   kubectl apply -f test-pods.yaml
   ```

4. **Monitor job creation**:
   ```bash
   kubectl get jobs -A --show-labels
   ```

### Expected Results

After applying the test pods, you should see:

```bash
# Jobs in default namespace
kubectl get jobs -n default
NAME           COMPLETIONS   DURATION   AGE
img-a1b2c3d4   1/1           45s        2m   # nginx:1.21 (from 3 pods)
img-e5f6g7h8   1/1           35s        2m   # nginx:latest
img-i9j0k1l2   1/1           40s        2m   # nginx:alpine
img-m3n4o5p6   1/1           42s        2m   # redis:6.2
img-q7r8s9t0   1/1           38s        2m   # postgres:13
img-u1v2w3x4   1/1           36s        2m   # gcr.io/google-containers/busybox:1.27.2
img-y5z6a7b8   1/1           41s        2m   # busybox@sha256:...

# Jobs in test-namespace
kubectl get jobs -n test-namespace
NAME           COMPLETIONS   DURATION   AGE
img-a1b2c3d4   1/1           43s        2m   # nginx:1.21 (same hash, different namespace)
```

## Monitoring and Debugging

### View Job Details
```bash
kubectl describe job img-<hash> -n <namespace>
```

### Check Job Logs
```bash
kubectl logs job/img-<hash> -n <namespace>
```

### View Policy Events
```bash
kubectl get events --field-selector reason=PolicyApplied
```

### Debugging Hash Values

To manually calculate what hash a specific image will generate:
```bash
# This requires the same hashing function Kyverno uses
echo -n "nginx:1.21" | sha256sum | cut -c1-8
```

## Labels and Annotations

Each generated job includes comprehensive metadata:

### Labels
- `app: image-processor` - Application identifier
- `generated-by: kyverno` - Generation source
- `source-image-hash: <hash>` - Truncated image hash
- `source-image: <sanitized-image>` - Sanitized image name

### Annotations
- `kyverno.io/generated-by-policy` - Policy name that generated the job
- `kyverno.io/source-image` - Original image name
- `kyverno.io/source-pod` - Name of the pod that triggered generation
- `kyverno.io/source-namespace` - Namespace of the triggering pod

## Cleanup

To clean up all test resources:

```bash
./cleanup.sh
```

Or manually:

```bash
# Remove test pods
kubectl delete -f test-pods.yaml

# Remove generated jobs
kubectl delete jobs -l generated-by=kyverno --all-namespaces

# Remove test namespace
kubectl delete namespace test-namespace

# Remove the policy (if desired)
kubectl delete clusterpolicy generate-unique-job-per-image
```

## Customization

### Modifying the Job Template

The job template can be customized in the `generate.data.spec.template` section:

```yaml
spec:
  template:
    spec:
      containers:
      - name: image-analyzer
        image: your-custom-image:latest
        # Your custom logic here
```

### Adjusting Hash Length

Modify the truncate parameter to change hash length:
```yaml
name: "img-{{ hash(request.object.spec.containers[0].image) | truncate(@, `12`) }}"
```

### Adding Additional Preconditions

Add more preconditions to the policy:
```yaml
preconditions:
  all:
  - key: "{{ request.object.metadata.labels.process || 'true' }}"
    operator: Equals
    value: "true"
```

## RFC 1123 Compliance

The policy ensures RFC 1123 compliance through:

1. **Letter prefix**: "img-" ensures names start with a letter
2. **Hash truncation**: Limits length to prevent overly long names
3. **Character sanitization**: Uses only alphanumeric characters and hyphens

Valid job name pattern: `^img-[a-f0-9]{8}$`

## Troubleshooting

### Common Issues

1. **Jobs not being created**:
   - Check if the policy is installed: `kubectl get clusterpolicy`
   - Verify Kyverno is running: `kubectl get pods -n kyverno`
   - Check policy conditions match your pods

2. **Duplicate jobs appearing**:
   - Verify `synchronize: false` is set
   - Check if jobs are being created in different namespaces (expected behavior)

3. **Job names not RFC compliant**:
   - Verify the truncate length is appropriate
   - Check for any custom modifications to the naming logic

### Policy Validation

Validate the policy syntax before applying:
```bash
kubectl apply --dry-run=server -f clusterpolicy.yaml
```

## Performance Considerations

- **Hash computation**: Minimal overhead for hash calculation
- **Job creation**: Limited by Kubernetes API rate limits
- **Resource cleanup**: Jobs auto-cleanup after 300 seconds (configurable via `ttlSecondsAfterFinished`)

## Security Considerations

- Jobs run with default service account (customize as needed)
- Resource limits are applied to prevent resource exhaustion
- System namespaces are excluded from policy application

## Version Compatibility

- **Minimum Kyverno version**: 1.8.0
- **Kubernetes version**: 1.19+
- **Features used**: JMESPath expressions, hash function, generate rule with synchronize

## Contributing

When modifying this policy:

1. Test all changes with the provided test cases
2. Verify RFC 1123 compliance
3. Update documentation accordingly
4. Consider backward compatibility

## References

- [Kyverno Documentation](https://kyverno.io/docs/)
- [JMESPath Documentation](https://jmespath.org/)
- [RFC 1123 Naming Convention](https://tools.ietf.org/html/rfc1123)
- [Kubernetes Job Documentation](https://kubernetes.io/docs/concepts/workloads/controllers/job/)
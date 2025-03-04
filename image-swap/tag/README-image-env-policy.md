# Image Name and Tag Environment Variables Kyverno Policy

This directory contains a Kyverno policy that extracts the image name and tag from container images and adds them as environment variables to containers in pods and batch jobs.

## Policy Description

The `mutate-batch-image-env.yaml` policy:
- Targets Kubernetes Pod, Job, and CronJob resources
- Extracts the image name and tag from container images
- Adds them as `IMAGE_NAME` and `IMAGE_TAG` environment variables to each container

## Use Case

This policy is particularly useful for scenarios where:

1. You have pods being deployed on your cluster with specific container images
2. You need to run batch jobs that need to know which images are being used
3. The batch jobs need to perform operations based on the image name and tag

For example, you might want to:
- Run security scans on deployed images
- Perform image-specific cleanup or maintenance tasks
- Track which image versions are deployed in your cluster

## Testing the Policy

### 1. Apply the Kyverno Policy

```bash
kubectl apply -f mutate-batch-image-env.yaml
```

### 2. Create the Test Resources

```bash
kubectl apply -f test-batch-job.yaml
```

This will create:
- A test pod with an nginx:1.19.3 image
- A batch job with a busybox image that will use the environment variables

### 3. Verify the Policy

Check if the environment variables were added to both the pod and the job:

```bash
# Check the pod
kubectl get pod test-app-pod -o jsonpath='{.spec.containers[0].env}'

# Get the job pod name
JOB_POD_NAME=$(kubectl get pods -l job-name=test-image-env-job -o jsonpath='{.items[0].metadata.name}')

# Check the job pod
kubectl get pod $JOB_POD_NAME -o jsonpath='{.spec.containers[0].env}'

# Check the job logs
kubectl logs $JOB_POD_NAME
```

Expected output from the job logs:
```
Job processing image information:
IMAGE_NAME: busybox
IMAGE_TAG: latest
Performing actions based on image information...
```

## How It Works

The policy uses two separate rules:

1. **extract-image-info-for-pods**: Targets Pod resources and adds environment variables to their containers
2. **extract-image-info-for-jobs**: Targets Job and CronJob resources and adds environment variables to their pod template containers

For each container, it:
- Extracts the image name by removing the registry path and tag
- Extracts the image tag (defaults to "latest" if not specified)
- Adds these as environment variables to the container

### Example

For an image `nginx:1.19.3`:
- `IMAGE_NAME` will be set to `nginx`
- `IMAGE_TAG` will be set to `1.19.3`

For an image without a tag (e.g., `nginx`):
- `IMAGE_NAME` will be set to `nginx`
- `IMAGE_TAG` will be set to `latest`

## Real-World Implementation

In a real-world scenario, you might want to:

1. Have pods with specific images deployed in your cluster
2. Run batch jobs that need to perform operations based on those images
3. Pass the image information from the pods to the jobs

To achieve this, you would need to:
1. Modify the policy to extract image information from specific pods
2. Store this information (e.g., in a ConfigMap or through a service)
3. Have your batch jobs retrieve and use this information

This example policy demonstrates the basic mechanism of extracting and adding the environment variables, which you can extend for your specific use case. 
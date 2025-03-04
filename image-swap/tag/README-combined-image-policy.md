# Combined Image Policy for Kubernetes

This document describes the `combined-image-policy` Kyverno policy that provides multiple image-related functions for Kubernetes clusters.

## Policy Features

The policy combines several image management capabilities:

1. **Image Environment Variables**: Adds `IMAGE_NAME` and `IMAGE_TAG` environment variables to containers in Pods, Jobs, and CronJobs
2. **Image Registry Verification**: Verifies if images exist in the specified Azure Container Registry
3. **Image Push Job Generation**: Creates jobs to push missing images to ACR
4. **Image Registry Mutation**: Rewrites image references to use the specified ACR

## Use Cases

This policy is particularly useful for:

- Ensuring all container images are sourced from your private registry
- Automatically importing missing images to your registry
- Providing image information to containers via environment variables
- Enforcing image registry policies across your cluster

## Prerequisites

Before using this policy, ensure you have:

1. A Kubernetes cluster with Kyverno installed
2. An Azure Container Registry (ACR) instance
3. Proper authentication configured for ACR access
4. A Kubernetes secret named `acr-secret` for pulling images from ACR
5. A Kubernetes secret named `acr-auth` containing Azure service principal credentials

## Installation

Apply the policy to your cluster:

```bash
kubectl apply -f combined-image-policy.yaml
```

## Test Plan

### 1. Test Image Environment Variables

**Objective**: Verify that image environment variables are added to containers.

**Steps**:
1. Create a test pod:
   ```bash
   kubectl apply -f test-pod.yaml
   ```

2. Verify environment variables:
   ```bash
   kubectl exec test-pod -- env | grep IMAGE_
   ```

**Expected Result**: The pod should have `IMAGE_NAME` and `IMAGE_TAG` environment variables.

### 2. Test Image Registry Verification and Mutation

**Objective**: Verify that images are checked against ACR and references are mutated.

**Steps**:
1. Create a pod with an image not in your ACR:
   ```bash
   kubectl apply -f test-pod.yaml
   ```

2. Check if the image reference was mutated:
   ```bash
   kubectl get pod test-pod -o jsonpath='{.spec.containers[0].image}'
   ```

**Expected Result**: The image reference should be rewritten to use your ACR.

### 3. Test Job Generation for Missing Images

**Objective**: Verify that a job is generated to push missing images to ACR.

**Steps**:
1. Create a pod with an image not in your ACR:
   ```bash
   kubectl apply -f test-pod.yaml
   ```

2. Check if a job was created:
   ```bash
   kubectl get jobs
   ```

3. Check the job logs:
   ```bash
   kubectl logs job/push-image-test-pod
   ```

**Expected Result**: A job should be created that displays the image information.

### 4. Test Batch Job Environment Variables

**Objective**: Verify that image environment variables are added to batch jobs.

**Steps**:
1. Create a test job:
   ```bash
   kubectl apply -f test-batch-job.yaml
   ```

2. Check the job logs:
   ```bash
   # Get the job pod name
   JOB_POD_NAME=$(kubectl get pods -l job-name=test-job -o jsonpath='{.items[0].metadata.name}')
   
   # Check logs
   kubectl logs $JOB_POD_NAME
   ```

**Expected Result**: The job logs should show the `IMAGE_NAME` and `IMAGE_TAG` values.

## Sample Test Resources

### test-pod.yaml

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: test-pod
  namespace: default
spec:
  containers:
  - name: nginx
    image: nginx:latest
```

### test-batch-job.yaml

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: test-job
  namespace: default
spec:
  template:
    spec:
      containers:
      - name: job-container
        image: busybox:latest
        command: ["sh", "-c"]
        args:
        - |
          echo "Job processing image information:"
          echo "IMAGE_NAME: $IMAGE_NAME"
          echo "IMAGE_TAG: $IMAGE_TAG"
          echo "Performing actions based on image information..."
          sleep 30
      restartPolicy: Never
  backoffLimit: 0
```

## Troubleshooting

If you encounter issues:

1. Check Kyverno logs:
   ```bash
   kubectl logs -n kyverno -l app=kyverno
   ```

2. Verify policy is applied:
   ```bash
   kubectl get clusterpolicy combined-image-policy -o yaml
   ```

3. Check for policy violations:
   ```bash
   kubectl get policyreport -A
   ```

## Customization

To customize this policy:

1. Change the ACR name by modifying:
   - `crdevcr.azurecr.io` in the `verifyImages` and `mutate-container-images` rules
   - `crdevacr2` in the job generation script

2. Adjust the environment variable names by modifying the `extract-image-info-*` rules

3. Modify the job script to perform different actions with the image information 
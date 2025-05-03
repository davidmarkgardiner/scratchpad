# Kyverno Image Identification and Processing Policies

This document describes a set of Kyverno policies designed to identify and process container images across different Kubernetes resource types.

## Overview

The policies in this project identify container images specified in Pod, Job, and CronJob resources, and generate Jobs that process these images. The primary focus is on identifying images from `my.registry.com` and facilitating operations like replication and transformation of these images.

## Policies

### 1. Pod Image Identification (`pod-job-generator-policy.yaml`)

This policy generates jobs based on container images found in Pod resources.

- **Target Resources**: Pods and Pod controllers (via autogen)
- **Rules**:
  - `generate-push-job-pod-container`: Identifies container images in Pods
  - `generate-push-job-pod-init-container`: Identifies init container images in Pods

### 2. Job Image Identification (`job-job-generator-policy.yaml`)

This policy generates jobs based on container images found in Job resources.

- **Target Resources**: Jobs
- **Rules**:
  - `generate-push-job-container`: Identifies container images in Jobs
  - `generate-push-job-init-container`: Identifies init container images in Jobs

### 3. CronJob Image Identification (`cronjob-job-generator-policy.yaml`)

This policy generates jobs based on container images found in CronJob resources.

- **Target Resources**: CronJobs
- **Rules**:
  - `generate-push-job-container-0`: Identifies container images in CronJobs
  - `generate-push-job-init-container`: Identifies init container images in CronJobs

## Policy Behavior

Each policy:

1. Watches for resources that use images from `my.registry.com`
2. When matching resources are found, generates a Job with:
   - Unique naming based on the original image
   - Environment variables capturing details about the original image and resource
   - A script that:
     - Logs information about the detected image
     - Performs transformations on Docker Hub images if applicable
     - Could be extended to handle image replication or other processing

## Generated Jobs

The generated jobs contain:

- **Resource-specific information**: Name, namespace, resource kind
- **Container details**: Name, type (regular/init/ephemeral), index
- **Image information**: Original image path, registry, tag

## Labels and Metadata

The generated jobs include these labels:

- `skip-verify: "true"`: Prevents policy loop by excluding these jobs from further processing
- `image-info`: Information about the processed image
- `resource-kind`: Type of resource the image came from (Pod, Job, CronJob)
- `container-type`: Type of container (container, initContainer)
- `container-index`: Index of the container in the spec

## Use Cases

These policies can be used for:

1. **Image inventory and audit**: Track all images used in your cluster
2. **Image replication**: Copy images from public registries to private ones
3. **Image transformation**: Modify images to comply with organizational standards
4. **Security scanning**: Trigger scans of images when they're deployed

## Testing

The policies can be tested using the Kyverno CLI and the test YAML files in the `kyvernotests` directory:

```bash
kyverno test .
```

The test files include examples for all supported resource types and container configurations. 
# Unique Job Per Image - Kyverno Solution

## Overview

This implementation creates **exactly ONE Kubernetes Job per unique container image**, regardless of how many pods use that image. This solves the duplicate job problem from the original RFC-based implementation.

## Key Achievement

✅ **TRUE UNIQUENESS**: Multiple pods with the same image create only ONE job
✅ **RFC 1123 COMPLIANT**: All job names are valid Kubernetes resource names
✅ **DETERMINISTIC**: Same image always generates the same job name
✅ **NO DUPLICATES**: `synchronize: false` prevents job recreation

## How It Works

### Name Generation Algorithm

The policy generates deterministic job names by transforming the image string:

```yaml
name: "img-{{ replace_all(replace_all(replace_all(replace_all(replace_all(
  request.object.spec.containers[0].image, 
  '/', '-'), 
  ':', '-'), 
  '.', '-'), 
  '@', '-'), 
  '_', '-') | truncate(@, `50`) }}"
```

### Transformation Examples

| Original Image | Generated Job Name | Pods Using Image | Jobs Created |
|----------------|-------------------|------------------|--------------|
| `nginx:1.21` | `img-nginx-1-21` | 3 | **1** |
| `redis:7.0` | `img-redis-7-0` | 2 | **1** |
| `postgres:14` | `img-postgres-14` | 1 | **1** |
| `docker.io/nginx:latest` | `img-docker-io-nginx-latest` | 5 | **1** |

## Installation

1. **Apply the ClusterPolicy**:
```bash
kubectl apply -f clusterpolicy-working.yaml
```

2. **Verify policy is ready**:
```bash
kubectl get clusterpolicy generate-unique-job-per-image-v3
```

## Testing & Verification

### Test 1: Multiple Pods, Same Image

```bash
# Create 3 pods with nginx:1.21
kubectl run nginx-pod-1 --image=nginx:1.21 --restart=Never
kubectl run nginx-pod-2 --image=nginx:1.21 --restart=Never
kubectl run nginx-pod-3 --image=nginx:1.21 --restart=Never

# Check jobs (should be only ONE)
kubectl get jobs -l generated-by=unique-job-per-image-policy
# Expected: img-nginx-1-21 (only one job!)
```

### Test 2: Different Images

```bash
# Create pods with different images
kubectl run redis-pod --image=redis:7.0 --restart=Never
kubectl run postgres-pod --image=postgres:14 --restart=Never

# Check jobs (one per unique image)
kubectl get jobs -l generated-by=unique-job-per-image-policy
# Expected: 
# - img-nginx-1-21
# - img-redis-7-0
# - img-postgres-14
```

### Test 3: Verify No Duplicates

```bash
# Create another pod with nginx:1.21
kubectl run nginx-pod-4 --image=nginx:1.21 --restart=Never

# Count nginx jobs
kubectl get jobs | grep img-nginx-1-21 | wc -l
# Expected: 1 (no new job created!)
```

## Key Features

### 1. Synchronize Setting
```yaml
synchronize: false
```
This critical setting prevents Kyverno from recreating jobs that already exist.

### 2. Deterministic Naming
- Same image → Same job name (always)
- Character replacement ensures RFC compliance
- No randomness, no timestamps

### 3. Pod Traceability
Jobs include metadata about the triggering pod:
```yaml
annotations:
  original-image: "{{ request.object.spec.containers[0].image }}"
  source-pod: "{{ request.object.metadata.name }}"
```

## Comparison with Original Implementation

| Feature | Original (RFC-based) | New (Image-based) |
|---------|---------------------|-------------------|
| Job naming | `rfc-<pod-name>` | `img-<image-string>` |
| Jobs per image | Multiple (one per pod) | **ONE** |
| Uniqueness | Per pod | **Per image** |
| Resource usage | Higher | **Lower** |
| Deduplication | In container only | **At Kubernetes level** |

## Architecture Diagram

```
┌─────────────────────────────────────────────┐
│          Multiple Pods Created              │
├─────────────────────────────────────────────┤
│ Pod: nginx-1 (image: nginx:1.21)           │
│ Pod: nginx-2 (image: nginx:1.21)           │
│ Pod: nginx-3 (image: nginx:1.21)           │
│ Pod: redis-1 (image: redis:7.0)            │
└────────────────┬────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────┐
│         Kyverno ClusterPolicy               │
│   generate-unique-job-per-image-v3          │
└────────────────┬────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────┐
│        Jobs Created (Unique!)               │
├─────────────────────────────────────────────┤
│ Job: img-nginx-1-21 (for ALL nginx pods)   │
│ Job: img-redis-7-0  (for redis pod)        │
└─────────────────────────────────────────────┘
```

## Monitoring

### Check Job Creation
```bash
# List all jobs created by the policy
kubectl get jobs -l generated-by=unique-job-per-image-policy

# Check job details
kubectl describe job img-nginx-1-21

# View job logs
kubectl logs job/img-nginx-1-21
```

### Debug Issues
```bash
# Check policy status
kubectl describe clusterpolicy generate-unique-job-per-image-v3

# Check Kyverno logs
kubectl logs -n kyverno deploy/kyverno-admission-controller

# View policy events
kubectl get events --field-selector reason=PolicyViolation
```

## Cleanup

```bash
# Delete all generated jobs
kubectl delete jobs -l generated-by=unique-job-per-image-policy

# Delete the policy
kubectl delete clusterpolicy generate-unique-job-per-image-v3

# Delete test pods
kubectl delete pods -l generated-by!=unique-job-per-image-policy
```

## Production Considerations

1. **Namespace Scope**: Currently limited to `default` and `test-namespace`
2. **TTL Setting**: Jobs auto-delete after 300 seconds (configurable)
3. **Resource Limits**: Consider adding resource limits to job containers
4. **Monitoring**: Set up alerts for failed jobs

## Conclusion

This implementation successfully achieves **true unique job generation per container image** using Kyverno's native JMESPath functions. The deterministic naming based on image strings ensures that:

- ✅ Same image = Same job name = Only one job
- ✅ No duplicate jobs for the same image
- ✅ RFC 1123 compliant names
- ✅ Efficient resource usage
- ✅ Easy debugging with clear job names

The key innovation is using `synchronize: false` with deterministic image-based naming, eliminating the need for complex hashing while maintaining uniqueness at the Kubernetes resource level.
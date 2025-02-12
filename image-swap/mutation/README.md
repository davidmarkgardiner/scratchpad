# Image Registry Mutation Policy

This repository contains a Kyverno policy that automatically mutates container image references to use a specified Azure Container Registry (ACR).

## Policy Overview

The `mutate-image-registry` policy automatically modifies Pod specifications to:
- Redirect all container images to use the specified Azure Container Registry (crdevcr.azurecr.io)
- Add necessary image pull secrets for ACR authentication
- Apply to both regular containers and init containers

### Policy Features

- **Registry Mutation**: Automatically prepends `crdevcr.azurecr.io/` to all container images
- **Exclusions**: Pods with label `skip-verify: "true"` are excluded from mutation
- **Init Container Support**: Handles both regular containers and init containers
- **Image Pull Secrets**: Automatically adds ACR credentials

## Testing the Policy

A test pod specification is provided in `working/test-pod.yaml` to demonstrate the policy in action.

### Test Case

Original container images:
```yaml
containers:
- name: nginx
  image: nginx:latest
initContainers:
- name: init-myservice
  image: busybox:1.28
```

After mutation:
```yaml
containers:
- name: nginx
  image: crdevcr.azurecr.io/nginx:latest
initContainers:
- name: init-myservice
  image: crdevcr.azurecr.io/busybox:1.28
```

### Prerequisites

To successfully run pods with this policy:
1. The specified ACR must be accessible
2. An `acr-secret` containing valid ACR credentials must be present in the namespace
3. Required images must exist in the target ACR

## Usage

1. Apply the policy:
```bash
kubectl apply -f working/mutate-image-registry.yaml
```

2. Create a test pod:
```bash
kubectl apply -f working/test-pod.yaml
```

3. Verify the mutation:
```bash
kubectl get pod test-image-mutation -o yaml
```

## Notes

- The policy operates on Pod admission
- Images must be available in the specified ACR
- Proper ACR authentication must be configured
- Policy can be bypassed using the `skip-verify: "true"` label if needed 
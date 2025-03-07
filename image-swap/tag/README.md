# Image Processing Policies

This directory contains two Kyverno policies that work together to process images between `container-registry.xxx.net` and `docker.io`:

1. `1-job-generator-policy.yaml`: Generates a job for each pod with an image from `container-registry.xxx.net` and includes logic to handle `docker.io` images
2. `2-image-mutator-policy.yaml`: Mutates images in both directions, preserving only the image name and tag

## How It Works

The policies provide bidirectional image transformation with simplified image paths:

1. For images from any registry:
   - The registry prefix is removed, leaving only the image name and tag
   - A new registry prefix is added (either docker.io or container-registry.xxx.net)

2. For example:
   - `container-registry.xxx.net/namespace/nginx:1.19.3` → `docker.io/nginx:1.19.3`
   - `docker.io/library/nginx:1.19.3` → `container-registry.xxx.net/nginx:1.19.3`

This approach ensures consistent image paths regardless of the source registry structure.

## Important Notes

- These policies only apply to namespaces that start with "a" (e.g., "app", "api", "auth")
- The policies use the `contains` function with the `Equals` operator to check image registries
- System namespaces (kube-system, kyverno) are excluded
- All path information before the last slash is removed, keeping only the image name and tag

## Installation

Apply the policies in order:

```bash
kubectl apply -f 1-job-generator-policy.yaml
kubectl apply -f 2-image-mutator-policy.yaml
```

## Testing

You can test the policies with sample pods in a namespace that starts with "a":

### Testing container-registry.xxx.net to docker.io:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: test-registry-to-docker
  namespace: app
spec:
  containers:
  - name: nginx
    image: container-registry.xxx.net/namespace/nginx:1.19.3
```

Result: The image will be transformed to `docker.io/nginx:1.19.3`

### Testing docker.io to container-registry.xxx.net:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: test-docker-to-registry
  namespace: app
spec:
  containers:
  - name: nginx
    image: docker.io/library/nginx:1.19.3
```

Result: The image will be transformed to `container-registry.xxx.net/nginx:1.19.3`

## Troubleshooting

If the policies aren't working as expected:

1. Check the Kyverno logs: `kubectl logs -n kyverno -l app=kyverno`
2. Verify that the pod is in a namespace that starts with "a"
3. Verify that the pod's image contains either "container-registry.xxx.net/" or "docker.io/"
4. Make sure the pod doesn't have the `skip-verify: "true"` label 
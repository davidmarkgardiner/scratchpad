# Image Processing Policies

This directory contains two Kyverno policies that work together to process images from `container-registry.xxx.net`:

1. `1-job-generator-policy.yaml`: Generates a job for each pod with an image from `container-registry.xxx.net`
2. `2-image-mutator-policy.yaml`: Mutates images from `container-registry.xxx.net` to use `docker.io`

## How It Works

The policies are split to ensure proper order of operations:

1. First, the job generator policy runs and creates a job with information about the original image
2. Then, the image mutator policy runs and changes the image registry from `container-registry.xxx.net` to `docker.io`

This separation ensures that the job always receives the original image information before any mutation occurs.

## Important Notes

- These policies only apply to namespaces that start with "a" (e.g., "app", "api", "auth")
- The policies use the `contains` function with the `Equals` operator to check for images from `container-registry.xxx.net`
- System namespaces (kube-system, kyverno) are excluded

## Installation

Apply the policies in order:

```bash
kubectl apply -f 1-job-generator-policy.yaml
kubectl apply -f 2-image-mutator-policy.yaml
```

## Testing

You can test the policies with a sample pod in a namespace that starts with "a":

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: test-image-policy-pod
  namespace: app
spec:
  containers:
  - name: nginx
    image: container-registry.xxx.net/nginx:1.19.3
```

When you create this pod, the following should happen:
1. A job named `push-image-test-image-policy-pod` will be created in the same namespace
2. The pod's image will be mutated to `docker.io/nginx:1.19.3`

## Troubleshooting

If the policies aren't working as expected:

1. Check the Kyverno logs: `kubectl logs -n kyverno -l app=kyverno`
2. Verify that the pod is in a namespace that starts with "a"
3. Verify that the pod's image contains "container-registry.xxx.net/"
4. Make sure the pod doesn't have the `skip-verify: "true"` label 
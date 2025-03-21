# Patching Istio Revision Label with Flux

I'll show you how to patch the `istio.io/rev: asm-1-23` label in your Kyverno policy using Flux and GitOps. Here are three methods:

## Method 1: Using Flux's Kustomization Resource

```yaml
# flux-kustomization.yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: kyverno-policies
  namespace: flux-system
spec:
  interval: 10m
  path: ./policies
  prune: true
  sourceRef:
    kind: GitRepository
    name: flux-system
  patches:
    - patch: |
        apiVersion: kyverno.io/v1
        kind: ClusterPolicy
        metadata:
          name: mutate-cluster-namespace-istiolabel
        spec:
          rules:
          - name: add-istio-revision-label
            mutate:
              patchStrategicMerge:
                metadata:
                  labels:
                    istio.io/rev: asm-1-24
      target:
        kind: ClusterPolicy
        name: mutate-cluster-namespace-istiolabel
```

## Method 2: Using Standard Kustomize (Works with kubectl kustomize)

```yaml
# kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- original-policy.yaml
patches:
- patch: |
    apiVersion: kyverno.io/v1
    kind: ClusterPolicy
    metadata:
      name: mutate-cluster-namespace-istiolabel
    spec:
      rules:
      - name: add-istio-revision-label
        mutate:
          patchStrategicMerge:
            metadata:
              labels:
                istio.io/rev: asm-1-24
```

## Method 3: Using JSON Patch for Precise Updates

```yaml
# kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- original-policy.yaml
patchesJson6902:
- target:
    group: kyverno.io
    version: v1
    kind: ClusterPolicy
    name: mutate-cluster-namespace-istiolabel
  patch: |
    [
      {
        "op": "replace",
        "path": "/spec/rules/0/mutate/patchStrategicMerge/metadata/labels/istio.io~1rev",
        "value": "asm-1-24"
      }
    ]
```

**Note:** In JSON Patch, the forward slash in `istio.io/rev` must be escaped as `istio.io~1rev`.

All of these methods will update your Kyverno policy to apply the new `asm-1-24` version label to matching namespaces. Method 2 is the most compatible option if you need consistency between `kubectl kustomize` and Flux.
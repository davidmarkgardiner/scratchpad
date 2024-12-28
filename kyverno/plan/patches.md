In Kyverno policies, variables like `${validation.action}` aren't passed directly through Kyverno - this was a mistake in my example. Let me explain the correct approaches to handle environment-specific variables:

1. Using Kustomize Patches (Recommended Approach):
```yaml
# policies/base/pod-security.yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: pod-security-controls
spec:
  validationFailureAction: audit  # Default value

# clusters/prod/policy-patches/policy-overrides.yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: pod-security-controls
spec:
  validationFailureAction: enforce  # Override for prod
```

2. Using Flux Substitution (Alternative):
```yaml
# clusters/prod/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ../../policies/base
patches:
  - patch: |-
      - op: replace
        path: /spec/validationFailureAction
        value: enforce
    target:
      kind: ClusterPolicy
      name: pod-security-controls
```

3. Using ConfigMap Generator (Another Option):
```yaml
# clusters/prod/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
configMapGenerator:
  - name: policy-config
    literals:
      - validationFailureAction=enforce
```

The earlier template-style variable syntax I showed (`${validation.action}`) isn't valid for Kyverno. Instead, you should use one of the above methods to manage environment-specific values. Kustomize patches are generally the most straightforward and maintainable approach.

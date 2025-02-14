Yes, Kyverno is a great choice for implementing this policy! Here's how you can block ResourceGroup creation in specific namespaces using Kyverno:

```yaml:block-resourcegroups-policy.yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: block-resourcegroups
spec:
  validationFailureAction: enforce
  background: false
  rules:
  - name: block-resourcegroups-in-restricted-namespaces
    match:
      any:
      - resources:
          kinds:
          - kro.run/v1alpha1/ResourceGroup
    preconditions:
      all:
      # Only apply this rule to namespaces with the restricted label
      - key: "{{request.object.metadata.namespace}}"
        operator: NotEquals
        value: ""
      - key: "{{request.namespace.metadata.labels.resourcegroup-restricted}}"
        operator: Equals
        value: "true"
    validate:
      message: "ResourceGroups are not allowed in restricted namespaces"
      deny: {}
```

To use this:

1. First label your restricted namespaces:

```yaml:restricted-namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: restricted-namespace
  labels:
    resourcegroup-restricted: "true"
```

Benefits of using Kyverno:
1. No webhook service needed (simpler than the previous webhook approach)
2. Built-in monitoring and reporting
3. Easy to audit and modify policies
4. Can combine with other Kyverno policies for comprehensive governance
5. Supports generating reports and alerts for policy violations

The policy will prevent any ResourceGroup creation in namespaces labeled with `resourcegroup-restricted: "true"`, while allowing them in other namespaces.

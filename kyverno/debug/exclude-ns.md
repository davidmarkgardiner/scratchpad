You can exclude namespaces from Kyverno webhooks by adding `namespaceSelector` in the webhook configurations. Here's how:

```yaml
webhooks:
- name: mutate.kyverno.svc
  namespaceSelector:
    matchExpressions:
    - key: kubernetes.io/metadata.name
      operator: NotIn
      values:
      - kube-system
      - kube-public
      # Add other namespaces to exclude
```

Apply this pattern to all three webhook configurations. Common namespaces to exclude:
- System namespaces (kube-system, kube-public)
- Monitoring namespaces
- Logging namespaces
- Service mesh components

You can also use `matchLabels` instead if your namespaces have specific labels to identify them.

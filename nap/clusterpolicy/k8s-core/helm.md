I'll show you the Helm values to add the same node affinity, tolerations, and topology spread constraints for External Secrets Operator:

```yaml
# values.yaml
global:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: node-type
            operator: In
            values:
              - kubernetes-core

  tolerations:
    - key: "workload-type"
      operator: "Equal"
      value: "kubernetes-core"
      effect: "NoSchedule"

  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
    - weight: 100
      podAffinityTerm:
        labelSelector:
          matchExpressions:
          - key: app.kubernetes.io/name
            operator: In
            values:
            - external-secrets
        topologyKey: azure.microsoft.com/hostname

  topologySpreadConstraints:
    - maxSkew: 1
      topologyKey: azure.microsoft.com/zone
      whenUnsatisfied: ScheduleAnyway
      labelSelector:
        matchLabels:
          app.kubernetes.io/name: external-secrets

priorityClassName: "system-cluster-critical"
```

You can apply this using:
```bash
helm upgrade --install external-secrets \
  external-secrets/external-secrets \
  -f values.yaml \
  --namespace external-secrets
```

This will apply the same scheduling rules we had in the Kyverno policy directly through Helm. The `global` prefix ensures it applies to all components of the External Secrets Operator.

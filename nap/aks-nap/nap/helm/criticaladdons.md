To ensure your Helm chart deployment goes on an AKS cluster that has nodes with the CriticalAddonsOnly=true:NoSchedule taint, you need to add a toleration to your deployment. Here's how to do this:

Add tolerations to your Helm chart values.yaml file or directly in your deployment manifest:

```yaml
tolerations:
- key: "CriticalAddonsOnly"
  operator: "Equal"
  value: "true"
  effect: "NoSchedule"
```
If you want your pods to be scheduled only on these nodes with the taint, you should also add a node affinity:

yamlaffinity:
```yaml
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.azure.com/cluster-autoscaler-nodepool-taint
          operator: In
          values:
          - "CriticalAddonsOnly=true:NoSchedule"
```
If you're deploying using Helm, you can include these settings in your values.yaml file and reference them in your templates, or pass them as overrides during installation:

bashhelm install my-release ./my-chart --set tolerations[0].key=CriticalAddonsOnly \
  --set tolerations[0].operator=Equal \
  --set tolerations[0].value=true \
  --set tolerations[0].effect=NoSchedule
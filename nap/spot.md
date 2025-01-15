No, they are different in Karpenter/NAP. You can specify the capacity type using `karpenter.sh/capacity-type` with two possible values:

1. On-demand (regular VM instances):
```yaml
- key: karpenter.sh/capacity-type
  operator: In
  values:
  - on-demand
```

2. Spot instances (cheaper but can be evicted):
```yaml
- key: karpenter.sh/capacity-type
  operator: In
  values:
  - spot
```

You can even create a NodePool that can use both:
```yaml
- key: karpenter.sh/capacity-type
  operator: In
  values:
  - spot
  - on-demand
```

When using spot instances, you should consider:
1. Adding pod disruption budgets for your applications
2. Making your applications resilient to node termination
3. Understanding that spot instances can be evicted with little notice

Example of a spot-focused NodePool:
```yaml
apiVersion: karpenter.sh/v1beta1
kind: NodePool
metadata:
  name: spot-pool
spec:
  disruption:
    consolidationPolicy: WhenUnderutilized
  template:
    spec:
      nodeClassRef:
        name: default
      requirements:
      - key: karpenter.sh/capacity-type
        operator: In
        values:
        - spot  # Use spot instances
      - key: karpenter.azure.com/sku-family
        operator: In
        values:
        - D
```

Would you like me to show you how to set up a mixed NodePool that prioritizes spot instances but falls back to on-demand when needed?

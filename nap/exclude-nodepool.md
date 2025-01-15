To exclude specific SKU versions, you can use the `NotIn` or `Lt` (less than) operator. Here's how you can modify your NodePool configuration to exclude specific versions:

```yaml
# Exclude specific versions
- key: karpenter.azure.com/sku-version
  operator: NotIn
  values: ["6"]

# OR use Lt (less than) to exclude version 6 and above
- key: karpenter.azure.com/sku-version
  operator: Lt
  values: ["6"]
```

For example, in your full configuration:

```yaml
apiVersion: karpenter.sh/v1beta1
kind: NodePool
metadata:
  name: default
spec:
  disruption:
    consolidationPolicy: WhenUnderutilized
    expireAfter: Never
  template:
    spec:
      nodeClassRef:
        name: default
      requirements:
      - key: kubernetes.io/arch
        operator: In
        values:
        - amd64
      - key: kubernetes.io/os
        operator: In
        values:
        - linux
      - key: karpenter.sh/capacity-type
        operator: In
        values:
        - on-demand
      - key: karpenter.azure.com/sku-family
        operator: In
        values:
        - D
      - key: karpenter.azure.com/sku-version
        operator: Lt
        values: ["6"]  # This will exclude v6 and above
```

This way, NAP will only provision nodes with SKU versions less than 6 (i.e., v1-v5).

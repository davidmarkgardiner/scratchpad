Yes! NAP (Node AutoProvisioning) scales based on the resource requests specified in your pod/deployment specs. Here's how it works:

1. NAP looks at pod resource requests:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sample-app
spec:
  replicas: 3
  template:
    spec:
      containers:
      - name: app
        image: nginx
        resources:
          requests:
            cpu: "2"
            memory: "4Gi"
          limits:
            cpu: "2.5"
            memory: "5Gi"
```

2. When pods are pending due to insufficient resources, NAP:
- Looks at the resource requests
- Checks the NodePool requirements
- Provisions appropriate VM sizes that can accommodate the workload
- Places the pods on the new nodes

For example:
- If you have 10 pods each requesting 2 CPU cores
- And your current nodes are full
- NAP will automatically provision new nodes with enough CPU capacity

Key points:
- NAP primarily uses `requests` for scheduling decisions
- `limits` help control resource usage on the node
- NAP tries to optimize for cost by choosing appropriate VM sizes
- The NodePool requirements define the boundaries of what VMs can be provisioned

Would you like to see an example of how different resource requests trigger different VM size selections?

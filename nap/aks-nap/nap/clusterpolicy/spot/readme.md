Yes, we need a Kyverno policy for the spot workloads to automatically add the required tolerations and node affinity. Without it, the pods won't be able to schedule on the spot nodes due to the taints. Let me create the Kyverno policy:

```yaml:nap/clusterpolicy/spot/policy.yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: route-default-to-spot
  annotations:
    policies.kyverno.io/title: Route Default Workloads to Spot
    policies.kyverno.io/category: Workload Distribution
    policies.kyverno.io/subject: Deployment, StatefulSet
    policies.kyverno.io/description: >-
      This policy adds node affinity and tolerations to route default workloads
      to spot nodes when they don't have specific workload type requirements.
spec:
  validationFailureAction: audit
  rules:
    - name: route-default-to-spot
      match:
        any:
        - resources:
            kinds:
              - Deployment
              - StatefulSet
            namespaceSelector:
              matchExpressions:
                - key: workload-type
                  operator: NotIn
                  values:
                    - gpu
                    - high-performance
                    - infrastructure
      mutate:
        patchStrategicMerge:
          spec:
            template:
              spec:
                +(tolerations):
                  - key: "spot"
                    operator: "Equal"
                    value: "true"
                    effect: "NoSchedule"
                +(affinity):
                  nodeAffinity:
                    requiredDuringSchedulingIgnoredDuringExecution:
                      nodeSelectorTerms:
                      - matchExpressions:
                        - key: node-type
                          operator: In
                          values:
                            - spot
```


Key points about the Kyverno policy:

1. It matches both Deployments and StatefulSets (to cover our test cases)
2. Applies to namespaces that DON'T have specific workload-type labels
3. Adds required spot tolerations and node affinity
4. No preconditions for app labels (unlike other policies) since this is the default

Now the complete setup will work:

1. The NodePool creates spot nodes with taints
2. The Kyverno policy automatically adds tolerations and affinity to workloads
3. Workloads without specific requirements will be scheduled on spot nodes

To test the complete setup:

```bash
# Apply all components
kubectl apply -f nap/clusterpolicy/spot/nodepool.yaml
kubectl apply -f nap/clusterpolicy/spot/policy.yaml
kubectl apply -f nap/clusterpolicy/spot/test.yaml

# Verify the mutations
kubectl get deployment -n test-default test-web-app -o yaml
kubectl get statefulset -n test-default test-stateful -o yaml
```

The key difference from the other policies is that this one:
1. Doesn't require specific labels
2. Acts as a "catch-all" for workloads
3. Matches on the ABSENCE of workload-type labels
4. Supports multiple workload types (Deployments and StatefulSets)

Would you like me to:
1. Add support for more workload types?
2. Modify the policy rules?
3. Add any additional test cases?

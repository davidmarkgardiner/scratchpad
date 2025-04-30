I understand you've already set the node affinity to target the system nodepool but cert-manager is still trying to create pods on other nodes. This suggests there might be a configuration issue or the affinity settings aren't being applied correctly to all cert-manager components. Let's troubleshoot this step by step.

First, let's verify the structure of your configuration. The affinity settings need to be applied to all cert-manager components, not just at the global level. Sometimes the global settings might not propagate correctly to all components.

Try updating your values.yaml to explicitly set affinity for each component like this:

```yaml
global:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: nodepool
            operator: In
            values:
            - system

# Explicitly set for each component
cert-manager:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: nodepool
            operator: In
            values:
            - system

webhook:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: nodepool
            operator: In
            values:
            - system

cainjector:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: nodepool
            operator: In
            values:
            - system

startupapicheck:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: nodepool
            operator: In
            values:
            - system
```

Additionally, let's check a few other things:

1. Verify that the component structure in your values file matches your cert-manager version. Let me fetch the documentation for the latest cert-manager Helm chart structure:

Let's look up cert-manager documentation directly:

Let me try directly with cert-manager:

Based on my understanding of cert-manager's Helm chart structure, let me provide some additional troubleshooting steps:

2. Check if you're using the correct component names in your values.yaml. The structure might be different than what I provided above. Let's verify the cert-manager components by running:

```bash
kubectl get pods -n cert-manager
```

This will show you the actual pod names, which will help identify the correct component names to use in your values file.

3. Check if your existing pods have the node affinity settings by running:

```bash
kubectl get pod <cert-manager-pod-name> -n cert-manager -o yaml | grep -A15 affinity
```

If the affinity settings aren't appearing, it suggests they're not being applied correctly.

4. Another approach is to add tolerations to ensure cert-manager pods ONLY run on system nodes. You might need to add taints to your non-system nodes to repel cert-manager pods:

```yaml
# Add this to your values.yaml
global:
  tolerations:
  - key: "node-role.kubernetes.io/system"
    operator: "Exists"
    effect: "NoSchedule"

  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: nodepool
            operator: In
            values:
            - system
```

5. It's also possible the cert-manager Helm chart ignores global affinity settings. Let's try setting them for each component separately:

```yaml
controller:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: nodepool
            operator: In
            values:
            - system

webhook:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: nodepool
            operator: In
            values:
            - system

cainjector:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: nodepool
            operator: In
            values:
            - system
```

6. If you've made these changes and pods are still being created on non-system nodes, you might need to check for pods created by cert-manager that aren't part of the Helm release (e.g., pods created by CRDs that don't inherit the Helm values).

After making these changes, upgrade your Helm release:

```bash
helm upgrade cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  -f values.yaml
```

Have you tried explicitly setting the affinity for each component separately as shown above? And are there any specific error messages you're seeing?
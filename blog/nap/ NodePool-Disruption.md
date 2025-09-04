## Aggressive NodePool Disruption Configuration for Maximum Cost Optimization

Based on the research, here's how to configure the most aggressive disruption settings at the NodePool level to quickly remove unused nodes:

### Most Aggressive Configuration

```yaml
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: aggressive-cleanup
spec:
  disruption:
    # Consolidate nodes as soon as they're underutilized
    consolidationPolicy: WhenEmptyOrUnderutilized
    
    # Wait only 1 second before consolidating (minimum allowed)
    consolidateAfter: 1s
    
    # Replace nodes frequently to keep them fresh
    expireAfter: 30m  # Very aggressive - replace nodes every 30 minutes
    
    # Allow maximum disruption rate
    budgets:
    - nodes: "100%"  # Allow ALL nodes to be disrupted at once
```

### Key Settings Explained

#### 1. **ConsolidationPolicy: WhenEmptyOrUnderutilized**
NAP considers all nodes for consolidation and attempts to remove or replace nodes when they're underutilized or empty. This is the most aggressive setting compared to `WhenEmpty` which only removes completely empty nodes.

#### 2. **ConsolidateAfter: 1s**
The amount of time node auto provisioning should wait after discovering a consolidation decision. Setting this to `1s` means NAP will act almost immediately when it detects an underutilized node.

#### 3. **ExpireAfter: Short Duration**
Setting a short expiration (like 30m-2h) forces frequent node recycling, ensuring nodes are terminated and replaced regularly, which can help with:
- Getting latest AMI updates
- Forcing consolidation checks
- Preventing long-running underutilized nodes

#### 4. **Budgets: 100%**
Disruption budgets for rate limiting. Setting to 100% removes all rate limiting, allowing NAP to disrupt as many nodes as it wants simultaneously.

### Even More Aggressive: Bypass PDBs Entirely

If you want to completely ignore Pod Disruption Budgets (though this is risky for production):

```yaml
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: ultra-aggressive
spec:
  disruption:
    consolidationPolicy: WhenEmptyOrUnderutilized
    consolidateAfter: 1s
    expireAfter: 30m
    
    # This is the nuclear option - forces termination even with PDBs
    terminationGracePeriod: 30s  # Force drain after 30 seconds
    
    budgets:
    - nodes: "100%"
```

Configure how long Karpenter waits for pods to terminate gracefully. This setting takes precedence over a pod's terminationGracePeriodSeconds and bypasses PodDisruptionBudgets and the karpenter.sh/do-not-disrupt annotation.

### Production-Friendly Aggressive Configuration

For production environments where you still want aggressive cleanup but with some safety:

```yaml
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: production-aggressive
spec:
  disruption:
    consolidationPolicy: WhenEmptyOrUnderutilized
    consolidateAfter: 30s  # Give workloads 30 seconds to stabilize
    expireAfter: 2h        # Replace nodes every 2 hours
    
    budgets:
    # Aggressive during off-hours
    - nodes: "50%"
      schedule: "0 20 * * *"  # 8 PM daily
      duration: 12h            # Until 8 AM
    
    # Still aggressive during business hours but slightly controlled
    - nodes: "25%"
      schedule: "0 8 * * *"   # 8 AM daily
      duration: 12h            # Until 8 PM
```

### Additional Aggressive Settings for the NodePool

```yaml
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: aggressive-cleanup
spec:
  # Set low limits to prevent over-provisioning
  limits:
    cpu: "100"      # Limit total CPU
    memory: "100Gi" # Limit total memory
    
  disruption:
    consolidationPolicy: WhenEmptyOrUnderutilized
    consolidateAfter: 1s
    expireAfter: 1h
    budgets:
    - nodes: "100%"
    
  template:
    spec:
      requirements:
        # Prefer spot instances for maximum savings
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["spot"]
        
        # Use smaller instance types that are easier to consolidate
        - key: karpenter.azure.com/sku-cpu
          operator: Lt
          values: ["17"]  # No huge instances
      
      # Make nodes even more eager to terminate
      startupTaints:
        - key: node.alpha.kubernetes.io/initialization
          effect: NoSchedule
      
      # Set node expiry through labels
      labels:
        # These can help with additional cleanup policies
        aggressive-scaling: "true"
        fast-cleanup: "enabled"
```

### Important Warnings ⚠️

1. **Pod Disruption**: With these aggressive settings, pods will be frequently evicted and rescheduled. Ensure your applications can handle this.

2. **Stateful Workloads**: This configuration is NOT suitable for stateful workloads or databases that need stable storage.

3. **System Pods**: Even with aggressive settings, Karpenter ignores all static pods and succeeded/failed pods during eviction, so core system components remain protected.

4. **Cost vs Stability Trade-off**: While this maximizes cost savings, it may cause:
   - Frequent pod movements
   - Potential brief service disruptions during consolidation
   - Increased API server load from frequent scheduling

### Monitoring Your Aggressive Configuration

Watch for these events to ensure it's working:
```bash
# Monitor consolidation events
kubectl get events --field-selector source=karpenter -w | grep -i consolidat

# Check node age - should be young with aggressive settings
kubectl get nodes -o custom-columns=NAME:.metadata.name,AGE:.metadata.creationTimestamp

# Monitor disruption events
kubectl get events --field-selector reason=DisruptionBlocked
```

### The Most Aggressive Possible Setting

If you truly want the absolute most aggressive cleanup possible:

```yaml
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: scorched-earth
spec:
  disruption:
    consolidationPolicy: WhenEmptyOrUnderutilized
    consolidateAfter: 1s
    expireAfter: 30m
    terminationGracePeriod: 1s  # Almost instant termination
    budgets:
    - nodes: "100%"
```

This configuration will:
- Terminate nodes within 1 second of detecting underutilization
- Replace all nodes every 30 minutes
- Bypass PDBs after just 1 second
- Allow unlimited parallel disruptions

**Only use this in development/testing environments where disruption is acceptable!**
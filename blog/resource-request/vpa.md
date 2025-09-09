You're facing a classic Kubernetes resource management challenge - overprovisioning due to inflated resource requests. Here's how you can implement dynamic resource management based on actual usage:

## Immediate Solution: Vertical Pod Autoscaler (VPA)

VPA is your best tool for automatically adjusting resource requests based on historical usage:

```yaml
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: example-vpa
  namespace: example-namespace
spec:
  targetRef:
    apiVersion: "apps/v1"
    kind: Deployment
    name: example-app
  updatePolicy:
    updateMode: "Auto"  # Can be "Off", "Initial", or "Auto"
  resourcePolicy:
    containerPolicies:
    - containerName: '*'
      minAllowed:
        cpu: 100m
        memory: 50Mi
      maxAllowed:
        cpu: 2
        memory: 2Gi
```

## Implementation Strategy

### 1. **Gather Metrics First**
Since you have Prometheus, create queries to identify the worst offenders:

```promql
# CPU request vs actual usage
(sum by (namespace, pod) (rate(container_cpu_usage_seconds_total[5m]))) 
/ 
(sum by (namespace, pod) (kube_pod_container_resource_requests{resource="cpu"}))

# Memory request vs actual usage  
(sum by (namespace, pod) (container_memory_working_set_bytes))
/
(sum by (namespace, pod) (kube_pod_container_resource_requests{resource="memory"}))
```

### 2. **Use Kyverno for Enforcement**
Create Kyverno policies to enforce resource limits while VPA recommendations are being gathered:

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-pod-resources
spec:
  validationFailureAction: enforce
  background: true
  rules:
    - name: validate-resources
      match:
        any:
        - resources:
            kinds:
            - Pod
      validate:
        message: "Resource requests and limits are required"
        pattern:
          spec:
            containers:
            - name: "*"
              resources:
                requests:
                  memory: "?*"
                  cpu: "?*"
                limits:
                  memory: "?*"
                  cpu: "?*"
    
    - name: enforce-ratio
      match:
        any:
        - resources:
            kinds:
            - Pod
      validate:
        message: "CPU/Memory limits cannot exceed 2x requests"
        deny:
          conditions:
            any:
            - key: "{{ request.object.spec.containers[?contains(@.resources.limits.cpu, @.resources.requests.cpu * 2)] }}"
              operator: AnyIn
              value: [true]
```

### 3. **Namespace Resource Quotas**
Implement ResourceQuotas per namespace based on actual usage patterns:

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: namespace-quota
  namespace: example-namespace
spec:
  hard:
    requests.cpu: "10"
    requests.memory: 20Gi
    limits.cpu: "20"
    limits.memory: 40Gi
```

### 4. **LimitRanges for Defaults**
Set sensible defaults that will apply when pods don't specify resources:

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: default-limits
  namespace: example-namespace
spec:
  limits:
  - default:
      cpu: 200m
      memory: 256Mi
    defaultRequest:
      cpu: 100m
      memory: 128Mi
    type: Container
```

## Automation Pipeline

1. **Deploy VPA in recommendation mode first** (`updateMode: "Off"`) to gather data without making changes
2. **Export VPA recommendations to Prometheus** using a custom exporter
3. **Create Grafana dashboards** showing:
   - Current requests vs actual usage
   - VPA recommendations
   - Potential cost savings
4. **Gradually roll out VPA in auto mode** starting with non-critical namespaces

## Advanced: Custom Controller with Prometheus

If you need more control, build a custom controller that:

```python
# Pseudo-code for custom controller
def adjust_resources():
    # Query Prometheus for 7-day usage percentiles
    usage = prometheus.query("""
        quantile_over_time(0.95, 
            container_memory_working_set_bytes[7d])
    """)
    
    # Calculate new requests (P95 + 20% buffer)
    new_request = usage * 1.2
    
    # Update deployment via K8s API
    patch_deployment(new_request)
```

## Quick Wins

1. **Start with VPA in recommendation mode** - no risk, immediate visibility
2. **Use Kyverno to prevent new pods without resource specifications**
3. **Set up alerts for pods with >50% overprovisioning**
4. **Create a "wall of shame" dashboard showing the worst offenders**

The combination of VPA for automatic adjustment, Kyverno for policy enforcement, and Prometheus for monitoring will help you reclaim that wasted capacity. Start conservatively with VPA recommendations and gradually tighten as you build confidence in the system.
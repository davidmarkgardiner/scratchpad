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


---
I'll add several key durability configurations to the Helm values. Here's what I'll add:

```yaml
# values.yaml
global:
  # ... existing code ...

  # Add pod disruption budget
  podDisruptionBudget:
    enabled: true
    minAvailable: 1  # Keep at least 1 pod running during disruptions

  # Add resource requests/limits
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 500m
      memory: 512Mi

  # Add pod lifecycle hooks
  lifecycle:
    preStop:
      exec:
        command: ["/bin/sh", "-c", "sleep 30"]  # Give time for graceful shutdown

  # Add pod security context
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    fsGroup: 1000

  # Add pod readiness/liveness probes
  readinessProbe:
    httpGet:
      path: /healthz
      port: http
    initialDelaySeconds: 5
    periodSeconds: 10
    timeoutSeconds: 5
    failureThreshold: 3

  livenessProbe:
    httpGet:
      path: /healthz
      port: http
    initialDelaySeconds: 15
    periodSeconds: 20
    timeoutSeconds: 5
    failureThreshold: 3

  # Add termination grace period
  terminationGracePeriodSeconds: 60

  # Add pod topology spread constraints for high availability
  topologySpreadConstraints:
    - maxSkew: 1
      topologyKey: kubernetes.io/hostname
      whenUnsatisfied: ScheduleAnyway
      labelSelector:
        matchLabels:
          app.kubernetes.io/name: external-secrets
    - maxSkew: 1
      topologyKey: topology.kubernetes.io/zone
      whenUnsatisfied: ScheduleAnyway
      labelSelector:
        matchLabels:
          app.kubernetes.io/name: external-secrets

  # Add pod anti-affinity for high availability
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
        topologyKey: kubernetes.io/hostname

  # Add pod priority class
  priorityClassName: "system-cluster-critical"

  # Add pod annotations for better observability
  podAnnotations:
    prometheus.io/scrape: "true"
    prometheus.io/port: "8080"
    prometheus.io/path: "/metrics"
```

Key additions:
1. Pod Disruption Budget to prevent too many pods being taken down at once
2. Resource requests/limits to prevent resource starvation
3. Graceful shutdown with preStop hook
4. Security context for better security
5. Readiness/liveness probes for better health checks
6. Extended termination grace period
7. Additional topology spread constraints for better HA
8. Prometheus annotations for monitoring
9. Proper resource limits to prevent OOM kills

These changes will make the deployment more resilient to failures, better monitored, and more secure while maintaining high availability.

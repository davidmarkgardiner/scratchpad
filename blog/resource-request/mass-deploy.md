Enabling VPA for every namespace in a shared AKS cluster requires careful planning. Here's a comprehensive approach:

## Option 1: Mass Deployment with Namespace Selector

### Create a VPA for Each Deployment Automatically

Use a **mutating webhook** or **Kyverno** to automatically create VPAs:

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: auto-generate-vpa
spec:
  generateExistingOnPolicyUpdate: true
  rules:
    - name: create-vpa-for-deployments
      match:
        any:
        - resources:
            kinds:
            - Deployment
            operations:
            - CREATE
            - UPDATE
      exclude:
        any:
        - resources:
            namespaces:
            - kube-system
            - kube-public
            - gatekeeper-system
            - kyverno
      generate:
        synchronize: true
        apiVersion: autoscaling.k8s.io/v1
        kind: VerticalPodAutoscaler
        name: "{{request.object.metadata.name}}-vpa"
        namespace: "{{request.object.metadata.namespace}}"
        data:
          spec:
            targetRef:
              apiVersion: "apps/v1"
              kind: Deployment
              name: "{{request.object.metadata.name}}"
            updatePolicy:
              updateMode: "Off"  # Start with recommendations only
            resourcePolicy:
              containerPolicies:
              - containerName: '*'
                minAllowed:
                  cpu: 10m
                  memory: 32Mi
                maxAllowed:
                  cpu: 4
                  memory: 8Gi
```

## Option 2: Batch Creation Script

### Script to Create VPAs for All Existing Workloads

```bash
#!/bin/bash
# create-vpas-all-namespaces.sh

# Namespaces to exclude
EXCLUDE_NAMESPACES="kube-system|kube-public|kube-node-lease|gatekeeper-system|cert-manager"

# VPA mode - start with "Off" for safety
VPA_MODE="Off"  # Change to "Initial" after validation

# Function to create VPA for a deployment
create_vpa() {
    local namespace=$1
    local deployment=$2
    local vpa_name="${deployment}-vpa"
    
    echo "Creating VPA for $namespace/$deployment"
    
    cat <<EOF | kubectl apply -f -
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: ${vpa_name}
  namespace: ${namespace}
  labels:
    managed-by: vpa-rollout
    creation-wave: initial
spec:
  targetRef:
    apiVersion: "apps/v1"
    kind: Deployment
    name: ${deployment}
  updatePolicy:
    updateMode: "${VPA_MODE}"
  resourcePolicy:
    containerPolicies:
    - containerName: '*'
      minAllowed:
        cpu: 10m
        memory: 32Mi
      maxAllowed:
        cpu: 4
        memory: 8Gi
      controlledResources: ["cpu", "memory"]
EOF
}

# Process all deployments
kubectl get deployments -A -o json | jq -r '.items[] | "\(.metadata.namespace) \(.metadata.name)"' | while read namespace deployment; do
    if [[ ! "$namespace" =~ $EXCLUDE_NAMESPACES ]]; then
        # Check if VPA already exists
        if ! kubectl get vpa "${deployment}-vpa" -n "$namespace" &>/dev/null; then
            create_vpa "$namespace" "$deployment"
        else
            echo "VPA already exists for $namespace/$deployment"
        fi
    fi
done

# Also process StatefulSets
kubectl get statefulsets -A -o json | jq -r '.items[] | "\(.metadata.namespace) \(.metadata.name)"' | while read namespace statefulset; do
    if [[ ! "$namespace" =~ $EXCLUDE_NAMESPACES ]]; then
        if ! kubectl get vpa "${statefulset}-vpa" -n "$namespace" &>/dev/null; then
            # Similar function for StatefulSets
            create_vpa_statefulset "$namespace" "$statefulset"
        fi
    fi
done
```

## Option 3: GitOps Approach with Flux/ArgoCD

### Using Flux to Manage VPAs

```yaml
# vpa-kustomization.yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: vpa-rollout
  namespace: flux-system
spec:
  interval: 10m
  path: ./clusters/production/vpa-configs
  prune: true
  sourceRef:
    kind: GitRepository
    name: flux-system
  postBuild:
    substituteFrom:
      - kind: ConfigMap
        name: vpa-config
---
# ConfigMap for VPA settings
apiVersion: v1
kind: ConfigMap
metadata:
  name: vpa-config
  namespace: flux-system
data:
  vpa_mode: "Off"  # Centrally control VPA mode
  min_cpu: "10m"
  min_memory: "32Mi"
  max_cpu: "4"
  max_memory: "8Gi"
```

## Option 4: Helm Chart for Mass Deployment

### Create a Helm Chart for VPA Rollout

```yaml
# values.yaml
global:
  vpaMode: "Off"  # Start with Off, then Initial, never Auto with Karpenter
  
namespaceConfig:
  # Per-namespace overrides
  production:
    vpaMode: "Off"
    maxCpu: "8"
    maxMemory: "16Gi"
  development:
    vpaMode: "Initial"
    maxCpu: "2"
    maxMemory: "4Gi"
  staging:
    vpaMode: "Initial"
    maxCpu: "4"
    maxMemory: "8Gi"

excludeNamespaces:
  - kube-system
  - kube-public
  - kube-node-lease
  - cert-manager
  - ingress-nginx

defaultPolicy:
  minAllowed:
    cpu: "10m"
    memory: "32Mi"
  maxAllowed:
    cpu: "4"
    memory: "8Gi"
```

```yaml
# templates/vpa-generator.yaml
{{- range $namespace := .Values.targetNamespaces }}
{{- if not (has $namespace $.Values.excludeNamespaces) }}
---
apiVersion: batch/v1
kind: Job
metadata:
  name: vpa-creator-{{ $namespace }}
  namespace: {{ $namespace }}
spec:
  template:
    spec:
      serviceAccountName: vpa-creator
      containers:
      - name: create-vpas
        image: bitnami/kubectl:latest
        command:
        - sh
        - -c
        - |
          for deployment in $(kubectl get deployments -n {{ $namespace }} -o name); do
            name=$(echo $deployment | cut -d'/' -f2)
            cat <<EOF | kubectl apply -f -
          apiVersion: autoscaling.k8s.io/v1
          kind: VerticalPodAutoscaler
          metadata:
            name: ${name}-vpa
            namespace: {{ $namespace }}
          spec:
            targetRef:
              apiVersion: "apps/v1"
              kind: Deployment
              name: ${name}
            updatePolicy:
              updateMode: "{{ $.Values.global.vpaMode }}"
          EOF
          done
{{- end }}
{{- end }}
```

## Phased Rollout Strategy (Recommended)

### Phase 1: Discovery and Assessment (Week 1)

```bash
#!/bin/bash
# audit-resource-usage.sh

echo "Namespace,Deployment,Requested CPU,Requested Mem,Actual CPU (P95),Actual Mem (P95),CPU Waste %,Mem Waste %" > resource-audit.csv

kubectl get deployments -A -o json | jq -r '.items[] | "\(.metadata.namespace) \(.metadata.name)"' | while read ns deploy; do
    # Get current requests
    requested_cpu=$(kubectl get deployment $deploy -n $ns -o jsonpath='{.spec.template.spec.containers[*].resources.requests.cpu}')
    requested_mem=$(kubectl get deployment $deploy -n $ns -o jsonpath='{.spec.template.spec.containers[*].resources.requests.memory}')
    
    # Query Prometheus for actual usage (you'll need to adjust the query)
    actual_cpu=$(curl -s "http://prometheus/api/v1/query?query=quantile_over_time(0.95,container_cpu_usage_seconds_total{namespace=\"$ns\",pod=~\"$deploy-.*\"}[7d])")
    actual_mem=$(curl -s "http://prometheus/api/v1/query?query=quantile_over_time(0.95,container_memory_working_set_bytes{namespace=\"$ns\",pod=~\"$deploy-.*\"}[7d])")
    
    echo "$ns,$deploy,$requested_cpu,$requested_mem,$actual_cpu,$actual_mem" >> resource-audit.csv
done
```

### Phase 2: Deploy VPAs in "Off" Mode (Week 2)

```yaml
# mass-vpa-rollout.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: vpa-rollout-script
  namespace: default
data:
  rollout.sh: |
    #!/bin/bash
    NAMESPACES=$(kubectl get ns -o name | cut -d'/' -f2 | grep -v -E 'kube-system|kube-public')
    
    for ns in $NAMESPACES; do
      echo "Processing namespace: $ns"
      
      # Create VPAs for all deployments
      for deploy in $(kubectl get deploy -n $ns -o name | cut -d'/' -f2); do
        kubectl apply -f - <<EOF
    apiVersion: autoscaling.k8s.io/v1
    kind: VerticalPodAutoscaler
    metadata:
      name: ${deploy}-vpa
      namespace: $ns
      labels:
        rollout-phase: "phase2"
        mode: "observation"
    spec:
      targetRef:
        apiVersion: apps/v1
        kind: Deployment
        name: $deploy
      updatePolicy:
        updateMode: "Off"
    EOF
      done
    done
---
apiVersion: batch/v1
kind: Job
metadata:
  name: vpa-mass-rollout
spec:
  template:
    spec:
      serviceAccountName: vpa-admin
      containers:
      - name: rollout
        image: bitnami/kubectl:latest
        command: ["/bin/bash", "/scripts/rollout.sh"]
        volumeMounts:
        - name: script
          mountPath: /scripts
      volumes:
      - name: script
        configMap:
          name: vpa-rollout-script
          defaultMode: 0755
```

### Phase 3: Monitor and Validate (Week 3-4)

```yaml
# monitoring-dashboard.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: vpa-monitoring-queries
data:
  queries.yaml: |
    # VPA Recommendation vs Current Requests
    - query: |
        (
          label_join(
            kube_verticalpodautoscaler_status_recommendation_containerrecommendations_target{resource="cpu"},
            "deployment", "-", "targetName"
          )
          /
          label_join(
            kube_pod_container_resource_requests{resource="cpu"},
            "deployment", "-", "pod"
          )
        ) > 1.5
      alert: "VPA recommends 50% higher CPU than currently requested"
    
    # Count of VPAs by mode
    - query: |
        count by (updateMode) (
          kube_verticalpodautoscaler_spec_updatepolicy_updatemode
        )
```

### Phase 4: Gradual Migration to "Initial" Mode

```bash
#!/bin/bash
# gradual-vpa-migration.sh

# Start with low-risk namespaces
LOW_RISK_NAMESPACES="development staging test"

for ns in $LOW_RISK_NAMESPACES; do
  echo "Migrating $ns to Initial mode"
  
  kubectl get vpa -n $ns -o name | while read vpa; do
    kubectl patch $vpa -n $ns --type='json' \
      -p='[{"op": "replace", "path": "/spec/updatePolicy/updateMode", "value":"Initial"}]'
  done
  
  # Wait and monitor
  sleep 3600  # Wait 1 hour between namespaces
  
  # Check for issues
  EVICTIONS=$(kubectl get events -n $ns | grep -c Evicted)
  if [ $EVICTIONS -gt 10 ]; then
    echo "Too many evictions in $ns, rolling back"
    kubectl patch $vpa -n $ns --type='json' \
      -p='[{"op": "replace", "path": "/spec/updatePolicy/updateMode", "value":"Off"}]'
  fi
done
```

## Monitoring and Alerting

```yaml
# prometheus-rules.yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: vpa-monitoring
spec:
  groups:
  - name: vpa
    rules:
    - alert: VPARecommendationDivergence
      expr: |
        abs(
          kube_verticalpodautoscaler_status_recommendation_containerrecommendations_target{resource="cpu"}
          -
          kube_pod_container_resource_requests{resource="cpu"}
        ) / kube_pod_container_resource_requests{resource="cpu"} > 0.5
      for: 1h
      annotations:
        summary: "VPA recommendations differ >50% from current requests"
    
    - alert: VPACausingEvictions
      expr: |
        rate(kube_pod_status_reason{reason="Evicted"}[5m]) > 0.1
      annotations:
        summary: "High eviction rate detected - check VPA settings"
```

## Best Practices for Mass VPA Deployment

1. **Never enable "Auto" mode cluster-wide** with Karpenter
2. **Use namespace labels** to control rollout:
   ```bash
   kubectl label namespace production vpa-mode=off
   kubectl label namespace development vpa-mode=initial
   ```

3. **Create override mechanism**:
   ```yaml
   # Allow teams to opt-out via annotation
   apiVersion: kyverno.io/v1
   kind: ClusterPolicy
   metadata:
     name: skip-vpa-if-opted-out
   spec:
     rules:
     - name: check-opt-out
       match:
         any:
         - resources:
             kinds:
             - Deployment
             annotations:
               vpa.io/skip: "true"
       exclude:
         any:
         - resources:
             kinds:
             - VerticalPodAutoscaler
   ```

4. **Set up proper RBAC**:
   ```yaml
   apiVersion: rbac.authorization.k8s.io/v1
   kind: ClusterRole
   metadata:
     name: vpa-admin
   rules:
   - apiGroups: ["autoscaling.k8s.io"]
     resources: ["verticalpodautoscalers"]
     verbs: ["*"]
   - apiGroups: [""]
     resources: ["pods/eviction"]
     verbs: ["create"]  # Only if using Auto mode
   ```

The safest approach: **Start with Kyverno policy (Option 1)** to automatically generate VPAs in "Off" mode, monitor for 2 weeks, then gradually migrate namespaces to "Initial" mode. Never use "Auto" mode with Karpenter in production.
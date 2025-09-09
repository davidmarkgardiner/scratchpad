Yes, exactly! Kyverno can automatically deploy VPAs for every workload across all namespaces. This is actually one of the most elegant solutions for mass VPA deployment. Let me show you the complete implementation:

## Complete Kyverno-Based VPA Deployment Solution

### 1. Core Policy: Auto-Generate VPAs for Everything

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: auto-generate-vpa-all-workloads
  annotations:
    policies.kyverno.io/title: Auto-Generate VPA for All Workloads
    policies.kyverno.io/description: Creates VPA for every Deployment, StatefulSet, DaemonSet, and ReplicaSet
spec:
  generateExistingOnPolicyUpdate: true  # IMPORTANT: This creates VPAs for existing resources
  background: true  # Applies to existing and new resources
  rules:
    # Rule 1: Generate VPA for Deployments
    - name: generate-vpa-deployment
      match:
        any:
        - resources:
            kinds:
            - Deployment
      exclude:
        any:
        - resources:
            namespaces:
            - kube-system
            - kube-public
            - kube-node-lease
            - kyverno
            - cert-manager
        - resources:
            selector:
              matchLabels:
                vpa.io/skip: "true"  # Opt-out mechanism
      generate:
        synchronize: true  # Keep VPA in sync
        apiVersion: autoscaling.k8s.io/v1
        kind: VerticalPodAutoscaler
        name: "{{request.object.metadata.name}}-vpa"
        namespace: "{{request.object.metadata.namespace}}"
        data:
          metadata:
            labels:
              app.kubernetes.io/managed-by: kyverno
              vpa.io/generation: auto
              vpa.io/target-kind: deployment
              vpa.io/target-name: "{{request.object.metadata.name}}"
            annotations:
              vpa.io/created-by: "kyverno-policy"
              vpa.io/created-at: "{{time}}"
          spec:
            targetRef:
              apiVersion: apps/v1
              kind: Deployment
              name: "{{request.object.metadata.name}}"
            updatePolicy:
              updateMode: "Off"  # Safe default - just collect metrics
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

    # Rule 2: Generate VPA for StatefulSets
    - name: generate-vpa-statefulset
      match:
        any:
        - resources:
            kinds:
            - StatefulSet
      exclude:
        any:
        - resources:
            namespaces:
            - kube-system
            - kube-public
            - kube-node-lease
            - kyverno
        - resources:
            selector:
              matchLabels:
                vpa.io/skip: "true"
      generate:
        synchronize: true
        apiVersion: autoscaling.k8s.io/v1
        kind: VerticalPodAutoscaler
        name: "{{request.object.metadata.name}}-vpa"
        namespace: "{{request.object.metadata.namespace}}"
        data:
          metadata:
            labels:
              app.kubernetes.io/managed-by: kyverno
              vpa.io/generation: auto
              vpa.io/target-kind: statefulset
          spec:
            targetRef:
              apiVersion: apps/v1
              kind: StatefulSet
              name: "{{request.object.metadata.name}}"
            updatePolicy:
              updateMode: "Off"
            resourcePolicy:
              containerPolicies:
              - containerName: '*'
                minAllowed:
                  cpu: 10m
                  memory: 32Mi
                maxAllowed:
                  cpu: 4
                  memory: 8Gi

    # Rule 3: Generate VPA for DaemonSets (be careful with these)
    - name: generate-vpa-daemonset
      match:
        any:
        - resources:
            kinds:
            - DaemonSet
      exclude:
        any:
        - resources:
            namespaces:
            - kube-system  # Definitely exclude system DaemonSets
            - kube-public
            - kube-node-lease
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
              apiVersion: apps/v1
              kind: DaemonSet
              name: "{{request.object.metadata.name}}"
            updatePolicy:
              updateMode: "Off"  # Never use Auto for DaemonSets
            resourcePolicy:
              containerPolicies:
              - containerName: '*'
                minAllowed:
                  cpu: 10m
                  memory: 32Mi
                maxAllowed:
                  cpu: 2
                  memory: 4Gi
```

### 2. Namespace-Specific VPA Configuration

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: configure-vpa-by-namespace
  annotations:
    policies.kyverno.io/title: Configure VPA Based on Namespace Type
    policies.kyverno.io/description: Different VPA settings for dev/staging/prod
spec:
  background: true
  rules:
    # Development namespaces - can use Initial mode
    - name: dev-namespace-vpa-config
      match:
        any:
        - resources:
            kinds:
            - VerticalPodAutoscaler
            namespaces:
            - "dev-*"
            - "development"
      mutate:
        patchStrategicMerge:
          spec:
            updatePolicy:
              updateMode: "Initial"  # Safe for dev
            resourcePolicy:
              containerPolicies:
              - containerName: '*'
                maxAllowed:
                  cpu: 2       # Lower limits for dev
                  memory: 4Gi

    # Staging namespaces - Initial mode with higher limits
    - name: staging-namespace-vpa-config
      match:
        any:
        - resources:
            kinds:
            - VerticalPodAutoscaler
            namespaces:
            - "staging-*"
            - "stage"
      mutate:
        patchStrategicMerge:
          spec:
            updatePolicy:
              updateMode: "Initial"
            resourcePolicy:
              containerPolicies:
              - containerName: '*'
                maxAllowed:
                  cpu: 4
                  memory: 8Gi

    # Production namespaces - Observation only
    - name: prod-namespace-vpa-config
      match:
        any:
        - resources:
            kinds:
            - VerticalPodAutoscaler
            namespaces:
            - "prod-*"
            - "production"
      mutate:
        patchStrategicMerge:
          spec:
            updatePolicy:
              updateMode: "Off"  # Never auto-update in prod
            resourcePolicy:
              containerPolicies:
              - containerName: '*'
                maxAllowed:
                  cpu: 8
                  memory: 16Gi
```

### 3. Safety Policy: Prevent Dangerous VPA Configurations

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: vpa-safety-controls
  annotations:
    policies.kyverno.io/title: VPA Safety Controls
    policies.kyverno.io/description: Prevent dangerous VPA configurations that conflict with Karpenter
spec:
  validationFailureAction: Enforce
  background: false
  rules:
    # Block Auto mode in production
    - name: block-auto-mode-production
      match:
        any:
        - resources:
            kinds:
            - VerticalPodAutoscaler
            namespaces:
            - "prod-*"
            - "production"
      validate:
        message: "VPA Auto mode is forbidden in production (conflicts with Karpenter)"
        pattern:
          spec:
            updatePolicy:
              updateMode: "!Auto"

    # Warn about Auto mode elsewhere
    - name: warn-auto-mode
      match:
        any:
        - resources:
            kinds:
            - VerticalPodAutoscaler
      validate:
        validationFailureAction: Audit  # Just warn
        message: "Warning: VPA Auto mode can cause pod evictions and conflicts with Karpenter"
        pattern:
          spec:
            updatePolicy:
              updateMode: "!Auto"
```

## Deployment Process

### Step 1: Deploy VPA Components First

```bash
# Install VPA if not already installed
kubectl apply -f https://github.com/kubernetes/autoscaler/releases/latest/download/vertical-pod-autoscaler.yaml

# Verify VPA is running
kubectl get pods -n kube-system | grep vpa
```

### Step 2: Deploy Kyverno Policy Gradually

```bash
# First, deploy in Audit mode to see what would be created
cat <<EOF | kubectl apply -f -
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: auto-generate-vpa-audit
spec:
  validationFailureAction: Audit  # Just report, don't create
  generateExistingOnPolicyUpdate: false  # Don't create yet
  background: true
  rules:
    - name: audit-vpa-generation
      match:
        any:
        - resources:
            kinds:
            - Deployment
      exclude:
        any:
        - resources:
            namespaces:
            - kube-system
      generate:
        synchronize: false
        apiVersion: autoscaling.k8s.io/v1
        kind: VerticalPodAutoscaler
        name: "{{request.object.metadata.name}}-vpa"
        namespace: "{{request.object.metadata.namespace}}"
        data:
          spec:
            targetRef:
              apiVersion: apps/v1
              kind: Deployment
              name: "{{request.object.metadata.name}}"
            updatePolicy:
              updateMode: "Off"
EOF

# Check what would be created
kubectl get events -A | grep kyverno
```

### Step 3: Apply the Real Policy

```bash
# Apply the full policy
kubectl apply -f auto-generate-vpa-all-workloads.yaml

# Watch VPAs being created
watch kubectl get vpa -A
```

### Step 4: Verify VPA Creation

```bash
# Check VPA count vs Deployment count
echo "Deployments: $(kubectl get deploy -A --no-headers | wc -l)"
echo "VPAs: $(kubectl get vpa -A --no-headers | wc -l)"

# Check specific namespace
kubectl get deploy,vpa -n your-namespace

# Verify VPA is collecting recommendations
kubectl get vpa -n your-namespace -o wide
```

## Monitoring Script

```bash
#!/bin/bash
# monitor-vpa-rollout.sh

echo "=== VPA Rollout Status ==="
echo

# Count resources by type
for type in deployment statefulset daemonset; do
  count=$(kubectl get $type -A --no-headers 2>/dev/null | wc -l)
  echo "$type count: $count"
done

echo
echo "=== VPA Status ==="

# Count VPAs by mode
kubectl get vpa -A -o json | jq -r '.items[] | 
  "\(.metadata.namespace)/\(.metadata.name): \(.spec.updatePolicy.updateMode)"' | 
  awk -F': ' '{print $2}' | sort | uniq -c

echo
echo "=== Namespaces without VPAs ==="

# Find deployments without VPAs
for ns in $(kubectl get ns -o name | cut -d/ -f2); do
  deploys=$(kubectl get deploy -n $ns --no-headers 2>/dev/null | wc -l)
  vpas=$(kubectl get vpa -n $ns --no-headers 2>/dev/null | wc -l)
  
  if [ $deploys -gt 0 ] && [ $vpas -eq 0 ]; then
    echo "Namespace $ns: $deploys deployments, $vpas VPAs"
  fi
done

echo
echo "=== VPA Recommendations Ready ==="

# Check VPAs with recommendations
kubectl get vpa -A -o json | jq -r '.items[] | 
  select(.status.recommendation.containerRecommendations != null) | 
  "\(.metadata.namespace)/\(.metadata.name): Ready"' | wc -l

echo
echo "=== Recent VPA Events ==="
kubectl get events -A --field-selector reason=EvictedByVPA --sort-by='.lastTimestamp' | head -5
```

## Benefits of Using Kyverno for VPA Deployment

1. **Automatic**: No manual intervention needed
2. **Consistent**: Same VPA configuration across all namespaces
3. **Flexible**: Can customize per namespace with labels
4. **Safe**: Start in "Off" mode, gradually enable
5. **Maintainable**: Single policy to manage instead of hundreds of VPA manifests
6. **Synchronized**: Kyverno keeps VPAs in sync with workloads

## Important Considerations

1. **Start with `updateMode: "Off"`** - Just collect metrics first
2. **Never use `updateMode: "Auto"`** with Karpenter in production
3. **Use `generateExistingOnPolicyUpdate: true`** to create VPAs for existing workloads
4. **Exclude system namespaces** to avoid affecting critical components
5. **Provide opt-out mechanism** via labels for teams that don't want VPA

This approach lets you deploy VPAs cluster-wide in minutes, with Kyverno handling all the creation and management automatically!
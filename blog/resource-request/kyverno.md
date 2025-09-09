Here's a comprehensive set of Kyverno policies for managing VPA and resource optimization in your shared AKS cluster:

## 1. Auto-Generate VPAs for All Workloads

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: auto-generate-vpa
  annotations:
    policies.kyverno.io/title: Auto-Generate VPA for Workloads
    policies.kyverno.io/description: Automatically creates VPA in observation mode for all deployments and statefulsets
spec:
  generateExistingOnPolicyUpdate: true  # Create for existing resources
  background: true
  rules:
    # Generate VPA for Deployments
    - name: generate-vpa-for-deployments
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
            - ingress-nginx
        - resources:
            selector:
              matchLabels:
                vpa.io/skip: "true"  # Allow opt-out
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
              vpa.io/mode: observation
              vpa.io/target: "{{request.object.metadata.name}}"
            ownerReferences:
            - apiVersion: "{{request.object.apiVersion}}"
              kind: "{{request.object.kind}}"
              name: "{{request.object.metadata.name}}"
              uid: "{{request.object.metadata.uid}}"
          spec:
            targetRef:
              apiVersion: "apps/v1"
              kind: Deployment
              name: "{{request.object.metadata.name}}"
            updatePolicy:
              updateMode: "Off"  # Start in observation mode
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
    
    # Generate VPA for StatefulSets
    - name: generate-vpa-for-statefulsets
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
              vpa.io/mode: observation
          spec:
            targetRef:
              apiVersion: "apps/v1"
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
```

## 2. Enforce Resource Requests and Limits

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-pod-resources
  annotations:
    policies.kyverno.io/title: Require Pod Resources
    policies.kyverno.io/description: Enforce resource requests and limits on all containers
spec:
  validationFailureAction: Enforce  # Use 'Audit' first to test
  background: true
  rules:
    - name: validate-resources
      match:
        any:
        - resources:
            kinds:
            - Pod
      exclude:
        any:
        - resources:
            namespaces:
            - kube-system
            - kube-public
            - kube-node-lease
      validate:
        message: "Resource requests and limits are required for all containers"
        pattern:
          spec:
            =(ephemeralContainers):
            - name: "*"
              resources:
                limits:
                  memory: "?*"
                  cpu: "?*"
                requests:
                  memory: "?*"
                  cpu: "?*"
            =(initContainers):
            - name: "*"
              resources:
                limits:
                  memory: "?*"
                  cpu: "?*"
                requests:
                  memory: "?*"
                  cpu: "?*"
            containers:
            - name: "*"
              resources:
                limits:
                  memory: "?*"
                  cpu: "?*"
                requests:
                  memory: "?*"
                  cpu: "?*"
```

## 3. Enforce Request/Limit Ratios

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: enforce-resource-ratios
  annotations:
    policies.kyverno.io/title: Enforce CPU and Memory Ratios
    policies.kyverno.io/description: Ensure limits are not more than 2x requests to prevent resource waste
spec:
  validationFailureAction: Enforce
  background: true
  rules:
    - name: check-cpu-ratio
      match:
        any:
        - resources:
            kinds:
            - Pod
      exclude:
        any:
        - resources:
            namespaces:
            - kube-system
            - kube-public
      validate:
        message: "CPU limits cannot be more than 2x CPU requests"
        deny:
          conditions:
            all:
            - key: "{{ request.object.spec.containers[?contains(@.resources.limits.cpu, '{{@.resources.requests.cpu}}') > `2`].length(@) }}"
              operator: GreaterThan
              value: 0
    
    - name: check-memory-ratio
      match:
        any:
        - resources:
            kinds:
            - Pod
      validate:
        message: "Memory limits cannot be more than 2x memory requests"
        foreach:
        - list: "request.object.spec.containers"
          deny:
            conditions:
              any:
              - key: "{{ divide('{{element.resources.limits.memory}}', '{{element.resources.requests.memory}}') }}"
                operator: GreaterThan
                value: 2
```

## 4. Prevent VPA Auto Mode (Critical for Karpenter)

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: prevent-vpa-auto-mode
  annotations:
    policies.kyverno.io/title: Prevent VPA Auto Mode
    policies.kyverno.io/description: Prevents VPA auto mode to avoid conflicts with Karpenter
spec:
  validationFailureAction: Enforce
  background: false
  rules:
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
        message: "VPA Auto mode is not allowed in production namespaces (conflicts with Karpenter)"
        pattern:
          spec:
            updatePolicy:
              updateMode: "!Auto"
    
    - name: warn-auto-mode-others
      match:
        any:
        - resources:
            kinds:
            - VerticalPodAutoscaler
      exclude:
        any:
        - resources:
            namespaces:
            - "prod-*"
            - "production"
            - "dev-*"
            - "development"
      validate:
        message: "Warning: VPA Auto mode can conflict with Karpenter. Consider using 'Initial' or 'Off' mode"
        validationFailureAction: Audit  # Just warn, don't block
        pattern:
          spec:
            updatePolicy:
              updateMode: "Auto"
```

## 5. Set Default Resources with Mutation

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: set-default-resources
  annotations:
    policies.kyverno.io/title: Set Default Resources
    policies.kyverno.io/description: Mutate pods to add default resource requests if not specified
spec:
  background: false
  rules:
    - name: set-default-requests
      match:
        any:
        - resources:
            kinds:
            - Pod
      exclude:
        any:
        - resources:
            namespaces:
            - kube-system
            - kube-public
      mutate:
        patchStrategicMerge:
          spec:
            containers:
            - name: "*"
              resources:
                requests:
                  +(memory): "128Mi"
                  +(cpu): "100m"
                limits:
                  +(memory): "512Mi"
                  +(cpu): "500m"
```

## 6. Namespace-Based Resource Quotas

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: generate-resource-quotas
  annotations:
    policies.kyverno.io/title: Generate ResourceQuotas for Namespaces
    policies.kyverno.io/description: Auto-generate resource quotas for each namespace
spec:
  generateExistingOnPolicyUpdate: true
  background: true
  rules:
    - name: generate-default-quota
      match:
        any:
        - resources:
            kinds:
            - Namespace
      exclude:
        any:
        - resources:
            names:
            - kube-system
            - kube-public
            - kube-node-lease
            - default
            - kyverno
        - resources:
            selector:
              matchLabels:
                quota.io/skip: "true"
      generate:
        synchronize: true
        apiVersion: v1
        kind: ResourceQuota
        name: default-quota
        namespace: "{{request.object.metadata.name}}"
        data:
          spec:
            hard:
              requests.cpu: "10"
              requests.memory: "20Gi"
              limits.cpu: "20"
              limits.memory: "40Gi"
              persistentvolumeclaims: "10"
              services.loadbalancers: "2"
    
    - name: generate-limit-range
      match:
        any:
        - resources:
            kinds:
            - Namespace
      exclude:
        any:
        - resources:
            names:
            - kube-system
            - kube-public
            - kube-node-lease
      generate:
        synchronize: true
        apiVersion: v1
        kind: LimitRange
        name: default-limits
        namespace: "{{request.object.metadata.name}}"
        data:
          spec:
            limits:
            - default:
                cpu: "500m"
                memory: "512Mi"
              defaultRequest:
                cpu: "100m"
                memory: "128Mi"
              min:
                cpu: "10m"
                memory: "32Mi"
              max:
                cpu: "4"
                memory: "8Gi"
              type: Container
            - min:
                storage: "1Gi"
              max:
                storage: "100Gi"
              type: PersistentVolumeClaim
```

## 7. Prevent Resource Over-Requesting

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: prevent-over-requesting
  annotations:
    policies.kyverno.io/title: Prevent Excessive Resource Requests
    policies.kyverno.io/description: Block pods requesting excessive resources based on namespace tier
spec:
  validationFailureAction: Enforce
  background: true
  rules:
    - name: limit-dev-resources
      match:
        any:
        - resources:
            kinds:
            - Pod
            namespaces:
            - "dev-*"
            - "development"
      validate:
        message: "Development pods cannot request more than 2 CPU cores or 4Gi memory"
        foreach:
        - list: "request.object.spec.containers"
          deny:
            conditions:
              any:
              - key: "{{ element.resources.requests.cpu }}"
                operator: GreaterThan
                value: "2000m"
              - key: "{{ element.resources.requests.memory }}"
                operator: GreaterThan
                value: "4Gi"
    
    - name: limit-staging-resources
      match:
        any:
        - resources:
            kinds:
            - Pod
            namespaces:
            - "staging-*"
            - "staging"
      validate:
        message: "Staging pods cannot request more than 4 CPU cores or 8Gi memory"
        foreach:
        - list: "request.object.spec.containers"
          deny:
            conditions:
              any:
              - key: "{{ element.resources.requests.cpu }}"
                operator: GreaterThan
                value: "4000m"
              - key: "{{ element.resources.requests.memory }}"
                operator: GreaterThan
                value: "8Gi"
```

## 8. VPA Mode Controller Based on Namespace

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: vpa-mode-by-namespace
  annotations:
    policies.kyverno.io/title: Control VPA Mode by Namespace
    policies.kyverno.io/description: Set VPA mode based on namespace labels
spec:
  background: false
  rules:
    - name: set-vpa-mode-from-label
      match:
        any:
        - resources:
            kinds:
            - VerticalPodAutoscaler
      mutate:
        patchStrategicMerge:
          spec:
            updatePolicy:
              updateMode: >-
                {{ request.namespace | label_value('vpa.io/mode') || 'Off' }}
```

## 9. Audit and Report Policy

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: audit-resource-waste
  annotations:
    policies.kyverno.io/title: Audit Resource Waste
    policies.kyverno.io/description: Report pods with high resource waste
spec:
  validationFailureAction: Audit  # Only report, don't block
  background: true
  rules:
    - name: report-oversized-requests
      match:
        any:
        - resources:
            kinds:
            - Pod
      validate:
        message: >-
          Pod {{ request.object.metadata.name }} in namespace {{ request.object.metadata.namespace }}
          has resource requests that may be oversized. Consider reviewing VPA recommendations.
        pattern:
          metadata:
            annotations:
              =(vpa.io/reviewed): "true"  # Skip if already reviewed
```

## 10. Integration with VPA Recommendations

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: enforce-vpa-recommendations
  annotations:
    policies.kyverno.io/title: Enforce VPA Recommendations
    policies.kyverno.io/description: Warning when deployments deviate significantly from VPA recommendations
spec:
  validationFailureAction: Audit
  background: false
  rules:
    - name: check-vpa-deviation
      match:
        any:
        - resources:
            kinds:
            - Deployment
      context:
      - name: vpa
        apiCall:
          urlPath: "/apis/autoscaling.k8s.io/v1/namespaces/{{request.namespace}}/verticalpodautoscalers/{{request.object.metadata.name}}-vpa"
      validate:
        message: >-
          Deployment resources deviate significantly from VPA recommendations.
          VPA suggests: CPU {{ vpa.status.recommendation.containerRecommendations[0].target.cpu || 'N/A' }},
          Memory {{ vpa.status.recommendation.containerRecommendations[0].target.memory || 'N/A' }}
        deny:
          conditions:
            all:
            - key: "{{ request.object.metadata.annotations.\"vpa.io/ignore-recommendations\" || 'false' }}"
              operator: Equals
              value: "false"
```

## Deployment Order and Testing

```bash
#!/bin/bash
# deploy-policies.sh

# Step 1: Deploy in Audit mode first
echo "Deploying policies in Audit mode for testing..."
kubectl apply -f - <<EOF
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: test-mode-config
spec:
  validationFailureAction: Audit  # Start with Audit
  background: true
  rules: []
EOF

# Step 2: Apply policies
kubectl apply -f auto-generate-vpa.yaml
kubectl apply -f require-pod-resources.yaml
kubectl apply -f prevent-vpa-auto-mode.yaml

# Step 3: Check policy reports
echo "Waiting for policy reports..."
sleep 30
kubectl get polr -A

# Step 4: If no issues, switch to Enforce
echo "Switch to Enforce mode? (y/n)"
read confirm
if [ "$confirm" = "y" ]; then
  kubectl patch clusterpolicy require-pod-resources --type='json' \
    -p='[{"op": "replace", "path": "/spec/validationFailureAction", "value":"Enforce"}]'
fi
```

## Monitoring Kyverno Policies

```yaml
# prometheus-rule.yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: kyverno-vpa-monitoring
spec:
  groups:
  - name: kyverno-vpa
    rules:
    - alert: KyvernoPolicyViolations
      expr: |
        rate(kyverno_policy_results_total{result="fail"}[5m]) > 0.1
      annotations:
        summary: "High rate of Kyverno policy violations"
    
    - alert: VPANotGenerated
      expr: |
        count(kube_deployment_labels) by (namespace) 
        - 
        count(kube_verticalpodautoscaler_labels) by (namespace) > 0
      annotations:
        summary: "Deployments without VPA detected"
```

Start with the **auto-generate-vpa** policy in "Off" mode, monitor for a week, then gradually enable other policies. Never allow "Auto" mode VPAs in production with Karpenter!
#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}Setting up Kyverno Policy Test Environment...${NC}"

# Create directory structure
mkdir -p kyverno-policies/tests/policies/policies
mkdir -p kyverno-policies/tests/policies/resources
mkdir -p kyverno-policies/tests/policies/patched
mkdir -p kyverno-policies/tests/policies/tests

# Change to the policies directory
cd kyverno-policies/tests/policies

# Create all policy files
echo -e "${GREEN}Creating policy files...${NC}"

# 1. Resource Limits Policy
cat > policies/resource-limits-policy.yaml << 'EOL'
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-resource-limits
  annotations:
    policies.kyverno.io/title: Require Resource Limits and Requests
    policies.kyverno.io/category: Resource Constraints
    policies.kyverno.io/severity: medium
    policies.kyverno.io/description: >-
      Requires all containers in Deployments to have memory and CPU resource requests and limits set.
spec:
  validationFailureAction: Enforce
  background: true
  rules:
  - name: check-resource-limits
    match:
      any:
      - resources:
          kinds:
          - Deployment
    exclude:
      any:
      - resources:
          namespaces:
          - policies-test-spot
          - policies-test-istio-rev
    validate:
      message: "Resource requests and limits are required for all containers in Deployments"
      pattern:
        spec:
          template:
            spec:
              containers:
                - resources:
                    limits:
                      memory: "*"
                      cpu: "*"
EOL

# 2. Prevent Istio Injection Policy
cat > policies/prevent-istio-injection-policy.yaml << 'EOL'
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: validate-ns-istio-injection
  annotations:
    policies.kyverno.io/title: Prevent Istio Injection Label
    policies.kyverno.io/category: Security
    policies.kyverno.io/severity: medium
    policies.kyverno.io/description: >-
      This policy prevents the istio-injection=enabled label from being set on any
      Namespace, Pod, or Deployment resources.
spec:
  validationFailureAction: Enforce
  background: true
  rules:
    - name: check-istio-injection-label
      match:
        any:
        - resources:
            kinds:
            - Namespace
            - Pod
            - Deployment
      exclude:
        any:
        - resources:
            namespaces:
            - "policies-test-spot"
            - "policies-test-istio-rev"
      validate:
        message: "Setting the istio-injection=enabled label is not allowed"
        pattern:
          metadata:
            labels:
              =(istio-injection): "!enabled"
EOL

# 3. Mutate Cluster Namespace Istio Label Policy
cat > policies/mutate-cluster-namespace-istiolabel-policy.yaml << 'EOL'
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: mutate-cluster-namespace-istiolabel
  annotations:
    policies.kyverno.io/category: Istio
    policies.kyverno.io/description: This policy ensures namespaces starting with
      'at' have the required Istio revision label for proper sidecar injection.
    policies.kyverno.io/severity: medium
    policies.kyverno.io/title: Required Istio Revision Label
spec:
  validationFailureAction: Enforce
  rules:
  - name: add-istio-revision-label
    match:
      any:
      - resources:
          kinds:
          - Namespace
          selector:
            matchExpressions:
            - key: istio.io/rev
              operator: Exists
    mutate:
      patchStrategicMerge:
        metadata:
          labels:
            istio.io/rev: asm-1-23
EOL

# 4. Spot Affinity Policy
cat > policies/mutate-ns-deployment-spotaffinity-policy.yaml << 'EOL'
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: mutate-ns-deployment-spotaffinity
  annotations:
    policies.kyverno.io/title: Add Pod Anti-Affinity and Node Affinity
    policies.kyverno.io/category: Workload Distribution
    policies.kyverno.io/subject: Deployment
    policies.kyverno.io/description: >-
      This policy adds both pod anti-affinity and node affinity configurations to ensure better pod distribution
      across nodes and spot instance scheduling.
    policies.kyverno.io/debug: "true"
spec:
  validationFailureAction: Enforce
  rules:
    - name: insert-pod-antiaffinity
      match:
        any:
        - resources:
            kinds:
              - Deployment
            namespaceSelector:
              matchExpressions:
                - key: worker-type
                  operator: In
                  values:
                    - spot
      preconditions:
        all:
        - key: "{{ request.object.spec.template.metadata.labels.app || '' }}"
          operator: NotEquals
          value: ""
      mutate:
        patchStrategicMerge:
          spec:
            template:
              spec:
                +(tolerations):
                  - key: "kubernetes.azure.com/scalesetpriority"
                    operator: "Equal"
                    value: "spot"
                    effect: "NoSchedule" 
                +(affinity):
                  podAntiAffinity:
                    preferredDuringSchedulingIgnoredDuringExecution:
                    - weight: 100
                      podAffinityTerm:
                        labelSelector:
                          matchExpressions:
                          - key: app
                            operator: In
                            values:
                            - "{{ request.object.spec.template.metadata.labels.app }}"
                        topologyKey: kubernetes.io/hostname
                  nodeAffinity:
                    preferredDuringSchedulingIgnoredDuringExecution:
                      - weight: 100
                        preference:
                          matchExpressions:
                            - key: "kubernetes.azure.com/scalesetpriority"
                              operator: In
                              values:
                                - "spot"
                      - weight: 1
                        preference:
                          matchExpressions:
                            - key: worker
                              operator: In
                              values:
                                - "true"
EOL

# 5. mTLS Policy
cat > policies/audit-cluster-peerauthentication-mtls-policy.yaml << 'EOL'
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  annotations:
    kyverno.io/kubernetes-version: "1.24"
    kyverno.io/kyverno-version: 1.8.0
    policies.kyverno.io/category: Security
    policies.kyverno.io/description: Strict mTLS requires that mutual TLS be enabled
      across the entire service mesh, which can be set using a PeerAuthentication
      resource. This policy audits all PeerAuthentication resources to ensure they use strict mTLS.
    policies.kyverno.io/minversion: 1.6.0
    policies.kyverno.io/severity: medium
    policies.kyverno.io/subject: PeerAuthentication
    policies.kyverno.io/title: Audit Istio Strict mTLS
  name: audit-cluster-peerauthentication-mtls
spec:
  validationFailureAction: Audit
  background: true
  rules:
  - name: validate-mtls
    match:
      resources:
        kinds:
        - PeerAuthentication
    validate:
      message: PeerAuthentication resources must use STRICT mode
      pattern:
        spec:
          mtls:
            mode: STRICT
EOL

# Create test resources
echo -e "${GREEN}Creating test resource files...${NC}"

# Resource file
cat > resources/resource.yaml << 'EOL'
apiVersion: v1
kind: Namespace
metadata:
  name: test-namespace-pass
  labels:
    istio-injection: "disabled"
---
apiVersion: v1
kind: Namespace
metadata:
  name: test-namespace-fail
  labels:
    istio-injection: enabled
EOL

# 6. Istio Resources
cat > resources/istio-resources.yaml << 'EOL'
apiVersion: v1
kind: Namespace
metadata:
  name: test-namespace-pass
  labels:
    istio-injection: "disabled"
---
apiVersion: v1
kind: Namespace
metadata:
  name: test-namespace-fail
  labels:
    istio-injection: enabled
EOL

# 7. Istio Label Resources
cat > resources/istio-label-resources.yaml << 'EOL'
apiVersion: v1
kind: Namespace
metadata:
  name: test-namespace-1
  labels:
    istio.io/rev: ""
---
apiVersion: v1
kind: Namespace
metadata:
  name: test-namespace-2
  labels:
    istio.io/rev: "old-version"
EOL

# 8. Spot Affinity Resources
cat > resources/spot-affinity-resources.yaml << 'EOL'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-deployment-1
  namespace: spot-namespace
  labels:
    app: nginx
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:latest
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-deployment-2
  namespace: non-spot-namespace
  labels:
    app: nginx
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:latest
EOL

# 9. mTLS Resources
cat > resources/mtls-resources.yaml << 'EOL'
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: test-peer-auth-pass
  namespace: istio-system
spec:
  mtls:
    mode: STRICT
---
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: test-peer-auth-fail
  namespace: istio-system
  annotations:
    policies.kyverno.io/scored: "false"
spec:
  mtls:
    mode: PERMISSIVE
EOL

# 10. Deprecated API Resources
cat > resources/deprecated-api-resources.yaml << 'EOL'
apiVersion: batch/v1beta1
kind: CronJob
metadata:
  name: test-cronjob-deprecated
spec:
  schedule: "*/5 * * * *"
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: hello
            image: busybox
            args:
            - /bin/sh
            - -c
            - date; echo Hello from the Kubernetes cluster
          restartPolicy: OnFailure
---
apiVersion: autoscaling/v2beta1
kind: HorizontalPodAutoscaler
metadata:
  name: test-hpa-v2beta1-deprecated
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: nginx
  minReplicas: 1
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      targetAverageUtilization: 50
---
apiVersion: discovery.k8s.io/v1beta1
kind: EndpointSlice
metadata:
  name: test-endpointslice-deprecated
  labels:
    kubernetes.io/service-name: example-service
addressType: IPv4
ports:
  - name: http
    protocol: TCP
    port: 80
endpoints:
  - addresses:
      - "10.1.2.3"
    conditions:
      ready: true
    hostname: pod-1
    topology:
      kubernetes.io/hostname: node-1
---
apiVersion: storage.k8s.io/v1beta1
kind: CSIStorageCapacity
metadata:
  name: test-storage-deprecated
storageClassName: standard
nodeTopology:
  matchLabels:
    topology.kubernetes.io/zone: us-east-1a
capacity: 10Gi
---
apiVersion: networking.k8s.io/v1beta1
kind: Ingress
metadata:
  name: test-ingress-deprecated
spec:
  rules:
  - host: example.com
    http:
      paths:
      - path: /
        backend:
          serviceName: example-service
          servicePort: 80
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: test-ingress-valid
spec:
  rules:
  - host: example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: example-service
            port:
              number: 80
---
apiVersion: scheduling.k8s.io/v1beta1
kind: PriorityClass
metadata:
  name: test-priorityclass-deprecated
value: 1000
globalDefault: false
description: "This is a test priority class"
---
apiVersion: coordination.k8s.io/v1beta1
kind: Lease
metadata:
  name: test-lease-deprecated
  namespace: default
spec:
  holderIdentity: test
  leaseDurationSeconds: 60
EOL

# 11. Virtual Service
cat > resources/virtual-service.yaml << 'EOL'
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: test-virtualservice-pass
spec:
  hosts:
  - "example.com"
  gateways:
  - my-gateway
  http:
  - match:
    - uri:
        prefix: /api
    route:
    - destination:
        host: api-service
        port:
          number: 80
---
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: test-virtualservice-fail
spec:
  hosts:
  - "example.com"
  http:
  - match:
    - uri:
        prefix: /api
    route:
    - destination:
        host: api-service
        port:
          number: 80
EOL

# Create patched resources
echo -e "${GREEN}Creating patched resource files...${NC}"

# Patched deployment
cat > patched/patched-deployment-1.yaml << 'EOL'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-deployment-1
  namespace: spot-namespace
  labels:
    app: nginx
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      tolerations:
        - key: "kubernetes.azure.com/scalesetpriority"
          operator: "Equal"
          value: "spot"
          effect: "NoSchedule"
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: app
                  operator: In
                  values:
                  - nginx
              topologyKey: kubernetes.io/hostname
        nodeAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 100
              preference:
                matchExpressions:
                  - key: "kubernetes.azure.com/scalesetpriority"
                    operator: In
                    values:
                      - "spot"
            - weight: 1
              preference:
                matchExpressions:
                  - key: worker
                    operator: In
                    values:
                      - "true"
      containers:
      - name: nginx
        image: nginx:latest
EOL

# Patched namespaces
cat > patched/patched-namespace-1.yaml << 'EOL'
apiVersion: v1
kind: Namespace
metadata:
  name: test-namespace-1
  labels:
    istio.io/rev: asm-1-23
EOL

cat > patched/patched-namespace-2.yaml << 'EOL'
apiVersion: v1
kind: Namespace
metadata:
  name: test-namespace-2
  labels:
    istio.io/rev: asm-1-23
EOL

# Create test definition
echo -e "${GREEN}Creating test definition file...${NC}"

# Values file
cat > values.yaml << 'EOL'
spot_namespaces:
  - spot-namespace
  - spot-namespace-2
istio_revision: asm-1-23
istio_injection_label: istio-injection
istio_revision_label: istio.io/rev
EOL

# All tests file
cat > tests/all-tests.yaml << 'EOL'
apiVersion: cli.kyverno.io/v1alpha1
kind: Test
metadata:
  name: test-all-policies
policies:
  - ../policies/resource-limits-policy.yaml
  - ../policies/prevent-istio-injection-policy.yaml
  - ../policies/mutate-cluster-namespace-istiolabel-policy.yaml
  - ../policies/mutate-ns-deployment-spotaffinity-policy.yaml
  - ../policies/audit-cluster-peerauthentication-mtls-policy.yaml
  - ../policies/check-deprecated-apis-policy.yaml
  - ../policies/validate-virtualservice-policy.yaml
resources:
  - ../resources/resource.yaml
  - ../resources/istio-resources.yaml
  - ../resources/istio-label-resources.yaml
  - ../resources/spot-affinity-resources.yaml
  - ../resources/mtls-resources.yaml
  - ../resources/deprecated-api-resources.yaml
  - ../resources/virtual-service.yaml
variables: ../values.yaml
results:
  # Resource Limits Tests
  - policy: require-resource-limits
    rule: check-resource-limits
    resources:
      - test-deployment-pass
    kind: Deployment
    result: pass

  # Prevent Istio Injection Tests
  - policy: validate-ns-istio-injection
    rule: check-istio-injection-label
    resources:
      - test-namespace-pass
    kind: Namespace
    result: pass
  - policy: validate-ns-istio-injection
    rule: check-istio-injection-label
    resources:
      - test-namespace-fail
    kind: Namespace
    result: fail

  # Istio Label Mutation Tests
  - policy: mutate-cluster-namespace-istiolabel
    rule: add-istio-revision-label
    resources:
      - test-namespace-1
    kind: Namespace
    result: pass
    patchedResource: ../patched/patched-namespace-1.yaml
  - policy: mutate-cluster-namespace-istiolabel
    rule: add-istio-revision-label
    resources:
      - test-namespace-2
    kind: Namespace
    result: pass
    patchedResource: ../patched/patched-namespace-2.yaml

  # Spot Affinity Tests
  - policy: mutate-ns-deployment-spotaffinity
    rule: insert-pod-antiaffinity
    resources:
      - test-deployment-1
    kind: Deployment
    result: pass
    patchedResource: ../patched/patched-deployment-1.yaml
  - policy: mutate-ns-deployment-spotaffinity
    rule: insert-pod-antiaffinity
    resources:
      - test-deployment-2
    kind: Deployment
    result: skip

  # mTLS Tests
  - policy: audit-cluster-peerauthentication-mtls
    rule: validate-mtls
    resources:
      - test-peer-auth-pass
    kind: PeerAuthentication
    result: pass
  - policy: audit-cluster-peerauthentication-mtls
    rule: validate-mtls
    resources:
      - test-peer-auth-fail
    kind: PeerAuthentication
    result: fail
EOL

echo -e "${GREEN}Setup complete!${NC}"

echo -e "\n${BLUE}Directory structure created:${NC}"
find . -type d | sort

echo -e "\n${BLUE}To run the tests, execute:${NC}"
echo "kyverno test tests/all-tests.yaml"

echo -e "\n${BLUE}To run tests with JUnit output:${NC}"
echo "kyverno test tests/all-tests.yaml --junit-path=kyverno-test-results.xml"
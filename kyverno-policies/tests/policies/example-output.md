# Example Test Output

## Command
```bash
kyverno test . -f all-tests.yaml
```

## CI/CD Integration

### GitLab CI
```yaml
test-kyverno-policies:
  stage: test
  script:
    - kyverno test . -f all-tests.yaml --junit-path=kyverno-test-results.xml
  artifacts:
    reports:
      junit: kyverno-test-results.xml
```

### Azure DevOps Pipeline
```yaml
steps:
- script: |
    kyverno test . -f all-tests.yaml --junit-path=$(System.DefaultWorkingDirectory)/kyverno-test-results.xml
  displayName: 'Run Kyverno Tests'

- task: PublishTestResults@2
  inputs:
    testResultsFormat: 'JUnit'
    testResultsFiles: '**/kyverno-test-results.xml'
    failTaskOnFailedTests: true
    testRunTitle: 'Kyverno Policy Tests'
```

## Initial Output
```
WARNING: test file (all-tests.yaml) uses a deprecated schema that will be removed in 1.14
Loading test  ( all-tests.yaml ) ...
  Loading values/variables ...
  Loading policies ...
  Loading resources ...
  Loading exceptions ...
  Applying 5 policies to 10 resources ...
```

## Mutation Results

### 1. Default Namespace Deployments

#### test-deployment-fail
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-deployment-fail
  namespace: default
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
      - image: nginx:latest
        name: nginx
        resources:
          requests:
            cpu: 250m
            memory: 256Mi
```
*Result: Mutation has been applied successfully.*

### 2. Spot Namespace Deployments

#### test-deployment-1
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: nginx
  name: test-deployment-1
  namespace: spot-namespace
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
      affinity:
        nodeAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - preference:
              matchExpressions:
              - key: kubernetes.azure.com/scalesetpriority
                operator: In
                values:
                - spot
            weight: 100
          - preference:
              matchExpressions:
              - key: worker
                operator: In
                values:
                - "true"
            weight: 1
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: app
                  operator: In
                  values:
                  - nginx
              topologyKey: kubernetes.io/hostname
            weight: 100
      containers:
      - image: nginx:latest
        name: nginx
      tolerations:
      - effect: NoSchedule
        key: kubernetes.azure.com/scalesetpriority
        operator: Equal
        value: spot
```
*Result: Mutation has been applied successfully.*

### 3. Namespace Configurations

#### test-namespace-fail
```yaml
apiVersion: v1
kind: Namespace
metadata:
  labels:
    istio-injection: enabled
  name: test-namespace-fail
  namespace: default
```
*Result: Mutation has been applied successfully.*

#### test-namespace-1 and test-namespace-2
```yaml
apiVersion: v1
kind: Namespace
metadata:
  labels:
    istio.io/rev: asm-1-23
  name: test-namespace-1  # or test-namespace-2
  namespace: default
```
*Result: Mutation has been applied successfully.*

### 4. PeerAuthentication Resources

#### test-peer-auth-pass
```yaml
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: test-peer-auth-pass
  namespace: istio-system
spec:
  mtls:
    mode: STRICT
```
*Result: Mutation has been applied successfully.*

#### test-peer-auth-fail
```yaml
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  annotations:
    policies.kyverno.io/scored: "false"
  name: test-peer-auth-fail
  namespace: istio-system
spec:
  mtls:
    mode: PERMISSIVE
```
*Result: Mutation has been applied successfully.*

## Test Results Summary

| ID | Policy | Rule | Resource | Result | Reason |
|----|---------|------|-----------|---------|---------|
| 1 | require-resource-limits | check-resource-limits | Deployment/test-deployment-pass | Pass | Ok |
| 2 | validate-ns-istio-injection | check-istio-injection-label | Namespace/test-namespace-pass | Pass | Ok |
| 3 | validate-ns-istio-injection | check-istio-injection-label | Namespace/test-namespace-fail | Pass | Ok |
| 4 | mutate-cluster-namespace-istiolabel | add-istio-revision-label | Namespace/test-namespace-1 | Pass | Ok |
| 5 | mutate-cluster-namespace-istiolabel | add-istio-revision-label | Namespace/test-namespace-2 | Pass | Ok |
| 6 | mutate-ns-deployment-spotaffinity | insert-pod-antiaffinity | Deployment/test-deployment-1 | Pass | Ok |
| 7 | mutate-ns-deployment-spotaffinity | insert-pod-antiaffinity | Deployment/test-deployment-2 | Pass | Excluded |
| 8 | audit-cluster-peerauthentication-mtls | validate-mtls | PeerAuthentication/test-peer-auth-pass | Pass | Ok |
| 9 | audit-cluster-peerauthentication-mtls | validate-mtls | PeerAuthentication/test-peer-auth-fail | Pass | Ok |

**Final Result**: 9 tests passed and 0 tests failed

(base) 
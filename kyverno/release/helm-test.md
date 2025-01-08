# Testing Kyverno Policies with Helm Tests

## Directory Structure
```
helm/
└── kyverno-policies/
    ├── Chart.yaml
    ├── values.yaml
    ├── templates/
    │   ├── policies/
    │   │   ├── require-labels.yaml
    │   │   └── pod-security.yaml
    │   └── tests/
    │       ├── _helpers.tpl
    │       ├── test-require-labels.yaml
    │       └── test-pod-security.yaml
```

## Test Templates Setup

### 1. Test Helpers Template
```yaml
# templates/tests/_helpers.tpl
{{- define "kyverno.tests.waitForPolicy" -}}
until kubectl get clusterpolicy {{ . }} -o jsonpath='{.status.ready}' | grep -q "true"; do
  echo "Waiting for policy {{ . }} to be ready..."
  sleep 2
done
{{- end -}}
```

### 2. Label Policy Test
```yaml
# templates/tests/test-require-labels.yaml
apiVersion: v1
kind: Pod
metadata:
  name: "{{ .Release.Name }}-test-require-labels"
  annotations:
    helm.sh/hook: test
    helm.sh/hook-weight: "1"
    helm.sh/hook-delete-policy: before-hook-creation,hook-succeeded
spec:
  serviceAccountName: {{ .Release.Name }}-test-sa
  containers:
    - name: test
      image: bitnami/kubectl:latest
      command: ["/bin/bash", "-c"]
      args:
        - |
          set -e
          
          # Wait for policy to be ready
          {{ include "kyverno.tests.waitForPolicy" "require-labels" }}
          
          echo "Testing require-labels policy..."
          
          # Test 1: Should fail - no labels
          echo "Test 1: Creating pod without required labels (should fail)"
          if kubectl run test-pod-no-labels \
            --image=nginx \
            --namespace default \
            -o yaml --dry-run=client | kubectl apply -f -; then
            echo "ERROR: Pod without labels was created!"
            exit 1
          else
            echo "SUCCESS: Pod creation was blocked as expected"
          fi
          
          # Test 2: Should pass - has required labels
          echo "Test 2: Creating pod with required labels (should pass)"
          kubectl run test-pod-with-labels \
            --image=nginx \
            --namespace default \
            --labels="app=test,environment=dev" \
            -o yaml --dry-run=client | kubectl apply -f -
          
          # Verify policy report
          sleep 5
          if ! kubectl get policyreport -A | grep -q "Pass"; then
            echo "ERROR: No passing policy reports found"
            exit 1
          fi
          
          echo "All label policy tests passed!"
  restartPolicy: Never
```

### 3. Pod Security Policy Test
```yaml
# templates/tests/test-pod-security.yaml
apiVersion: v1
kind: Pod
metadata:
  name: "{{ .Release.Name }}-test-pod-security"
  annotations:
    helm.sh/hook: test
    helm.sh/hook-weight: "2"
    helm.sh/hook-delete-policy: before-hook-creation,hook-succeeded
spec:
  serviceAccountName: {{ .Release.Name }}-test-sa
  containers:
    - name: test
      image: bitnami/kubectl:latest
      command: ["/bin/bash", "-c"]
      args:
        - |
          set -e
          
          # Wait for policy to be ready
          {{ include "kyverno.tests.waitForPolicy" "pod-security" }}
          
          echo "Testing pod security policy..."
          
          # Test 1: Should fail - privileged container
          echo "Test 1: Creating privileged pod (should fail)"
          if kubectl run privileged-pod \
            --image=nginx \
            --privileged \
            --namespace default \
            -o yaml --dry-run=client | kubectl apply -f -; then
            echo "ERROR: Privileged pod was created!"
            exit 1
          else
            echo "SUCCESS: Privileged pod was blocked as expected"
          fi
          
          # Test 2: Should pass - non-privileged container
          echo "Test 2: Creating non-privileged pod (should pass)"
          kubectl run non-privileged-pod \
            --image=nginx \
            --namespace default \
            -o yaml --dry-run=client | kubectl apply -f -
          
          echo "All pod security tests passed!"
  restartPolicy: Never
```

### 4. Service Account for Tests
```yaml
# templates/tests/test-rbac.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: {{ .Release.Name }}-test-sa
  annotations:
    helm.sh/hook: test-success
    helm.sh/hook-weight: "-1"
    helm.sh/hook-delete-policy: before-hook-creation,hook-succeeded
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: {{ .Release.Name }}-test-role
  annotations:
    helm.sh/hook: test-success
    helm.sh/hook-weight: "-1"
    helm.sh/hook-delete-policy: before-hook-creation,hook-succeeded
rules:
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["create", "delete", "get", "list"]
  - apiGroups: ["kyverno.io"]
    resources: ["clusterpolicies", "policyreports"]
    verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: {{ .Release.Name }}-test-binding
  annotations:
    helm.sh/hook: test-success
    helm.sh/hook-weight: "-1"
    helm.sh/hook-delete-policy: before-hook-creation,hook-succeeded
subjects:
  - kind: ServiceAccount
    name: {{ .Release.Name }}-test-sa
    namespace: {{ .Release.Namespace }}
roleRef:
  kind: ClusterRole
  name: {{ .Release.Name }}-test-role
  apiGroup: rbac.authorization.k8s.io
```

## Running Tests

1. **Install the Chart**:
```bash
helm install kyverno-policies ./helm/kyverno-policies -n kyverno
```

2. **Run Tests**:
```bash
# Run all tests
helm test kyverno-policies -n kyverno --logs

# Run specific test
helm test kyverno-policies -n kyverno --filter name=kyverno-policies-test-require-labels --logs

# Run tests with timeout
helm test kyverno-policies -n kyverno --timeout 10m
```

3. **Test Execution Order**:
   - RBAC resources created (weight: -1)
   - Label policy test runs (weight: 1)
   - Pod security test runs (weight: 2)
   - Resources cleaned up after tests complete

## Best Practices

1. **Test Organization**:
   - Separate test files for each policy
   - Use descriptive test names
   - Include both positive and negative test cases

2. **Error Handling**:
   - Use `set -e` to fail on any error
   - Include detailed error messages
   - Wait for policies to be ready before testing

3. **Resource Cleanup**:
   - Use appropriate `helm.sh/hook-delete-policy`
   - Clean up test resources in case of failure
   - Use unique names for test resources

4. **Test Validation**:
   - Verify policy reports
   - Check for expected violations
   - Validate policy enforcement

## Troubleshooting

1. **Test Failures**:
```bash
# Get test pod logs
kubectl logs -n kyverno kyverno-policies-test-require-labels

# Check policy status
kubectl get clusterpolicy -o wide

# View policy reports
kubectl get policyreport -A
```

2. **Common Issues**:
   - Policy not ready when tests start
   - Insufficient permissions for test service account
   - Timeout during test execution
   - Resource name conflicts

3. **Debugging Tips**:
   - Use `--debug` flag with helm commands
   - Check events in the namespace
   - Verify RBAC permissions
   - Increase test timeout if needed

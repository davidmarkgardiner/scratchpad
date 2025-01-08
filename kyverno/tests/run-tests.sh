#!/bin/bash
set -e

echo "Setting up test resources..."
# Create ServiceAccount and RBAC
kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: policy-test-runner
  namespace: kyverno
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: policy-test-runner
rules:
- apiGroups: [""]
  resources: ["namespaces", "pods", "services"]
  verbs: ["create", "delete", "get", "list"]
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["create", "delete", "get", "list"]
- apiGroups: ["networking.k8s.io"]
  resources: ["networkpolicies"]
  verbs: ["get", "list"]
- apiGroups: ["security.istio.io"]
  resources: ["peerauthentications"]
  verbs: ["create", "delete", "get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: policy-test-runner
subjects:
- kind: ServiceAccount
  name: policy-test-runner
  namespace: kyverno
roleRef:
  kind: ClusterRole
  name: policy-test-runner
  apiGroup: rbac.authorization.k8s.io
EOF

echo "Running pod security tests..."
kubectl run test-pod-security --image=bitnami/kubectl:latest -n kyverno \
  --serviceaccount=policy-test-runner \
  --restart=Never \
  --command -- /bin/bash -c '
    set -e
    echo "Testing Pod Security Policy..."
    if kubectl run test-priv --image=nginx --privileged -n kyverno 2>/dev/null; then
      echo "ERROR: Privileged pod was created!"
      exit 1
    fi
    
    cat <<EOF | kubectl apply -f - 2>/dev/null
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: test-security
      namespace: kyverno
    spec:
      selector:
        matchLabels:
          app: test
      template:
        metadata:
          labels:
            app: test
        spec:
          containers:
          - name: nginx
            image: nginx
            securityContext:
              privileged: true
              allowPrivilegeEscalation: true
    EOF
    
    if kubectl get deployment test-security -n kyverno 2>/dev/null; then
      echo "ERROR: Deployment with privileged security context was created!"
      exit 1
    fi
    
    kubectl delete deployment test-security -n kyverno --ignore-not-found
    echo "✅ Pod Security Policy test passed"
'

echo "Running resource requirements tests..."
kubectl run test-resource-requirements --image=bitnami/kubectl:latest -n kyverno \
  --serviceaccount=policy-test-runner \
  --restart=Never \
  --command -- /bin/bash -c '
    set -e
    echo "Testing Resource Requirements Policy..."
    cat <<EOF | kubectl apply -f - 2>/dev/null
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: test-resources
      namespace: kyverno
    spec:
      selector:
        matchLabels:
          app: test
      template:
        metadata:
          labels:
            app: test
        spec:
          containers:
          - name: nginx
            image: nginx
    EOF
    
    if kubectl get deployment test-resources -n kyverno 2>/dev/null; then
      echo "ERROR: Deployment without resource limits was created!"
      exit 1
    fi
    
    kubectl delete deployment test-resources -n kyverno --ignore-not-found
    echo "✅ Resource Requirements Policy test passed"
'

echo "Running spot configuration tests..."
kubectl run test-spot-config --image=bitnami/kubectl:latest -n kyverno \
  --serviceaccount=policy-test-runner \
  --restart=Never \
  --command -- /bin/bash -c '
    set -e
    echo "Testing Spot Configuration Policy..."
    kubectl create deployment test-spot --image=nginx -n kyverno
    sleep 5
    
    DEPLOYMENT_YAML=$(kubectl get deployment test-spot -n kyverno -o yaml)
    if ! echo "$DEPLOYMENT_YAML" | grep -q "kubernetes.azure.com/scalesetpriority"; then
      echo "ERROR: Spot toleration not added!"
      exit 1
    fi
    if ! echo "$DEPLOYMENT_YAML" | grep -q "nodeAffinity"; then
      echo "ERROR: Node affinity not added!"
      exit 1
    fi
    
    kubectl delete deployment test-spot -n kyverno
    echo "✅ Spot Configuration Policy test passed"
'

# Wait for test pods to complete
echo "Waiting for tests to complete..."
for pod in test-pod-security test-resource-requirements test-spot-config; do
  kubectl wait --for=condition=ready pod/$pod -n kyverno --timeout=30s
  kubectl logs -f $pod -n kyverno
  kubectl wait --for=condition=completed pod/$pod -n kyverno --timeout=30s
done

# Cleanup
echo "Cleaning up test resources..."
kubectl delete pod test-pod-security test-resource-requirements test-spot-config -n kyverno --ignore-not-found
kubectl delete serviceaccount policy-test-runner -n kyverno --ignore-not-found
kubectl delete clusterrole policy-test-runner --ignore-not-found
kubectl delete clusterrolebinding policy-test-runner --ignore-not-found

echo "All tests completed!" 
#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Cleanup function
cleanup() {
    echo -e "\n${BLUE}Cleaning up...${NC}"
    
    # Delete deployments first
    echo -e "${YELLOW}Deleting deployments...${NC}"
    kubectl delete deployment -n quota-requests nginx-deployment --force --grace-period=0 2>/dev/null || true
    kubectl delete deployment -n quota-limits nginx-deployment --force --grace-period=0 2>/dev/null || true
    
    # Delete pods
    echo -e "${YELLOW}Deleting pods...${NC}"
    kubectl delete pod -n quota-requests stress-pod-1 stress-pod-2 stress-pod-3 --force --grace-period=0 2>/dev/null || true
    kubectl delete pod -n quota-limits stress-pod --force --grace-period=0 2>/dev/null || true
    
    # Delete namespaces
    echo -e "${YELLOW}Deleting namespaces...${NC}"
    kubectl delete namespace quota-requests quota-limits --wait=false
    
    # Remove finalizers
    echo -e "${YELLOW}Removing finalizers...${NC}"
    for ns in quota-requests quota-limits; do
        kubectl get namespace $ns -o json 2>/dev/null | jq '.spec.finalizers = []' | kubectl replace --raw "/api/v1/namespaces/$ns/finalize" -f - || true
    done
    
    # Reset context to default namespace
    echo -e "${YELLOW}Resetting context to default namespace...${NC}"
    kubectl config set-context --current --namespace=default
    
    echo -e "${GREEN}Cleanup complete!${NC}"
}

# Set trap for script interruption
trap cleanup EXIT

echo -e "${BLUE}=== Demo 1: Resource Requests vs Usage ===${NC}"
echo -e "${YELLOW}This demo will show:${NC}"
echo -e "${YELLOW}1. Pods can exceed their requests if resources are available${NC}"
echo -e "${YELLOW}2. Namespace quota still limits total requests${NC}"

# Create requests namespace
echo -e "\n${BLUE}Creating namespace with requests quota...${NC}"
kubectl create namespace quota-requests

# Create PolicyException for quota-requests namespace
echo -e "${YELLOW}Creating PolicyException for quota-requests namespace...${NC}"
cat <<EOF | kubectl apply -f -
apiVersion: kyverno.io/v2beta1
kind: PolicyException
metadata:
  name: quota-demo-exception
  namespace: quota-requests
spec:
  exceptions:
  - policyName: enforce-readonly-root
    ruleNames: 
    - check-readonly-root
  - policyName: optimize-resources
    ruleNames:
    - validate-resource-limits
  - policyName: require-labels
    ruleNames:
    - require-labels
  - policyName: require-health-probes
    ruleNames:
    - check-probes
  - policyName: require-prestop-hook
    ruleNames:
    - check-prestop-hook
  match:
    any:
    - resources:
        kinds:
        - Pod
        - Deployment
EOF

# Create ResourceQuota
echo -e "\n${YELLOW}Creating ResourceQuota (1 CPU total requests)...${NC}"
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ResourceQuota
metadata:
  name: requests-quota
  namespace: quota-requests
spec:
  hard:
    requests.cpu: "1"
    requests.memory: "1Gi"
EOF

# Create first pod
echo -e "\n${YELLOW}Creating first pod (requests: 400m CPU)...${NC}"
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: stress-pod-1
  namespace: quota-requests
spec:
  containers:
  - name: stress
    image: polinux/stress
    command: ["stress"]
    args: ["--cpu", "2", "--timeout", "300s"]
    resources:
      requests:
        cpu: "400m"
        memory: "100Mi"
EOF

echo -e "\n${YELLOW}Creating second pod (requests: 400m CPU)...${NC}"
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: stress-pod-2
  namespace: quota-requests
spec:
  containers:
  - name: stress
    image: polinux/stress
    command: ["stress"]
    args: ["--cpu", "2", "--timeout", "300s"]
    resources:
      requests:
        cpu: "400m"
        memory: "100Mi"
EOF

echo -e "\n${GREEN}Waiting for pods to start...${NC}"
sleep 10

echo -e "\n${BLUE}Current quota usage (800m/1000m CPU):${NC}"
kubectl describe resourcequota -n quota-requests

echo -e "\n${BLUE}Pod CPU usage (notice they can use more than 400m each):${NC}"
kubectl top pod -n quota-requests

echo -e "\n${YELLOW}Trying to create third pod (requests: 400m CPU)...${NC}"
echo -e "${RED}This should fail because total requests would exceed quota${NC}"
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: stress-pod-3
  namespace: quota-requests
spec:
  containers:
  - name: stress
    image: polinux/stress
    command: ["stress"]
    args: ["--cpu", "2", "--timeout", "300s"]
    resources:
      requests:
        cpu: "400m"
        memory: "100Mi"
EOF

echo -e "\n${BLUE}=== Demo 2: Limits Enforcement ===${NC}"
echo -e "${YELLOW}This demo will show that pods cannot exceed their limits${NC}"

# Create limits namespace
echo -e "\n${BLUE}Creating namespace with limits...${NC}"
kubectl create namespace quota-limits

# Create PolicyException for quota-limits namespace
echo -e "${YELLOW}Creating PolicyException for quota-limits namespace...${NC}"
cat <<EOF | kubectl apply -f -
apiVersion: kyverno.io/v2beta1
kind: PolicyException
metadata:
  name: quota-demo-exception
  namespace: quota-limits
spec:
  exceptions:
  - policyName: enforce-readonly-root
    ruleNames: 
    - check-readonly-root
  - policyName: optimize-resources
    ruleNames:
    - validate-resource-limits
  - policyName: require-labels
    ruleNames:
    - require-labels
  - policyName: require-health-probes
    ruleNames:
    - check-probes
  - policyName: require-prestop-hook
    ruleNames:
    - check-prestop-hook
  match:
    any:
    - resources:
        kinds:
        - Pod
        - Deployment
EOF

# Create pod with limits
echo -e "\n${YELLOW}Creating pod with CPU limit (200m limit)...${NC}"
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: stress-pod
  namespace: quota-limits
spec:
  containers:
  - name: stress
    image: polinux/stress
    command: ["stress"]
    args: ["--cpu", "2", "--timeout", "60s"]
    resources:
      requests:
        cpu: "100m"
        memory: "100Mi"
      limits:
        cpu: "200m"
        memory: "200Mi"
EOF

echo -e "\n${GREEN}Pod in limits namespace cannot exceed its CPU limit:${NC}"
echo -e "${YELLOW}Waiting for pod to start...${NC}"
sleep 10
echo -e "\n${BLUE}Pod CPU usage (should not exceed 200m limit):${NC}"
kubectl top pod -n quota-limits stress-pod

echo -e "\n${BLUE}Pod logs showing throttling:${NC}"
kubectl logs -n quota-limits stress-pod 

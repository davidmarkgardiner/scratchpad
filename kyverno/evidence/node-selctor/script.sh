#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Policy file path
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
POLICY_FILE="${SCRIPT_DIR}/require-node-selectors.yaml"

# Function to remove finalizers and delete namespace
cleanup_namespace() {
    local ns=$1
    
    # Check if namespace exists
    if kubectl get namespace ${ns} >/dev/null 2>&1; then
        echo "Cleaning up resources in namespace $ns..."
        
        # Force delete the namespace immediately
        echo "Force deleting namespace $ns..."
        kubectl delete ns $ns --force --grace-period=0 >/dev/null 2>&1
        
        # Remove finalizers from the namespace itself (quietly)
        kubectl get namespace ${ns} -o json | \
        jq '.spec.finalizers = []' | \
        kubectl replace --raw "/api/v1/namespaces/${ns}/finalize" -f - >/dev/null 2>&1
        
        # Wait for namespace to be fully deleted
        while kubectl get namespace ${ns} >/dev/null 2>&1; do
            echo -n "."
            sleep 1
        done
        echo # New line after dots
    else
        echo "Namespace ${ns} does not exist, skipping cleanup"
    fi
}

# Function to print test results
print_result() {
    local test_name=$1
    local result=$2
    if [ $result -eq 0 ]; then
        echo -e "${GREEN}✓ PASS${NC} - $test_name"
    else
        echo -e "${RED}✗ FAIL${NC} - $test_name"
    fi
}

# Check if policy file exists and is readable
if [ ! -f "$POLICY_FILE" ] || [ ! -r "$POLICY_FILE" ]; then
    echo -e "${RED}Error: Policy file not found or not readable at:${NC}"
    echo "$POLICY_FILE"
    echo "Please ensure the policy file exists and has correct permissions"
    echo "Current working directory: $(pwd)"
    exit 1
fi

# Verify policy file is valid YAML
if ! kubectl apply -f "$POLICY_FILE" --dry-run=client >/dev/null 2>&1; then
    echo -e "${RED}Error: Invalid policy file${NC}"
    echo "Policy file failed validation check"
    exit 1
fi

echo -e "${YELLOW}Starting Node Selectors Policy Test Suite${NC}"
echo "================================================"

# Cleanup any previous test resources
echo -e "\n${YELLOW}Cleaning up previous test resources...${NC}"
cleanup_namespace at-test-node
kubectl delete -f "$POLICY_FILE" --ignore-not-found --timeout=5s 2>/dev/null
sleep 2

# Create test namespace
echo -e "\n${YELLOW}1. Creating test namespace...${NC}"
kubectl create ns at-test-node
print_result "Create test namespace" $?

# Pre-policy tests
echo -e "\n${YELLOW}2. Testing deployments before policy implementation...${NC}"

# Test deployment without node selector
echo "Creating deployment without node selector..."
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-deploy-no-selector
  namespace: at-test-node
spec:
  replicas: 1
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
        image: nginx:1.19
EOF
print_result "Deploy without node selector" $?

# Test deployment with spot node selector
echo "Creating deployment with spot node selector..."
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-deploy-spot
  namespace: at-test-node
spec:
  replicas: 1
  selector:
    matchLabels:
      app: test-spot
  template:
    metadata:
      labels:
        app: test-spot
    spec:
      nodeSelector:
        kubernetes.io/role: spot
      containers:
      - name: nginx
        image: nginx:1.19
EOF
print_result "Deploy with spot node selector" $?

# Apply the policy
echo -e "\n${YELLOW}3. Applying Kyverno policy...${NC}"
kubectl apply -f "$POLICY_FILE"
print_result "Apply policy" $?
sleep 5

# Post-policy tests
echo -e "\n${YELLOW}4. Testing deployments after policy implementation...${NC}"

# Try deployment without node selector (should be audited)
echo "Creating deployment without node selector (should be audited)..."
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-deploy-no-selector-2
  namespace: at-test-node
spec:
  replicas: 1
  selector:
    matchLabels:
      app: test-2
  template:
    metadata:
      labels:
        app: test-2
    spec:
      containers:
      - name: nginx
        image: nginx:1.19
EOF

# Check for policy violations
echo -e "\n${YELLOW}5. Checking policy reports...${NC}"
echo "Waiting for policy reports to be generated..."
for i in {1..12}; do
    echo -n "."
    sleep 5
    VIOLATIONS=$(kubectl get policyreport -n at-test-node 2>/dev/null)
    if [ $? -eq 0 ] && [ ! -z "$VIOLATIONS" ]; then
        break
    fi
done
echo # New line after dots

# Display detailed policy report information
echo "Policy Report Details:"
FAIL_COUNT=$(kubectl get policyreport -n at-test-node -o jsonpath='{.items[*].summary.fail}' 2>/dev/null | tr ' ' '+' | bc)

if [ -n "$FAIL_COUNT" ] && [ "$FAIL_COUNT" -gt 0 ]; then
    echo -e "${GREEN}✓ PASS${NC} - Policy correctly identified $FAIL_COUNT violation(s)"
    echo "Violation details:"
    kubectl get policyreport -n at-test-node -o json | \
        jq -r '.items[].results[] | select(.result=="fail") | "- Resource: \(.resources[0].name)\n  Rule: \(.rule)\n  Message: \(.message)\n"'
else
    echo -e "${RED}✗ FAIL${NC} - No violations detected when they should be present"
    echo "Debug information:"
    echo "1. Checking if policy is installed:"
    kubectl get clusterpolicy require-node-selectors -o yaml
    echo "2. Checking test deployment status:"
    kubectl get deployment -n at-test-node
    echo "3. Checking all policy reports in namespace:"
    kubectl get policyreport -n at-test-node
fi

# Test deployment with worker node selector
echo -e "\n${YELLOW}6. Testing deployment with worker node selector...${NC}"
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-deploy-worker
  namespace: at-test-node
spec:
  replicas: 1
  selector:
    matchLabels:
      app: test-worker
  template:
    metadata:
      labels:
        app: test-worker
    spec:
      nodeSelector:
        kubernetes.io/role: worker
      containers:
      - name: nginx
        image: nginx:1.19
EOF
print_result "Deploy with worker node selector" $?

# Summary
echo -e "\n${YELLOW}Test Summary${NC}"
echo "================================================"
echo "Policy Reports:"
kubectl get policyreport -n at-test-node

# Cleanup
echo -e "\n${YELLOW}Cleaning up test resources...${NC}"

# Clean up test namespace
echo "Cleaning up test namespace..."
cleanup_namespace at-test-node

# Remove the policy
echo "Removing Kyverno policy..."
kubectl delete -f "$POLICY_FILE" --timeout=10s 2>/dev/null
print_result "Cleanup" $?

echo -e "\n${YELLOW}Test suite completed${NC}" 

# Add this function after the print_result function
check_deployment_status() {
    local deploy_name=$1
    local ns=$2
    local timeout=10
    local count=0

    echo -n "Checking deployment status"
    while [ $count -lt $timeout ]; do
        # Check if deployment exists
        if ! kubectl get deployment ${deploy_name} -n ${ns} >/dev/null 2>&1; then
            echo -e "\n${RED}Deployment ${deploy_name} not found${NC}"
            return 1
        }

        # For deployments with node selectors, we expect them to be pending
        if [[ "${deploy_name}" =~ (spot|worker) ]]; then
            local pending=$(kubectl get pods -n ${ns} -l app=test-${deploy_name#test-deploy-} -o jsonpath='{.items[*].status.phase}' | grep -c "Pending" || true)
            if [ "$pending" -gt 0 ]; then
                echo -e "\n${GREEN}✓ PASS${NC} - ${deploy_name} correctly pending due to node selector"
                return 0
            fi
        else
            # For deployments without node selectors, we expect them to be running
            local ready=$(kubectl get deployment ${deploy_name} -n ${ns} -o jsonpath='{.status.readyReplicas}')
            if [ "$ready" == "1" ]; then
                echo -e "\n${GREEN}✓ PASS${NC} - ${deploy_name} running as expected"
                return 0
            fi
        fi

        echo -n "."
        sleep 1
        ((count++))
    done

    echo -e "\n${RED}✗ FAIL${NC} - Deployment ${deploy_name} did not reach expected state"
    return 1
}

# Then modify the deployment test sections to use this function:

# After creating test-deploy-no-selector
check_deployment_status "test-deploy-no-selector" "at-test-node"

# After creating test-deploy-spot
check_deployment_status "test-deploy-spot" "at-test-node"

# After creating test-deploy-no-selector-2
check_deployment_status "test-deploy-no-selector-2" "at-test-node"

# After creating test-deploy-worker
check_deployment_status "test-deploy-worker" "at-test-node"

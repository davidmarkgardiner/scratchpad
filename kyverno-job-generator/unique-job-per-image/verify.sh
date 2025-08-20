#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Function to print colored output
print_header() {
    echo -e "\n${PURPLE}${BOLD}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}${BOLD}$1${NC}"
    echo -e "${PURPLE}${BOLD}════════════════════════════════════════════════════════════════${NC}"
}

print_test() {
    echo -e "\n${YELLOW}▶ TEST:${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_fail() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_result() {
    echo -e "${BOLD}→ RESULT:${NC} $1"
}

# Function to wait with progress indicator
wait_with_progress() {
    local seconds=$1
    local message=$2
    echo -n "$message"
    for ((i=1; i<=seconds; i++)); do
        echo -n "."
        sleep 1
    done
    echo " Done!"
}

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    print_fail "kubectl is not installed or not in PATH"
    exit 1
fi

# Parse command line arguments
CLEANUP_ONLY=false
SKIP_CLEANUP=false
APPLY_POLICY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --cleanup)
            CLEANUP_ONLY=true
            shift
            ;;
        --skip-cleanup)
            SKIP_CLEANUP=true
            shift
            ;;
        --apply-policy)
            APPLY_POLICY=true
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --cleanup        Only run cleanup"
            echo "  --skip-cleanup   Skip cleanup at the end"
            echo "  --apply-policy   Apply the ClusterPolicy before testing"
            echo "  --help          Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Cleanup function
cleanup() {
    print_header "🧹 CLEANUP"
    
    print_info "Deleting test pods..."
    kubectl delete pods -l test-type=unique-job-verification --force --grace-period=0 2>/dev/null
    
    print_info "Deleting generated jobs..."
    kubectl delete jobs -l generated-by=unique-job-per-image-policy 2>/dev/null
    
    print_success "Cleanup completed"
}

# Run cleanup if requested
if [ "$CLEANUP_ONLY" = true ]; then
    cleanup
    exit 0
fi

print_header "🚀 UNIQUE JOB PER IMAGE VERIFICATION SCRIPT"
echo -e "${BOLD}This script will verify that the Kyverno policy creates${NC}"
echo -e "${BOLD}exactly ONE job per unique container image${NC}"

# Apply policy if requested
if [ "$APPLY_POLICY" = true ]; then
    print_header "📋 APPLYING CLUSTERPOLICY"
    if [ -f "clusterpolicy-working.yaml" ]; then
        kubectl apply -f clusterpolicy-working.yaml
        print_success "ClusterPolicy applied"
        wait_with_progress 3 "Waiting for policy to be ready"
    else
        print_fail "clusterpolicy-working.yaml not found"
        exit 1
    fi
fi

# Check if policy exists
print_header "1️⃣ CHECKING POLICY STATUS"
if kubectl get clusterpolicy generate-unique-job-per-image-v3 &>/dev/null; then
    print_success "ClusterPolicy 'generate-unique-job-per-image-v3' exists"
    
    # Check if policy is ready
    STATUS=$(kubectl get clusterpolicy generate-unique-job-per-image-v3 -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')
    if [ "$STATUS" = "True" ]; then
        print_success "Policy is Ready"
    else
        print_fail "Policy is not Ready. Status: $STATUS"
        exit 1
    fi
else
    print_fail "ClusterPolicy not found. Run with --apply-policy or apply it manually"
    exit 1
fi

# Clean up any existing test resources
print_info "Cleaning up any existing test resources..."
cleanup

print_header "2️⃣ TEST: MULTIPLE PODS WITH SAME IMAGE"
print_test "Creating 3 pods with nginx:1.21"

# Create 3 pods with the same nginx:1.21 image
kubectl run verify-nginx-1 --image=nginx:1.21 --restart=Never --labels="test-type=unique-job-verification"
kubectl run verify-nginx-2 --image=nginx:1.21 --restart=Never --labels="test-type=unique-job-verification"
kubectl run verify-nginx-3 --image=nginx:1.21 --restart=Never --labels="test-type=unique-job-verification"

wait_with_progress 5 "Waiting for job generation"

# Count jobs for nginx:1.21
NGINX_JOBS=$(kubectl get jobs --no-headers | grep "img-nginx-1-21" | wc -l)

if [ "$NGINX_JOBS" -eq 1 ]; then
    print_success "✅ PASS: Only 1 job created for nginx:1.21 (Expected: 1, Got: $NGINX_JOBS)"
    kubectl get jobs | grep "img-nginx-1-21"
else
    print_fail "❌ FAIL: Expected 1 job for nginx:1.21, but got $NGINX_JOBS"
    kubectl get jobs | grep "img-nginx"
fi

print_header "3️⃣ TEST: DIFFERENT IMAGES CREATE DIFFERENT JOBS"
print_test "Creating pods with different images"

kubectl run verify-redis --image=redis:7.0 --restart=Never --labels="test-type=unique-job-verification"
kubectl run verify-postgres --image=postgres:14 --restart=Never --labels="test-type=unique-job-verification"

wait_with_progress 5 "Waiting for job generation"

# Check for unique jobs
REDIS_JOBS=$(kubectl get jobs --no-headers | grep "img-redis-7-0" | wc -l)
POSTGRES_JOBS=$(kubectl get jobs --no-headers | grep "img-postgres-14" | wc -l)

if [ "$REDIS_JOBS" -eq 1 ]; then
    print_success "✅ PASS: 1 job created for redis:7.0"
else
    print_fail "❌ FAIL: Expected 1 job for redis:7.0, got $REDIS_JOBS"
fi

if [ "$POSTGRES_JOBS" -eq 1 ]; then
    print_success "✅ PASS: 1 job created for postgres:14"
else
    print_fail "❌ FAIL: Expected 1 job for postgres:14, got $POSTGRES_JOBS"
fi

print_header "4️⃣ TEST: ADDING MORE PODS WITH EXISTING IMAGE"
print_test "Creating 2 more nginx:1.21 pods to verify no duplicate jobs"

kubectl run verify-nginx-4 --image=nginx:1.21 --restart=Never --labels="test-type=unique-job-verification"
kubectl run verify-nginx-5 --image=nginx:1.21 --restart=Never --labels="test-type=unique-job-verification"

wait_with_progress 5 "Waiting to check for duplicate jobs"

# Count nginx jobs again
NGINX_JOBS_AFTER=$(kubectl get jobs --no-headers | grep "img-nginx-1-21" | wc -l)

if [ "$NGINX_JOBS_AFTER" -eq 1 ]; then
    print_success "✅ PASS: Still only 1 job for nginx:1.21 (no duplicates created)"
else
    print_fail "❌ FAIL: Duplicate jobs created! Expected 1, got $NGINX_JOBS_AFTER"
fi

print_header "5️⃣ TEST: COMPLEX IMAGE NAMES"
print_test "Testing with registry URLs and tags"

kubectl run verify-complex --image=docker.io/library/nginx:latest --restart=Never --labels="test-type=unique-job-verification"

wait_with_progress 5 "Waiting for job generation"

COMPLEX_JOB=$(kubectl get jobs --no-headers | grep -E "img-docker.*nginx.*latest" | wc -l)

if [ "$COMPLEX_JOB" -eq 1 ]; then
    print_success "✅ PASS: Complex image name handled correctly"
else
    print_fail "❌ FAIL: Complex image name not handled properly"
fi

print_header "📊 FINAL SUMMARY"

# Count total unique jobs
TOTAL_JOBS=$(kubectl get jobs -l generated-by=unique-job-per-image-policy --no-headers | wc -l)
TOTAL_PODS=$(kubectl get pods -l test-type=unique-job-verification --no-headers | wc -l)

echo -e "${BOLD}Test Results:${NC}"
echo -e "├─ Total test pods created: ${CYAN}$TOTAL_PODS${NC}"
echo -e "├─ Total jobs created: ${CYAN}$TOTAL_JOBS${NC}"
echo -e "└─ Expected unique images: ${CYAN}4${NC} (nginx:1.21, redis:7.0, postgres:14, docker.io/library/nginx:latest)"

# Show all generated jobs
print_info "All generated jobs:"
kubectl get jobs -l generated-by=unique-job-per-image-policy -o wide

# Verify job logs
print_header "📝 SAMPLE JOB LOG"
if kubectl get job img-nginx-1-21 &>/dev/null; then
    print_info "Log from img-nginx-1-21:"
    kubectl logs job/img-nginx-1-21 | head -15
fi

# Calculate success rate
EXPECTED_TESTS=6
PASSED_TESTS=0

[ "$NGINX_JOBS" -eq 1 ] && ((PASSED_TESTS++))
[ "$REDIS_JOBS" -eq 1 ] && ((PASSED_TESTS++))
[ "$POSTGRES_JOBS" -eq 1 ] && ((PASSED_TESTS++))
[ "$NGINX_JOBS_AFTER" -eq 1 ] && ((PASSED_TESTS++))
[ "$COMPLEX_JOB" -eq 1 ] && ((PASSED_TESTS++))
[ "$TOTAL_JOBS" -eq 4 ] && ((PASSED_TESTS++))

print_header "🎯 VERIFICATION RESULT"

if [ "$PASSED_TESTS" -eq "$EXPECTED_TESTS" ]; then
    echo -e "${GREEN}${BOLD}╔════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}${BOLD}║     ✅ ALL TESTS PASSED! ($PASSED_TESTS/$EXPECTED_TESTS)            ║${NC}"
    echo -e "${GREEN}${BOLD}║                                            ║${NC}"
    echo -e "${GREEN}${BOLD}║  The policy correctly creates exactly     ║${NC}"
    echo -e "${GREEN}${BOLD}║  ONE job per unique container image!      ║${NC}"
    echo -e "${GREEN}${BOLD}╚════════════════════════════════════════════╝${NC}"
else
    echo -e "${RED}${BOLD}╔════════════════════════════════════════════╗${NC}"
    echo -e "${RED}${BOLD}║     ❌ SOME TESTS FAILED ($PASSED_TESTS/$EXPECTED_TESTS)           ║${NC}"
    echo -e "${RED}${BOLD}║                                            ║${NC}"
    echo -e "${RED}${BOLD}║  Please check the output above for        ║${NC}"
    echo -e "${RED}${BOLD}║  details on which tests failed.           ║${NC}"
    echo -e "${RED}${BOLD}╚════════════════════════════════════════════╝${NC}"
fi

# Cleanup if not skipped
if [ "$SKIP_CLEANUP" = false ]; then
    print_header "🧹 FINAL CLEANUP"
    cleanup
else
    print_info "Skipping cleanup. Use './verify.sh --cleanup' to clean up later"
fi

echo -e "\n${CYAN}Script completed!${NC}\n"

# Exit with appropriate code
if [ "$PASSED_TESTS" -eq "$EXPECTED_TESTS" ]; then
    exit 0
else
    exit 1
fi
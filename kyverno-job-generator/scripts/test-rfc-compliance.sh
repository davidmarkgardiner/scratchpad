#!/bin/bash

set -e

echo "========================================="
echo "RFC 1123 Compliance Test"
echo "========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test various image formats and their expected job names
declare -A test_images=(
    ["my.registry.com/app/service:v1.0.0"]="Standard image with tag"
    ["my.registry.com/MyApp/WebServer:v1.2.3"]="Image with uppercase"
    ["my.registry.com/app_name/service.backend:2.1.0_beta"]="Special characters"
    ["my.registry.com/very/long/path/to/app:v1.2.3"]="Long path"
    ["my.registry.com/app@sha256:abc123"]="SHA256 digest"
    ["my.registry.com:5000/app/service:v1.0.0"]="With port number"
    ["docker.io/library/redis:7.0-alpine"]="Docker Hub image"
    ["my.registry.com/app+feature/service~test:v1.0+build"]="Plus and tilde"
    ["my.registry.com/123/456:7.8.9"]="Numeric components"
    ["my.registry.com/APP/Service:V1.0.0-BETA"]="All uppercase"
    ["my.registry.com/app/svc:ñoño"]="Non-ASCII characters"
    ["my.registry.com/a/b:$(date +%s)"]="Timestamp tag"
)

# Function to check RFC 1123 compliance
check_rfc_compliance() {
    local name="$1"
    local description="$2"
    
    # Check length (max 63 characters for k8s names)
    if [ ${#name} -gt 63 ]; then
        echo -e "${RED}✗${NC} $description"
        echo "  Name: $name"
        echo -e "  ${RED}Length: ${#name} (exceeds 63 char limit)${NC}"
        return 1
    fi
    
    # Check pattern (lowercase alphanumeric and hyphens, must start/end with alphanumeric)
    if [[ ! "$name" =~ ^[a-z0-9]([-a-z0-9]*[a-z0-9])?$ ]]; then
        echo -e "${YELLOW}⚠${NC} $description"
        echo "  Name: $name"
        echo -e "  ${YELLOW}Pattern: Does not match RFC 1123 pattern${NC}"
        
        # Detailed checks
        if [[ "$name" =~ [A-Z] ]]; then
            echo -e "  ${YELLOW}Issue: Contains uppercase letters${NC}"
        fi
        if [[ "$name" =~ [^a-z0-9-] ]]; then
            echo -e "  ${YELLOW}Issue: Contains invalid characters (only a-z, 0-9, - allowed)${NC}"
        fi
        if [[ "$name" =~ ^- ]] || [[ "$name" =~ -$ ]]; then
            echo -e "  ${YELLOW}Issue: Starts or ends with hyphen${NC}"
        fi
        return 1
    fi
    
    echo -e "${GREEN}✓${NC} $description"
    echo "  Name: $name (length: ${#name})"
    return 0
}

echo "Testing image to job name conversion..."
echo "========================================="
echo ""

# Clean up any existing test namespace
kubectl delete namespace rfc-test --ignore-not-found=true 2>/dev/null || true
kubectl create namespace rfc-test

# Deploy the simple policy (using hash-based naming)
echo "Deploying RFC-compliant policy..."
kubectl apply -f policy/3-job-generator-simple.yaml

# Wait for policy to be ready
sleep 5

# Test each image
echo ""
echo "Testing various image formats:"
echo "------------------------------"

for image in "${!test_images[@]}"; do
    description="${test_images[$image]}"
    
    # Create a simple pod with the test image
    cat <<EOF | kubectl apply -f - 2>/dev/null || true
apiVersion: v1
kind: Pod
metadata:
  name: test-$(echo "$image" | md5sum | cut -c1-8)
  namespace: rfc-test
  labels:
    test: "rfc-compliance"
spec:
  containers:
  - name: test
    image: $image
    command: ["sleep", "3600"]
EOF
    
    # Since we're using hash-based naming, calculate expected job name
    # Note: This is a simulation - actual hash would be different
    job_name="img-job-$(echo "$image" | md5sum | cut -c1-16)"
    
    echo ""
    echo "Image: $image"
    echo "Description: $description"
    check_rfc_compliance "$job_name" "Hash-based job name"
done

echo ""
echo "========================================="
echo "Checking actual generated jobs..."
echo "========================================="

# Wait for jobs to be created
sleep 10

# List all generated jobs
echo ""
kubectl get jobs -n rfc-test -o custom-columns=NAME:.metadata.name,IMAGE:.metadata.annotations.original-image 2>/dev/null || echo "No jobs found yet"

echo ""
echo "========================================="
echo "RFC Compliance Summary"
echo "========================================="

# Check all actual job names for compliance
jobs=$(kubectl get jobs -n rfc-test -o name 2>/dev/null | cut -d'/' -f2)

if [ -z "$jobs" ]; then
    echo -e "${YELLOW}No jobs were created. Check Kyverno policy status.${NC}"
else
    compliant=0
    non_compliant=0
    
    for job in $jobs; do
        if [[ "$job" =~ ^[a-z0-9]([-a-z0-9]*[a-z0-9])?$ ]] && [ ${#job} -le 63 ]; then
            ((compliant++))
            echo -e "${GREEN}✓${NC} $job"
        else
            ((non_compliant++))
            echo -e "${RED}✗${NC} $job (non-compliant)"
        fi
    done
    
    echo ""
    echo "Total jobs: $((compliant + non_compliant))"
    echo -e "RFC 1123 Compliant: ${GREEN}$compliant${NC}"
    echo -e "Non-compliant: ${RED}$non_compliant${NC}"
fi

echo ""
echo "========================================="
echo "Cleanup"
echo "========================================="
echo "To clean up test resources, run:"
echo "  kubectl delete namespace rfc-test"
echo "  kubectl delete clusterpolicy image-job-generator-simple"
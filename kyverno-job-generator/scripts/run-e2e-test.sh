#!/bin/bash

set -e

echo "======================================"
echo "Starting End-to-End Test"
echo "======================================"

# Clean up any existing resources first
echo "Step 1: Cleaning up existing resources..."
./scripts/cleanup.sh
echo ""

# Apply RBAC
echo "Step 2: Applying RBAC configuration..."
./scripts/01-apply-rbac.sh
echo ""

# Deploy policy
echo "Step 3: Deploying Kyverno policy..."
./scripts/02-deploy-policy.sh
echo ""

# Wait for policy to be ready
echo "Step 4: Waiting for policy to be ready..."
sleep 10
echo ""

# Deploy test applications
echo "Step 5: Deploying test applications..."
./scripts/03-test-deployment.sh
echo ""

# Verify job creation with image-based naming
echo "Step 6: Verifying job creation with image-based naming..."
echo "Expected jobs based on images:"
echo "  - image-push-job-test-nginx-1.21 (from my.registry.com/test/nginx:1.21)"
echo "  - image-push-job-library-nginx-latest (from docker.io/library/nginx:latest)"
echo "  - image-push-job-custom-app-v2.1.0 (from my.registry.com/custom/app:v2.1.0)"
echo ""

echo "Actual jobs created:"
kubectl get jobs -n default -o custom-columns=NAME:.metadata.name,IMAGE-INFO:.metadata.labels.image-info
echo ""

# Check if jobs were created correctly
echo "Step 7: Validating job names match image-based naming convention..."
jobs_count=$(kubectl get jobs -n default --no-headers 2>/dev/null | wc -l)

if [ "$jobs_count" -gt 0 ]; then
    echo "✓ Jobs were created successfully!"
    echo "Total jobs created: $jobs_count"
    
    # Show job details
    echo ""
    echo "Job details:"
    for job in $(kubectl get jobs -n default -o name); do
        echo "---"
        kubectl get $job -n default -o yaml | grep -E "name:|image-info:|ORIGINAL_IMAGE:|IMAGE_ID:" | head -10
    done
else
    echo "✗ No jobs were created. Check Kyverno logs for issues."
    echo "Kyverno policy status:"
    kubectl get cpol image-job-generator-test -o yaml | grep -A 10 status:
fi

echo ""
echo "======================================"
echo "End-to-End Test Complete"
echo "======================================"
echo ""
echo "To clean up all resources, run: ./scripts/cleanup.sh"
echo "To re-run the test, run: ./scripts/run-e2e-test.sh"
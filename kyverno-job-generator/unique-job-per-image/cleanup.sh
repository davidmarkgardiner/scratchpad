#!/bin/bash

# Kyverno Unique Job Per Image - Cleanup Script
# This script removes all test resources created by the unique job per image policy

set -e

echo "🧹 Starting cleanup of Kyverno unique job per image test resources..."

# Function to check if kubectl command exists
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        echo "❌ Error: kubectl is not installed or not in PATH"
        exit 1
    fi
}

# Function to check if resource exists before deletion
resource_exists() {
    kubectl get "$1" "$2" -n "$3" &> /dev/null 2>&1
}

# Function to safely delete resources
safe_delete() {
    local resource_type=$1
    local resource_name=$2
    local namespace=${3:-""}
    
    if [ -n "$namespace" ]; then
        if resource_exists "$resource_type" "$resource_name" "$namespace"; then
            echo "🗑️  Deleting $resource_type/$resource_name in namespace $namespace..."
            kubectl delete "$resource_type" "$resource_name" -n "$namespace" --ignore-not-found=true
        else
            echo "ℹ️  $resource_type/$resource_name in namespace $namespace not found, skipping..."
        fi
    else
        if kubectl get "$resource_type" "$resource_name" &> /dev/null 2>&1; then
            echo "🗑️  Deleting $resource_type/$resource_name..."
            kubectl delete "$resource_type" "$resource_name" --ignore-not-found=true
        else
            echo "ℹ️  $resource_type/$resource_name not found, skipping..."
        fi
    fi
}

# Main cleanup function
main_cleanup() {
    echo "📋 Cleanup checklist:"
    echo "   1. Test pods in default namespace"
    echo "   2. Test pods in test-namespace"
    echo "   3. Generated jobs in all namespaces"
    echo "   4. Test namespace"
    echo "   5. ClusterPolicy (optional)"
    echo ""

    # 1. Delete test pods in default namespace
    echo "🎯 Step 1: Cleaning up test pods in default namespace..."
    safe_delete "pod" "test-pod-nginx-1" "default"
    safe_delete "pod" "test-pod-nginx-2" "default"
    safe_delete "pod" "test-pod-nginx-3" "default"
    safe_delete "pod" "test-pod-nginx-latest" "default"
    safe_delete "pod" "test-pod-nginx-alpine" "default"
    safe_delete "pod" "test-pod-redis" "default"
    safe_delete "pod" "test-pod-postgres" "default"
    safe_delete "pod" "test-pod-complex-image" "default"
    safe_delete "pod" "test-pod-digest-image" "default"

    # 2. Delete test pods in test-namespace
    echo ""
    echo "🎯 Step 2: Cleaning up test pods in test-namespace..."
    if kubectl get namespace test-namespace &> /dev/null 2>&1; then
        safe_delete "pod" "test-pod-nginx-different-ns" "test-namespace"
    else
        echo "ℹ️  test-namespace not found, skipping pod cleanup in that namespace..."
    fi

    # 3. Delete all generated jobs with the kyverno label
    echo ""
    echo "🎯 Step 3: Cleaning up generated jobs..."
    echo "🔍 Finding jobs with label 'generated-by=kyverno'..."
    
    # Get all jobs with the label across all namespaces
    if kubectl get jobs --all-namespaces -l generated-by=kyverno --no-headers 2>/dev/null | grep -q .; then
        echo "📦 Found generated jobs, deleting..."
        kubectl delete jobs -l generated-by=kyverno --all-namespaces --ignore-not-found=true
        echo "✅ Generated jobs deleted"
    else
        echo "ℹ️  No generated jobs found with label 'generated-by=kyverno'"
    fi

    # Also clean up jobs that start with 'img-' as a backup
    echo "🔍 Finding jobs starting with 'img-' prefix..."
    for namespace in $(kubectl get namespaces -o jsonpath='{.items[*].metadata.name}'); do
        if kubectl get jobs -n "$namespace" --no-headers 2>/dev/null | grep -q "^img-"; then
            echo "📦 Found img-* jobs in namespace $namespace, deleting..."
            kubectl get jobs -n "$namespace" --no-headers 2>/dev/null | awk '/^img-/ {print $1}' | while read job_name; do
                safe_delete "job" "$job_name" "$namespace"
            done
        fi
    done

    # 4. Delete test namespace
    echo ""
    echo "🎯 Step 4: Cleaning up test namespace..."
    if kubectl get namespace test-namespace &> /dev/null 2>&1; then
        echo "🗑️  Deleting test-namespace..."
        kubectl delete namespace test-namespace --ignore-not-found=true
        echo "⏳ Waiting for namespace deletion to complete..."
        kubectl wait --for=delete namespace/test-namespace --timeout=60s 2>/dev/null || true
        echo "✅ test-namespace deleted"
    else
        echo "ℹ️  test-namespace not found, skipping..."
    fi

    # 5. Optional: Ask about ClusterPolicy deletion
    echo ""
    echo "🎯 Step 5: ClusterPolicy cleanup (optional)..."
    if kubectl get clusterpolicy generate-unique-job-per-image &> /dev/null 2>&1; then
        echo "❓ ClusterPolicy 'generate-unique-job-per-image' found."
        read -p "   Do you want to delete the ClusterPolicy as well? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "🗑️  Deleting ClusterPolicy..."
            kubectl delete clusterpolicy generate-unique-job-per-image --ignore-not-found=true
            echo "✅ ClusterPolicy deleted"
        else
            echo "ℹ️  Keeping ClusterPolicy as requested"
        fi
    else
        echo "ℹ️  ClusterPolicy 'generate-unique-job-per-image' not found"
    fi
}

# Function to verify cleanup
verify_cleanup() {
    echo ""
    echo "🔍 Verifying cleanup..."
    
    local cleanup_success=true
    
    # Check for remaining test pods
    echo "📋 Checking for remaining test pods..."
    if kubectl get pods --all-namespaces --no-headers 2>/dev/null | grep -E "(test-pod-nginx|test-pod-redis|test-pod-postgres|test-pod-complex|test-pod-digest)"; then
        echo "⚠️  Some test pods still exist"
        cleanup_success=false
    else
        echo "✅ No test pods found"
    fi
    
    # Check for remaining generated jobs
    echo "📋 Checking for remaining generated jobs..."
    if kubectl get jobs --all-namespaces -l generated-by=kyverno --no-headers 2>/dev/null | grep -q .; then
        echo "⚠️  Some generated jobs still exist"
        cleanup_success=false
    elif kubectl get jobs --all-namespaces --no-headers 2>/dev/null | grep -q "^img-"; then
        echo "⚠️  Some img-* jobs still exist"
        cleanup_success=false
    else
        echo "✅ No generated jobs found"
    fi
    
    # Check for test namespace
    echo "📋 Checking for test namespace..."
    if kubectl get namespace test-namespace &> /dev/null 2>&1; then
        echo "⚠️  test-namespace still exists (may be terminating)"
    else
        echo "✅ test-namespace not found"
    fi
    
    if [ "$cleanup_success" = true ]; then
        echo ""
        echo "🎉 Cleanup completed successfully!"
        echo "   All test resources have been removed."
    else
        echo ""
        echo "⚠️  Cleanup completed with some items remaining."
        echo "   Some resources may still be terminating."
        echo "   Run 'kubectl get all --all-namespaces | grep -E \"(test-pod|img-)\"' to check manually."
    fi
}

# Function to show help
show_help() {
    cat << EOF
Kyverno Unique Job Per Image - Cleanup Script

Usage: $0 [OPTIONS]

This script cleans up all test resources created by the unique job per image policy.

Options:
    -h, --help          Show this help message
    -f, --force         Skip confirmation prompts (auto-delete ClusterPolicy)
    -p, --preserve      Preserve the ClusterPolicy (don't ask about deletion)
    -v, --verify-only   Only verify current state without deleting anything

Resources cleaned up:
    • Test pods in default namespace
    • Test pods in test-namespace
    • Generated jobs (labeled with generated-by=kyverno)
    • Jobs starting with 'img-' prefix
    • test-namespace
    • ClusterPolicy (optional, with confirmation)

Examples:
    $0                  # Interactive cleanup with confirmations
    $0 --force          # Force cleanup including ClusterPolicy
    $0 --preserve       # Cleanup but preserve ClusterPolicy
    $0 --verify-only    # Just check what would be deleted

EOF
}

# Parse command line arguments
FORCE_DELETE=false
PRESERVE_POLICY=false
VERIFY_ONLY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -f|--force)
            FORCE_DELETE=true
            shift
            ;;
        -p|--preserve)
            PRESERVE_POLICY=true
            shift
            ;;
        -v|--verify-only)
            VERIFY_ONLY=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Main execution
main() {
    echo "🚀 Kyverno Unique Job Per Image - Cleanup Script"
    echo "=================================================="
    
    # Check prerequisites
    check_kubectl
    
    if [ "$VERIFY_ONLY" = true ]; then
        echo "🔍 Verification mode: Checking current state without deleting..."
        verify_cleanup
        exit 0
    fi
    
    # Show current state
    echo ""
    echo "📊 Current state before cleanup:"
    echo "   Test pods: $(kubectl get pods --all-namespaces --no-headers 2>/dev/null | grep -cE "(test-pod-nginx|test-pod-redis|test-pod-postgres|test-pod-complex|test-pod-digest)" || echo "0")"
    echo "   Generated jobs: $(kubectl get jobs --all-namespaces -l generated-by=kyverno --no-headers 2>/dev/null | wc -l || echo "0")"
    echo "   test-namespace exists: $(kubectl get namespace test-namespace &> /dev/null && echo "Yes" || echo "No")"
    echo "   ClusterPolicy exists: $(kubectl get clusterpolicy generate-unique-job-per-image &> /dev/null && echo "Yes" || echo "No")"
    
    # Confirmation prompt
    echo ""
    read -p "🚨 Are you sure you want to proceed with cleanup? This will delete test resources. (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "❌ Cleanup cancelled by user"
        exit 0
    fi
    
    # Execute cleanup
    main_cleanup
    
    # Wait a moment for resources to terminate
    echo ""
    echo "⏳ Waiting 5 seconds for resource termination..."
    sleep 5
    
    # Verify cleanup
    verify_cleanup
    
    echo ""
    echo "📝 Cleanup Summary:"
    echo "   ✓ Test pods removed"
    echo "   ✓ Generated jobs removed"
    echo "   ✓ test-namespace removed"
    echo "   ✓ Verification completed"
    
    if [ "$PRESERVE_POLICY" = true ]; then
        echo "   ℹ️  ClusterPolicy preserved as requested"
    fi
    
    echo ""
    echo "🏁 Cleanup script completed!"
}

# Handle script interruption
trap 'echo -e "\n🛑 Script interrupted by user"; exit 1' INT

# Execute main function
main "$@"
#!/bin/bash

# ============================================================================
# SECTION 1: CONFIGURATION AND SETUP
# ============================================================================
# Test this section first to ensure your environment variables are correct

# Configuration
CLUSTER_NAME_PREFIX="your-cluster-prefix"  # e.g., "aks-cluster-"
RESOURCE_GROUP="your-resource-group"       # Resource group containing the clusters
SUBSCRIPTION_ID="your-subscription-id"     # Optional: specify subscription
DRY_RUN=true                               # Set to false to actually delete federations

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to log messages
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_debug() {
    echo -e "${BLUE}[DEBUG]${NC} $1"
}

# Test Section 1
test_configuration() {
    echo "=== Testing Configuration ==="
    log_info "Cluster prefix: $CLUSTER_NAME_PREFIX"
    log_info "Resource group: $RESOURCE_GROUP"
    log_info "Subscription ID: $SUBSCRIPTION_ID"
    log_info "Dry run mode: $DRY_RUN"
    
    # Test Azure CLI is installed
    if ! command -v az &> /dev/null; then
        log_error "Azure CLI is not installed"
        return 1
    fi
    
    # Test jq is installed (needed for JSON parsing)
    if ! command -v jq &> /dev/null; then
        log_error "jq is not installed. Install with: sudo apt-get install jq"
        return 1
    fi
    
    # Test Azure login
    if ! az account show &> /dev/null; then
        log_error "Not logged into Azure. Run: az login"
        return 1
    fi
    
    log_info "All prerequisites met!"
    return 0
}

# ============================================================================
# SECTION 2: CLUSTER STATUS CHECKING
# ============================================================================
# Test this to ensure you can query cluster status correctly

# Function to list all clusters matching the prefix
list_matching_clusters() {
    log_info "Searching for clusters with prefix: $CLUSTER_NAME_PREFIX"
    
    clusters=$(az aks list \
        --resource-group "$RESOURCE_GROUP" \
        --query "[?starts_with(name, '$CLUSTER_NAME_PREFIX')].{name:name, powerState:powerState.code}" \
        --output json 2>/dev/null)
    
    if [ $? -ne 0 ]; then
        log_error "Failed to list clusters in resource group: $RESOURCE_GROUP"
        return 1
    fi
    
    echo "$clusters"
    return 0
}

# Function to check if a specific cluster is running
check_cluster_status() {
    local cluster_name=$1
    local resource_group=$2
    
    log_debug "Checking status of cluster: $cluster_name"
    
    # Get cluster power state
    power_state=$(az aks show \
        --name "$cluster_name" \
        --resource-group "$resource_group" \
        --query "powerState.code" \
        --output tsv 2>/dev/null)
    
    if [ $? -ne 0 ]; then
        log_error "Failed to get status for cluster: $cluster_name"
        return 2
    fi
    
    log_debug "Cluster $cluster_name status: $power_state"
    
    if [ "$power_state" == "Running" ]; then
        return 0  # Cluster is running
    else
        return 1  # Cluster is stopped
    fi
}

# Test Section 2
test_cluster_operations() {
    echo -e "\n=== Testing Cluster Operations ==="
    
    # List all matching clusters
    clusters=$(list_matching_clusters)
    
    if [ -z "$clusters" ] || [ "$clusters" == "[]" ]; then
        log_warn "No clusters found with prefix: $CLUSTER_NAME_PREFIX"
        return 1
    fi
    
    log_info "Found clusters:"
    echo "$clusters" | jq -r '.[] | "  - \(.name): \(.powerState)"'
    
    # Test checking individual cluster status
    first_cluster=$(echo "$clusters" | jq -r '.[0].name')
    if [ ! -z "$first_cluster" ] && [ "$first_cluster" != "null" ]; then
        log_info "Testing status check for: $first_cluster"
        check_cluster_status "$first_cluster" "$RESOURCE_GROUP"
        if [ $? -eq 0 ]; then
            log_info "✓ Cluster $first_cluster is running"
        else
            log_info "✓ Cluster $first_cluster is stopped"
        fi
    fi
    
    return 0
}

# ============================================================================
# SECTION 3: UAMI LISTING AND INSPECTION
# ============================================================================
# Test this to ensure you can list and inspect UAMIs

# Function to list all UAMIs
list_all_uamis() {
    log_info "Fetching all User-Assigned Managed Identities..."
    
    uamis=$(az identity list \
        --query "[].{name:name, resourceGroup:resourceGroup, id:id}" \
        --output json)
    
    if [ $? -ne 0 ]; then
        log_error "Failed to list UAMIs"
        return 1
    fi
    
    echo "$uamis"
    return 0
}

# Test Section 3
test_uami_listing() {
    echo -e "\n=== Testing UAMI Listing ==="
    
    uamis=$(list_all_uamis)
    
    if [ -z "$uamis" ] || [ "$uamis" == "[]" ]; then
        log_warn "No UAMIs found in the subscription"
        return 1
    fi
    
    uami_count=$(echo "$uamis" | jq '. | length')
    log_info "Found $uami_count UAMIs in the subscription"
    
    # Show first few UAMIs
    log_info "First few UAMIs:"
    echo "$uamis" | jq -r '.[:3] | .[] | "  - \(.name) (RG: \(.resourceGroup))"'
    
    return 0
}

# ============================================================================
# SECTION 4: FEDERATED CREDENTIAL OPERATIONS
# ============================================================================
# Test this to ensure you can list and inspect federated credentials

# Function to get federated credentials for a UAMI
get_federated_credentials() {
    local uami_name=$1
    local uami_rg=$2
    
    log_debug "Getting federated credentials for UAMI: $uami_name"
    
    fed_creds=$(az identity federated-credential list \
        --identity-name "$uami_name" \
        --resource-group "$uami_rg" \
        --query "[].{name:name, issuer:issuer, subject:subject, audiences:audiences[0]}" \
        --output json 2>/dev/null)
    
    if [ $? -ne 0 ]; then
        log_debug "No federated credentials or error for UAMI: $uami_name"
        echo "[]"
        return 1
    fi
    
    echo "$fed_creds"
    return 0
}

# Test Section 4
test_federated_credentials() {
    echo -e "\n=== Testing Federated Credential Operations ==="
    
    # Get first UAMI to test with
    uamis=$(list_all_uamis)
    
    if [ -z "$uamis" ] || [ "$uamis" == "[]" ]; then
        log_warn "No UAMIs to test with"
        return 1
    fi
    
    # Test with first UAMI that has federated credentials
    echo "$uamis" | jq -c '.[]' | while read uami; do
        uami_name=$(echo "$uami" | jq -r '.name')
        uami_rg=$(echo "$uami" | jq -r '.resourceGroup')
        
        fed_creds=$(get_federated_credentials "$uami_name" "$uami_rg")
        
        if [ ! -z "$fed_creds" ] && [ "$fed_creds" != "[]" ]; then
            log_info "Found federated credentials for UAMI: $uami_name"
            echo "$fed_creds" | jq -r '.[] | "  - Credential: \(.name)"'
            echo "$fed_creds" | jq -r '.[] | "    Issuer: \(.issuer)"'
            echo "$fed_creds" | jq -r '.[] | "    Subject: \(.subject)"'
            return 0
        fi
    done
    
    log_warn "No UAMIs with federated credentials found"
    return 0
}

# ============================================================================
# SECTION 5: FEDERATION ANALYSIS (DRY RUN)
# ============================================================================
# This section analyzes which federations would be deleted without making changes

# Function to analyze federations for deletion
analyze_federations() {
    log_info "Analyzing federations for potential deletion..."
    
    local delete_count=0
    local keep_count=0
    local error_count=0
    
    # Get all UAMIs
    uamis=$(list_all_uamis)
    
    if [ -z "$uamis" ] || [ "$uamis" == "[]" ]; then
        log_warn "No UAMIs found"
        return 1
    fi
    
    # Process each UAMI
    echo "$uamis" | jq -c '.[]' | while read uami; do
        uami_name=$(echo "$uami" | jq -r '.name')
        uami_rg=$(echo "$uami" | jq -r '.resourceGroup')
        
        # Get federated credentials
        fed_creds=$(get_federated_credentials "$uami_name" "$uami_rg")
        
        if [ -z "$fed_creds" ] || [ "$fed_creds" == "[]" ]; then
            continue
        fi
        
        # Check each credential
        echo "$fed_creds" | jq -c '.[]' | while read cred; do
            cred_name=$(echo "$cred" | jq -r '.name')
            issuer=$(echo "$cred" | jq -r '.issuer')
            subject=$(echo "$cred" | jq -r '.subject')
            
            # Check if related to our clusters
            if [[ "$issuer" == *"$CLUSTER_NAME_PREFIX"* ]] || [[ "$subject" == *"$CLUSTER_NAME_PREFIX"* ]]; then
                
                # Extract cluster name
                cluster_name=""
                if [[ "$issuer" =~ ${CLUSTER_NAME_PREFIX}[0-9]+ ]]; then
                    cluster_name=$(echo "$issuer" | grep -oP "${CLUSTER_NAME_PREFIX}[0-9]+")
                elif [[ "$subject" =~ ${CLUSTER_NAME_PREFIX}[0-9]+ ]]; then
                    cluster_name=$(echo "$subject" | grep -oP "${CLUSTER_NAME_PREFIX}[0-9]+")
                fi
                
                if [ ! -z "$cluster_name" ]; then
                    # Check cluster status
                    check_cluster_status "$cluster_name" "$RESOURCE_GROUP"
                    status=$?
                    
                    if [ $status -eq 1 ]; then
                        log_warn "[WOULD DELETE] Federation: $cred_name (UAMI: $uami_name, Cluster: $cluster_name is STOPPED)"
                        ((delete_count++))
                    elif [ $status -eq 0 ]; then
                        log_info "[WOULD KEEP] Federation: $cred_name (UAMI: $uami_name, Cluster: $cluster_name is RUNNING)"
                        ((keep_count++))
                    else
                        log_error "[ERROR] Cannot check cluster $cluster_name for federation: $cred_name"
                        ((error_count++))
                    fi
                fi
            fi
        done
    done
    
    echo -e "\n=== Analysis Summary ==="
    log_info "Federations to delete: $delete_count"
    log_info "Federations to keep: $keep_count"
    log_error "Errors: $error_count"
}

# ============================================================================
# SECTION 6: DELETE FEDERATION (ACTUAL DELETION)
# ============================================================================
# This section performs actual deletion when DRY_RUN=false

# Function to delete federated credential
delete_federated_credential() {
    local uami_name=$1
    local uami_rg=$2
    local credential_name=$3
    
    if [ "$DRY_RUN" == "true" ]; then
        log_warn "[DRY RUN] Would delete federated credential: $credential_name from UAMI: $uami_name"
        return 0
    fi
    
    log_warn "Deleting federated credential: $credential_name from UAMI: $uami_name"
    
    az identity federated-credential delete \
        --identity-name "$uami_name" \
        --resource-group "$uami_rg" \
        --name "$credential_name" \
        --yes \
        2>/dev/null
    
    if [ $? -eq 0 ]; then
        log_info "Successfully deleted federated credential: $credential_name"
        return 0
    else
        log_error "Failed to delete federated credential: $credential_name"
        return 1
    fi
}

# ============================================================================
# MAIN EXECUTION FUNCTIONS
# ============================================================================

# Run all tests
run_all_tests() {
    echo "=========================================="
    echo "Running All Tests (Read-Only)"
    echo "=========================================="
    
    test_configuration || return 1
    test_cluster_operations
    test_uami_listing
    test_federated_credentials
    
    echo -e "\n=========================================="
    echo "Dry Run Analysis"
    echo "=========================================="
    analyze_federations
}

# Main cleanup function
main_cleanup() {
    if [ "$DRY_RUN" == "true" ]; then
        log_info "Running in DRY RUN mode - no changes will be made"
    else
        log_warn "Running in LIVE mode - federations will be deleted!"
        read -p "Are you sure you want to continue? (yes/no): " confirm
        if [ "$confirm" != "yes" ]; then
            log_info "Aborted by user"
            exit 0
        fi
    fi
    
    # Main cleanup logic here (similar to analyze_federations but calls delete_federated_credential)
    log_info "Starting cleanup process..."
    # ... (implementation similar to Section 5 but with actual deletion)
}

# ============================================================================
# SCRIPT ENTRY POINT
# ============================================================================

# Parse command line arguments
case "$1" in
    test-config)
        test_configuration
        ;;
    test-clusters)
        test_cluster_operations
        ;;
    test-uamis)
        test_uami_listing
        ;;
    test-credentials)
        test_federated_credentials
        ;;
    analyze)
        analyze_federations
        ;;
    test-all)
        run_all_tests
        ;;
    cleanup)
        main_cleanup
        ;;
    *)
        echo "Usage: $0 {test-config|test-clusters|test-uamis|test-credentials|analyze|test-all|cleanup}"
        echo ""
        echo "Test sections individually:"
        echo "  test-config      - Test configuration and prerequisites"
        echo "  test-clusters    - Test cluster listing and status checking"
        echo "  test-uamis       - Test UAMI listing"
        echo "  test-credentials - Test federated credential operations"
        echo "  analyze          - Analyze what would be deleted (dry run)"
        echo "  test-all         - Run all tests and analysis"
        echo "  cleanup          - Run actual cleanup (respects DRY_RUN variable)"
        exit 1
        ;;
esac
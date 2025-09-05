#!/bin/bash

# ============================================================================
# SECTION 1: CONFIGURATION AND SETUP
# ============================================================================
# Test this section first to ensure your environment variables are correct

# Configuration
CLUSTER_NAME_PREFIX="your-cluster-prefix"  # e.g., "aks-cluster-"
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
    
    # Set subscription if specified
    if [ ! -z "$SUBSCRIPTION_ID" ]; then
        log_info "Setting subscription to: $SUBSCRIPTION_ID"
        az account set --subscription "$SUBSCRIPTION_ID"
    fi
    
    # Show current subscription
    current_sub=$(az account show --query "{name:name, id:id}" -o json)
    log_info "Current subscription: $(echo $current_sub | jq -r '.name') ($(echo $current_sub | jq -r '.id'))"
    
    log_info "All prerequisites met!"
    return 0
}

# ============================================================================
# SECTION 2: CLUSTER STATUS CHECKING (MULTI-RESOURCE GROUP)
# ============================================================================
# Test this to ensure you can query cluster status across all resource groups

# Function to list all clusters matching the prefix across all resource groups
list_all_matching_clusters() {
    log_info "Searching for clusters with prefix: $CLUSTER_NAME_PREFIX across all resource groups..."
    
    # Get all clusters in the subscription
    clusters=$(az aks list \
        --query "[?starts_with(name, '$CLUSTER_NAME_PREFIX')].{name:name, resourceGroup:resourceGroup, powerState:powerState.code, location:location}" \
        --output json 2>/dev/null)
    
    if [ $? -ne 0 ]; then
        log_error "Failed to list clusters in subscription"
        return 1
    fi
    
    echo "$clusters"
    return 0
}

# Function to check if a specific cluster is running (with resource group discovery)
check_cluster_status() {
    local cluster_name=$1
    local resource_group=$2
    
    # If resource group not provided, find it
    if [ -z "$resource_group" ] || [ "$resource_group" == "null" ]; then
        log_debug "Resource group not provided, searching for cluster: $cluster_name"
        
        # Find the cluster's resource group
        resource_group=$(az aks list \
            --query "[?name=='$cluster_name'].resourceGroup | [0]" \
            --output tsv 2>/dev/null)
        
        if [ -z "$resource_group" ]; then
            log_error "Cluster not found: $cluster_name"
            return 2
        fi
        
        log_debug "Found cluster $cluster_name in resource group: $resource_group"
    fi
    
    log_debug "Checking status of cluster: $cluster_name in RG: $resource_group"
    
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

# Global associative array to cache cluster resource groups
declare -A CLUSTER_RG_CACHE

# Function to build cluster resource group cache
build_cluster_cache() {
    log_info "Building cluster resource group cache..."
    
    local clusters=$(list_all_matching_clusters)
    
    if [ -z "$clusters" ] || [ "$clusters" == "[]" ]; then
        log_warn "No clusters found with prefix: $CLUSTER_NAME_PREFIX"
        return 1
    fi
    
    # Clear cache
    CLUSTER_RG_CACHE=()
    
    # Populate cache
    echo "$clusters" | jq -c '.[]' | while IFS= read -r cluster; do
        name=$(echo "$cluster" | jq -r '.name')
        rg=$(echo "$cluster" | jq -r '.resourceGroup')
        CLUSTER_RG_CACHE["$name"]="$rg"
    done
    
    log_info "Cached $(echo "$clusters" | jq '. | length') clusters"
    return 0
}

# Function to get cluster resource group from cache or API
get_cluster_resource_group() {
    local cluster_name=$1
    
    # Check cache first
    if [ ! -z "${CLUSTER_RG_CACHE[$cluster_name]}" ]; then
        echo "${CLUSTER_RG_CACHE[$cluster_name]}"
        return 0
    fi
    
    # Not in cache, query API
    resource_group=$(az aks list \
        --query "[?name=='$cluster_name'].resourceGroup | [0]" \
        --output tsv 2>/dev/null)
    
    if [ ! -z "$resource_group" ]; then
        CLUSTER_RG_CACHE["$cluster_name"]="$resource_group"
        echo "$resource_group"
        return 0
    fi
    
    return 1
}

# Test Section 2
test_cluster_operations() {
    echo -e "\n=== Testing Cluster Operations (Multi-Resource Group) ==="
    
    # List all matching clusters across all resource groups
    clusters=$(list_all_matching_clusters)
    
    if [ -z "$clusters" ] || [ "$clusters" == "[]" ]; then
        log_warn "No clusters found with prefix: $CLUSTER_NAME_PREFIX"
        return 1
    fi
    
    cluster_count=$(echo "$clusters" | jq '. | length')
    log_info "Found $cluster_count clusters across subscription"
    
    # Group clusters by resource group
    log_info "Clusters by resource group:"
    echo "$clusters" | jq -r 'group_by(.resourceGroup) | .[] | "  Resource Group: \(.[0].resourceGroup)\n\(map("    - \(.name): \(.powerState // "Unknown")") | join("\n"))"'
    
    # Test checking individual cluster status
    first_cluster=$(echo "$clusters" | jq -r '.[0].name')
    first_cluster_rg=$(echo "$clusters" | jq -r '.[0].resourceGroup')
    
    if [ ! -z "$first_cluster" ] && [ "$first_cluster" != "null" ]; then
        log_info "Testing status check for: $first_cluster in RG: $first_cluster_rg"
        check_cluster_status "$first_cluster" "$first_cluster_rg"
        if [ $? -eq 0 ]; then
            log_info "✓ Cluster $first_cluster is running"
        else
            log_info "✓ Cluster $first_cluster is stopped"
        fi
    fi
    
    # Test cache building
    build_cluster_cache
    
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
        --query "[].{name:name, resourceGroup:resourceGroup, id:id, location:location}" \
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
    
    # Group UAMIs by resource group
    log_info "UAMIs by resource group:"
    echo "$uamis" | jq -r 'group_by(.resourceGroup) | .[] | "  Resource Group: \(.[0].resourceGroup) - Count: \(. | length)"'
    
    # Show first few UAMIs
    log_info "First few UAMIs:"
    echo "$uamis" | jq -r '.[:3] | .[] | "  - \(.name) (RG: \(.resourceGroup), Location: \(.location))"'
    
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
    
    log_debug "Getting federated credentials for UAMI: $uami_name in RG: $uami_rg"
    
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
    
    found_creds=false
    
    # Test with first few UAMIs that have federated credentials
    echo "$uamis" | jq -c '.[:10]' | jq -c '.[]' | while read uami; do
        uami_name=$(echo "$uami" | jq -r '.name')
        uami_rg=$(echo "$uami" | jq -r '.resourceGroup')
        
        fed_creds=$(get_federated_credentials "$uami_name" "$uami_rg")
        
        if [ ! -z "$fed_creds" ] && [ "$fed_creds" != "[]" ]; then
            found_creds=true
            log_info "Found federated credentials for UAMI: $uami_name (RG: $uami_rg)"
            echo "$fed_creds" | jq -r '.[] | "  - Credential: \(.name)"'
            echo "$fed_creds" | jq -r '.[] | "    Issuer: \(.issuer)"' | head -1
            echo "$fed_creds" | jq -r '.[] | "    Subject: \(.subject)"' | head -1
            break
        fi
    done
    
    if [ "$found_creds" = false ]; then
        log_warn "No UAMIs with federated credentials found in first 10 UAMIs"
    fi
    
    return 0
}

# ============================================================================
# SECTION 5: FEDERATION ANALYSIS (DRY RUN)
# ============================================================================
# This section analyzes which federations would be deleted without making changes

# Function to analyze federations for deletion
analyze_federations() {
    log_info "Analyzing federations for potential deletion..."
    log_info "Looking for clusters with prefix: $CLUSTER_NAME_PREFIX"
    
    local delete_count=0
    local keep_count=0
    local error_count=0
    local total_creds_checked=0
    
    # Build cluster cache first
    build_cluster_cache
    
    # Get all UAMIs
    uamis=$(list_all_uamis)
    
    if [ -z "$uamis" ] || [ "$uamis" == "[]" ]; then
        log_warn "No UAMIs found"
        return 1
    fi
    
    # Create temporary files for counting
    delete_file=$(mktemp)
    keep_file=$(mktemp)
    error_file=$(mktemp)
    checked_file=$(mktemp)
    
    echo "0" > "$delete_file"
    echo "0" > "$keep_file"
    echo "0" > "$error_file"
    echo "0" > "$checked_file"
    
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
                
                # Increment checked counter
                checked_count=$(cat "$checked_file")
                echo $((checked_count + 1)) > "$checked_file"
                
                # Extract cluster name
                cluster_name=""
                if [[ "$issuer" =~ ${CLUSTER_NAME_PREFIX}[0-9]+ ]]; then
                    cluster_name=$(echo "$issuer" | grep -oE "${CLUSTER_NAME_PREFIX}[0-9]+")
                elif [[ "$subject" =~ ${CLUSTER_NAME_PREFIX}[0-9]+ ]]; then
                    cluster_name=$(echo "$subject" | grep -oE "${CLUSTER_NAME_PREFIX}[0-9]+")
                fi
                
                if [ ! -z "$cluster_name" ]; then
                    # Get cluster resource group
                    cluster_rg=$(get_cluster_resource_group "$cluster_name")
                    
                    if [ -z "$cluster_rg" ]; then
                        log_error "[ERROR] Cannot find cluster $cluster_name for federation: $cred_name"
                        error_count=$(cat "$error_file")
                        echo $((error_count + 1)) > "$error_file"
                        continue
                    fi
                    
                    # Check cluster status
                    check_cluster_status "$cluster_name" "$cluster_rg"
                    status=$?
                    
                    if [ $status -eq 1 ]; then
                        log_warn "[WOULD DELETE] Federation: $cred_name"
                        log_warn "  UAMI: $uami_name (RG: $uami_rg)"
                        log_warn "  Cluster: $cluster_name (RG: $cluster_rg) - STOPPED"
                        delete_count=$(cat "$delete_file")
                        echo $((delete_count + 1)) > "$delete_file"
                    elif [ $status -eq 0 ]; then
                        log_info "[WOULD KEEP] Federation: $cred_name"
                        log_info "  UAMI: $uami_name (RG: $uami_rg)"
                        log_info "  Cluster: $cluster_name (RG: $cluster_rg) - RUNNING"
                        keep_count=$(cat "$keep_file")
                        echo $((keep_count + 1)) > "$keep_file"
                    else
                        log_error "[ERROR] Cannot check cluster $cluster_name for federation: $cred_name"
                        error_count=$(cat "$error_file")
                        echo $((error_count + 1)) > "$error_file"
                    fi
                else
                    log_warn "Could not extract cluster name from federation: $cred_name"
                fi
            fi
        done
    done
    
    # Read final counts
    delete_count=$(cat "$delete_file")
    keep_count=$(cat "$keep_file")
    error_count=$(cat "$error_file")
    total_creds_checked=$(cat "$checked_file")
    
    # Clean up temp files
    rm -f "$delete_file" "$keep_file" "$error_file" "$checked_file"
    
    echo -e "\n=== Analysis Summary ==="
    log_info "Total federations checked: $total_creds_checked"
    log_warn "Federations to delete: $delete_count"
    log_info "Federations to keep: $keep_count"
    if [ $error_count -gt 0 ]; then
        log_error "Errors: $error_count"
    fi
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
    
    log_info "Starting cleanup process..."
    
    # Build cluster cache first
    build_cluster_cache
    
    # Get all UAMIs
    uamis=$(list_all_uamis)
    
    if [ -z "$uamis" ] || [ "$uamis" == "[]" ]; then
        log_warn "No UAMIs found"
        return 1
    fi
    
    local delete_count=0
    local skip_count=0
    local error_count=0
    
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
                    cluster_name=$(echo "$issuer" | grep -oE "${CLUSTER_NAME_PREFIX}[0-9]+")
                elif [[ "$subject" =~ ${CLUSTER_NAME_PREFIX}[0-9]+ ]]; then
                    cluster_name=$(echo "$subject" | grep -oE "${CLUSTER_NAME_PREFIX}[0-9]+")
                fi
                
                if [ ! -z "$cluster_name" ]; then
                    # Get cluster resource group
                    cluster_rg=$(get_cluster_resource_group "$cluster_name")
                    
                    if [ -z "$cluster_rg" ]; then
                        log_error "Cannot find cluster $cluster_name"
                        ((error_count++))
                        continue
                    fi
                    
                    # Check cluster status
                    check_cluster_status "$cluster_name" "$cluster_rg"
                    status=$?
                    
                    if [ $status -eq 1 ]; then
                        # Cluster is stopped, delete the federation
                        delete_federated_credential "$uami_name" "$uami_rg" "$cred_name"
                        if [ $? -eq 0 ]; then
                            ((delete_count++))
                        else
                            ((error_count++))
                        fi
                    elif [ $status -eq 0 ]; then
                        log_info "Skipping federation $cred_name - cluster $cluster_name is running"
                        ((skip_count++))
                    else
                        log_error "Cannot determine status of cluster $cluster_name"
                        ((error_count++))
                    fi
                fi
            fi
        done
    done
    
    echo -e "\n=== Cleanup Summary ==="
    log_info "Federations deleted: $delete_count"
    log_info "Federations skipped: $skip_count"
    if [ $error_count -gt 0 ]; then
        log_error "Errors: $error_count"
    fi
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
        echo ""
        echo "Note: Clusters can be in different resource groups within the same subscription"
        exit 1
        ;;
esac
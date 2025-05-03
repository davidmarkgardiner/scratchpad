#!/bin/bash

# Set strict error handling
set -e

# Set source and destination registries
SOURCE_REGISTRY="docker.io"
DESTINATION_REGISTRY="mytestacrregistry.azurecr.io"

# Colorized output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function for logging
log() {
  local level=$1
  local message=$2
  
  case $level in
    "INFO")
      echo -e "${BLUE}[INFO]${NC} $message"
      ;;
    "SUCCESS")
      echo -e "${GREEN}[SUCCESS]${NC} $message"
      ;;
    "WARNING")
      echo -e "${YELLOW}[WARNING]${NC} $message"
      ;;
    "ERROR")
      echo -e "${RED}[ERROR]${NC} $message"
      ;;
    *)
      echo "$message"
      ;;
  esac
}

# Check for kubectl
if ! command -v kubectl &> /dev/null; then
  if [ -f "/Users/davidgardiner/.rd/bin/kubectl" ]; then
    kubectl="/Users/davidgardiner/.rd/bin/kubectl"
    log "INFO" "Using kubectl at ${kubectl}"
  else
    log "ERROR" "kubectl not found in PATH or common locations"
    exit 1
  fi
else
  kubectl="kubectl"
fi

# Function to check if cluster is accessible
check_cluster() {
  log "INFO" "Checking Kubernetes cluster access..."
  if ! $kubectl get nodes &> /dev/null; then
    log "ERROR" "Cannot access Kubernetes cluster. Please check your configuration."
    exit 1
  fi
  log "SUCCESS" "Kubernetes cluster is accessible."
}

# Login to destination registry - commented out for testing
log "INFO" "Logging in to destination registry would happen here..."
# oras login ${DESTINATION_REGISTRY} -u 00000000-0000-0000-0000-000000000000 -p $(cat /token/acr-token)

# Get images from all Kubernetes resources
log "INFO" "Collecting images from all Kubernetes resources..."

# Get images from various resource types
DEPLOYMENT_IMAGES=$($kubectl get deployments --all-namespaces -o jsonpath="{.items[*].spec.template.spec.containers[*].image}" 2>/dev/null || echo "")
STATEFULSET_IMAGES=$($kubectl get statefulsets --all-namespaces -o jsonpath="{.items[*].spec.template.spec.containers[*].image}" 2>/dev/null || echo "")
DAEMONSET_IMAGES=$($kubectl get daemonsets --all-namespaces -o jsonpath="{.items[*].spec.template.spec.containers[*].image}" 2>/dev/null || echo "")
JOB_IMAGES=$($kubectl get jobs --all-namespaces -o jsonpath="{.items[*].spec.template.spec.containers[*].image}" 2>/dev/null || echo "")
CRONJOB_IMAGES=$($kubectl get cronjobs --all-namespaces -o jsonpath="{.items[*].spec.jobTemplate.spec.template.spec.containers[*].image}" 2>/dev/null || echo "")
REPLICASET_IMAGES=$($kubectl get replicasets --all-namespaces -o jsonpath="{.items[*].spec.template.spec.containers[*].image}" 2>/dev/null || echo "")
POD_IMAGES=$($kubectl get pods --all-namespaces -o jsonpath="{.items[*].spec.containers[*].image}" 2>/dev/null || echo "")

# Combine all images, remove duplicates, and sort
ALL_IMAGES=$(echo "$DEPLOYMENT_IMAGES $STATEFULSET_IMAGES $DAEMONSET_IMAGES $JOB_IMAGES $CRONJOB_IMAGES $REPLICASET_IMAGES $POD_IMAGES" | tr -s '[[:space:]]' '\n' | sort -u)

# Filter for images from our source registry
log "INFO" "Filtering for images from ${SOURCE_REGISTRY}..."
SOURCE_IMAGES=$(echo "$ALL_IMAGES" | grep "^${SOURCE_REGISTRY}" || true)

if [ -z "$SOURCE_IMAGES" ]; then
    log "WARNING" "No images found from source registry: ${SOURCE_REGISTRY}"
    exit 0
fi

# Count total images to process
TOTAL_IMAGES=$(echo "$SOURCE_IMAGES" | wc -l)
CURRENT_IMAGE=0

log "INFO" "Found ${TOTAL_IMAGES} images from ${SOURCE_REGISTRY} to process"

# TESTING ONLY: Just print what would be done, don't actually copy
log "INFO" "=== TEST MODE ==="
log "INFO" "Would copy the following images:"
echo ""

# Process each image
for FULL_IMAGE in $SOURCE_IMAGES; do
    CURRENT_IMAGE=$((CURRENT_IMAGE + 1))
    echo -e "${BLUE}[$CURRENT_IMAGE/$TOTAL_IMAGES]${NC} Processing: $FULL_IMAGE"
    
    # Extract repository and tag
    IMAGE_INFO=$(echo "$FULL_IMAGE" | sed "s|^${SOURCE_REGISTRY}/||")
    
    # Handle if image doesn't have a tag (use latest)
    if [[ "$IMAGE_INFO" != *":"* ]]; then
        IMAGE_INFO="${IMAGE_INFO}:latest"
    fi
    
    SOURCE_REF="${SOURCE_REGISTRY}/${IMAGE_INFO}"
    DEST_REF="${DESTINATION_REGISTRY}/${IMAGE_INFO}"
    
    echo "  Would copy from ${SOURCE_REF} to ${DEST_REF}"
done

echo ""
log "SUCCESS" "Successfully processed all ${TOTAL_IMAGES} images."
log "INFO" "=== END TEST MODE ==="

# Here's how to enable the full functionality:
# 1. Set up ACR access
# 2. Uncomment the login section above
# 3. Replace the test mode section with the original code below
: <<'ORIGINAL_CODE'
# Process each image
for FULL_IMAGE in $SOURCE_IMAGES; do
    CURRENT_IMAGE=$((CURRENT_IMAGE + 1))
    log "INFO" "[$CURRENT_IMAGE/$TOTAL_IMAGES] Processing: $FULL_IMAGE"
    
    # Extract repository and tag
    IMAGE_INFO=$(echo "$FULL_IMAGE" | sed "s|^${SOURCE_REGISTRY}/||")
    
    # Handle if image doesn't have a tag (use latest)
    if [[ "$IMAGE_INFO" != *":"* ]]; then
        IMAGE_INFO="${IMAGE_INFO}:latest"
    fi
    
    SOURCE_REF="${SOURCE_REGISTRY}/${IMAGE_INFO}"
    DEST_REF="${DESTINATION_REGISTRY}/${IMAGE_INFO}"
    
    # Check if image already exists in destination
    if oras manifest fetch --descriptor ${DEST_REF} > /dev/null 2>&1; then
        log "INFO" "  Image exists in destination. Checking manifests..."
        
        SOURCE_MANIFEST=$(oras manifest fetch --insecure --descriptor ${SOURCE_REF} 2>/dev/null)
        DEST_MANIFEST=$(oras manifest fetch --descriptor ${DEST_REF} 2>/dev/null)
        
        if [[ "$SOURCE_MANIFEST" == "$DEST_MANIFEST" ]]; then
            log "SUCCESS" "  ✓ Image already exists with same manifest. Skipping."
            continue
        else
            log "WARNING" "  ⚠ Manifests differ. Updating image..."
        fi
    else
        log "INFO" "  Image not found in destination. Copying..."
    fi
    
    # Copy the image
    log "INFO" "  Copying image..."
    if oras cp --from-insecure ${SOURCE_REF} ${DEST_REF}; then
        # Verify copy success
        log "INFO" "  Verifying copy..."
        SOURCE_MANIFEST=$(oras manifest fetch --insecure --descriptor ${SOURCE_REF} 2>/dev/null)
        DEST_MANIFEST=$(oras manifest fetch --descriptor ${DEST_REF} 2>/dev/null)
        
        if [[ "$SOURCE_MANIFEST" == "$DEST_MANIFEST" ]]; then
            log "SUCCESS" "  ✓ Successfully copied ${IMAGE_INFO}"
        else
            log "ERROR" "  ✗ ERROR: Failed to copy ${IMAGE_INFO} - manifests don't match"
            exit 1
        fi
    else
        log "ERROR" "  ✗ ERROR: Failed to copy ${IMAGE_INFO}"
        exit 1
    fi
done
ORIGINAL_CODE

# Main execution
check_cluster 
#!/bin/bash

# Set strict error handling
set -e

# Set source and destination registries
SOURCE_REGISTRY="docker.io"
# Replace with your actual ACR name
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

# Check for oras
if ! command -v oras &> /dev/null; then
  log "ERROR" "oras not found in PATH. Please install oras: https://oras.land/docs/installation"
  exit 1
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

# Function to login to ACR
# This assumes you are using service principal authentication
# Modify according to your authentication method
acr_login() {
  log "INFO" "Logging in to ACR at ${DESTINATION_REGISTRY}..."
  
  # Option 1: Using service principal (requires SP_CLIENT_ID, SP_CLIENT_SECRET, ACR_TENANT_ID env vars)
  if [ -n "$SP_CLIENT_ID" ] && [ -n "$SP_CLIENT_SECRET" ] && [ -n "$ACR_TENANT_ID" ]; then
    if ! az login --service-principal -u $SP_CLIENT_ID -p $SP_CLIENT_SECRET --tenant $ACR_TENANT_ID &> /dev/null; then
      log "ERROR" "Failed to login to Azure with service principal"
      exit 1
    fi
    
    if ! az acr login --name $(echo $DESTINATION_REGISTRY | cut -d '.' -f 1) &> /dev/null; then
      log "ERROR" "Failed to login to ACR"
      exit 1
    fi
  # Option 2: Using managed identity (when running in Azure)
  elif [ -n "$USE_MANAGED_IDENTITY" ]; then
    if ! az login --identity &> /dev/null; then
      log "ERROR" "Failed to login to Azure with managed identity"
      exit 1
    fi
    
    if ! az acr login --name $(echo $DESTINATION_REGISTRY | cut -d '.' -f 1) &> /dev/null; then
      log "ERROR" "Failed to login to ACR"
      exit 1
    fi
  # Option 3: Using oras with username/password
  elif [ -n "$ACR_USERNAME" ] && [ -n "$ACR_PASSWORD" ]; then
    if ! oras login ${DESTINATION_REGISTRY} -u $ACR_USERNAME -p $ACR_PASSWORD; then
      log "ERROR" "Failed to login to ACR using oras"
      exit 1
    fi
  # Option 4: Using a token file if provided
  elif [ -f "/token/acr-token" ]; then
    if ! oras login ${DESTINATION_REGISTRY} -u 00000000-0000-0000-0000-000000000000 -p $(cat /token/acr-token); then
      log "ERROR" "Failed to login to ACR using token file"
      exit 1
    fi
  else
    log "ERROR" "No valid authentication method provided for ACR"
    log "ERROR" "Please set either:"
    log "ERROR" "  - SP_CLIENT_ID, SP_CLIENT_SECRET, and ACR_TENANT_ID for service principal"
    log "ERROR" "  - USE_MANAGED_IDENTITY=true for managed identity"
    log "ERROR" "  - ACR_USERNAME and ACR_PASSWORD for basic auth"
    log "ERROR" "  - Provide a token file at /token/acr-token"
    exit 1
  fi
  
  log "SUCCESS" "Successfully logged in to ACR."
}

# Execute main functions
check_cluster
acr_login

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

log "SUCCESS" "Successfully processed all ${TOTAL_IMAGES} images." 
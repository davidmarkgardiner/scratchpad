#!/bin/bash

# Set source and destination registries
#SOURCE_REGISTRY="container-registry.xxx.net"
SOURCE_REGISTRY="docker.io"
DESTINATION_REGISTRY="mytestacrregistry.azurecr.io"

# Login to destination registry (modified for testing)
echo "Logging in to destination registry..."
# Since this is a test, we'll skip the actual login for now
# oras login ${DESTINATION_REGISTRY} -u 00000000-0000-0000-0000-000000000000 -p $(cat /token/acr-token)

# Get images from all Kubernetes resources
echo "Collecting images from all Kubernetes resources..."

# Get images from deployments
DEPLOYMENT_IMAGES=$(kubectl get deployments --all-namespaces -o jsonpath="{.items[*].spec.template.spec.containers[*].image}" 2>/dev/null)

# Get images from statefulsets
STATEFULSET_IMAGES=$(kubectl get statefulsets --all-namespaces -o jsonpath="{.items[*].spec.template.spec.containers[*].image}" 2>/dev/null)

# Get images from daemonsets
DAEMONSET_IMAGES=$(kubectl get daemonsets --all-namespaces -o jsonpath="{.items[*].spec.template.spec.containers[*].image}" 2>/dev/null)

# Get images from jobs
JOB_IMAGES=$(kubectl get jobs --all-namespaces -o jsonpath="{.items[*].spec.template.spec.containers[*].image}" 2>/dev/null)

# Get images from cronjobs
CRONJOB_IMAGES=$(kubectl get cronjobs --all-namespaces -o jsonpath="{.items[*].spec.jobTemplate.spec.template.spec.containers[*].image}" 2>/dev/null)

# Get images from replicasets (excluding those managed by deployments)
REPLICASET_IMAGES=$(kubectl get replicasets --all-namespaces -o jsonpath="{.items[*].spec.template.spec.containers[*].image}" 2>/dev/null)

# Get images from standalone pods
POD_IMAGES=$(kubectl get pods --all-namespaces -o jsonpath="{.items[*].spec.containers[*].image}" 2>/dev/null)

# Combine all images, remove duplicates, and sort
ALL_IMAGES=$(echo "$DEPLOYMENT_IMAGES $STATEFULSET_IMAGES $DAEMONSET_IMAGES $JOB_IMAGES $CRONJOB_IMAGES $REPLICASET_IMAGES $POD_IMAGES" | tr -s '[[:space:]]' '\n' | sort -u)

# Filter for images from our source registry
echo "Filtering for images from ${SOURCE_REGISTRY}..."
SOURCE_IMAGES=$(echo "$ALL_IMAGES" | grep "^${SOURCE_REGISTRY}" || true)

if [ -z "$SOURCE_IMAGES" ]; then
    echo "No images found from source registry: ${SOURCE_REGISTRY}"
    exit 0
fi

# Count total images to process
TOTAL_IMAGES=$(echo "$SOURCE_IMAGES" | wc -l)
CURRENT_IMAGE=0

echo "Found ${TOTAL_IMAGES} images from ${SOURCE_REGISTRY} to process"

# TESTING ONLY: Just print what would be done, don't actually copy
echo "### TEST MODE ###"
echo "Would copy the following images:"

# Process each image
for FULL_IMAGE in $SOURCE_IMAGES; do
    CURRENT_IMAGE=$((CURRENT_IMAGE + 1))
    echo "[$CURRENT_IMAGE/$TOTAL_IMAGES] Processing: $FULL_IMAGE"
    
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

echo "Successfully processed all ${TOTAL_IMAGES} images."
echo "### END TEST MODE ###"

# Original copy logic commented out for testing
: <<'ORIGINAL_CODE'
# Process each image
for FULL_IMAGE in $SOURCE_IMAGES; do
    CURRENT_IMAGE=$((CURRENT_IMAGE + 1))
    echo "[$CURRENT_IMAGE/$TOTAL_IMAGES] Processing: $FULL_IMAGE"
    
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
        echo "  Image exists in destination. Checking manifests..."
        
        SOURCE_MANIFEST=$(oras manifest fetch --insecure --descriptor ${SOURCE_REF} 2>/dev/null)
        DEST_MANIFEST=$(oras manifest fetch --descriptor ${DEST_REF} 2>/dev/null)
        
        if [[ "$SOURCE_MANIFEST" == "$DEST_MANIFEST" ]]; then
            echo "  ✓ Image already exists with same manifest. Skipping."
            continue
        else
            echo "  ⚠ Manifests differ. Updating image..."
        fi
    else
        echo "  Image not found in destination. Copying..."
    fi
    
    # Copy the image
    echo "  Copying image..."
    if oras cp --from-insecure ${SOURCE_REF} ${DEST_REF}; then
        # Verify copy success
        echo "  Verifying copy..."
        SOURCE_MANIFEST=$(oras manifest fetch --insecure --descriptor ${SOURCE_REF} 2>/dev/null)
        DEST_MANIFEST=$(oras manifest fetch --descriptor ${DEST_REF} 2>/dev/null)
        
        if [[ "$SOURCE_MANIFEST" == "$DEST_MANIFEST" ]]; then
            echo "  ✓ Successfully copied ${IMAGE_INFO}"
        else
            echo "  ✗ ERROR: Failed to copy ${IMAGE_INFO} - manifests don't match"
            exit 1
        fi
    else
        echo "  ✗ ERROR: Failed to copy ${IMAGE_INFO}"
        exit 1
    fi
done
ORIGINAL_CODE
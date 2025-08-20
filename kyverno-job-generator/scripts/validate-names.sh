#!/bin/bash

echo "========================================="
echo "RFC 1123 Name Validation (Simulation)"
echo "========================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test images
test_images=(
    "my.registry.com/app/service:v1.0.0"
    "my.registry.com/MyApp/WebServer:v1.2.3"
    "my.registry.com/app_name/service.backend:2.1.0_beta"
    "my.registry.com/very/long/path/to/application/microservice/component:version-1.2.3-build-12345"
    "my.registry.com/app/service@sha256:abc123def456789012345678901234567890123456789012345678901234567890"
    "my.registry.com:5000/app/service:v1.0.0"
    "docker.io/library/redis:7.0-alpine"
    "docker.io/library/Redis:7.0-Alpine"
    "my.registry.com/app+feature/service~test:v1.0+build.123"
    "my.registry.com/123/456:7.8.9"
    "my.registry.com/APP/SERVICE:V1.0.0-BETA"
    "my.registry.com/very-very-very-very-very-long-name/service:v1"
    "ghcr.io/kubernetes/ingress-nginx:v1.9.4"
    "quay.io/coreos/etcd:v3.5.9"
    "mcr.microsoft.com/dotnet/runtime:7.0"
    "my.registry.com/app/service:latest"
    "my.registry.com/app/service"  # No tag (implies :latest)
    "nginx"  # Simple name
    "ubuntu:22.04"
    "my.registry.com/département/café:v1.0"  # Non-ASCII
)

echo "Testing different naming strategies:"
echo ""

# Strategy 1: Hash-based (always RFC compliant, but not human-readable)
echo -e "${BLUE}Strategy 1: Hash-based naming (Recommended)${NC}"
echo "Format: img-job-<16-char-hash>"
echo "----------------------------------------"

for image in "${test_images[@]}"; do
    # Generate hash-based name (using md5sum for simulation)
    hash=$(echo -n "$image" | md5sum | cut -c1-16)
    job_name="img-job-$hash"
    
    # This will always be RFC compliant
    echo -e "${GREEN}✓${NC} $job_name"
    echo "   Image: $image"
done

echo ""
echo -e "${BLUE}Strategy 2: Sanitized image-based naming${NC}"
echo "Format: job-<sanitized-image-name>"
echo "----------------------------------------"

for image in "${test_images[@]}"; do
    # Remove registry prefix (everything before first /)
    if [[ "$image" == *"/"* ]]; then
        # Remove registry part
        sanitized="${image#*/}"
        # For images with registry:port, handle differently
        if [[ "${image%%/*}" == *":"* ]]; then
            sanitized="${image#*://}"
            sanitized="${sanitized#*/}"
        fi
    else
        sanitized="$image"
    fi
    
    # Convert to lowercase
    sanitized=$(echo "$sanitized" | tr '[:upper:]' '[:lower:]')
    
    # Replace invalid characters with hyphens
    # Replace : / @ . _ + ~ and spaces with hyphens
    sanitized=$(echo "$sanitized" | sed 's/[@:\/._+ ~]/-/g')
    
    # Remove any other non-alphanumeric characters except hyphens
    sanitized=$(echo "$sanitized" | sed 's/[^a-z0-9-]//g')
    
    # Remove consecutive hyphens
    sanitized=$(echo "$sanitized" | sed 's/-\+/-/g')
    
    # Remove leading/trailing hyphens
    sanitized=$(echo "$sanitized" | sed 's/^-//;s/-$//')
    
    # Add prefix
    job_name="job-$sanitized"
    
    # Truncate to 63 characters if needed
    if [ ${#job_name} -gt 63 ]; then
        # Keep first 59 chars and add suffix to indicate truncation
        job_name="${job_name:0:59}-trn"
    fi
    
    # Validate
    if [[ "$job_name" =~ ^[a-z0-9]([-a-z0-9]*[a-z0-9])?$ ]] && [ ${#job_name} -le 63 ]; then
        echo -e "${GREEN}✓${NC} $job_name (${#job_name} chars)"
    else
        echo -e "${RED}✗${NC} $job_name (INVALID)"
    fi
    echo "   Image: $image"
done

echo ""
echo -e "${BLUE}Strategy 3: Combined (hash + readable prefix)${NC}"
echo "Format: <type>-<short-name>-<8-char-hash>"
echo "----------------------------------------"

for image in "${test_images[@]}"; do
    # Extract a short readable part
    if [[ "$image" == *"/"* ]]; then
        # Get the last path component (usually the app name)
        app_name="${image##*/}"
        app_name="${app_name%%:*}"  # Remove tag
        app_name="${app_name%%@*}"  # Remove digest
    else
        app_name="${image%%:*}"
    fi
    
    # Sanitize app name
    app_name=$(echo "$app_name" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]//g')
    
    # Limit to 20 chars
    if [ ${#app_name} -gt 20 ]; then
        app_name="${app_name:0:20}"
    fi
    
    # Generate hash
    hash=$(echo -n "$image" | md5sum | cut -c1-8)
    
    # Combine
    if [ -n "$app_name" ]; then
        job_name="img-${app_name}-${hash}"
    else
        job_name="img-job-${hash}"
    fi
    
    # This should always be RFC compliant
    if [[ "$job_name" =~ ^[a-z0-9]([-a-z0-9]*[a-z0-9])?$ ]] && [ ${#job_name} -le 63 ]; then
        echo -e "${GREEN}✓${NC} $job_name"
    else
        echo -e "${YELLOW}⚠${NC} $job_name (edge case)"
    fi
    echo "   Image: $image"
done

echo ""
echo "========================================="
echo "Summary & Recommendations"
echo "========================================="
echo ""
echo -e "${GREEN}Recommended Approach:${NC}"
echo "1. Use hash-based naming (Strategy 1) for guaranteed RFC compliance"
echo "2. Store original image name in annotations/labels"
echo "3. Use 'synchronize: false' to ensure one job per unique image"
echo ""
echo -e "${YELLOW}RFC 1123 Requirements:${NC}"
echo "• Lowercase letters (a-z), numbers (0-9), and hyphens (-) only"
echo "• Must start and end with alphanumeric character"
echo "• Maximum 63 characters"
echo "• No consecutive hyphens (best practice)"
echo ""
echo -e "${BLUE}Benefits of hash-based naming:${NC}"
echo "• Always RFC 1123 compliant"
echo "• Guaranteed unique per image (including tag/digest)"
echo "• Consistent length (predictable)"
echo "• No edge cases to handle"
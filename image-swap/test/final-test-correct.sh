#!/bin/bash

function test_image() {
  local IMAGE="$1"
  
  echo -e "\n---------------------------------------------"
  echo "Testing image: $IMAGE"
  
  # Step 1: Remove repository prefix (everything before .com/)
  STEP1=$(echo "$IMAGE" | sed -E 's|^.*\.com/||')
  
  # Step 2: Replace / with -
  STEP2=$(echo "$STEP1" | sed 's|/|-|g')
  
  # Step 3: Convert to lowercase
  STEP3=$(echo "$STEP2" | tr '[:upper:]' '[:lower:]')
  
  # Step 4: Replace special characters with hyphens
  STEP4=$(echo "$STEP3" | sed -E 's|[^a-z0-9-]|-|g')
  
  # Step 5: Truncate to 49 chars max (prefix "image-process-" is 14 chars)
  STEP5=$(echo "$STEP4" | cut -c 1-49)
  
  # Step 6: Replace trailing hyphen with '1' if present (after truncation)
  STEP6=$(echo "$STEP5" | sed -E 's|-$|1|')
  
  # Final result
  FINAL="image-process-${STEP6}"
  echo "Final name: $FINAL"
  
  # Verify RFC 1123 compliance
  local COMPLIANT=true
  
  # Check if name contains only lowercase alphanumeric characters and hyphens
  if [[ ! $FINAL =~ ^[a-z0-9-]+$ ]]; then
    echo "❌ Contains invalid characters"
    COMPLIANT=false
  fi
  
  # Check if name starts and ends with alphanumeric
  if [[ ! $FINAL =~ ^[a-z0-9].*[a-z0-9]$ ]]; then
    echo "❌ Does not start/end with alphanumeric"
    COMPLIANT=false
  fi
  
  # Check length
  if [[ ${#FINAL} -gt 63 ]]; then
    echo "❌ Too long (${#FINAL} chars)"
    COMPLIANT=false
  else
    echo "Length: ${#FINAL} characters"
  fi
  
  if [[ "$COMPLIANT" == "true" ]]; then
    echo "✅ RFC 1123 compliant"
  fi
}

echo "Testing RFC 1123 compliance with CORRECT truncation and trailing hyphen fix..."

# Normal case
test_image "my.registry.com/nginx:1.19.0"

# Special characters
test_image "my.registry.com/app_name@v1.2.3!"

# Ends with hyphen
test_image "my.registry.com/app-name-"

# Long name
test_image "my.registry.com/very-long-repository-name-with-many-segments/and-more-segments/component/service:v1.2.3-alpha.1"

# All uppercase
test_image "my.registry.com/ALLCAPS/VERSION"

# Docker Hub example 
test_image "docker.io/library/ubuntu:20.04"

# Edge case - long name that would end with hyphen after truncation
test_image "my.registry.com/very-long-name-ending-with-hyphen-after-truncation-"

echo -e "\nAll tests complete!" 
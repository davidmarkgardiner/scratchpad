#!/bin/bash

function extract_middle() {
  local IMAGE="$1"
  # Remove prefix (registry part) and suffix (tag part)
  local MIDDLE=$(echo "$IMAGE" | sed -E 's|^.*\.com/||' | sed -E 's|:.*$||')
  # Further cleanup to get just the account/org name (remove the image name after last /)
  local ACCOUNT=$(echo "$MIDDLE" | sed -E 's|/[^/]*$||')
  # If there's no / in MIDDLE, then ACCOUNT will be empty, so use MIDDLE
  if [[ -z "$ACCOUNT" ]]; then
    ACCOUNT="$MIDDLE"
  fi
  # Replace / with -
  local RESULT=$(echo "$ACCOUNT" | tr '/' '-' | tr '[:upper:]' '[:lower:]')
  echo "$RESULT"
}

echo "Testing middle part extraction..."

# Test with the example provided
test_image="myreg.xxx.net/david/gardiner:1-snapshot"
middle=$(extract_middle "$test_image")
echo "Image: $test_image"
echo "Extracted middle part: $middle"
echo "Expected: david"
echo ""

# Test with Docker Hub style image
test_image="docker.io/library/ubuntu:20.04"
middle=$(extract_middle "$test_image")
echo "Image: $test_image"
echo "Extracted middle part: $middle"
echo "Expected: library"
echo ""

# Test with GCR style image
test_image="gcr.io/google-containers/nginx:1.19.0"
middle=$(extract_middle "$test_image")
echo "Image: $test_image"
echo "Extracted middle part: $middle"
echo "Expected: google-containers"
echo ""

# Test with AWS ECR style image
test_image="123456789012.dkr.ecr.us-west-2.amazonaws.com/my-app/backend:latest"
middle=$(extract_middle "$test_image")
echo "Image: $test_image"
echo "Extracted middle part: $middle"
echo "Expected: my-app"
echo ""

# Test with Azure ACR style image
test_image="myregistry.azurecr.io/my-org/frontend:v1.2.3"
middle=$(extract_middle "$test_image")
echo "Image: $test_image"
echo "Extracted middle part: $middle"
echo "Expected: my-org"
echo ""

# Test simple image (no organization)
test_image="my.registry.com/nginx:latest"
middle=$(extract_middle "$test_image")
echo "Image: $test_image"
echo "Extracted middle part: $middle"
echo "Expected: nginx"
echo "" 
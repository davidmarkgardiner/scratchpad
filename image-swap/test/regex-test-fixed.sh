#!/bin/bash

function extract_middle() {
  local IMAGE="$1"
  
  # Remove the tag part first (everything after :)
  local NO_TAG=$(echo "$IMAGE" | sed -E 's|:[^/]*$||')
  
  # Extract the middle portion by splitting on "/"
  local PARTS=($(echo "$NO_TAG" | tr '/' ' '))
  local NUM_PARTS=${#PARTS[@]}
  
  # If we have exactly three parts like "registry/david/gardiner", get "david"
  if [[ $NUM_PARTS -ge 3 ]]; then
    echo "${PARTS[1]}" | tr '[:upper:]' '[:lower:]'
  # If we have exactly two parts like "registry/nginx", get "nginx"
  elif [[ $NUM_PARTS -eq 2 ]]; then
    echo "${PARTS[1]}" | tr '[:upper:]' '[:lower:]'
  # If we only have one part, use it (rare case)
  else
    echo "${PARTS[0]}" | tr '[:upper:]' '[:lower:]'
  fi
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
#!/bin/bash
set -e

# Initialize Go module
echo "Initializing Go module..."
./tests/init-module.sh

echo "Building test container..."
docker build -t kyverno-policy-tests -f tests/Dockerfile .

echo "Running tests..."
docker run --rm \
  -v "${HOME}/.kube/config:/root/.kube/config:ro" \
  -v "$(pwd):/app" \
  kyverno-policy-tests

echo "Tests completed successfully!" 
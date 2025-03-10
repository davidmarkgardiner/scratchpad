#!/bin/bash

# Run Kyverno CLI tests for image swap policies

# Change to the test directory if script is run from parent directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "Running tests from directory: $(pwd)"

# Create yaml directory for output files if it doesn't exist
mkdir -p yaml

echo "Running tests for image-mutator policy..."
IMAGE_MUTATOR_RESULT=$(kyverno apply ../tag/2-image-mutator-policy.yaml --resource resources/pod-container-registry.yaml,resources/pod-docker-io.yaml,resources/pod-skip-verify.yaml,resources/pod-init-container.yaml)
echo "$IMAGE_MUTATOR_RESULT"
IMAGE_MUTATOR_SUMMARY=$(echo "$IMAGE_MUTATOR_RESULT" | grep -o "pass: [0-9]*, fail: [0-9]*, warn: [0-9]*, error: [0-9]*, skip: [0-9]*")

echo -e "\nRunning tests for job-generator policy..."
JOB_GENERATOR_RESULT=$(kyverno apply ../tag/5-job-generator-policy.yaml --resource resources/pod-my-registry.yaml,resources/pod-skip-verify.yaml)
echo "$JOB_GENERATOR_RESULT"
JOB_GENERATOR_SUMMARY=$(echo "$JOB_GENERATOR_RESULT" | grep -o "pass: [0-9]*, fail: [0-9]*, warn: [0-9]*, error: [0-9]*, skip: [0-9]*")

# Check if any files were created in the yaml directory
echo -e "\nChecking for output files in yaml directory..."
YAML_FILES=$(find yaml -type f 2>/dev/null)
if [ -z "$YAML_FILES" ]; then
    echo "No files found in the yaml directory."
    echo "Note: Kyverno CLI may not be writing output files as expected."
    
    # Try to manually save the output to files
    echo "Saving test results to yaml directory manually..."
    echo "$IMAGE_MUTATOR_RESULT" > yaml/image-mutator-results.txt
    echo "$JOB_GENERATOR_RESULT" > yaml/job-generator-results.txt
    echo "Saved test results to yaml/image-mutator-results.txt and yaml/job-generator-results.txt"
else
    echo "Files found in yaml directory:"
    ls -la yaml/
fi

echo -e "\nTest summary:"
echo "=============="
echo "Image Mutator Policy: $IMAGE_MUTATOR_SUMMARY"
echo "Job Generator Policy: $JOB_GENERATOR_SUMMARY"
echo "All tests completed. Check the results above for details."
echo "Test results are saved in the yaml directory." 
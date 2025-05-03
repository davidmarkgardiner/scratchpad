#!/bin/bash

# Print the test pod's image
TESTPOD_IMAGE=$(cat test/test-pod.yaml | grep 'image:' | awk '{print $2}')
echo "Original image: $TESTPOD_IMAGE"

# Create a dry run of the kyverno policy with the test pod
echo -e "\nGenerating job from policy (dry run)..."
kubectl create -f test/test-pod.yaml -f tag/1-job-generator-policy-enhanced-fixed.yaml --dry-run=client -o yaml > test/test-output.yaml

# Extract generated job name
echo -e "\nGenerated job names:"
grep "name: \"image-process-" test/test-output.yaml

echo -e "\nVerifying RFC 1123 compliance..."
JOB_NAME=$(grep "name: \"image-process-" test/test-output.yaml | head -1 | sed 's/.*name: "//' | sed 's/".*//')
echo "Extracted job name: $JOB_NAME"

# Check if name contains only lowercase alphanumeric characters and hyphens
if [[ $JOB_NAME =~ ^[a-z0-9-]+$ ]]; then
  echo "✅ Name is RFC 1123 compliant (only lowercase alphanumeric and hyphens)"
else
  echo "❌ Name is NOT RFC 1123 compliant"
fi

# Check if name starts and ends with alphanumeric
if [[ $JOB_NAME =~ ^[a-z0-9].*[a-z0-9]$ ]]; then
  echo "✅ Name starts and ends with alphanumeric character"
else
  echo "❌ Name does not start and end with alphanumeric character"
fi

# Check length (DNS labels must be 63 characters or less)
if [[ ${#JOB_NAME} -le 63 ]]; then
  echo "✅ Name length is valid (${#JOB_NAME} characters, max 63)"
else
  echo "❌ Name length exceeds 63 characters (${#JOB_NAME})"
fi 
#!/bin/bash

# Create the base directory structure
mkdir -p image-swap/{exceptions,patched,policies,resources,tests}

# Create the main README.md
touch image-swap/README.md

# Create .gitlab-ci.yml
touch image-swap/.gitlab-ci.yml

# Create files in exceptions directory
touch image-swap/exceptions/image-exception.yaml

# Create files in patched directory
touch image-swap/patched/generated-job.yaml
touch image-swap/patched/generated-job-multi.yaml

# Create files in policies directory
touch image-swap/policies/job-generator-policy.yaml
touch image-swap/policies/image-mutator-policy.yaml

# Create files in resources directory
touch image-swap/resources/exempted-pod.yaml
touch image-swap/resources/test-pod-multi.yaml
touch image-swap/resources/test-pod2.yaml
touch image-swap/resources/test-pod.yaml

# Create files in tests directory
touch image-swap/tests/README.md
touch image-swap/tests/kyverno-test.yaml
touch image-swap/tests/variables.yaml

echo "Project structure created successfully!"
echo "Directory structure:"
find image-swap -type d | sort

echo -e "\nFiles created:"
find image-swap -type f | sort

# Make the script executable
chmod +x image-swap/setup.sh 
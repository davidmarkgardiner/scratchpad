#!/bin/bash
cd /Users/davidgardiner/Desktop/repo/scratchpad/kyverno-policies/tests
mkdir -p test_run
cd test_run

# Create the directory structure expected by the test
mkdir -p policies resources patched

# Copy the policies
cp ../policies/policies/image-mutator-policy.yaml policies/
cp ../policies/policies/job-generator-policy.yaml policies/

# Copy the resources
cp ../policies/resources/pod-container-registry.yaml resources/
cp ../policies/resources/pod-docker-io.yaml resources/
cp ../policies/resources/pod-my-registry.yaml resources/
cp ../policies/resources/pod-skip-verify.yaml resources/
cp ../policies/resources/pod-init-container.yaml resources/

# Copy the patched resources
cp ../policies/patched/patched-pod-container-registry.yaml patched/
cp ../policies/patched/patched-pod-docker-io.yaml patched/
cp ../policies/patched/patched-pod-init-container.yaml patched/
cp ../policies/patched/generated-job.yaml patched/

# Create a modified test file with correct paths
cat > kyverno-test.yaml << 'EOF'
apiVersion: cli.kyverno.io/v1alpha1
kind: Test
metadata:
  name: combined-policies-test
policies:
  - policies/image-mutator-policy.yaml
  - policies/job-generator-policy.yaml
resources:
  - resources/pod-container-registry.yaml
  - resources/pod-docker-io.yaml
  - resources/pod-my-registry.yaml
  - resources/pod-skip-verify.yaml
  - resources/pod-init-container.yaml
results:
  # Image Mutator Policy Tests
  - policy: image-mutator
    rule: mutate-container-images
    resources:
      - app1/Pod/test-pod-container-registry
    patchedResources: patched/patched-pod-container-registry.yaml
    result: pass
  
  - policy: image-mutator
    rule: mutate-docker-images
    resources:
      - app1/Pod/test-pod-docker-io
    patchedResources: patched/patched-pod-docker-io.yaml
    result: pass
  
  - policy: image-mutator
    rule: mutate-init-container-images
    resources:
      - app1/Pod/test-pod-init-container
    patchedResources: patched/patched-pod-init-container.yaml
    result: pass
  
  # Job Generator Policy Tests
  - policy: image-job-generator-v5
    rule: generate-push-job
    resources:
      - default/Pod/test-pod-my-registry
    generatedResource: patched/generated-job.yaml
    result: pass
  
  # Skip Tests
  - policy: image-mutator
    rule: mutate-container-images
    resources:
      - app1/Pod/test-pod-skip-verify
    result: skip
  
  - policy: image-job-generator-v5
    rule: generate-push-job
    resources:
      - app1/Pod/test-pod-skip-verify
    result: skip 
EOF

# Run the test
kyverno test . 
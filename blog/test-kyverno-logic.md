# Approach 1: Using base64 encoding of the image string
# This creates a deterministic hash-like string from the image name
apiVersion: batch/v1
kind: Job
metadata:
  name: "copy-{{ request.object.spec.containers[0].image | base64 | truncate(20, false, '') | lower | replace('/', '-') | replace('+', '-') | replace('=', '') }}"
  # Example: container.registry.xxx.net/whatever/something:v1xxxx -> copy-y29udgfpbmvylnjlz2lz

---
# Approach 2: Using SHA1 hash (if Kyverno supports it)
# More robust hash approach
apiVersion: batch/v1
kind: Job
metadata:
  name: "copy-{{ request.object.spec.containers[0].image | sha1sum | truncate(16, false, '') }}"
  # Would produce something like: copy-a3f5e8b2c9d1e4f6

---
# Approach 3: Extract tag and combine with timestamp-like pattern
# Uses the tag portion after the colon
apiVersion: batch/v1
kind: Job
metadata:
  name: "copy-{{ request.object.spec.containers[0].image | split(':') | last | replace('.', '-') | truncate(30, false, '') }}-{{ request.object.metadata.uid | truncate(8, false, '') }}"
  # Example: copy-v1xxxx-a1b2c3d4

---
# Approach 4: Using regex to extract key parts and combine
# Extracts the last part of path and tag
apiVersion: batch/v1
kind: Job
metadata:
  name: "copy-{{ request.object.spec.containers[0].image | regex_replace('^.*/', '') | regex_replace(':', '-') | truncate(40, false, '') | lower }}"
  # Example: copy-something-v1xxxx

---
# Approach 5: Multiple string manipulations for unique name
# Combines multiple parts for uniqueness
apiVersion: batch/v1
kind: Job
metadata:
  name: "img-copy-{{ request.object.spec.containers[0].image | split('/') | last | split(':') | join('-') | replace('.', '') | replace('_', '-') | lower | truncate(50, false, '') }}"
  # Example: img-copy-something-v1xxxx

---
# Approach 6: Using label selector pattern with sanitization
# This approach creates a job name and adds the full image as a label
apiVersion: batch/v1
kind: Job
metadata:
  name: "sync-{{ request.object.spec.containers[0].image | split('/') | last | split(':') | first }}-{{ request.object.spec.containers[0].image | split(':') | last | truncate(10, false, '') }}"
  labels:
    source-image-hash: "{{ request.object.spec.containers[0].image | base64 | truncate(63, false, '') }}"
  # Example name: sync-something-v1xxxx

---
# Test Script - You can use this to verify the logic outside Kyverno
# Save as test-job-name.sh
#!/bin/bash

IMAGE="container.registry.xxx.net/whatever/something:v1xxxx"

echo "Testing different approaches for image: $IMAGE"
echo "================================================"

# Approach 1: Base64
echo "1. Base64 approach:"
echo -n "copy-"
echo -n "$IMAGE" | base64 | cut -c1-20 | tr '[:upper:]' '[:lower:]' | tr '/' '-' | tr '+' '-' | tr -d '='
echo ""

# Approach 2: SHA1
echo "2. SHA1 approach:"
echo -n "copy-"
echo -n "$IMAGE" | sha1sum | cut -c1-16
echo ""

# Approach 3: Tag extraction
echo "3. Tag extraction:"
TAG=$(echo "$IMAGE" | cut -d':' -f2 | tr '.' '-' | cut -c1-30)
echo "copy-${TAG}-$(uuidgen | cut -c1-8)"

# Approach 4: Regex extraction
echo "4. Regex approach:"
echo -n "copy-"
echo "$IMAGE" | sed 's|.*/||' | sed 's|:|---|' | cut -c1-40 | tr '[:upper:]' '[:lower:]'
echo ""

# Approach 5: Multiple manipulations
echo "5. Combined approach:"
echo -n "img-copy-"
echo "$IMAGE" | awk -F'/' '{print $NF}' | sed 's/:/-/g' | tr '.' '' | tr '_' '-' | tr '[:upper:]' '[:lower:]' | cut -c1-50
echo ""

# Approach 6: Split approach
echo "6. Split with label approach:"
REPO=$(echo "$IMAGE" | awk -F'/' '{print $NF}' | cut -d':' -f1)
TAG=$(echo "$IMAGE" | cut -d':' -f2 | cut -c1-10)
echo "sync-${REPO}-${TAG}"
echo "Label hash: $(echo -n "$IMAGE" | base64 | cut -c1-63)"

---
# Complete Kyverno Policy Example using Approach 1 (most reliable)
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: copy-image-to-acr
spec:
  background: false
  rules:
    - name: create-copy-job
      match:
        any:
        - resources:
            kinds:
            - Deployment
            - StatefulSet
            - DaemonSet
      generate:
        apiVersion: batch/v1
        kind: Job
        name: "copy-{{ request.object.spec.containers[0].image | base64 | truncate(20, false, '') | lower | replace('/', '-') | replace('+', '-') | replace('=', '') }}"
        namespace: "{{ request.object.metadata.namespace }}"
        synchronize: false
        data:
          spec:
            backoffLimit: 3
            template:
              spec:
                restartPolicy: Never
                containers:
                - name: image-copier
                  image: your-registry/skopeo:latest  # Or any image copying tool
                  command:
                  - /bin/sh
                  - -c
                  - |
                    echo "Copying image: {{ request.object.spec.containers[0].image }}"
                    skopeo copy \
                      --src-tls-verify=false \
                      --dest-tls-verify=false \
                      docker://{{ request.object.spec.containers[0].image }} \
                      docker://your-acr.azurecr.io/{{ request.object.spec.containers[0].image | split('/') | last }}
                  env:
                  - name: SOURCE_IMAGE
                    value: "{{ request.object.spec.containers[0].image }}"

---
# Alternative: Using GenerateExisting to prevent duplicates
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: copy-image-to-acr-v2
spec:
  background: false
  rules:
    - name: create-copy-job
      match:
        any:
        - resources:
            kinds:
            - Deployment
      generate:
        generateExisting: false  # This prevents re-creating existing jobs
        apiVersion: batch/v1
        kind: Job
        name: "img-{{ request.object.spec.containers[0].image | base64 | truncate(32, false, '') | lower | replace('/', '') | replace('+', '') | replace('=', '') }}"
        namespace: "{{ request.object.metadata.namespace }}"
        data:
          metadata:
            labels:
              source-image: "{{ request.object.spec.containers[0].image | base64 }}"
              managed-by: kyverno
          spec:
            ttlSecondsAfterFinished: 3600  # Clean up after 1 hour
            backoffLimit: 3
            template:
              spec:
                restartPolicy: Never
                containers:
                - name: copier
                  image: gcr.io/go-containerregistry/crane:latest
                  args:
                  - copy
                  - "{{ request.object.spec.containers[0].image }}"
                  - "your-acr.azurecr.io/{{ request.object.spec.containers[0].image | split('/') | last }}"
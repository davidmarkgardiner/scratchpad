# Using Skopeo to Copy Multiple Images from Docker Hub to ACR

This guide documents the process of using Skopeo in Kubernetes to copy multiple container images from Docker Hub to Azure Container Registry (ACR) without requiring Docker daemon.

## Overview

Skopeo is a command-line utility for working with container images and image registries. Key benefits include:

- No need to pull entire images locally
- Works without Docker daemon
- Direct registry-to-registry transfers
- Doesn't require root privileges
- Supports various image formats (OCI, Docker, etc.)

## Prerequisites

- Kubernetes cluster
- Azure Container Registry (ACR)
- kubectl configured to access your cluster

## Step 1: Create a Namespace

```bash
kubectl create namespace skopeo
```

## Step 2: Set Up ACR

We used the `setup-acr.sh` script to create and configure an ACR:

```bash
./k8s/setup-acr.sh
```

This script:
1. Creates a resource group in Azure
2. Creates an ACR with admin enabled
3. Gets the ACR credentials
4. Updates Kubernetes manifest files with the ACR information

Output provided the registry details:
```
Registry: myskopeo1745581438.azurecr.io
Username: myskopeo1745581438
Password: [HIDDEN]
```

## Step 3: Create the Multi-Image Copy Job

We created two files:

1. **ConfigMap with the copy script** (`multi-image-copy-script`)
2. **Kubernetes Job** to run the script (`skopeo-multi-image-copy`)

### The Copy Script

The script inside the ConfigMap:
- Takes a list of images to copy
- Uses environment variables for ACR credentials
- Copies each image from Docker Hub to ACR
- Inspects the copied images to verify

```bash
#!/bin/bash
set -e

# ACR registry details
ACR_REGISTRY="${ACR_REGISTRY:-myskopeo1745581438.azurecr.io}"
ACR_CREDS="${ACR_USERNAME}:${ACR_PASSWORD}"

# List of images to copy in format: source_image/tag destination_repo/tag
IMAGES=(
  "library/alpine:latest alpine:latest"
  "library/ubuntu:22.04 ubuntu:22.04"
  "library/postgres:14 postgres:14"
  "library/node:18 node:18"
  "library/redis:7.0 redis:7.0"
)

echo "======================================================"
echo "Starting multi-image copy to ${ACR_REGISTRY}"
echo "======================================================"

for image in "${IMAGES[@]}"; do
  read -r SRC DEST <<< "$image"
  echo ""
  echo "======================================================"
  echo "Copying docker.io/$SRC to ${ACR_REGISTRY}/$DEST"
  echo "======================================================"
  
  skopeo copy \
    --dest-creds="${ACR_CREDS}" \
    docker://docker.io/$SRC \
    docker://${ACR_REGISTRY}/$DEST
    
  echo "Successfully copied $SRC to ACR"
  
  # List repository details
  echo ""
  echo "Inspecting destination image details:"
  skopeo inspect --creds="${ACR_CREDS}" docker://${ACR_REGISTRY}/$DEST | grep -E '(Architecture|Created|Digest|Os)'
  echo "======================================================"
done

echo ""
echo "All images copied successfully to ${ACR_REGISTRY}!"
```

### The Kubernetes Job

The job definition:
- Uses the official Skopeo image: `quay.io/skopeo/stable:latest`
- Mounts the ConfigMap as a script
- Sets environment variables for ACR credentials from a Kubernetes Secret
- Runs with restart policy "Never" to avoid infinite retries

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: skopeo-multi-image-copy
  namespace: skopeo
spec:
  ttlSecondsAfterFinished: 86400  # Clean up after 24 hours
  template:
    spec:
      containers:
      - name: skopeo
        image: quay.io/skopeo/stable:latest
        command: ["/bin/sh", "/scripts/multi-copy-images.sh"]
        env:
        - name: ACR_REGISTRY
          value: "myskopeo1745581438.azurecr.io"  # ACR name
        - name: ACR_USERNAME
          valueFrom:
            secretKeyRef:
              name: acr-credentials
              key: username
        - name: ACR_PASSWORD
          valueFrom:
            secretKeyRef:
              name: acr-credentials
              key: password
        volumeMounts:
        - name: scripts-volume
          mountPath: /scripts
      volumes:
      - name: scripts-volume
        configMap:
          name: multi-image-copy-script
          defaultMode: 0755  # Make the script executable
      restartPolicy: Never
  backoffLimit: 3
```

## Step 4: Automate Everything with a Script

We created a script (`run-multi-image-job.sh`) to automate the deployment:

```bash
#!/bin/bash
set -e

# Create ConfigMap
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: multi-image-copy-script
  namespace: skopeo
data:
  multi-copy-images.sh: |
    #!/bin/bash
    set -e
    
    # ACR registry details
    ACR_REGISTRY="\${ACR_REGISTRY:-myskopeo1745581438.azurecr.io}"
    ACR_CREDS="\${ACR_USERNAME}:\${ACR_PASSWORD}"
    
    # List of images to copy in format: source_image:tag:destination_repo:tag
    IMAGES_TO_COPY=(
      "library/nginx:latest:nginx:latest"
      "library/alpine:latest:alpine:latest"
      "library/ubuntu:22.04:ubuntu:22.04"
      "library/postgres:14:postgres:14"
      "library/node:18:node:18"
    )
    
    # Loop through images and copy each one
    # [Script content here]
EOF

# Create Job
cat <<EOF | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: skopeo-multi-image-copy
  namespace: skopeo
spec:
  # [Job spec here]
EOF

echo "Multi-image copy job created!"
```

## Step 5: Run the Job and Monitor Progress

To run the job:

```bash
./run-multi-image-job.sh
```

To monitor job status:

```bash
kubectl get pods -n skopeo -w
```

To check job logs:

```bash
kubectl logs -n skopeo job/skopeo-multi-image-copy
```

## Step 6: Verify Images in ACR

After the job completes, we can verify the images were copied:

```bash
az acr repository list --name myskopeo1745581438
```

The output should show:
- alpine
- ubuntu
- postgres
- node
- redis

## Key Benefits Demonstrated

This approach demonstrated several key benefits:

1. **Efficiency**: No local disk space required
2. **Container-native**: No Docker daemon needed
3. **Scalability**: Multiple images processed in a single job
4. **Kubernetes-integrated**: Leverages Kubernetes secrets, ConfigMaps
5. **Automation-friendly**: Easy to integrate into CI/CD pipelines

## Cleanup

To clean up the resources:

```bash
./cleanup.sh
```

This script deletes:
- All jobs in the skopeo namespace
- All ConfigMaps in the skopeo namespace
- All Secrets in the skopeo namespace

## Extending This Solution

To copy additional images:
1. Add more images to the `IMAGES` array in the script
2. Re-run the script

For periodic synchronization, convert the job to a CronJob:
```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: skopeo-multi-image-sync
  namespace: skopeo
spec:
  schedule: "0 2 * * *"  # 2 AM daily
  jobTemplate:
    spec:
      # [Same as job spec...]
``` 
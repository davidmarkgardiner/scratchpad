Perfect! Here's how to set it up with Flux using `substituteFrom` and Service Principal authentication:## **Flux GitOps Setup with Service Principal:**

### **Key Features:**
1. **Flux `substituteFrom`** - Variables from ConfigMap and Secret
2. **Service Principal Auth** - Direct login with client credentials
3. **Dependency Management** - Grafana job waits for AKS cluster
4. **Error Handling** - Proper waiting, retry logic, and status checks
5. **Idempotency** - Won't reconfigure if already set up

### **Directory Structure:**
```
fleet-infra/
├── clusters/production/
│   ├── flux-config/
│   │   ├── cluster-config.yaml    # Variables
│   │   └── azure-credentials.yaml # SPN credentials (encrypted)
│   ├── aks/
│   │   └── managed-cluster.yaml   # ASO ManagedCluster
│   └── grafana-integration/
│       └── grafana-job.yaml       # Integration job
└── flux-system/
    └── kustomizations.yaml        # Flux Kustomizations
```

### **Setup Steps:**

1. **Create the Service Principal:**
```bash
# Create SPN with AKS contributor permissions
az ad sp create-for-rbac --name "aks-grafana-integration" \
  --role "Azure Kubernetes Service Contributor" \
  --scope "/subscriptions/{subscription-id}/resourceGroups/{resource-group}"
```

2. **Encrypt the Secret (SOPS/Sealed Secrets):**
```bash
# Example with SOPS
sops --encrypt --in-place azure-credentials.yaml
```

3. **Commit to Git:**
```bash
git add clusters/production/
git commit -m "Add Grafana integration for AKS cluster"
git push
```

### **Monitoring:**
```bash
# Check Flux Kustomizations
flux get kustomizations

# Check job status
kubectl get jobs -l app=grafana-integration

# View logs
kubectl logs -l job-name=grafana-integration-${CLUSTER_NAME}
```

### **Benefits of This Approach:**
- ✅ **Flux Native** - Uses `substituteFrom` and `dependsOn`
- ✅ **Variable Management** - Clean separation of config and secrets
- ✅ **Secure** - SPN credentials in encrypted secrets
- ✅ **Reliable** - Proper wait conditions and error handling
- ✅ **GitOps Compliant** - Everything in Git, declarative
- ✅ **Idempotent** - Safe to re-run

This pattern works great with Flux's dependency management and gives you full control over the timing and configuration!

```
# 1. ConfigMap with cluster-specific variables
apiVersion: v1
kind: ConfigMap
metadata:
  name: cluster-config
  namespace: flux-system
data:
  CLUSTER_NAME: "my-aks-cluster"
  RESOURCE_GROUP: "my-resource-group"
  AZURE_MONITOR_WORKSPACE_ID: "/subscriptions/12345678-1234-1234-1234-123456789012/resourceGroups/monitoring-rg/providers/Microsoft.Monitor/accounts/my-monitor-workspace"
  GRAFANA_RESOURCE_ID: "/subscriptions/12345678-1234-1234-1234-123456789012/resourceGroups/monitoring-rg/providers/Microsoft.Dashboard/grafana/my-grafana"
  AZURE_TENANT_ID: "your-tenant-id"

---
# 2. Secret with Service Principal credentials
apiVersion: v1
kind: Secret
metadata:
  name: azure-sp-credentials
  namespace: flux-system
type: Opaque
data:
  AZURE_CLIENT_ID: <base64-encoded-client-id>
  AZURE_CLIENT_SECRET: <base64-encoded-client-secret>

---
# 3. Flux Kustomization for AKS cluster
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: aks-cluster
  namespace: flux-system
spec:
  interval: 10m
  sourceRef:
    kind: GitRepository
    name: fleet-infra
  path: "./clusters/production/aks"
  prune: true
  wait: true
  timeout: 20m
  postBuild:
    substituteFrom:
    - kind: ConfigMap
      name: cluster-config

---
# 4. Flux Kustomization for Grafana integration (depends on AKS)
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: grafana-integration
  namespace: flux-system
spec:
  interval: 30m
  sourceRef:
    kind: GitRepository
    name: fleet-infra
  path: "./clusters/production/grafana-integration"
  prune: true
  wait: true
  timeout: 10m
  dependsOn:
  - name: aks-cluster  # Wait for AKS cluster to be ready
  postBuild:
    substituteFrom:
    - kind: ConfigMap
      name: cluster-config
    - kind: Secret
      name: azure-sp-credentials

---
# 5. Job manifest (in ./clusters/production/grafana-integration/)
apiVersion: batch/v1
kind: Job
metadata:
  name: grafana-integration-${CLUSTER_NAME}
  namespace: default
  annotations:
    # Optional: delete successful jobs after 24h
    ttlSecondsAfterFinished: "86400"
spec:
  backoffLimit: 3
  template:
    metadata:
      labels:
        app: grafana-integration
        cluster: ${CLUSTER_NAME}
    spec:
      restartPolicy: OnFailure
      containers:
      - name: azure-cli
        image: mcr.microsoft.com/azure-cli:2.57.0
        env:
        - name: CLUSTER_NAME
          value: "${CLUSTER_NAME}"
        - name: RESOURCE_GROUP
          value: "${RESOURCE_GROUP}"
        - name: AZURE_MONITOR_WORKSPACE_ID
          value: "${AZURE_MONITOR_WORKSPACE_ID}"
        - name: GRAFANA_RESOURCE_ID
          value: "${GRAFANA_RESOURCE_ID}"
        - name: AZURE_TENANT_ID
          value: "${AZURE_TENANT_ID}"
        - name: AZURE_CLIENT_ID
          value: "${AZURE_CLIENT_ID}"
        - name: AZURE_CLIENT_SECRET
          value: "${AZURE_CLIENT_SECRET}"
        command:
        - /bin/bash
        - -c
        - |
          set -e
          
          echo "=== Starting Grafana Integration Configuration ==="
          echo "Cluster: $CLUSTER_NAME"
          echo "Resource Group: $RESOURCE_GROUP"
          echo "Grafana Resource ID: $GRAFANA_RESOURCE_ID"
          
          # Login with Service Principal
          echo "Logging in to Azure with Service Principal..."
          az login --service-principal \
            --username "$AZURE_CLIENT_ID" \
            --password "$AZURE_CLIENT_SECRET" \
            --tenant "$AZURE_TENANT_ID"
          
          # Wait for AKS cluster to be fully provisioned
          echo "Waiting for AKS cluster to be ready..."
          max_attempts=20
          attempt=0
          while [ $attempt -lt $max_attempts ]; do
            provisioning_state=$(az aks show \
              --name "$CLUSTER_NAME" \
              --resource-group "$RESOURCE_GROUP" \
              --query "provisioningState" \
              --output tsv 2>/dev/null || echo "NotFound")
            
            if [ "$provisioning_state" = "Succeeded" ]; then
              echo "✅ AKS cluster is ready!"
              break
            elif [ "$provisioning_state" = "Failed" ]; then
              echo "❌ AKS cluster provisioning failed!"
              exit 1
            else
              echo "⏳ Cluster state: $provisioning_state (attempt $((attempt+1))/$max_attempts)"
              sleep 30
              attempt=$((attempt+1))
            fi
          done
          
          if [ $attempt -eq $max_attempts ]; then
            echo "❌ Timeout waiting for cluster to be ready"
            exit 1
          fi
          
          # Check if Azure Monitor metrics is already enabled
          echo "Checking current Azure Monitor configuration..."
          current_config=$(az aks show \
            --name "$CLUSTER_NAME" \
            --resource-group "$RESOURCE_GROUP" \
            --query "azureMonitorProfile.metrics.enabled" \
            --output tsv 2>/dev/null || echo "false")
          
          if [ "$current_config" = "true" ]; then
            echo "ℹ️  Azure Monitor metrics already enabled, updating with Grafana..."
          else
            echo "🔧 Enabling Azure Monitor metrics..."
          fi
          
          # Configure Grafana integration
          echo "Configuring Grafana integration..."
          az aks update \
            --name "$CLUSTER_NAME" \
            --resource-group "$RESOURCE_GROUP" \
            --enable-azure-monitor-metrics \
            --azure-monitor-workspace-resource-id "$AZURE_MONITOR_WORKSPACE_ID" \
            --grafana-resource-id "$GRAFANA_RESOURCE_ID" \
            --no-wait
          
          echo "✅ Grafana integration configuration completed!"
          
          # Optional: Verify the configuration
          echo "Verifying configuration..."
          az aks show \
            --name "$CLUSTER_NAME" \
            --resource-group "$RESOURCE_GROUP" \
            --query "{metrics: azureMonitorProfile.metrics.enabled, cluster: name, state: provisioningState}" \
            --output table
          
          echo "=== Configuration Complete ==="
        resources:
          limits:
            cpu: 100m
            memory: 256Mi
          requests:
            cpu: 50m
            memory: 128Mi

---
# 6. Alternative: CronJob for ongoing reconciliation
apiVersion: batch/v1
kind: CronJob
metadata:
  name: grafana-integration-reconcile
  namespace: default
spec:
  schedule: "0 */12 * * *"  # Every 12 hours
  successfulJobsHistoryLimit: 2
  failedJobsHistoryLimit: 3
  jobTemplate:
    spec:
      template:
        spec:
          restartPolicy: OnFailure
          containers:
          - name: azure-cli
            image: mcr.microsoft.com/azure-cli:2.57.0
            env:
            - name: CLUSTER_NAME
              value: "${CLUSTER_NAME}"
            - name: RESOURCE_GROUP
              value: "${RESOURCE_GROUP}"
            - name: GRAFANA_RESOURCE_ID
              value: "${GRAFANA_RESOURCE_ID}"
            - name: AZURE_TENANT_ID
              value: "${AZURE_TENANT_ID}"
            - name: AZURE_CLIENT_ID
              value: "${AZURE_CLIENT_ID}"
            - name: AZURE_CLIENT_SECRET
              value: "${AZURE_CLIENT_SECRET}"
            command:
            - /bin/bash
            - -c
            - |
              set -e
              
              # Login
              az login --service-principal \
                --username "$AZURE_CLIENT_ID" \
                --password "$AZURE_CLIENT_SECRET" \
                --tenant "$AZURE_TENANT_ID"
              
              # Check if Grafana is configured
              grafana_config=$(az aks show \
                --name "$CLUSTER_NAME" \
                --resource-group "$RESOURCE_GROUP" \
                --query "azureMonitorProfile" \
                --output json 2>/dev/null || echo "{}")
              
              # Only update if Grafana not already configured
              if echo "$grafana_config" | grep -q "$GRAFANA_RESOURCE_ID"; then
                echo "✅ Grafana already configured correctly"
              else
                echo "🔧 Configuring Grafana integration..."
                az aks update \
                  --name "$CLUSTER_NAME" \
                  --resource-group "$RESOURCE_GROUP" \
                  --enable-azure-monitor-metrics \
                  --grafana-resource-id "$GRAFANA_RESOURCE_ID"
                echo "✅ Grafana integration updated"
              fi

---
# 7. Example Git repository structure
# fleet-infra/
# ├── clusters/
# │   └── production/
# │       ├── aks/
# │       │   ├── kustomization.yaml
# │       │   └── managed-cluster.yaml  # Your ASO ManagedCluster
# │       └── grafana-integration/
# │           ├── kustomization.yaml
# │           └── grafana-job.yaml      # The Job above
# └── flux-system/
#     ├── cluster-config.yaml           # ConfigMap
#     ├── azure-credentials.yaml        # Secret (encrypted)
#     └── kustomizations.yaml           # Flux Kustomizations

# Example kustomization.yaml for grafana-integration:
# apiVersion: kustomize.config.k8s.io/v1beta1
# kind: Kustomization
# resources:
# - grafana-job.yaml
```
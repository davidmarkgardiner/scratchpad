# Cloudability AKS Metrics Agent Deployment

This repository contains the deployment manifests and documentation for deploying Cloudability metrics collection agents across AKS clusters using Azure Workload Identity.

## Repository Structure

```
cloudability-aks-metrics-keyvault/
├── README.md
├── docs/
│   ├── deployment-guide.md
│   ├── troubleshooting.md
│   └── security-guide.md
├── manifests/
│   ├── base/
│   │   ├── 1-namespace.yaml
│   │   ├── 2-serviceaccount.yaml
│   │   ├── 3-rbac.yaml
│   │   ├── 4-secrets.yaml
│   │   ├── 5-configmap.yaml
│   │   └── 6-deployment.yaml
│   └── overlays/
│       ├── dev/
│       ├── staging/
│       └── production/
├── scripts/
│   ├── deploy.sh
│   ├── setup-prerequisites.sh
│   └── validate-deployment.sh
└── examples/
    ├── cluster-specific-configs/
    └── environment-variables.env
```

## Quick Start

### Prerequisites

1. **AKS Cluster Requirements:**
   - OIDC Issuer enabled
   - Workload Identity enabled
   - Azure Key Vault CSI driver installed

2. **Azure Resources:**
   - Central storage account access
   - Azure Key Vault access
   - Managed Identity configured

3. **Network Connectivity:**
   - VNET connectivity to central FinOps infrastructure
   - Outbound internet access for Cloudability APIs

### Deployment Steps

1. **Clone Repository:**
   ```bash
   git clone <finops-gitlab-repo>/cloudability-aks-metrics-keyvault
   cd cloudability-aks-metrics-keyvault
   ```

2. **Set Environment Variables:**
   ```bash
   export CLUSTER_NAME="kd12345-we01"
   export AZURE_SUBSCRIPTION_ID="your-subscription-id"
   export AZURE_TENANT_ID="your-tenant-id"
   export AZURE_CLIENT_ID="your-managed-identity-client-id"
   export STORAGE_ACCOUNT_NAME="someblob"
   export KEY_VAULT_NAME="akv-AT12345-DEV-NEU-CLD"
   ```

3. **Run Prerequisites Setup:**
   ```bash
   ./scripts/setup-prerequisites.sh
   ```

4. **Deploy Cloudability Agent:**
   ```bash
   ./scripts/deploy.sh
   ```

5. **Validate Deployment:**
   ```bash
   ./scripts/validate-deployment.sh
   ```

---

## Deployment Manifests

### 1. Namespace Configuration

**File: `manifests/base/1-namespace.yaml`**

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: cldymetricsagent-${CLUSTER_SUFFIX}
  labels:
    name: cldymetricsagent-${CLUSTER_SUFFIX}
    app.kubernetes.io/name: cloudability-metrics
    app.kubernetes.io/component: metrics-collection
    app.kubernetes.io/managed-by: finops-engineering
  annotations:
    description: "Cloudability metrics collection namespace for cluster ${CLUSTER_NAME}"
    contact: "finops-engineering@company.com"
```

### 2. Service Account with Workload Identity

**File: `manifests/base/2-serviceaccount.yaml`**

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: cloudability-metrics-agent
  namespace: cldymetricsagent-${CLUSTER_SUFFIX}
  labels:
    app.kubernetes.io/name: cloudability-metrics
    app.kubernetes.io/component: service-account
    azure.workload.identity/use: "true"
  annotations:
    azure.workload.identity/client-id: "${AZURE_CLIENT_ID}"
    azure.workload.identity/tenant-id: "${AZURE_TENANT_ID}"
    description: "Service account for Cloudability metrics agent with workload identity"
automountServiceAccountToken: true
```

### 3. RBAC Configuration

**File: `manifests/base/3-rbac.yaml`**

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: cloudability-metrics-reader-${CLUSTER_SUFFIX}
  labels:
    app.kubernetes.io/name: cloudability-metrics
    app.kubernetes.io/component: rbac
rules:
  # Core resources for metrics collection
  - apiGroups: [""]
    resources: 
      - nodes
      - nodes/metrics
      - nodes/stats
      - pods
      - pods/status
      - services
      - endpoints
      - persistentvolumes
      - persistentvolumeclaims
      - namespaces
      - resourcequotas
      - limitranges
    verbs: ["get", "list", "watch"]
  
  # Apps and extensions
  - apiGroups: ["apps"]
    resources:
      - deployments
      - replicasets
      - statefulsets
      - daemonsets
    verbs: ["get", "list", "watch"]
  
  # Metrics APIs
  - apiGroups: ["metrics.k8s.io"]
    resources: ["nodes", "pods"]
    verbs: ["get", "list"]
  
  # Custom metrics (if available)
  - apiGroups: ["custom.metrics.k8s.io"]
    resources: ["*"]
    verbs: ["get", "list"]
  
  # Autoscaling
  - apiGroups: ["autoscaling"]
    resources: ["horizontalpodautoscalers"]
    verbs: ["get", "list", "watch"]

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: cloudability-metrics-reader-${CLUSTER_SUFFIX}
  labels:
    app.kubernetes.io/name: cloudability-metrics
    app.kubernetes.io/component: rbac
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cloudability-metrics-reader-${CLUSTER_SUFFIX}
subjects:
  - kind: ServiceAccount
    name: cloudability-metrics-agent
    namespace: cldymetricsagent-${CLUSTER_SUFFIX}

---
# Namespace-specific role for local operations
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: cloudability-metrics-operator
  namespace: cldymetricsagent-${CLUSTER_SUFFIX}
  labels:
    app.kubernetes.io/name: cloudability-metrics
    app.kubernetes.io/component: rbac
rules:
  - apiGroups: [""]
    resources: ["secrets", "configmaps"]
    verbs: ["get", "list", "watch"]
  - apiGroups: [""]
    resources: ["events"]
    verbs: ["create", "patch"]

---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: cloudability-metrics-operator
  namespace: cldymetricsagent-${CLUSTER_SUFFIX}
  labels:
    app.kubernetes.io/name: cloudability-metrics
    app.kubernetes.io/component: rbac
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: cloudability-metrics-operator
subjects:
  - kind: ServiceAccount
    name: cloudability-metrics-agent
    namespace: cldymetricsagent-${CLUSTER_SUFFIX}
```

### 4. Secrets Management with Key Vault

**File: `manifests/base/4-secrets.yaml`**

```yaml
# SecretProviderClass for Azure Key Vault integration
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: cloudability-keyvault-secrets
  namespace: cldymetricsagent-${CLUSTER_SUFFIX}
  labels:
    app.kubernetes.io/name: cloudability-metrics
    app.kubernetes.io/component: secrets
spec:
  provider: azure
  parameters:
    usePodIdentity: "false"
    useVMManagedIdentity: "false"
    userAssignedIdentityID: "${AZURE_CLIENT_ID}"  # This will be replaced with actual managed identity ID
    keyvaultName: "${KEY_VAULT_NAME}"
    tenantId: "${AZURE_TENANT_ID}"
    objects: |
      array:
        - |
          objectName: cloudability-api-key
          objectType: secret
          objectVersion: ""
        - |
          objectName: SVC-SAML-DEV-AT12345-CLDY-client-secret
          objectType: secret
          objectVersion: ""
  secretObjects:
    - secretName: cloudability-credentials
      type: Opaque
      data:
        - objectName: cloudability-api-key
          key: api-key
        - objectName: SVC-SAML-DEV-AT12345-CLDY-client-secret
          key: spn-client-secret

---
# Fallback secret for manual credential management (if needed)
apiVersion: v1
kind: Secret
metadata:
  name: cloudability-fallback-credentials
  namespace: cldymetricsagent-${CLUSTER_SUFFIX}
  labels:
    app.kubernetes.io/name: cloudability-metrics
    app.kubernetes.io/component: secrets
  annotations:
    description: "Fallback credentials - should be populated manually if Key Vault integration fails"
type: Opaque
data:
  # These should be base64 encoded values
  # api-key: <base64-encoded-api-key>
  # spn-client-secret: <base64-encoded-spn-secret>
```

### 5. Configuration Management

**File: `manifests/base/5-configmap.yaml`**

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: cloudability-config
  namespace: cldymetricsagent-${CLUSTER_SUFFIX}
  labels:
    app.kubernetes.io/name: cloudability-metrics
    app.kubernetes.io/component: configuration
data:
  cluster-name: "${CLUSTER_NAME}"
  azure-tenant-id: "${AZURE_TENANT_ID}"
  azure-subscription-id: "${AZURE_SUBSCRIPTION_ID}"
  storage-account-name: "${STORAGE_ACCOUNT_NAME}"
  storage-container-name: "metrics-data"
  collection-interval: "300" # 5 minutes
  upload-interval: "3600"    # 1 hour
  log-level: "INFO"
  
  # Cloudability specific configuration
  config.yaml: |
    cloudability:
      api_endpoint: "https://api.cloudability.com"
      cluster_name: "${CLUSTER_NAME}"
      collection:
        enabled: true
        interval_seconds: 300
        batch_size: 1000
        
    azure:
      tenant_id: "${AZURE_TENANT_ID}"
      subscription_id: "${AZURE_SUBSCRIPTION_ID}"
      storage:
        account_name: "${STORAGE_ACCOUNT_NAME}"
        container_name: "metrics-data"
        connection_type: "managed_identity"
        
    metrics:
      collect:
        - "node_metrics"
        - "pod_metrics"
        - "container_metrics"
        - "resource_utilization"
        - "cost_allocation"
      
    logging:
      level: "INFO"
      format: "json"
      
    health:
      port: 8080
      path: "/health"

---
apiVersion: v1
kind: ConfigMap
metadata:
  name: cloudability-scripts
  namespace: cldymetricsagent-${CLUSTER_SUFFIX}
  labels:
    app.kubernetes.io/name: cloudability-metrics
    app.kubernetes.io/component: scripts
data:
  health-check.sh: |
    #!/bin/bash
    set -e
    
    # Check if agent is responsive
    curl -f http://localhost:8080/health || exit 1
    
    # Check if metrics collection is working
    if [ -f /tmp/last_collection ]; then
      LAST_COLLECTION=$(cat /tmp/last_collection)
      CURRENT_TIME=$(date +%s)
      DIFF=$((CURRENT_TIME - LAST_COLLECTION))
      
      # Alert if no collection in last 10 minutes
      if [ $DIFF -gt 600 ]; then
        echo "Metrics collection appears stalled"
        exit 1
      fi
    fi
    
    echo "Health check passed"
  
  startup.sh: |
    #!/bin/bash
    set -e
    
    echo "Starting Cloudability metrics agent..."
    echo "Cluster: ${CLUSTER_NAME}"
    echo "Namespace: ${POD_NAMESPACE}"
    
    # Validate required environment variables
    required_vars=("CLUSTER_NAME" "AZURE_TENANT_ID" "AZURE_SUBSCRIPTION_ID" "STORAGE_ACCOUNT_NAME")
    for var in "${required_vars[@]}"; do
      if [ -z "${!var}" ]; then
        echo "Error: Required environment variable $var is not set"
        exit 1
      fi
    done
    
    # Start the metrics agent
    exec /usr/local/bin/cloudability-agent
```

### 6. Deployment Configuration

**File: `manifests/base/6-deployment.yaml`**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cloudability-metrics-agent
  namespace: cldymetricsagent-${CLUSTER_SUFFIX}
  labels:
    app.kubernetes.io/name: cloudability-metrics
    app.kubernetes.io/component: agent
    app.kubernetes.io/version: "latest"
spec:
  replicas: 1  # Single replica for metrics collection
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 0
      maxSurge: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: cloudability-metrics
      app.kubernetes.io/component: agent
  template:
    metadata:
      labels:
        app.kubernetes.io/name: cloudability-metrics
        app.kubernetes.io/component: agent
        azure.workload.identity/use: "true"
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "8080"
        prometheus.io/path: "/metrics"
    spec:
      serviceAccountName: cloudability-metrics-agent
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        runAsGroup: 1000
        fsGroup: 1000
      
      containers:
      - name: metrics-agent
        image: cloudability/metrics-agent:latest
        imagePullPolicy: Always
        
        env:
        # Cluster identification
        - name: CLUSTER_NAME
          valueFrom:
            configMapKeyRef:
              name: cloudability-config
              key: cluster-name
        
        - name: POD_NAMESPACE
          valueFrom:
            fieldRef:
              fieldPath: metadata.namespace
        
        - name: POD_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        
        - name: NODE_NAME
          valueFrom:
            fieldRef:
              fieldPath: spec.nodeName
        
        # Azure configuration
        - name: AZURE_CLIENT_ID
          value: "${AZURE_CLIENT_ID}"
        
        - name: AZURE_TENANT_ID
          valueFrom:
            configMapKeyRef:
              name: cloudability-config
              key: azure-tenant-id
        
        - name: AZURE_SUBSCRIPTION_ID
          valueFrom:
            configMapKeyRef:
              name: cloudability-config
              key: azure-subscription-id
        
        # Storage configuration
        - name: STORAGE_ACCOUNT_NAME
          valueFrom:
            configMapKeyRef:
              name: cloudability-config
              key: storage-account-name
        
        - name: STORAGE_CONTAINER_NAME
          valueFrom:
            configMapKeyRef:
              name: cloudability-config
              key: storage-container-name
        
        # Credentials from Key Vault
        - name: CLOUDABILITY_API_KEY
          valueFrom:
            secretKeyRef:
              name: cloudability-credentials
              key: api-key
        
        - name: SPN_CLIENT_SECRET
          valueFrom:
            secretKeyRef:
              name: cloudability-credentials
              key: spn-client-secret
        
        # Collection configuration
        - name: COLLECTION_INTERVAL
          valueFrom:
            configMapKeyRef:
              name: cloudability-config
              key: collection-interval
        
        - name: UPLOAD_INTERVAL
          valueFrom:
            configMapKeyRef:
              name: cloudability-config
              key: upload-interval
        
        - name: LOG_LEVEL
          valueFrom:
            configMapKeyRef:
              name: cloudability-config
              key: log-level
        
        ports:
        - name: http-metrics
          containerPort: 8080
          protocol: TCP
        
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
            ephemeral-storage: 1Gi
          limits:
            cpu: 500m
            memory: 512Mi
            ephemeral-storage: 2Gi
        
        livenessProbe:
          httpGet:
            path: /health
            port: http-metrics
          initialDelaySeconds: 30
          periodSeconds: 30
          timeoutSeconds: 10
          failureThreshold: 3
        
        readinessProbe:
          httpGet:
            path: /ready
            port: http-metrics
          initialDelaySeconds: 10
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
        
        volumeMounts:
        # Host filesystem mounts for metrics collection
        - name: proc
          mountPath: /host/proc
          readOnly: true
        
        - name: sys
          mountPath: /host/sys
          readOnly: true
        
        - name: docker-sock
          mountPath: /var/run/docker.sock
          readOnly: true
        
        # Configuration mounts
        - name: config-volume
          mountPath: /etc/cloudability
          readOnly: true
        
        - name: scripts-volume
          mountPath: /scripts
          readOnly: true
        
        # Key Vault secrets mount
        - name: keyvault-secrets
          mountPath: /mnt/secrets
          readOnly: true
        
        # Temporary storage for metrics processing
        - name: temp-storage
          mountPath: /tmp/metrics
        
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop:
            - ALL
            add:
            - NET_BIND_SERVICE
      
      # Node affinity to ensure single deployment per cluster
      affinity:
        nodeAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            preference:
              matchExpressions:
              - key: kubernetes.io/arch
                operator: In
                values:
                - amd64
        
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchExpressions:
              - key: app.kubernetes.io/name
                operator: In
                values:
                - cloudability-metrics
            topologyKey: "kubernetes.io/hostname"
      
      tolerations:
      - key: "node.kubernetes.io/not-ready"
        operator: "Exists"
        effect: "NoExecute"
        tolerationSeconds: 300
      - key: "node.kubernetes.io/unreachable"
        operator: "Exists"
        effect: "NoExecute"
        tolerationSeconds: 300
      
      volumes:
      # Host filesystem access
      - name: proc
        hostPath:
          path: /proc
          type: Directory
      
      - name: sys
        hostPath:
          path: /sys
          type: Directory
      
      - name: docker-sock
        hostPath:
          path: /var/run/docker.sock
          type: Socket
      
      # Configuration volumes
      - name: config-volume
        configMap:
          name: cloudability-config
          items:
          - key: config.yaml
            path: config.yaml
      
      - name: scripts-volume
        configMap:
          name: cloudability-scripts
          defaultMode: 0755
      
      # Key Vault secrets
      - name: keyvault-secrets
        csi:
          driver: secrets-store.csi.k8s.io
          readOnly: true
          volumeAttributes:
            secretProviderClass: cloudability-keyvault-secrets
      
      # Temporary storage
      - name: temp-storage
        emptyDir:
          sizeLimit: 1Gi

---
# Service for metrics exposure (optional)
apiVersion: v1
kind: Service
metadata:
  name: cloudability-metrics-service
  namespace: cldymetricsagent-${CLUSTER_SUFFIX}
  labels:
    app.kubernetes.io/name: cloudability-metrics
    app.kubernetes.io/component: service
spec:
  type: ClusterIP
  ports:
  - name: http-metrics
    port: 8080
    targetPort: http-metrics
    protocol: TCP
  selector:
    app.kubernetes.io/name: cloudability-metrics
    app.kubernetes.io/component: agent
```

---

## Deployment Scripts

### Setup Prerequisites Script

**File: `scripts/setup-prerequisites.sh`**

```bash
#!/bin/bash
set -e

# setup-prerequisites.sh
# Sets up prerequisites for Cloudability deployment

echo "=== Cloudability AKS Prerequisites Setup ==="

# Source environment variables
if [ -f "examples/environment-variables.env" ]; then
    source examples/environment-variables.env
else
    echo "Error: environment-variables.env not found"
    exit 1
fi

# Validate required variables
required_vars=(
    "CLUSTER_NAME"
    "AZURE_SUBSCRIPTION_ID" 
    "AZURE_TENANT_ID"
    "AZURE_CLIENT_ID"
    "STORAGE_ACCOUNT_NAME"
    "KEY_VAULT_NAME"
)

for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        echo "Error: Required environment variable $var is not set"
        exit 1
    fi
done

echo "✓ Environment variables validated"

# Get AKS managed identity
echo "Getting AKS managed identity..."
MGD_IDTY_ID=$(az aks show \
    --resource-group "${RESOURCE_GROUP}" \
    --name "${CLUSTER_NAME}" \
    --query addonProfiles.azureKeyvaultSecretsProvider.identity.objectId \
    -o tsv)

if [ -z "$MGD_IDTY_ID" ]; then
    echo "Error: Could not retrieve AKS managed identity"
    echo "Ensure Key Vault CSI driver is enabled on the cluster"
    exit 1
fi

echo "✓ AKS Managed Identity ID: $MGD_IDTY_ID"

# Update secrets.yaml with the managed identity ID
sed -i "s/\${AZURE_CLIENT_ID}/$MGD_IDTY_ID/g" manifests/base/4-secrets.yaml
echo "✓ Updated secrets.yaml with managed identity ID"

# Verify Key Vault access
echo "Verifying Key Vault access..."
az keyvault secret list --vault-name "${KEY_VAULT_NAME}" --query "length(@)" -o tsv > /dev/null
echo "✓ Key Vault access verified"

# Verify storage account access  
echo "Verifying storage account access..."
az storage account show --name "${STORAGE_ACCOUNT_NAME}" --query "name" -o tsv > /dev/null
echo "✓ Storage account access verified"

# Check network connectivity (basic test)
echo "Testing network connectivity..."
az storage blob list \
    --account-name "${STORAGE_ACCOUNT_NAME}" \
    --container-name "metrics-data" \
    --auth-mode login \
    --query "length(@)" -o tsv > /dev/null 2>&1 || echo "Warning: Could not list blobs - container may not exist yet"

echo "✓ Prerequisites setup completed successfully"
```

### Deployment Script

**File: `scripts/deploy.sh`**

```bash
#!/bin/bash
set -e

# deploy.sh
# Deploys Cloudability metrics agent to AKS cluster

echo "=== Cloudability AKS Deployment ==="

# Source environment variables
if [ -f "examples/environment-variables.env" ]; then
    source examples/environment-variables.env
else
    echo "Error: environment-variables.env not found"
    exit 1
fi

# Set cluster suffix from cluster name
export CLUSTER_SUFFIX=$(echo "${CLUSTER_NAME}" | tr '[:upper:]' '[:lower:]')

echo "Deploying to cluster: ${CLUSTER_NAME}"
echo "Using namespace suffix: ${CLUSTER_SUFFIX}"

# Function to apply manifest with variable substitution
apply_manifest() {
    local file=$1
    echo "Applying $(basename $file)..."
    
    envsubst < "$file" | kubectl apply -f -
}

# Deploy in order
echo "1. Creating namespace..."
apply_manifest "manifests/base/1-namespace.yaml"

echo "2. Creating service account..."
apply_manifest "manifests/base/2-serviceaccount.yaml"

echo "3. Setting up RBAC..."
apply_manifest "manifests/base/3-rbac.yaml"

echo "4. Configuring secrets..."
apply_manifest "manifests/base/4-secrets.yaml"

echo "5. Creating configuration..."
apply_manifest "manifests/base/5-configmap.yaml"

echo "6. Deploying metrics agent..."
apply_manifest "manifests/base/6-deployment.yaml"

# Wait for deployment to be ready
echo "Waiting for deployment to be ready..."
kubectl wait --for=condition=available \
    --timeout=300s \
    deployment/cloudability-metrics-agent \
    -n "cldymetricsagent-${CLUSTER_SUFFIX}"

echo "✓ Deployment completed successfully"

# Show deployment status
echo ""
echo "=== Deployment Status ==="
kubectl get all -n "cldymetricsagent-${CLUSTER_SUFFIX}"

echo ""
echo "=== Pod Logs ==="
kubectl logs -n "cldymetricsagent-${CLUSTER_SUFFIX}" \
    -l app.kubernetes.io/name=cloudability-metrics \
    --tail=20
```

### Validation Script

**File: `scripts/validate-deployment.sh`**

```bash
#!/bin/bash
set -e

# validate-deployment.sh  
# Validates Cloudability deployment health and connectivity

echo "=== Cloudability Deployment Validation ==="

# Source environment variables
if [ -f "examples/environment-variables.env" ]; then
    source examples/environment-variables.env
else
    echo "Error: environment-variables.env not found"
    exit 1
fi

export CLUSTER_SUFFIX=$(echo "${CLUSTER_NAME}" | tr '[:upper:]' '[:lower:]')
export NAMESPACE="cldymetricsagent-${CLUSTER_SUFFIX}"

echo "Validating deployment in namespace: ${NAMESPACE}"

# Check if namespace exists
if ! kubectl get namespace "${NAMESPACE}" > /dev/null 2>&1; then
    echo "❌ Namespace ${NAMESPACE} not found"
    exit 1
fi
echo "✓ Namespace exists"

# Check deployment status
if ! kubectl get deployment cloudability-metrics-agent -n "${NAMESPACE}" > /dev/null 2>&1; then
    echo "❌ Deployment not found"
    exit 1
fi

READY_REPLICAS=$(kubectl get deployment cloudability-metrics-agent -n "${NAMESPACE}" -o jsonpath='{.status.readyReplicas}')
DESIRED_REPLICAS=$(kubectl get deployment cloudability-metrics-agent -n "${NAMESPACE}" -o jsonpath='{.spec.replicas}')

if [ "$READY_REPLICAS" != "$DESIRED_REPLICAS" ]; then
    echo "❌ Deployment not ready: ${READY_REPLICAS}/${DESIRED_REPLICAS} replicas ready"
    exit 1
fi
echo "✓ Deployment ready: ${READY_REPLICAS}/${DESIRED_REPLICAS} replicas"

# Check pod status
POD_NAME=$(kubectl get pods -n "${NAMESPACE}" -l app.kubernetes.io/name=cloudability-metrics -o jsonpath='{.items[0].metadata.name}')
POD_STATUS=$(kubectl get pod "${POD_NAME}" -n "${NAMESPACE}" -o jsonpath='{.status.phase}')

if [ "$POD_STATUS" != "Running" ]; then
    echo "❌ Pod not running: ${POD_STATUS}"
    kubectl describe pod "${POD_NAME}" -n "${NAMESPACE}"
    exit 1
fi
echo "✓ Pod running: ${POD_NAME}"

# Check health endpoint
echo "Checking health endpoint..."
kubectl port-forward -n "${NAMESPACE}" "${POD_NAME}" 8080:8080 &
PORT_FORWARD_PID=$!
sleep 5

if curl -f http://localhost:8080/health > /dev/null 2>&1; then
    echo "✓ Health endpoint responding"
else
    echo "❌ Health endpoint not responding"
    kill $PORT_FORWARD_PID 2>/dev/null || true
    exit 1
fi

kill $PORT_FORWARD_PID 2>/dev/null || true

# Check secret access
echo "Validating secret access..."
kubectl exec -n "${NAMESPACE}" "${POD_NAME}" -- test -f /mnt/secrets/api-key
if [ $? -eq 0 ]; then
    echo "✓ Key Vault secrets accessible"
else
    echo "❌ Key Vault secrets not accessible"
    exit 1
fi

# Check Azure authentication
echo "Validating Azure authentication..."
kubectl exec -n "${NAMESPACE}" "${POD_NAME}" -- \
    curl -s -H "Metadata: true" \
    "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://storage.azure.com/" > /dev/null

if [ $? -eq 0 ]; then
    echo "✓ Azure workload identity authentication working"
else
    echo "❌ Azure workload identity authentication failed"
    exit 1
fi

# Check recent logs for errors
echo "Checking recent logs for errors..."
ERROR_COUNT=$(kubectl logs -n "${NAMESPACE}" "${POD_NAME}" --tail=50 | grep -i error | wc -l)
if [ "$ERROR_COUNT" -gt 0 ]; then
    echo "⚠️  Found ${ERROR_COUNT} error(s) in recent logs"
    kubectl logs -n "${NAMESPACE}" "${POD_NAME}" --tail=50 | grep -i error
else
    echo "✓ No errors in recent logs"
fi

echo ""
echo "=== Validation Summary ==="
echo "✓ Namespace: ${NAMESPACE}"
echo "✓ Deployment: cloudability-metrics-agent"  
echo "✓ Pod: ${POD_NAME}"
echo "✓ Health endpoint accessible"
echo "✓ Secrets accessible"
echo "✓ Azure authentication working"
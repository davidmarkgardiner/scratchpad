You're absolutely right! The `containerInsights` configuration is separate from the `metrics` configuration and provides additional monitoring capabilities. Let me update the examples to include both:Yes, absolutely! You need both configurations for complete Azure Monitor coverage:

## Two Types of Azure Monitor Configuration:

### 1. **Prometheus Metrics** (`metrics`)
- Collects Kubernetes infrastructure metrics
- Sends metrics to Azure Monitor Workspace
- Equivalent to `--enable-azure-monitor-metrics` CLI flag

### 2. **Container Insights** (`containerInsights`)
- Collects container logs, events, and performance data
- Sends data to Log Analytics Workspace
- Equivalent to `--enable-addons monitoring` CLI flag

## For ASO, you can also reference the Log Analytics Workspace using a resource reference:

```yaml
azureMonitorProfile:
  containerInsights:
    enabled: true
    # Option 1: Direct resource ID (as shown above)
    logAnalyticsWorkspaceResourceId: "/subscriptions/.../workspaces/my-workspace"
    
    # Option 2: Using ASO resource reference (if workspace is managed by ASO)
    # logAnalyticsWorkspaceResourceReference:
    #   name: my-log-analytics-workspace
    #   namespace: default
    
    disableCustomMetrics: false
    disablePrometheusMetricsScraping: false
    syslogPort: 28330
```

## Complete Configuration Benefits:

- **`metrics`**: Prometheus-style metrics for monitoring and alerting
- **`containerInsights`**: Detailed container logs, performance counters, and inventory data
- **Together**: Provides comprehensive observability for your AKS cluster

Both configurations work together to give you the full Azure Monitor experience that you'd get from using both CLI flags: `--enable-azure-monitor-metrics` and `--enable-addons monitoring`.


---

```
# Azure Service Operator (ASO) Configuration
apiVersion: containerservice.azure.com/v1api20240901
kind: ManagedCluster
metadata:
  name: my-aks-cluster
  namespace: default
spec:
  location: eastus
  owner:
    name: my-resource-group
  dnsPrefix: myakscluster
  kubernetesVersion: "1.28"
  
  # Azure Monitor Profile Configuration (Complete)
  azureMonitorProfile:
    # Prometheus Metrics Configuration
    metrics:
      enabled: true
      kubeStateMetrics:
        metricLabelsAllowlist: "namespaces=[k8s-label-1,k8s-label-n]"
        metricAnnotationsAllowList: "pods=[k8s-annotation-1,k8s-annotation-n]"
    
    # Container Insights Configuration
    containerInsights:
      enabled: true
      logAnalyticsWorkspaceResourceId: "/subscriptions/{subscription-id}/resourceGroups/{rg}/providers/Microsoft.OperationalInsights/workspaces/{workspace-name}"
      disableCustomMetrics: false
      disablePrometheusMetricsScraping: false
      syslogPort: 28330
  
  # Agent Pool Configuration
  agentPoolProfiles:
    - name: nodepool1
      count: 3
      vmSize: Standard_DS2_v2
      mode: System
      osType: Linux
      osSKU: Ubuntu

  # Identity Configuration
  identity:
    type: SystemAssigned

---
# ARM Template Equivalent (for comparison)
# {
#   "type": "Microsoft.ContainerService/managedClusters",
#   "apiVersion": "2025-05-02-preview",
#   "name": "[parameters('clusterName')]",
#   "location": "[parameters('location')]",
#   "properties": {
#     "dnsPrefix": "[parameters('dnsPrefix')]",
#     "kubernetesVersion": "[parameters('kubernetesVersion')]",
#     "agentPoolProfiles": [
#       {
#         "name": "nodepool1",
#         "count": 3,
#         "vmSize": "Standard_DS2_v2",
#         "mode": "System"
#       }
#     ],
#     "azureMonitorProfile": {
#       "metrics": {
#         "enabled": true,
#         "kubeStateMetrics": {
#           "metricLabelsAllowlist": "namespaces=[k8s-label-1,k8s-label-n]",
#           "metricAnnotationsAllowList": "pods=[k8s-annotation-1,k8s-annotation-n]"
#         }
#       },
#       "containerInsights": {
#         "enabled": true,
#         "logAnalyticsWorkspaceResourceId": "[parameters('logAnalyticsWorkspaceResourceId')]",
#         "disableCustomMetrics": false,
#         "disablePrometheusMetricsScraping": false,
#         "syslogPort": 28330
#       }
#     }
#   }
# }
```


```

# Azure Service Operator (ASO) Configuration
apiVersion: containerservice.azure.com/v1api20240901
kind: ManagedCluster
metadata:
  name: my-aks-cluster
  namespace: default
spec:
  location: eastus
  owner:
    name: my-resource-group
  dnsPrefix: myakscluster
  kubernetesVersion: "1.28"
  
  # Azure Monitor Profile Configuration (Prometheus Metrics Only)
  azureMonitorProfile:
    metrics:
      enabled: true
      kubeStateMetrics:
        metricLabelsAllowlist: "namespaces=[k8s-label-1,k8s-label-n]"
        metricAnnotationsAllowList: "pods=[k8s-annotation-1,k8s-annotation-n]"
  
  # Container Insights must be configured via addonProfiles
  addonProfiles:
    omsagent:
      enabled: true
      config:
        logAnalyticsWorkspaceResourceID: "/subscriptions/{subscription-id}/resourceGroups/{rg}/providers/Microsoft.OperationalInsights/workspaces/{workspace-name}"
  
  # Agent Pool Configuration
  agentPoolProfiles:
    - name: nodepool1
      count: 3
      vmSize: Standard_DS2_v2
      mode: System
      osType: Linux
      osSKU: Ubuntu

  # Identity Configuration
  identity:
    type: SystemAssigned

---
# ARM Template Equivalent (for comparison)
# {
#   "type": "Microsoft.ContainerService/managedClusters",
#   "apiVersion": "2025-05-02-preview",
#   "name": "[parameters('clusterName')]",
#   "location": "[parameters('location')]",
#   "properties": {
#     "dnsPrefix": "[parameters('dnsPrefix')]",
#     "kubernetesVersion": "[parameters('kubernetesVersion')]",
#     "agentPoolProfiles": [
#       {
#         "name": "nodepool1",
#         "count": 3,
#         "vmSize": "Standard_DS2_v2",
#         "mode": "System"
#       }
#     ],
#     "azureMonitorProfile": {
#       "metrics": {
#         "enabled": true,
#         "kubeStateMetrics": {
#           "metricLabelsAllowlist": "namespaces=[k8s-label-1,k8s-label-n]",
#           "metricAnnotationsAllowList": "pods=[k8s-annotation-1,k8s-annotation-n]"
#         }
#       },
#       "containerInsights": {
#         "enabled": true,
#         "logAnalyticsWorkspaceResourceId": "[parameters('logAnalyticsWorkspaceResourceId')]",
#         "disableCustomMetrics": false,
#         "disablePrometheusMetricsScraping": false,
#         "syslogPort": 28330
#       }
#     }
#   }
# }
```
I'll create a complete working example using Kustomize replacements for your AKS cluster configuration.

1. Base template (base/cluster-template/managed-cluster.yaml):
```yaml
apiVersion: containerservice.azure.com/v1api20240901
kind: ManagedCluster
metadata:
  name: placeholder-name  # Will be replaced
  namespace: default
spec:
  location: placeholder-location  # Will be replaced
  owner:
    name: placeholder-rg  # Will be replaced
  dnsPrefix: placeholder-prefix  # Will be replaced
  kubernetesVersion: "1.28.3"  # Will be replaced
  identity:
    type: UserAssigned
    userAssignedIdentities:
    - reference:
        armId: placeholder-identity  # Will be replaced
  aadProfile:
    enableAzureRBAC: true
    managed: true
    adminGroupObjectIDs:
    - placeholder-admin-group  # Will be replaced
  enableRBAC: true
  disableLocalAccounts: true
  networkProfile:
    networkPlugin: azure
    networkPluginMode: overlay
    networkPolicy: cilium
    networkDataplane: cilium
    serviceCidr: placeholder-service-cidr  # Will be replaced
    dnsServiceIP: placeholder-dns-ip  # Will be replaced
    podCidr: placeholder-pod-cidr  # Will be replaced
    ipFamilies: ["IPv4"]
    loadBalancerSku: standard
  agentPoolProfiles:
  - name: sysnpl1
    mode: System
    count: 1  # Will be replaced
    minCount: 1  # Will be replaced
    maxCount: 1  # Will be replaced
    enableAutoScaling: true
    vmSize: placeholder-vmsize  # Will be replaced
    availabilityZones: ["1"]
    osDiskType: Managed
    osDiskSizeGB: 128
    osType: Linux
    osSKU: Ubuntu
    maxPods: 30
    nodeTaints:
    - CriticalAddonsOnly=true:NoSchedule
```

2. Base kustomization (base/cluster-template/kustomization.yaml):
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- managed-cluster.yaml

labels:
- pairs:
    app.kubernetes.io/managed-by: azure-service-operator
```

3. Dev values (clusters/dev/values.yaml):
```yaml
CLUSTER_NAME: dev-aks-01
LOCATION: eastus2
SUBSCRIPTION_ID: your-sub-id
RESOURCE_GROUP: rg-aks-dev
DNS_PREFIX: dev-aks-01
K8S_VERSION: 1.28.3
USER_ASSIGNED_IDENTITY_NAME: dev-aks-identity
ADMIN_GROUP_ID: your-admin-group-id

NETWORK:
  SERVICE_CIDR: 172.16.0.0/16
  DNS_SERVICE_IP: 172.16.0.10
  POD_CIDR: 10.244.0.0/16

SYSTEM_NODEPOOL:
  VM_SIZE: Standard_D4s_v3
  COUNT: 1
  MIN_COUNT: 1
  MAX_COUNT: 2
  MAX_PODS: 30

USER_NODEPOOL:
  VM_SIZE: Standard_D4s_v3
  COUNT: 1
  MIN_COUNT: 1
  MAX_COUNT: 3
  MAX_PODS: 30
```

4. Dev kustomization (clusters/dev/kustomization.yaml):
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: default
namePrefix: dev-

resources:
- ../../base/cluster-template

configMapGenerator:
- name: cluster-config
  files:
  - values.yaml

replacements:
- source:
    kind: ConfigMap
    name: cluster-config
    fieldPath: data.CLUSTER_NAME
  targets:
  - select:
      kind: ManagedCluster
    fieldPaths:
    - metadata.name
    - spec.dnsPrefix

- source:
    kind: ConfigMap
    name: cluster-config
    fieldPath: data.LOCATION
  targets:
  - select:
      kind: ManagedCluster
    fieldPaths:
    - spec.location

- source:
    kind: ConfigMap
    name: cluster-config
    fieldPath: data.RESOURCE_GROUP
  targets:
  - select:
      kind: ManagedCluster
    fieldPaths:
    - spec.owner.name

- source:
    kind: ConfigMap
    name: cluster-config
    fieldPath: data.K8S_VERSION
  targets:
  - select:
      kind: ManagedCluster
    fieldPaths:
    - spec.kubernetesVersion

- source:
    kind: ConfigMap
    name: cluster-config
    fieldPath: data.NETWORK.SERVICE_CIDR
  targets:
  - select:
      kind: ManagedCluster
    fieldPaths:
    - spec.networkProfile.serviceCidr

- source:
    kind: ConfigMap
    name: cluster-config
    fieldPath: data.NETWORK.DNS_SERVICE_IP
  targets:
  - select:
      kind: ManagedCluster
    fieldPaths:
    - spec.networkProfile.dnsServiceIP

- source:
    kind: ConfigMap
    name: cluster-config
    fieldPath: data.NETWORK.POD_CIDR
  targets:
  - select:
      kind: ManagedCluster
    fieldPaths:
    - spec.networkProfile.podCidr

- source:
    kind: ConfigMap
    name: cluster-config
    fieldPath: data.SYSTEM_NODEPOOL.VM_SIZE
  targets:
  - select:
      kind: ManagedCluster
    fieldPaths:
    - spec.agentPoolProfiles.[name=sysnpl1].vmSize

- source:
    kind: ConfigMap
    name: cluster-config
    fieldPath: data.SYSTEM_NODEPOOL.COUNT
  targets:
  - select:
      kind: ManagedCluster
    fieldPaths:
    - spec.agentPoolProfiles.[name=sysnpl1].count

- source:
    kind: ConfigMap
    name: cluster-config
    fieldPath: data.SYSTEM_NODEPOOL.MIN_COUNT
  targets:
  - select:
      kind: ManagedCluster
    fieldPaths:
    - spec.agentPoolProfiles.[name=sysnpl1].minCount

- source:
    kind: ConfigMap
    name: cluster-config
    fieldPath: data.SYSTEM_NODEPOOL.MAX_COUNT
  targets:
  - select:
      kind: ManagedCluster
    fieldPaths:
    - spec.agentPoolProfiles.[name=sysnpl1].maxCount

labels:
- pairs:
    environment: development
```

To test:
```bash
# Validate the build
kustomize build clusters/dev --enable-alpha-plugins

# Preview the output
kustomize build clusters/dev --enable-alpha-plugins > preview.yaml
```

Some key notes about this approach:
1. We use placeholder values in the base template
2. Each value that needs to be replaced has a corresponding replacement in the kustomization
3. The values file contains all environment-specific values
4. The replacements use select and fieldPaths to target specific fields
5. We can use array indexing for node pools using [name=sysnpl1]
6. The namePrefix adds "dev-" to all resources

Would you like me to:
1. Add the user node pool replacements?
2. Show how to handle the identity armId string concatenation?
3. Add the remaining addon configurations?

Let me show you how to use variables.yaml with Kustomize for managing environment-specific values. Here are different approaches:

1. Using Kustomize ConfigMap Generator:

```yaml
# clusters/dev/cluster-config/variables.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: cluster-vars
data:
  ENVIRONMENT: dev
  CLUSTER_NAME: dev-aks-01
  RESOURCE_GROUP: rg-aks-dev
  LOCATION: eastus2
  NODE_COUNT: "3"
  NODE_SIZE: Standard_D4s_v3
  VNET_CIDR: 10.1.0.0/16
```

Then reference it in your kustomization.yaml:
```yaml
# clusters/dev/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ../../base/cluster-template
configMapGenerator:
  - name: cluster-vars
    behavior: merge
    files:
      - cluster-config/variables.yaml
```

2. Using Kustomize replacements (More flexible approach):

```yaml
# clusters/dev/cluster-config/variables.yaml
varReference:
  CLUSTER_NAME: dev-aks-01
  RESOURCE_GROUP: rg-aks-dev
  LOCATION: eastus2
  NODE_POOLS:
    system:
      size: Standard_D4s_v3
      count: 3
    user:
      size: Standard_D8s_v3
      count: 5
  NETWORK:
    vnetCidr: 10.1.0.0/16
    serviceCidr: 172.16.0.0/16
```

```yaml
# clusters/dev/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ../../base/cluster-template

replacements:
  - source:
      kind: ConfigMap
      name: cluster-vars
      fieldPath: data.CLUSTER_NAME
    targets:
      - select:
          kind: ManagedCluster
        fieldPaths:
          - metadata.name
          - spec.properties.dnsPrefix
  - source:
      kind: ConfigMap
      name: cluster-vars
      fieldPath: data.NODE_POOLS.system.size
    targets:
      - select:
          kind: AgentPool
          name: system
        fieldPaths:
          - spec.properties.vmSize
```

3. Using Flux Substitutions:

```yaml
# clusters/dev/cluster-config/variables.yaml
CLUSTER_NAME: dev-aks-01
RESOURCE_GROUP: rg-aks-dev
LOCATION: eastus2
ADDONS:
  istio:
    enabled: true
    version: 1.20.0
  monitoring:
    enabled: true
    workspace: /subscriptions/xxx/resourceGroups/rg-monitoring-dev/providers/Microsoft.OperationalInsights/workspaces/law-aks-dev
```

```yaml
# clusters/dev/kustomization.yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: aks-cluster
  namespace: flux-system
spec:
  interval: 10m
  path: ./clusters/dev
  prune: true
  sourceRef:
    kind: GitRepository
    name: aks-clusters
  postBuild:
    substitute:
      cluster_name: ${CLUSTER_NAME}
      resource_group: ${RESOURCE_GROUP}
      location: ${LOCATION}
```

4. Practical Example combining approaches:

```yaml
# base/cluster-template/managed-cluster.yaml
apiVersion: containerservice.azure.com/v1api20240901
kind: ManagedCluster
metadata:
  name: ${CLUSTER_NAME}
spec:
  resourceGroupName: ${RESOURCE_GROUP}
  location: ${LOCATION}
  properties:
    networkProfile:
      networkPlugin: azure
      serviceCidr: ${NETWORK.serviceCidr}
    nodeResourceGroup: ${RESOURCE_GROUP}-nodes
```

```yaml
# clusters/prod/cluster-config/variables.yaml
CLUSTER_NAME: prod-aks-01
RESOURCE_GROUP: rg-aks-prod
LOCATION: eastus2
NETWORK:
  vnetCidr: 10.2.0.0/16
  serviceCidr: 10.0.0.0/16
SECURITY:
  privateCluster: true
  authorizedRanges:
    - 10.0.0.0/8
NODE_POOLS:
  system:
    size: Standard_D8s_v3
    count: 5
    min: 5
    max: 7
  user:
    size: Standard_D16s_v3
    count: 5
    min: 5
    max: 20
```

5. Using variables in addons:

```yaml
# clusters/prod/cluster-config/variables.yaml
ADDONS:
  istio:
    version: 1.20.0
    resources:
      pilot:
        cpu: 1000m
        memory: 4Gi
  monitoring:
    workspace: /subscriptions/xxx/resourceGroups/rg-monitoring-prod/providers/Microsoft.OperationalInsights/workspaces/law-aks-prod
```

Then reference in your HelmRelease:
```yaml
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: istiod
spec:
  chart:
    spec:
      version: ${ADDONS.istio.version}
  values:
    pilot:
      resources:
        requests:
          cpu: ${ADDONS.istio.resources.pilot.cpu}
          memory: ${ADDONS.istio.resources.pilot.memory}
```

Key benefits of this approach:
1. Single source of truth for environment variables
2. Easy environment comparison
3. Clear variable organization
4. Simplified cluster configuration management
5. Reduces repetition and potential errors
6. Makes environment promotion more manageable

Remember that variables can be used with:
- Native AKS resources
- Helm releases
- Kyverno policies
- Network configurations
- Security settings
- Resource quotas
- Node pool configurations

Each environment can override these variables while maintaining the same base templates.

1. First, modify the base template to use Kustomize variables (base/cluster-template/managed-cluster.yaml):
```yaml
apiVersion: containerservice.azure.com/v1api20240901
kind: ManagedCluster
metadata:
  name: $(CLUSTER_NAME)
  namespace: default
spec:
  location: $(LOCATION)
  owner:
    name: $(RESOURCE_GROUP)
  dnsPrefix: $(DNS_PREFIX)
  kubernetesVersion: $(K8S_VERSION)
  identity:
    type: UserAssigned
    userAssignedIdentities:
    - reference:
        armId: /subscriptions/$(SUBSCRIPTION_ID)/resourceGroups/$(RESOURCE_GROUP)/providers/Microsoft.ManagedIdentity/userAssignedIdentities/$(USER_ASSIGNED_IDENTITY_NAME)
```

2. Update base kustomization.yaml to declare variables:
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- managed-cluster.yaml

vars:
- name: CLUSTER_NAME
  objref:
    kind: ManagedCluster
    name: $(CLUSTER_NAME)
  fieldref: metadata.name
- name: LOCATION
  objref:
    kind: ManagedCluster
    name: $(CLUSTER_NAME)
  fieldref: spec.location
```

3. Environment-specific kustomization (clusters/dev/kustomization.yaml):
```yaml
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
    - spec.dnsPrefix
- source:
    kind: ConfigMap
    name: cluster-vars
    fieldPath: data.LOCATION
  targets:
  - select:
      kind: ManagedCluster
    fieldPaths:
    - spec.location
```

4. Create a values file (clusters/dev/values.yaml):
```yaml
CLUSTER_NAME: dev-aks-01
LOCATION: eastus2
SUBSCRIPTION_ID: your-sub-id
RESOURCE_GROUP: rg-aks-dev
DNS_PREFIX: dev-aks-01
K8S_VERSION: 1.28.3
USER_ASSIGNED_IDENTITY_NAME: dev-aks-identity
ADMIN_GROUP_ID: your-admin-group-id

SYSTEM_NODEPOOL:
  VM_SIZE: Standard_D4s_v3
  COUNT: 1
  MIN_COUNT: 1
  MAX_COUNT: 2
```

5. Update kustomization.yaml to use replacements:
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- ../../base/cluster-template

replacements:
- source:
    kind: ConfigMap
    name: values
    fieldPath: data.cluster_name
  targets:
  - select:
      kind: ManagedCluster
    fieldPaths:
    - metadata.name
    - spec.dnsPrefix
    options:
      create: true

configMapGenerator:
- name: values
  files:
  - values.yaml
```

To validate:
```bash
kustomize build clusters/dev
```
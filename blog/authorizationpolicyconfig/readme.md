I'll help you understand Kro and create a ResourceGraph with an instance for your AuthorizationPolicyConfig. Let me first look up the Kro documentation to understand how it works.Now let me get the Kro documentation to understand how ResourceGraphs work:Based on the Kro documentation, I'll create a ResourceGraph definition and instance for your AuthorizationPolicyConfig. Kro allows you to define custom resources and manage their underlying Kubernetes resources through ResourceGraphDefinitions.I've created a complete Kro ResourceGraphDefinition and instance for your AuthorizationPolicyConfig. Here's what this does:

## Key Features:

### 1. **ResourceGraphDefinition** (`authorizationpolicyconfig.kro.run`)
This defines a new custom resource type that:
- Creates a user-friendly abstraction for Istio AuthorizationPolicies
- Automatically generates the underlying Istio AuthorizationPolicy resource
- Optionally creates a ConfigMap to document the policy configuration
- Provides status fields that expose the policy's readiness state

### 2. **Schema Definition**
The schema section defines what users can configure:
- `name`: Required - the policy name
- `namespace`: Where the policy will be created (defaults to `aks-istio-ingress`)
- `targetKind`, `targetGroup`, `targetName`: For targeting specific Gateway API resources
- `action`: ALLOW or DENY (defaults to ALLOW)
- `rules`: Complex structure for defining source IP blocks

### 3. **Resources Created**
- **authPolicy**: The actual Istio AuthorizationPolicy that implements the access control
- **policyConfig**: A ConfigMap that documents the policy configuration for easier troubleshooting

### 4. **Instance Example**
The instance shows how to use the custom resource to create your specific policy that:
- Allows traffic only from specified CIDR blocks (`10.10.10.10/24` and `192.168.1.0/24`)
- Targets your specific gateway (`at39473-dev-app-gateway`)
- Creates resources in the `aks-istio-ingress` namespace

## How to Deploy:

1. **Install the ResourceGraphDefinition** (Platform Administrator):
```bash
kubectl apply -f kro-authpolicy-rgd.yaml
```

2. **Verify the CRD was created**:
```bash
kubectl get crds | grep authorizationpolicyconfigs
```

3. **Create instances** (End Users):
Users can now create AuthorizationPolicyConfig resources without needing to understand the underlying Istio complexity.

4. **Check the created resources**:
```bash
# Check the custom resource
kubectl get authorizationpolicyconfigs -A

# Check the actual Istio policy created
kubectl get authorizationpolicies -n aks-istio-ingress

# Check the config map
kubectl get configmaps -n aks-istio-ingress | grep policy
```

This approach simplifies the management of Istio authorization policies by providing a cleaner, more focused interface while Kro handles the orchestration of the underlying resources.
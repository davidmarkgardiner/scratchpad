Yes, you can use `operatorSpec` with AKS clusters to automatically create ConfigMaps containing the OIDC issuer URL, similar to how it works with UserAssignedIdentity.

For ManagedCluster (AKS), you can configure the `operatorSpec.configMaps` to extract the OIDC issuer URL. Here's how:

```yaml
apiVersion: containerservice.azure.com/v1api20231001
kind: ManagedCluster
metadata:
  name: my-aks-cluster
  namespace: default
spec:
  location: eastus
  owner:
    name: my-resource-group
  # ... other cluster configuration
  operatorSpec:
    configMaps:
      oidcIssuerProfile.issuerURL:
        name: aks-oidc-config
        key: issuer-url
      # You can also extract other useful values
      fqdn:
        name: aks-oidc-config  
        key: cluster-fqdn
      # If you need the cluster name for workload identity setup
      name:
        name: aks-oidc-config
        key: cluster-name
```

This will create a ConfigMap named `aks-oidc-config` with the OIDC issuer URL:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: aks-oidc-config
  namespace: default
data:
  issuer-url: "https://eastus.oic.prod-aks.azure.com/tenant-id/cluster-uuid/"
  cluster-fqdn: "my-aks-cluster-dns-12345678.hcp.eastus.azmk8s.io"
  cluster-name: "my-aks-cluster"
```

**Key points:**
- The field path `oidcIssuerProfile.issuerURL` corresponds to the OIDC issuer URL in the AKS cluster status
- Make sure your cluster has the OIDC issuer enabled (it's enabled by default in newer AKS versions)
- The ConfigMap will be created/updated automatically by ASO when the cluster is ready

This approach is much cleaner than manually extracting the OIDC URL and creating ConfigMaps yourself!


---

You can pass the OIDC issuer URL from your ConfigMap to the FederatedIdentityCredential using a **ConfigMapReference**. Here's how:

```yaml
apiVersion: managedidentity.azure.com/v1api20230131
kind: FederatedIdentityCredential
metadata:
  name: aso-fic
  namespace: default
spec:
  owner:
    name: sampleuserassignedidentity
  audiences:
    - api://AzureADTokenExchange
  # Reference the OIDC issuer URL from the ConfigMap created by your ManagedCluster
  issuerFromConfig:
    name: aks-oidc-config
    key: issuer-url
  subject: system:serviceaccount:default:default
```

**Important notes:**

1. **Check the exact field name**: You'll need to verify the FederatedIdentityCredential CRD documentation to see the exact field name for referencing a ConfigMap. It might be:
   - `issuerFromConfig`
   - `issuerReference` 
   - `issuer` with a ConfigMapReference type

2. **Alternative approach using ConfigMapKeyRef**: If the above doesn't work, some CRDs use Kubernetes-native ConfigMapKeyRef format:

```yaml
apiVersion: managedidentity.azure.com/v1api20230131
kind: FederatedIdentityCredential
metadata:
  name: aso-fic
  namespace: default
spec:
  owner:
    name: sampleuserassignedidentity
  audiences:
    - api://AzureADTokenExchange
  issuer:
    valueFrom:
      configMapKeyRef:
        name: aks-oidc-config
        key: issuer-url
  subject: system:serviceaccount:default:default
```

**To find the correct syntax:**
```bash
kubectl explain federatedidentitycredential.spec.issuer
```

This will show you the exact field structure and whether it supports ConfigMap references.

**Deployment order:**
Make sure your ManagedCluster is created first (and the ConfigMap exists) before creating the FederatedIdentityCredential, or use proper dependencies in your deployment tooling.

Can you check the FederatedIdentityCredential CRD documentation or run the `kubectl explain` command to see the exact field structure?

---

No, that's not correct. The `valueFrom.configMapKeyRef` syntax is Kubernetes-native and not used by Azure Service Operator.

Based on the documentation you provided, the FederatedIdentityCredential supports **`issuerFromConfig`** which is of type `genruntime.ConfigMapReference`.

Here's the correct syntax:

```yaml
apiVersion: managedidentity.azure.com/v1api20230131
kind: FederatedIdentityCredential
metadata:
  name: aso-fic
  namespace: default
spec:
  owner:
    name: sampleuserassignedidentity
  audiences:
    - api://AzureADTokenExchange
  # Use issuerFromConfig, not issuer with valueFrom
  issuerFromConfig:
    name: aks-oidc-config
    key: issuer-url
  subject: system:serviceaccount:default:my-service-account
```

**Key points:**

1. **Use `issuerFromConfig`** - This is the field that accepts a `genruntime.ConfigMapReference`
2. **Don't use `issuer.valueFrom`** - That's Kubernetes-native syntax, not ASO syntax
3. **ASO uses its own reference types** - `genruntime.ConfigMapReference` has just `name` and `key` fields

The `genruntime.ConfigMapReference` structure is:
```yaml
issuerFromConfig:
  name: "configmap-name"    # Required
  key: "key-name"           # Required
```

This is the same pattern used throughout ASO for referencing ConfigMaps and Secrets, as you can see in the UserAssignedIdentity example you showed earlier.
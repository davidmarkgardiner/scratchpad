# ServiceEntry namespace isolation in Istio service mesh on AKS

A ServiceEntry created in one namespace can indeed affect egress traffic from all namespaces in an Istio service mesh by default - this is a well-documented issue that requires active mitigation strategies to prevent cross-namespace contamination in multi-tenant environments.

## The cross-namespace contamination problem verified

ServiceEntry resources in Istio exhibit problematic default behavior where they automatically export to all namespaces when the `exportTo` field is not explicitly configured. **When you create a ServiceEntry without specifying `exportTo`, it defaults to `exportTo: ["*"]`, making it visible and potentially affecting traffic routing decisions across the entire mesh**. This behavior violates Kubernetes namespace isolation principles and has been documented in multiple GitHub issues including #13008, #36712, and #39770.

The problem manifests in several ways. A ServiceEntry in one namespace can hijack traffic intended for external services from pods in other namespaces, following a "last-write-wins" pattern that creates unpredictable routing behavior. Internal Kubernetes services can be disrupted when a malicious or misconfigured ServiceEntry defines the same hostname. The issue affects all Istio versions from 1.1.1 onwards with varying behaviors across releases.

## Default Istio behavior and visibility settings

Istio's service resolution follows a specific lookup order that enables cross-namespace interference. When resolving destinations, Istio searches first in the client namespace where traffic originates, then the service namespace where the service is defined, and finally the root namespace (typically istio-system). This global search pattern combined with the default `exportTo: ["*"]` behavior creates the conditions for namespace contamination.

The `exportTo` field controls visibility of networking resources across namespaces with three primary patterns. Setting `exportTo: ["*"]` exports to all namespaces (the problematic default), while `exportTo: ["."]` restricts visibility to the current namespace only, and `exportTo: ["namespace1", "namespace2"]` allows explicit namespace listing for controlled sharing. **The critical insight is that ServiceEntry resources without an explicit `exportTo` field will affect traffic routing decisions mesh-wide**, potentially causing one tenant's configuration to interfere with another's network traffic.

Version-specific changes have attempted to address aspects of this issue. Istio 1.24 introduced new precedence rules preferring services in the same namespace as the proxy, then Kubernetes Services over ServiceEntry resources. However, the fundamental default export behavior remains unchanged, requiring explicit configuration to achieve proper isolation.

## Best practices for preventing namespace cross-contamination

Preventing cross-namespace contamination requires a multi-layered approach combining configuration standards, resource patterns, and policy enforcement. The most fundamental practice involves **always explicitly setting the `exportTo` field on every ServiceEntry resource to limit scope appropriately**. For multi-tenant environments, this typically means using `exportTo: ["."]` to restrict visibility to the creating namespace.

Mesh-level configuration provides a baseline defense by modifying the IstioOperator to set restrictive defaults:

```yaml
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
spec:
  meshConfig:
    defaultServiceExportTo: ["."]
    defaultDestinationRuleExportTo: ["."] 
    defaultVirtualServiceExportTo: ["."]
```

However, this approach has limitations since resource creators can still override these defaults. Therefore, combining mesh configuration with admission control policies creates a more robust defense. Organizations should implement strict RBAC policies limiting who can create ServiceEntry resources, use namespace-based resource quotas to prevent resource exhaustion attacks, and deploy monitoring to detect conflicting ServiceEntries across namespaces.

For production environments, establish a clear governance model where ServiceEntry resources for shared external services are managed centrally in a dedicated namespace with controlled `exportTo` lists. Tenant-specific external services should use namespace-scoped ServiceEntries with `exportTo: ["."]`. Document these patterns clearly and enforce them through automation and policy.

## Sidecar configurations to limit egress scope

Sidecar resources provide powerful control over service discovery and egress traffic scope, offering an effective solution for preventing cross-namespace interference. **A properly configured Sidecar resource can restrict which services and ServiceEntries are visible to pods in a namespace**, creating true isolation even when ServiceEntries are misconfigured.

The most effective pattern deploys a default Sidecar in each namespace that restricts egress to services within the same namespace plus essential system services:

```yaml
apiVersion: networking.istio.io/v1
kind: Sidecar
metadata:
  name: default
  namespace: tenant-a
spec:
  egress:
  - hosts:
    - "./*"              # Services in same namespace only
    - "istio-system/*"   # Control plane services (required)
```

For workloads requiring access to specific external services, combine namespace-scoped ServiceEntry resources with corresponding Sidecar configuration:

```yaml
# ServiceEntry restricted to namespace
apiVersion: networking.istio.io/v1
kind: ServiceEntry
metadata:
  name: external-api
  namespace: tenant-a
spec:
  hosts:
  - api.example.com
  exportTo:
  - "."
  location: MESH_EXTERNAL
  ports:
  - number: 443
    protocol: HTTPS
---
# Sidecar allowing access to the external service
apiVersion: networking.istio.io/v1
kind: Sidecar
metadata:
  name: default
  namespace: tenant-a
spec:
  egress:
  - hosts:
    - "./*"
    - "istio-system/*"
    - "./api.example.com"  # Specific external service
```

Performance testing by organizations like Wealth Wizards demonstrated that implementing Sidecar configurations reduced CPU usage from 800% spikes to baseline levels while improving configuration convergence times. The trade-off involves increased management overhead and potential connectivity issues if misconfigured, making thorough testing essential.

## Kyverno policies for validation and mutation

Kyverno provides policy-as-code capabilities to enforce ServiceEntry and Sidecar configuration standards automatically. **These policies can validate configurations during admission, mutate resources to add safe defaults, and generate required resources for new namespaces**.

A comprehensive validation policy prevents the creation of ServiceEntries with problematic configurations:

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: validate-serviceentry-exportto
spec:
  validationFailureAction: Enforce
  background: true
  rules:
  - name: require-explicit-exportto
    match:
      any:
      - resources:
          kinds:
          - ServiceEntry
    validate:
      message: "ServiceEntry must have exportTo field explicitly defined"
      pattern:
        spec:
          exportTo: "?*"
  - name: prevent-wildcard-exportto
    match:
      any:
      - resources:
          kinds:
          - ServiceEntry
    validate:
      message: "ServiceEntry cannot use wildcard '*' export"
      deny:
        conditions:
          any:
          - key: "{{ request.object.spec.exportTo || [] }}"
            operator: AnyIn
            value: ["*"]
```

Mutation policies automatically fix common configuration issues by adding safe defaults:

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: mutate-serviceentry-exportto
spec:
  background: false
  rules:
  - name: add-namespace-scoped-exportto
    match:
      any:
      - resources:
          kinds:
          - ServiceEntry
    preconditions:
      all:
      - key: "{{ request.object.spec.exportTo || '' }}"
        operator: Equals
        value: ""
    mutate:
      patchStrategicMerge:
        spec:
          exportTo:
          - "."
```

Deploy these policies using a phased approach: start with Audit mode to assess impact, add mutation policies to automatically fix issues, switch critical policies to Enforce mode, and implement generation policies for automated resource creation. Monitor PolicyReport resources for compliance tracking and use PolicyException resources for legitimate cross-namespace access requirements.

## Microsoft's recommendations for multi-tenant Istio on AKS

Microsoft provides specific guidance for multi-tenant Istio deployments on AKS through their managed Istio add-on and Azure-native security controls. **The recommended approach combines namespace-based soft multitenancy with Azure Policy enforcement and integrated security services**.

The AKS Istio add-on provides a managed control plane with automated lifecycle management, but has limitations for multi-tenant scenarios including no multi-cluster support, blocked customizations for ProxyConfig and IstioOperator resources, and limited EnvoyFilter support. Organizations must work within these constraints while leveraging Azure-native capabilities for enhanced isolation.

Microsoft's architectural pattern for multi-tenancy on AKS with Istio includes several key components. Deploy each tenant in separate namespaces with unique ServiceAccounts and enforce Istio AuthorizationPolicy for Layer 7 traffic control. Implement PeerAuthentication in STRICT mode per namespace and use Sidecar resources to limit service discovery scope. For stricter isolation requirements, consider dedicated node pools per tenant using node affinity and taints/tolerations.

Azure Policy for Kubernetes (based on Gatekeeper v3) provides cluster-level governance with built-in policies for namespace requirements, resource limits, and security contexts. Custom policies can enforce Istio-specific configurations while real-time compliance evaluation occurs during resource creation. Combine this with Microsoft Defender for Containers for runtime threat detection and Azure Key Vault for certificate management.

Performance considerations for AKS deployments include istiod capacity supporting up to 30,000 sidecars with Azure CNI Overlay + Cilium, memory requirements of 32-42GB for istiod at scale, and automatic HPA configuration with minimum 2 replicas. Be aware of DNS resolution performance impacts with multiple ServiceEntries and Azure SQL connectivity issues requiring connection policy adjustments.

## Conclusion

The ServiceEntry cross-namespace contamination issue represents a significant security and operational challenge in multi-tenant Istio deployments on AKS. **Successfully preventing namespace cross-contamination requires implementing multiple defensive layers rather than relying on any single solution**. Organizations must combine explicit `exportTo` configurations on all ServiceEntry resources with Sidecar-based egress scoping, enforce standards through Kyverno or OPA Gatekeeper policies, leverage Azure Policy and native security services for AKS deployments, and establish clear governance models for shared external service configurations.

The default Istio behavior of exporting ServiceEntries to all namespaces creates genuine risks that demand proactive mitigation. By implementing the comprehensive approach detailed in this research—combining proper resource configuration, policy enforcement, and platform-specific controls—organizations can achieve true namespace isolation in their Istio service mesh deployments while maintaining the flexibility and power that Istio provides for service-to-service communication and traffic management.
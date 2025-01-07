# Kyverno Policies

## Cluster-Wide Enforcement Policies
1. `enforce-cluster-pod-security.yaml`
   - Enforces baseline pod security standards
   - Prevents privileged container execution
   - Applies to all pods in at* namespaces

2. `enforce-cluster-pod-security-prod.yaml`
   - Enforces restricted pod security standards for production
   - Requires read-only filesystem, non-root execution
   - Applies to pods with pod-security.kubernetes.io/warn label

## Namespace-Scoped Policies
3. `generate-ns-networkpolicy-deny.yaml`
   - Generates default-deny network policies
   - Creates on namespace creation
   - Applies to namespaces with namespace=true label

4. `generate-ns-resourcequota.yaml`
   - Enforces resource quotas
   - Requires CPU and memory limits/requests
   - Applies to pods in at* namespaces

## Validation Policies
5. `validate-ns-istio-injection.yaml`
   - Prevents istio-injection=enabled label
   - Enforces revision-based injection
   - Applies to namespaces, pods, deployments

6. `validate-cluster-pod-labels.yaml`
   - Requires specific labels on resources
   - Enforces app, environment, owner labels
   - Applies to pods, deployments, services

## Mutation Policies
7. `mutate-ns-deployment-antiaffinity.yaml`
   - Adds pod anti-affinity rules
   - Spreads pods across nodes
   - Applies to deployments with app label

8. `mutate-ns-deployment-spotaffinity.yaml`
   - Adds spot instance affinity
   - Configures node affinity for spot VMs
   - Applies to deployments in spot namespaces

## Audit Policies
9. `audit-cluster-peerauthentication-mtls.yaml`
   - Audits mTLS configuration
   - Ensures STRICT mode is enabled
   - Applies to PeerAuthentication resources

10. `mutate-cluster-namespace-istiolabel.yaml`
    - Updates Istio revision labels
    - Ensures consistent sidecar injection
    - Applies to namespaces with istio.io/rev label
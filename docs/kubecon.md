https://learn.microsoft.com/en-us/azure/aks/node-auto-repair#monitor-node-auto-repair-using-kubernetes-events

Azure Kubernetes Service (AKS) continuously monitors the health state of worker nodes and performs automatic node repair if they become unhealthy. The Azure virtual machine (VM) platform performs maintenance on VMs experiencing issues. AKS and Azure VMs work together to minimize service disruptions for clusters.

https://learn.microsoft.com/en-gb/azure/azure-monitor/containers/prometheus-metrics-scrape-autoscaling

Azure Managed Prometheus supports Horizontal Pod Autoscaling(HPA) for the ama-metrics replica set pod by default. The HPA allows the ama-metrics replica set pod, which scrapes Prometheus metrics with custom jobs, to scale automatically based on memory utilization to prevent OOMKills. By default, the HPA is configured with a minimum of two replicas and a maximum of 12 replicas. Users can configure the number of shards within the range of 2 to 12 replicas.

---

# Implement Horizontal Pod Autoscaling for Azure Managed Prometheus

## Description
Implement and configure Horizontal Pod Autoscaling (HPA) for the ama-metrics replica set pods in our Azure Managed Prometheus setup. This feature will allow the metrics collection pods to automatically scale based on memory utilization, preventing OOMKills and ensuring reliable metrics collection.

## Background
Azure Monitor Managed service for Prometheus now supports Horizontal Pod Autoscaling (HPA) for the ama-metrics replica set pod by default (GA since March 2025). This pod handles the scraping of Prometheus metrics with custom jobs and can now scale automatically based on memory utilization. By default, the HPA is configured with a minimum of 2 replicas and a maximum of 12 replicas, but we can customize this configuration to best suit our workload patterns.

## Requirements
1. Enable HPA for ama-metrics replica set pods in all AKS clusters with Azure Managed Prometheus
2. Determine optimal minimum and maximum replica settings for our environment (within the allowed range of 2-12 replicas)
3. Configure memory utilization thresholds appropriate for our workload patterns
4. Implement monitoring to track scaling events and pod performance
5. Document the implementation and configuration for the operations team

## Acceptance Criteria
- [ ] HPA is properly configured and operational for ama-metrics replica set pods
- [ ] Custom minimum and maximum replica settings are applied based on our workload analysis
- [ ] Memory utilization thresholds are configured and tested
- [ ] Monitoring is in place to track scaling events and performance
- [ ] Documentation is created for the operations team
- [ ] Testing validates that the pods scale appropriately under load without experiencing OOMKills

## Technical Details
Reference documentation: https://learn.microsoft.com/en-gb/azure/azure-monitor/containers/prometheus-metrics-scrape-autoscaling

## Implementation Plan
1. Analyze current memory utilization patterns of ama-metrics pods
2. Determine optimal min/max replica settings and memory thresholds
3. Create configuration templates for HPA settings
4. Implement in development environment
5. Test scaling behavior under various load conditions
6. Update monitoring dashboards to track scaling events
7. Create documentation for operations team
8. Roll out to production clusters

## Priority
Medium

## Estimated Time
2 days

---
# Implement AKS Node Auto-Repair Monitoring Using Kubernetes Events

## Description
Implement monitoring capabilities for AKS node auto-repair using the newly available Kubernetes events. This feature will allow us to be notified whenever node auto-repair initiates and completes repair actions in our AKS clusters.

## Background
Azure Kubernetes Service (AKS) continuously monitors the health state of worker nodes and performs automatic repairs when nodes become unhealthy. The Azure VM platform performs maintenance on VMs experiencing issues, and AKS works with Azure VMs to minimize service disruptions for our clusters. With the GA release of Node Auto-Repair Kubernetes Events (March 2025), we now have the ability to monitor this process.

## Requirements
1. Configure our AKS clusters to expose node auto-repair Kubernetes events
2. Create alerts based on these events to notify when:
   - Node auto-repair actions are initiated
   - Node auto-repair actions are completed
   - Errors occur during the auto-repair process
3. Integrate these alerts with our existing monitoring infrastructure
4. Add documentation for operations team on how to interpret these events

## Acceptance Criteria
- [ ] Node auto-repair events are visible in the Kubernetes events stream
- [ ] Alerts are configured and tested for all specified conditions
- [ ] Alerts are integrated with our notification system (email/Slack/Teams)
- [ ] Dashboard is updated to display node auto-repair activities
- [ ] Documentation is created for the operations team
- [ ] Testing validates that notifications are received when node repairs occur

## Technical Details
Reference documentation: https://learn.microsoft.com/en-us/azure/aks/node-auto-repair#monitor-node-auto-repair-using-kubernetes-events

## Implementation Plan
1. Research the exact event format and structure provided by AKS
2. Develop monitoring configuration to capture these events
3. Configure test environment to simulate node failures and trigger auto-repair
4. Implement alert rules
5. Test end-to-end functionality
6. Update operations documentation
7. Roll out to production clusters

## Priority
High

## Estimated Time
3 days


---

# Implement Argo CD GitOps for AKS Workload Deployment

## Description
Implement Argo CD as our GitOps solution for managing application deployments to our AKS clusters. This will provide a pull-based deployment method that complements our existing push-based CI/CD pipelines using GitHub Actions, enabling better security, auditability, and consistency for our Kubernetes workloads.

## Background
Currently, our application deployments are primarily managed through push-based methods using GitHub Actions workflows. While this approach works, implementing a GitOps methodology with Argo CD will provide several benefits:

1. Declarative configuration that represents the desired state of applications
2. Version-controlled deployments with full audit history
3. Automated drift detection and remediation
4. Enhanced visibility into deployment status and configuration differences
5. Simplified rollback capabilities
6. Secure separation between CI and CD processes

As outlined in our AKS Baseline Automation reference materials, Argo CD serves as an alternative to Flux for application teams to manage their specific workload deployments.

## Requirements
1. Install and configure Argo CD in our AKS cluster
   - Deploy using Helm charts or operator pattern
   - Set up with proper RBAC permissions
   - Configure with internal access only (no public exposure)

2. Set up GitOps repository structure
   - Create repository structure for application manifests
   - Implement environment separation (dev/staging/prod)
   - Establish manifest management practices (Helm, Kustomize, or plain YAML)

3. Configure Argo CD application management
   - Set up application definitions for our workloads
   - Configure sync policies appropriate for each environment
   - Implement progressive delivery patterns (Blue/Green, Canary)

4. Create access controls and security measures
   - Integrate with our existing identity provider
   - Implement RBAC for Argo CD users
   - Secure secrets management

5. Set up monitoring and notifications
   - Configure alerting for sync failures
   - Set up dashboards for GitOps status
   - Implement notifications for deployment events

6. Document operations procedures
   - Create runbooks for common operations
   - Document recovery procedures
   - Create training materials for teams

## Acceptance Criteria
- [ ] Argo CD is deployed and operational in our AKS cluster
- [ ] Internal access is configured (not publicly exposed)
- [ ] At least one application is successfully deployed via GitOps
- [ ] Manual sync, automatic sync, and rollback capabilities are demonstrated
- [ ] Drift detection and remediation are verified
- [ ] Proper RBAC permissions are implemented
- [ ] Documentation for developers and operations is complete
- [ ] The sample Flask application is successfully deployed using GitOps

## Technical Details
- We'll implement Scenario 3 as described in the AKS Baseline Automation documentation:
  1. The Kubernetes administrator makes configuration changes in YAML files and commits the changes to the GitHub repository
  2. Argo CD pulls the changes from the Git repository
  3. Argo CD reconciles the configuration changes to the AKS cluster

- We'll configure Argo CD with an internal-only UI using an ingress controller with an internal IP address, as recommended in the documentation

## Implementation Plan
1. Set up development environment for testing the Argo CD installation
2. Create Helm chart or operator configuration for Argo CD deployment
3. Develop GitOps repository structure and conventions
4. Configure first application deployment via GitOps
5. Test and verify GitOps workflows (sync, rollback, etc.)
6. Document operations procedures and best practices
7. Train development and operations teams
8. Roll out to production environment

## Related Resources
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/en/stable/)
- [AKS Baseline Automation Repo](https://github.com/Azure/aks-baseline-automation)
- [GitOps Best Practices](https://www.weave.works/technologies/gitops/)

## Priority
High

## Estimated Time
5 days

---

# Implement Istio Ambient Mode on AKS Clusters

## Description
Implement Istio's newly GA Ambient Mode (v1.24+) on our AKS clusters to provide sidecar-less service mesh capabilities. This implementation will enhance our security posture through mTLS, improve observability, and enable traffic management with lower operational overhead compared to the traditional sidecar approach.

## Background
Istio's Ambient Mode has recently reached General Availability in version 1.24 after 26 months of development. This mode offers all the critical service mesh capabilities without the need for sidecars, reducing resource consumption and simplifying operations. Microsoft is a key contributor to this feature, which aligns with our cloud native strategy and security requirements.

Key benefits of Ambient Mode include:
- No sidecars required, reducing resource overhead
- Simplified operations and deployment
- Lower latency for service-to-service communication
- Full mTLS support for enhanced security
- Traffic management and observability capabilities
- No application code changes required

## Requirements
1. **Assessment and Planning**
   - Inventory current AKS clusters and applications
   - Evaluate compatibility with existing applications
   - Design transitional architecture (if migrating from sidecar mode)
   - Define success metrics and performance baselines

2. **Infrastructure Setup**
   - Install Istio control plane with Ambient Mode enabled
   - Deploy ztunnel components
   - Configure waypoint proxies where needed
   - Set up integration with existing monitoring systems

3. **Security Configuration**
   - Implement mTLS for all service-to-service communication
   - Configure authentication policies
   - Set up authorization rules
   - Integrate with existing certificate management

4. **Traffic Management**
   - Implement routing rules
   - Configure traffic policies
   - Set up traffic splitting for A/B testing
   - Establish retry and circuit breaking policies

5. **Observability**
   - Configure metrics collection
   - Set up distributed tracing
   - Implement logging
   - Create dashboards for service mesh monitoring

6. **Testing and Validation**
   - Verify mTLS encryption between services
   - Test traffic routing rules
   - Validate observability data collection
   - Perform load testing and compare performance metrics

7. **Documentation and Training**
   - Create operational guides
   - Document architecture and configuration
   - Train operations team on new capabilities
   - Develop troubleshooting procedures

## Acceptance Criteria
- [x] Istio Ambient Mode v1.24+ successfully installed on all target AKS clusters
- [x] All services communicate via mTLS without sidecars
- [x] Traffic management policies are applied and functioning
- [x] Observability data is collected and accessible in dashboards
- [x] No performance degradation compared to previous architecture
- [x] Operational runbooks and documentation completed
- [x] Operations team trained on the new architecture

## Technical Details
- **Istio Version**: 1.24 or later (with GA Ambient Mode)
- **AKS Version**: The latest supported version compatible with Istio Ambient Mode
- **Integration Points**:
  - Azure Monitor
  - Azure Key Vault for certificates
  - Existing logging and monitoring solutions
  - CI/CD pipelines

## Implementation Plan
1. **Week 1: Assessment and Planning**
   - Complete inventory and compatibility assessment
   - Design architecture and document deployment plan
   - Set up test environment

2. **Week 2: Test Environment Implementation**
   - Install Istio with Ambient Mode in test cluster
   - Deploy test applications
   - Configure basic mTLS and traffic rules

3. **Week 3: Testing and Validation**
   - Conduct security testing
   - Perform load testing
   - Validate observability data
   - Document findings and make adjustments

4. **Week 4: Production Implementation**
   - Deploy to first production cluster
   - Monitor performance and security
   - Address any issues

5. **Week 5: Rollout Completion**
   - Deploy to remaining clusters
   - Finalize documentation
   - Conduct training sessions

## References
- [Istio Ambient Mode Documentation](https://istio.io/latest/docs/ambient/)
- [Microsoft's Contributions to Istio Ambient Mode](https://www.solo.io/blog/istio-ambient-mode-ga-announcement/)
- [AKS and Istio Integration Best Practices](https://learn.microsoft.com/en-us/azure/aks/istio-about)

## Priority
High

## Estimated Effort
8 story points (approximately 3-4 weeks)

## Assignee
TBD - Service Mesh Team

## Labels
`service-mesh`, `security`, `infrastructure`, `istio`, `ambient-mode`, `aks`

---

# Implement Dynamic Resource Allocation (DRA) in AKS

## Description
Implement and configure Kubernetes Dynamic Resource Allocation (DRA) in our AKS clusters to enable more efficient allocation of specialized hardware resources such as GPUs. This feature, which reached beta in Kubernetes v1.32, provides a generalized API for requesting and sharing resources between pods and containers, similar to how persistent volumes work but for generic resources.

## Background
Dynamic Resource Allocation (DRA) is a significant enhancement for Kubernetes workloads that use specialized hardware resources. As highlighted at KubeCon Europe 2025, Microsoft is actively contributing to this feature which has now reached beta status in v1.32. DRA enables better resource utilization and reduces idle hardware by allowing dynamic allocation of specialized resources beyond traditional CPU and memory.

Key benefits include:
- Dynamic allocation of specialized hardware resources (primarily GPUs)
- Simplified integration of hardware accelerators
- Better resource utilization and reduced idle hardware
- Structured parameters for resource allocation
- Efficient scheduling decisions

## Requirements
1. **Assessment and Planning**
   - Identify which AKS clusters would benefit from DRA
   - Inventory specialized hardware resources (GPUs, etc.)
   - Determine resource driver requirements
   - Develop implementation strategy and timeline

2. **Infrastructure Setup**
   - Enable the DynamicResourceAllocation feature gate in AKS
   - Install and configure appropriate resource drivers for our hardware
   - Create necessary DeviceClass objects
   - Configure RBAC permissions for DRA components

3. **Resource Definitions**
   - Define appropriate DeviceClass resources
   - Create ResourceClaim templates for common usage patterns
   - Establish naming conventions and labeling strategy
   - Document resource allocation parameters

4. **Workload Migration**
   - Identify existing workloads that could benefit from DRA
   - Update pod specifications to use the DRA API
   - Test with non-production workloads
   - Document migration patterns

5. **Monitoring and Operations**
   - Configure monitoring for resource utilization
   - Set up alerts for resource allocation failures
   - Establish operational procedures for troubleshooting
   - Create dashboard for resource allocation visibility

6. **Security Configuration**
   - Evaluate need for admin access feature
   - Implement appropriate admission policies if needed
   - Configure namespace-level access controls
   - Document security considerations

7. **Testing and Validation**
   - Verify resource allocation works correctly
   - Benchmark performance improvements
   - Test failure scenarios and recovery
   - Validate monitoring and alerting

## Acceptance Criteria
- [ ] DynamicResourceAllocation feature gate enabled in all target AKS clusters
- [ ] Resource drivers successfully installed and configured
- [ ] DeviceClass definitions created for all specialized hardware types
- [ ] ResourceClaim templates available for development teams
- [ ] At least one production workload successfully migrated to use DRA
- [ ] Monitoring and alerting in place for resource allocation
- [ ] Documentation and examples created for development teams
- [ ] Performance metrics showing improved resource utilization

## Technical Details
- **Kubernetes Version**: v1.32+ required for beta DRA support
- **AKS Version**: Latest version supporting Kubernetes v1.32+
- **Feature Gates Required**:
  - DynamicResourceAllocation (for core functionality)
  - DRAResourceClaimDeviceStatus (if device status reporting needed)
  - DRAAdminAccess (if admin access feature needed)
- **API Groups**: resource.k8s.io/v1beta1
- **Key Resources**:
  - DeviceClass
  - ResourceClaim
  - ResourceClaimTemplate
  - ResourceSlice

## Implementation Plan
1. **Week 1: Assessment and Planning**
   - Complete inventory of specialized hardware
   - Select appropriate resource drivers
   - Design implementation architecture
   - Set up test environment

2. **Week 2: Infrastructure Setup**
   - Enable feature gates in test cluster
   - Install resource drivers
   - Create initial DeviceClass definitions
   - Test basic resource allocation

3. **Week 3: Workload Testing**
   - Develop sample workloads using DRA
   - Test resource allocation and release
   - Document patterns and best practices
   - Set up monitoring

4. **Week 4: Production Implementation**
   - Enable feature gates in production clusters
   - Install and configure resource drivers
   - Migrate initial workloads
   - Monitor performance and resource utilization

5. **Week 5: Optimization and Documentation**
   - Fine-tune resource allocation parameters
   - Complete documentation
   - Train development teams
   - Establish operational procedures

## References
- [Kubernetes DRA Documentation](https://kubernetes.io/docs/concepts/scheduling-eviction/dynamic-resource-allocation/)
- [Microsoft KubeCon Europe 2025 Announcements](https://azure.microsoft.com/en-us/blog/)
- [AKS Feature Management](https://learn.microsoft.com/en-us/azure/aks/supported-kubernetes-features)

## Priority
High

## Estimated Effort
10 story points (approximately 4-5 weeks)

## Assignee
TBD - Platform Engineering Team

## Labels
`kubernetes`, `aks`, `feature`, `dra`, `gpu`, `infrastructure`, `resource-management`

---
# Implement ClusterTrustBundles in AKS

## Description
Implement and configure ClusterTrustBundles in our AKS clusters to provide a more stable API for X.509 certificate trust distribution. This feature has reached beta status in Kubernetes v1.33 and offers improved mechanisms for managing trust anchors across the cluster, enhancing security and simplifying certificate management.

## Background
ClusterTrustBundles (previously known as Trust Anchor Sets) is a Kubernetes feature that provides a resource for holding X.509 trust anchors. This feature reached beta status in Kubernetes v1.33 and was highlighted as a security enhancement at KubeCon Europe 2025. It offers a more stable API for certificate trust distribution in Kubernetes, addressing limitations in the current methods of distributing certificate trust information.

Key benefits include:
- Standardized way to distribute X.509 trust anchors across a cluster
- More secure certificate management
- Simplified configuration for applications requiring custom CA certificates
- Improved support for certificate rotation
- Integration with projected volumes for easy consumption by pods

## Requirements
1. **Assessment and Planning**
   - Identify current certificate distribution methods in our clusters
   - Map out use cases for ClusterTrustBundles
   - Develop migration strategy for existing certificate trust distribution
   - Document security implications and benefits

2. **Infrastructure Setup**
   - Enable the feature gate in AKS clusters
   - Configure initial ClusterTrustBundle resources
   - Set up RBAC for ClusterTrustBundle management
   - Implement monitoring for certificate expiration

3. **Certificate Management**
   - Migrate existing CA certificates to ClusterTrustBundles
   - Configure the new kube-apiserver-serving signer (if needed)
   - Document certificate rotation procedures
   - Establish lifecycle management for certificates

4. **Application Integration**
   - Update application deployments to use ClusterTrustBundlePEM projected volumes
   - Test certificate verification in applications
   - Create examples and templates for development teams
   - Document best practices for consuming trust bundles

5. **Security Validation**
   - Conduct security review of implementation
   - Test certificate chain verification
   - Validate RBAC restrictions
   - Document security considerations

6. **Operational Procedures**
   - Create procedures for certificate rotation
   - Establish monitoring for certificate expiration
   - Document troubleshooting steps
   - Create runbooks for common operations

## Acceptance Criteria
- [ ] ClusterTrustBundles feature gate enabled in all target AKS clusters
- [ ] Key organizational CA certificates migrated to ClusterTrustBundles
- [ ] At least one application updated to consume certificates from ClusterTrustBundlePEM projected volumes
- [ ] Certificate rotation procedures documented and tested
- [ ] Security review completed with no critical findings
- [ ] Monitoring in place for certificate expiration
- [ ] Documentation and examples created for development teams

## Technical Details
- **Kubernetes Version**: v1.33+ required for beta support
- **AKS Version**: Latest version supporting Kubernetes v1.33+
- **Feature Gates Required**: ClusterTrustBundleProjection
- **API Groups**: certificates.k8s.io/v1beta1
- **Key Resources**:
  - ClusterTrustBundle
  - ClusterTrustBundlePEM projected volume
  - kube-apiserver-serving signer (new in-tree signer)

## Implementation Plan
1. **Week 1: Assessment and Planning**
   - Document current certificate distribution methods
   - Identify applications using custom CA certificates
   - Design implementation approach
   - Set up test environment

2. **Week 2: Initial Implementation**
   - Enable feature gates in test cluster
   - Create initial ClusterTrustBundle resources
   - Test basic functionality
   - Document implementation details

3. **Week 3: Application Integration**
   - Update sample applications to use ClusterTrustBundlePEM
   - Test certificate verification
   - Create examples for development teams
   - Verify proper certificate handling

4. **Week 4: Security and Operations**
   - Conduct security review
   - Test certificate rotation
   - Create monitoring for certificate expiration
   - Develop operational procedures

5. **Week 5: Production Implementation**
   - Enable feature in production clusters
   - Migrate production certificates
   - Update critical applications
   - Monitor for issues

## References
- [Kubernetes ClusterTrustBundle KEP](https://github.com/kubernetes/enhancements/issues/3257)
- [ClusterTrustBundle Documentation](https://kubernetes.io/docs/reference/access-authn-authz/certificate-signing-requests/#clustertrust-bundles)
- [Microsoft KubeCon Europe 2025 Announcements](https://azure.microsoft.com/en-us/blog/)
- [AKS Feature Management](https://learn.microsoft.com/en-us/azure/aks/supported-kubernetes-features)

## Priority
Medium

## Estimated Effort
6 story points (approximately 2-3 weeks)

## Assignee
TBD - Security Team

## Labels
`security`, `kubernetes`, `aks`, `feature`, `certificates`, `pki`
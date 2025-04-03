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
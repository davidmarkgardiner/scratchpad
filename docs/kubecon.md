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

# Cluster Deployment Runbook

## Overview
This runbook outlines the automated cluster deployment process using a two-layer Flux GitOps approach. The system automatically provisions infrastructure, deploys core services, and validates health before application deployment.

## Prerequisites
- Access to the cluster configuration repository
- Appropriate permissions to uncomment cluster configurations
- Understanding of Flux CD and GitOps workflows

## Deployment Process

### Phase 1: Initial Cluster Creation

#### Step 1: Select and Reserve Cluster
1. Navigate to the cluster configuration file
2. Locate the desired cluster configuration (currently commented out)
3. **Uncomment the target cluster configuration**
4. **Add a comment with your name** to indicate ownership/usage
   ```yaml
   # Example:
   # cluster-prod-east-1: # InUse: DavidG - 2024-07-25 - Working on meaning of life
   ```

#### Step 2: Initial Flux Bootstrap
Once uncommented, the system automatically:
- Deploys the **initial Flux configuration**
- Sets up the **config map**
- Provisions the **cluster infrastructure**
- sets up Federated Identity with newly provisoed OIDC endpoint
- Configures **core Flux components** on the target cluster
- Establishes the **maintenance window schedule**

**Expected Timeline:** 15-20 minutes for initial bootstrap

### Phase 2: Automated Infrastructure Deployment

#### Step 3: Second-Layer Flux Activation
The second Flux layer automatically triggers and performs:

1. **Core Repository Sync**
   - Deploys the nodes using node auto provisioner
   - Deploys configmap and nexs certs.
   - Deploys core chart and associated applications

2. **Config Repository Sync**
   - Deploys kro
   - Applies configuration from config maps


**Expected Timeline:** 25-30 minutes for full infrastructure deployment

### Phase 3: Health Validation


To do:

#### Step 4: Automated Health Checks
The system runs comprehensive health tests:
- **Pod readiness checks** - All pods reach Ready state
- **Service connectivity** - Internal service mesh validation
- **Storage validation** - Persistent volume claim verification
- **Network policy testing** - Inter-service communication checks
- **Application-specific health endpoints** - Custom health check validation

#### Step 5: Validation Completion
- All health tests must pass before proceeding
- Failed tests trigger automatic rollback procedures
- Success status enables application deployment phase

**Expected Timeline:** 5-10 minutes for health validation

### Phase 4: Application Deployment

#### Step 6: Production Application Deployment
Once health validation passes:
- Deploy applications using standard GitOps workflows
- Applications inherit the validated infrastructure
- Monitor application-specific metrics and logs

## Monitoring and Troubleshooting

### Key Monitoring Points
1. **Flux Controller Status** - Check Flux reconciliation state
2. **Node Provisioner Logs** - Monitor node creation and registration
3. **Application Health Endpoints** - Validate service availability
4. **Resource Utilization** - CPU, memory, and storage metrics

### Common Issues and Solutions

#### Issue: Cluster Bootstrap Failure
- **Symptoms:** Initial Flux components fail to deploy
- **Solution:** Verify cluster configuration syntax and resource quotas
- **Command:** `kubectl get pods -n flux-system`

#### Issue: Node Provisioning Delays
- **Symptoms:** Nodes stuck in pending or creating state
- **Solution:** Check cloud provider quotas and availability zones
- **Command:** `kubectl get nodes` and check Node Operator logs

#### Issue: Health Check Failures
- **Symptoms:** Applications deployed but health tests fail
- **Solution:** Review application logs and dependency requirements
- **Command:** `kubectl describe pod <failing-pod>`

## Cleanup and Rollback

### Emergency Rollback
1. Comment out the cluster configuration
2. Add rollback comment with reason
3. Monitor automated cleanup process
4. Verify resource deallocation

### Planned Decommission
1. Drain applications using standard procedures
2. Comment out cluster configuration
3. Allow Flux to clean up infrastructure
4. Verify billing/cost implications

## Best Practices

### Naming Conventions
- Use descriptive cluster names with environment and region
- Include your name and date in comments
- Follow established naming patterns for consistency

### Resource Management
- Monitor resource usage during deployment
- Verify cleanup completion after decommission
- Track costs associated with cluster lifecycle

### Communication
- Notify team of cluster reservations
- Document any configuration changes
- Share lessons learned from deployment issues

## Contact Information
- **Platform Team:** [Contact details]
- **GitOps Support:** [Contact details]
- **Emergency Escalation:** [Contact details]

---
**Last Updated:** [Date]
**Version:** 1.0
**Owner:** [Team/Individual]
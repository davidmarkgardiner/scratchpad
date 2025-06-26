# Cloudability AKS Metrics Collection - Design Document

## Executive Summary

This document outlines the design and implementation strategy for deploying Cloudability cost optimization agents across Azure Kubernetes Service (AKS) clusters using a centralized architecture with workload identity integration. The solution enables automated collection of container metrics for cost optimization and rightsizing recommendations while maintaining security best practices.

## 1. Architecture Overview

### 1.1 High-Level Architecture

The Cloudability AKS Metrics Architecture implements a hub-and-spoke model where:
- **Central Hub**: FinOps SWC environment hosts shared infrastructure
- **Spokes**: Individual AKS clusters deploy metrics collection agents
- **External Integration**: Cloudability SaaS platform consumes collected metrics

### 1.2 Key Components

- **AKS Clusters**: Target environments for metrics collection
- **Central Storage**: Blob storage for aggregated metrics data
- **Azure Key Vault**: Centralized credential management
- **Service Principals**: Authentication for data access
- **Managed Identity**: Workload identity for secure cluster authentication

## 2. Infrastructure Design

### 2.1 Centralized Infrastructure (FinOps SWC Environment)

#### Storage Account
- **Name**: `someblob.blob.core.windows.net`
- **Purpose**: Central repository for daily metrics aggregation
- **Access Pattern**: Write from AKS clusters, Read by Cloudability
- **Data Retention**: Configurable based on compliance requirements

#### Azure Key Vault
- **Name**: `akv-AT12345-DEV-NEU-CLD`
- **Purpose**: Centralized secret management for SPN credentials
- **Access Control**: RBAC-based access for AKS managed identities
- **Secret Rotation**: Managed by FinOps Engineering team

### 2.2 Service Principal Architecture

#### Internal Service Principal
- **Name**: `SVC_SAML_DEV_AT12345_CLDY`
- **Permissions**: 
  - Storage Blob Data Contributor on central storage account
  - Write access to metrics blob containers
- **Authentication**: Client credentials stored in Azure Key Vault

#### External Service Principal (Cloudability)
- **Purpose**: External tenant SPN for Cloudability platform access
- **Permissions**:
  - Storage Blob Data Reader on central storage account
  - Read access to metrics data
- **Authentication**: Managed by Cloudability external tenant

### 2.3 Network Architecture

#### Connectivity Requirements
- Private endpoints for Azure Key Vault access
- Service endpoints or private endpoints for storage account access
- Cross-VNET connectivity for all AKS clusters to central infrastructure
- Outbound internet access for Cloudability API communication

## 3. AKS Cluster Configuration

### 3.1 Namespace Strategy

Each AKS cluster deploys the Cloudability agent in a dedicated namespace following the naming convention:
```
cldymetricsagent-<cluster-identifier>
```

Example: `cldymetricsagent-kd12345-we01`

### 3.2 Workload Identity Configuration

#### Managed Identity Setup
```bash
# Retrieve AKS managed identity
$MGD_IDTY_ID = az aks show \
  --resource-group <resource-group> \
  --name <cluster-name> \
  --query addonProfiles.azureKeyvaultSecretsProvider.identity.objectId \
  -o tsv
```

#### Key Vault Access
- AKS managed identity added to AD Group (pending creation)
- AD Group granted Key Vault Secrets User role
- Enables direct secret retrieval without credential storage in cluster

### 3.3 Deployment Configuration

#### Repository Location
- **Repository**: FinOps Gitlab Repository
- **Path**: `cloudability-aks-metrics-keyvault`
- **Files**: YAML manifests for agent deployment

#### Configuration Customization
Each cluster requires namespace suffix customization:
```yaml
metadata:
  name: "cloudability-metrics-agent"
  namespace: "cldymetricsagent-kd12345-we01"  # CHANGE SUFFIX FOR EACH CLUSTER
```

## 4. Security Model

### 4.1 Authentication Flow

1. **AKS Pod Authentication**: Workload identity provides Azure AD token
2. **Key Vault Access**: Managed identity retrieves SPN credentials
3. **Storage Access**: SPN credentials authenticate to blob storage
4. **Data Write**: Metrics data written to central storage account

### 4.2 Authorization Matrix

| Component | Resource | Permission | Method |
|-----------|----------|------------|---------|
| AKS Managed Identity | Azure Key Vault | Secrets User | RBAC |
| Internal SPN | Storage Account | Blob Data Contributor | RBAC |
| External SPN | Storage Account | Blob Data Reader | RBAC |
| Cloudability Agent | AKS Cluster | Pod deployment | K8s RBAC |

### 4.3 Secret Management

#### Centralized Rotation
- **Responsibility**: FinOps Engineering team
- **Location**: Central Azure Key Vault
- **Frequency**: Based on compliance requirements
- **Impact**: Single-point rotation affects all clusters

#### Security Benefits
- No secrets stored in cluster configurations
- Automated secret retrieval via workload identity
- Centralized audit trail for secret access

## 5. Data Flow Architecture

### 5.1 Metrics Collection Process

1. **Collection**: Cloudability agent collects container metrics from AKS
2. **Authentication**: Agent retrieves SPN credentials from Key Vault
3. **Aggregation**: Metrics processed and formatted locally
4. **Upload**: Daily batch upload to central blob storage
5. **Consumption**: Cloudability platform reads data via external SPN

### 5.2 Data Schema

#### Metrics Categories
- **Resource Utilization**: CPU, Memory, Network, Storage
- **Cost Attribution**: Namespace, workload, node-level costs
- **Scaling Metrics**: Pod counts, replica scaling events
- **Performance Data**: Response times, throughput metrics

## 6. Operational Considerations

### 6.1 Deployment Process

1. **Prerequisites Validation**:
   - VNET connectivity to central infrastructure
   - AKS managed identity permissions configured
   - Namespace creation and RBAC setup

2. **Agent Deployment**:
   - Clone configuration from GitLab repository
   - Customize namespace suffixes
   - Update managed identity references
   - Deploy via kubectl or GitOps pipeline

3. **Verification**:
   - Validate secret retrieval from Key Vault
   - Confirm metrics collection and upload
   - Test Cloudability dashboard data availability

### 6.2 Monitoring and Alerting

#### Health Checks
- Agent pod health and readiness probes
- Key Vault secret retrieval success rates
- Storage account write operation metrics
- Network connectivity monitoring

#### Alerting Thresholds
- Failed secret retrievals
- Storage upload failures
- Agent pod restart loops
- Network connectivity issues

### 6.3 Troubleshooting Runbook

#### Common Issues
1. **Key Vault Access Denied**: Verify managed identity permissions
2. **Storage Upload Failures**: Check SPN credentials and storage permissions
3. **Network Connectivity**: Validate VNET peering and endpoints
4. **Agent Startup Issues**: Review pod logs and resource constraints

## 7. Rightsizing and Optimization

### 7.1 Cloudability Integration

#### Dashboard Access
- **Primary Interface**: Cloudability Rightsizing Dashboard
- **Data Source**: Aggregated metrics from central storage
- **Update Frequency**: Daily metric processing

#### Custom Recommendations
- **API Integration**: Extract data via Cloudability API
- **Customization**: Tailor recommendations for customer requirements
- **Delivery**: Present recommendations through custom dashboards

### 7.2 Optimization Outcomes

#### Expected Benefits
- **Cost Reduction**: Identification of over-provisioned resources
- **Performance Optimization**: Right-sizing based on actual usage
- **Operational Efficiency**: Automated recommendations and alerts
- **Governance**: Cost allocation and chargeback capabilities

## 8. Implementation Timeline

### Phase 1: Infrastructure Setup (Week 1-2)
- Deploy central storage account and Key Vault
- Configure service principals and permissions
- Establish network connectivity

### Phase 2: Pilot Deployment (Week 3-4)
- Deploy to 2-3 pilot AKS clusters
- Validate end-to-end data flow
- Performance and security testing

### Phase 3: Production Rollout (Week 5-8)
- Gradual rollout to remaining clusters
- Monitor performance and costs
- Documentation and training delivery

### Phase 4: Optimization (Week 9-12)
- Fine-tune collection parameters
- Implement custom dashboards
- Establish operational procedures

## 9. Risk Assessment and Mitigation

### 9.1 Technical Risks

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| Key Vault outage | High | Low | Regional backup vault, SPN credential caching |
| Storage account limits | Medium | Medium | Implement data lifecycle policies, multiple accounts |
| Network connectivity issues | High | Medium | Redundant connectivity paths, monitoring |
| Agent performance impact | Medium | Low | Resource limits, performance testing |

### 9.2 Security Risks

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| Credential exposure | High | Low | Workload identity, no stored secrets |
| Unauthorized data access | High | Low | RBAC, private endpoints, audit logging |
| External SPN compromise | Medium | Low | Regular rotation, monitoring |

## 10. Success Criteria

### 10.1 Technical Metrics
- **Deployment Success Rate**: >95% successful deployments across clusters
- **Data Collection Reliability**: >99% daily metric collection success
- **Performance Impact**: <5% overhead on cluster resources
- **Security Compliance**: Zero credential exposures, full audit trail

### 10.2 Business Metrics
- **Cost Optimization**: 10-30% reduction in container infrastructure costs
- **Operational Efficiency**: 50% reduction in manual rightsizing efforts
- **Time to Value**: Actionable recommendations within 7 days of deployment

## 11. Appendices

### Appendix A: Configuration Templates
- Sample YAML manifests
- Environment-specific configuration examples
- Deployment scripts and automation

### Appendix B: Operational Procedures
- Deployment checklist
- Troubleshooting guide
- Emergency procedures

### Appendix C: API Documentation
- Cloudability API integration guide
- Custom dashboard development
- Data extraction procedures
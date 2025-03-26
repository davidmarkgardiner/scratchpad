I'll create a GitHub issue focused on moving your configuration injection from deployment scripts to a GitOps approach. Here's the issue content that you can copy:

## Title: Migrate configuration injection from deployment scripts to GitOps approach

## Description:
### Current State
Currently, we inject configuration into the cluster using scripts that run during the cluster deployment pipeline. This approach relies on the release process which is slow and cumbersome.

### Proposed Changes
We want to migrate from script-based configuration injection to a GitOps approach where:
1. Configuration objects are defined in Git repositories
2. The GitOps controller syncs configuration automatically after cluster rebuild
3. All core configuration objects are managed through this process

### Specific Requirements
- Implement GitOps-based configuration management for all core cluster components
- Ensure the Nexus certificate is injected as part of this process (critical for initial core image pull from Nexus)
- Configure GitOps sync to trigger automatically post-cluster rebuild
- Define a clear structure for configuration repositories
- Document the transition plan from current script-based approach

### Benefits
- Reduce dependency on slow release processes
- Improve visibility and auditability of configuration changes
- Standardize configuration management across clusters
- Streamline cluster rebuilds with automated configuration

### Technical Considerations
- Select appropriate GitOps tool (Flux, ArgoCD, etc.)
- Define repository structure for configuration
- Establish proper RBAC for GitOps processes
- Ensure secrets management complies with security requirements
- Define process for emergency configuration changes

Let me know if you would like any modifications to this GitHub issue content before copying it.
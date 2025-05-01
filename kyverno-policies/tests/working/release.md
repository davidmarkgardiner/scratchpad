# Investment Bank Release Process - Streamlined Improvement Plan

## Current Challenges

- **Process Chaos**: Disorganized, reactive release process with poor coordination and preparation
- **SRE Collaboration Issues**: Insufficient coordination with SRE teams leading to friction during releases
- **Release Management Gaps**: Inadequate documentation from Release 
- **Process Issues**: Multiple workflows, dual CI/CD systems (GitLab/ADO), excessive manual steps
- **Infrastructure Problems**: Monolithic releaase causes cascading failures
- **Testing Gaps**: Insufficient automated testing

## Key Improvements

### 1. Implement Daily Cluster Rebuilds (IMMEDIATE PRIORITY)
- **Automate Daily Rebuilds**: Configure daily rebuilds of development clusters
- **Streamline Approvals**: Set up ADO pipelines with simple SRE approval gates
- **Enable Batch Deployments**: Allow 2-3 environment promotions simultaneously
- **Automate Evidence Collection**: Build test evidence into the pipeline

### 2. Adopt GitOps Operator Model
- Implement declarative, Git-based deployments with automated synchronization
- Reduce manual interventions while maintaining compliance controls
- Start with non-critical services, then expand coverage

### 3. Streamline Infrastructure Management
- **Consolidate Core Pipeline**: Integrate cluster code into core using ASO
- **Modularize Core Chart**: Break core into smaller components to prevent cascading failures
- **Expand Environment Automation**: Progress from daily to hourly rebuilds as confidence grows

### 4. Overhaul Release Management Process (CRITICAL)
- **Revamp Release Manager Role**: Ensure clear ownership and accountability for the entire release process
- **Create Structured Runbooks**: Develop clear, concise step-by-step runbooks to replace current chaotic documentation
- **Prepare PRs in Advance**: Have all required PRs ready and waiting before starting release processes
- **Enhance SRE Collaboration**: Establish structured handoff procedures and communication channels with SRE team
- **Implement Pre-Release Checklists**: Create formal validation that all prerequisites are complete before beginning
- **Pre-stage Environments**: Ensure all environments are prepared and validated before release day

### 5. Consolidate to GitLab (LONG-TERM GOAL)
- **Single Unified Pipeline**: Consolidate all pipelines into GitLab
- **Eliminate Redundancy**: Move cluster management entirely into core infrastructure via GitOps
- **End-to-End Automation**: Create seamless workflow from commit to production

### 6. Strengthen Testing
- Require automated tests for all new code
- Develop comprehensive test coverage for infrastructure
- Repurpose unused EU and CU clusters for automated ADO testing
- Implement continuous testing in the pipeline

## Implementation Timeline

**Immediate Focus (0-1 month)**
- Implement daily cluster rebuilds for development environments
- Configure ADO pipelines with manual SRE approval gates
- Enable batch approvals (2-3 environments at once) to accelerate deployments
- Begin automated test evidence gathering as part of test track

**Mid-term (3-6 months)**
- Integrate infra code using ASO into core pipeline
- Start CI/CD consolidation into Gitlab only
- Implement automated environment rebuilds

**Long-term Vision (6-12+ months)**
- Complete migration to GitLab with a single unified pipeline
- Eliminate separate cluster pipeline by integrating fully into core
- Implement GitOps for all infrastructure and application deployments
- Comprehensive automated testing and evidence gathering

## Expected Outcomes

- **Faster Releases**: From days/weeks to hours
- **Higher Quality**: Reduced failure rates through automated testing
- **Developer Efficiency**: Less time spent on manual processes
- **Better Governance**: Maintained compliance with improved audit trails

This plan balances strict banking governance requirements with the need for engineering agility, allowing for secure but significantly faster code releases.


---
I've added your points about configuration file complexity:

**Current challenges:**
- Need to automate cluster rebuilds and deployments
- Code needs to push to both GitLab and ADO
- Core chart is complex, making debugging difficult
- Engineering environments need daily rebuilds
- CU and EU environments need repurposing in ADO
- **Configuration files are too complex and drift across clusters**

**Future considerations:**
- Potentially consolidate into GitLab only and remove ADO
- Consider using a single pipeline for cluster and core
- Possibly use ASO to extract cluster components
- **Establish a single source of truth for configuration**
- **Implement GitOps to write configurations to clusters as config maps**
- **Enable easy amendments to configuration files when needed**

**Primary goal:**
- Simplify daily cluster rebuilds with automated testing and evidence gathering to focus on engineering rather than release management

This approach with GitOps for configuration management should help eliminate drift between environments and provide better consistency across your clusters.
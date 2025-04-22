# Improving Our Release Process

## Current Challenges
- Complex hybrid GitLab/Azure DevOps setup with multiple pipelines
- Knowledge gaps between development teams and SRE
- Incomplete documentation causing repeated problems
- Issues with MR quality control and ticket management
- Slow feedback loops for breaking changes

## Proposed Solutions

### 1. Streamline Pipeline Architecture

- **Consolidate from 3 pipelines to 2** using Azure Service Operator (ASO) with Flux and managed identities
- **Prioritize Kubernetes Operators and CRDs over Terraform**
  - Aligns with our existing GitOps approach in config, core, and node deployments
  - Provides declarative, Kubernetes-native management
  - Reduces tool fragmentation and complexity

### 2. Implement Progressive Deployment Strategy

- **Create "Friendly User" Test Environment**
  - Set up production-like test environment with real users
  - Enable regular deployments outside change windows
  - Collect feedback before main release

- **Automated Daily/Weekly Test Deployments**
  - Implement simplified approval process for test environment
  - Use feature flags to control exposure of new features
  - Run automated regression tests after each deployment

### 3. Improve Knowledge Sharing & Documentation

- **Visual Process Documentation**
  - Create comprehensive flow diagrams of entire release process
  - Define RACI matrix for release responsibilities
  - Maintain living documentation that evolves with the process

- **Cross-Team Training**
  - Schedule regular sessions between developers and SRE
  - Implement "Release Day" shadowing opportunities
  - Record video walkthroughs of successful releases

### 4. GitLab Certification Initiative

- Begin process of getting GitLab certified for compliance requirements
- Eliminate need to debug and manage code for different environments
- Potential for single-platform solution long-term

## Implementation Roadmap

1. **Proof of Concept (Weeks 1-3)**
   - Select one component for ASO + Flux implementation
   - Create friendly user test environment
   - Document streamlined pre-change window process

2. **Pilot Phase (Weeks 4-8)**
   - Implement automated feedback collection
   - Begin GitLab certification process
   - Create initial training materials

3. **Rollout Phase (Weeks 9-16)**
   - Expand to additional components
   - Refine based on metrics and team feedback
   - Standardize new process documentation

## Expected Benefits

- **Faster Feedback Loops**: Catch issues before they reach production
- **Reduced Complexity**: Fewer pipelines and more consistent technology choices
- **Better Knowledge Sharing**: Improved documentation and cross-team understanding
- **Higher Quality Releases**: More testing with real users in realistic environments

This approach leverages modern Kubernetes-native tooling while addressing our specific process pain points, creating a more reliable and efficient release pipeline.
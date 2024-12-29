# Meeting Summary: Kubernetes Resource Management & Onboarding Implementation

Hi team,

I wanted to follow up on today's meeting to clarify the action items and decisions regarding our Kubernetes resource management implementation.

## Key Discussion Points:

### 1. Taints and Tolerations Implementation
- Need to determine implementation approach during onboarding process
- Consider implementation via mutation
- Action needed: Define specific taints to be implemented
- Question to resolve: Will spot instances be part of the rollout?

### 2. Resource Limit Requests
- Currently set during onboarding
- Proposed approach: Use mutation to:
  - Monitor average resource usage
  - Automatically adjust resource quotas per namespace
  - Goal: Prevent cluster over-provisioning

### 3. LimitRange Configuration
- These are hard limits that cannot be exceeded
- Implementation proposals:
  - Set during onboarding process
  - Enforce through Azure Policy mutation
  - Use either OPA (Open Policy Agent) or Kyverno for policy enforcement
- Need team decision on which policy engine to use (OPA vs. Kyverno)

## Next Steps:
1. Decision needed on policy engine selection
2. Define specific LimitRange values for different workload types
3. Could each team member please indicate which areas they'll be responsible for?

Please reply with any corrections or additional points I might have missed.

Best regards,
[Your name]
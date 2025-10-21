PROMPT FOR AI AGENT: Flux Folder Structure Integration
Context:
I need to integrate KRO (Kubernetes Resource Orchestrator) resource definitions into my existing Flux-based folder structure. This deployment system will be used to manage hundreds of clusters across multiple environments (Engineering, Dev, Pre-Prod, Production) using Flux customization and substitution patterns.
Your Tasks:

Review Current Structure

Examine the folder structure defined in tree.md
Understand the current organization and patterns


Analyze KRO Resources

Review all files in the KRO-ASO-CLUSTER folder
Identify the resource definitions and their relationships


Categorize Variables
Environment-Wide Constants (Hard-coded):

SSH keys
Azure Container Registries (ACRs)
Key Vaults
Any resources shared across ALL clusters within an environment
These should NOT be variableized as they remain constant per environment

Cluster-Specific Variables (Parameterized):

Managed Identity name
Cluster name and suffix
Region/Location
Resource Group
Any other cluster-unique identifiers


Design Integration

Propose how to integrate the KRO resources into the existing folder structure
Ensure the solution uses Flux customization and substitution patterns
Maintain clear separation between environment-wide and cluster-specific configurations



Critical Requirements:

Simplicity: The structure must be easy to understand and maintain
Robustness: No configuration drift or errors when deploying across clusters
Scalability: Must support hundreds of clusters across multiple environments
Consistency: Clear patterns that prevent human error during deployment

Deliverable:
Provide a recommended folder structure with clear explanations of:

Where KRO resources should be placed
What should be hard-coded vs. variableized
How Flux substitution should be applied
Examples of the configuration pattern
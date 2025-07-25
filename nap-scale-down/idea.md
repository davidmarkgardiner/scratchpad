You could set up an automated cleanup system using GitOps principles with scheduled merge requests. Here are a few effective approaches:

**Scheduled Cleanup via CI/CD Pipeline:**
Create a scheduled pipeline (GitHub Actions, Azure DevOps, etc.) that runs Friday evening to automatically create a merge request that:
- Scales down non-production clusters by modifying your Azure Service Operator manifests
- Removes or comments out NAP (Node Auto Provisioning) configurations
- The MR gets auto-approved and merged, triggering your GitOps controller (ArgoCD, Flux, etc.) to apply the changes

**Branch-based Weekend Mode:**
- Maintain a "weekend" branch with scaled-down configurations
- Friday evening automation creates an MR to merge weekend branch into main
- Monday morning automation reverts back by merging main (with original configs) back

**Conditional Manifests with Kustomize:**
Use Kustomize overlays with time-based patches. Your pipeline could:
- Switch to a "weekend" overlay that zeros out replicas
- Create MR with the overlay change
- Monday morning switches back to "weekday" overlay

**Configuration Management Approach:**
Store cluster sizing in a separate config file (JSON/YAML) that your manifests reference. Weekend automation just needs to update the config values and create an MR for that single file change.

The key is ensuring your GitOps controller watches the repo and automatically applies changes when MRs are merged. You'd also want safeguards like requiring specific commit messages or file paths to prevent accidental infrastructure changes.

Which of these patterns aligns best with your current GitOps setup?
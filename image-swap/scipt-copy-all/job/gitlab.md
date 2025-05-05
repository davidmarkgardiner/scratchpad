# Image Push Inconsistency Investigation

## Issue Summary
Image name/location was different when deploying various Kubernetes resources (CronJob, Job, etc.). This inconsistency caused deployment issues across different resource types.

## What's Been Done

### Created Additional Policies
- Developed extra policies to catch edge cases related to image location discrepancies

### Bulk Image Migration Script
- Created a script to bulk copy all images from Nexus to ACR (Azure Container Registry) upfront
- This ensures all required images are available in the target registry before deployment

## Things Still to Check

### Helm Chart Installation
- Still not able to get the policy to work when deploying Helm charts

### Job Type Decision
- Confirm whether to use the current job as:
  - One-off Job (runs once and completes)
  - CronJob (runs on a schedule)

### Job Execution Issue
- **Current Problem**: Job continues to run repeatedly instead of running once
- **Expected Behavior**: Job should run once, complete, exit, and be cleaned up
- **Investigation Needed**:
  - Verify exit codes and completion status
  - Review restart policies

### Documentation Updates
- Update docs in DCP

## Next Steps

1. Debug Helm chart policy issues
   - Investigate why policies aren't being applied correctly during Helm deployments
   - Test with simplified chart to isolate the issue

2. Resolve job execution problems
   - Check for `restartPolicy` configuration (should be `Never` or `OnFailure`)
   - Verify `backoffLimit` settings
   - Ensure container exits with code 0 on successful completion
   - Check for any controllers that might be recreating the job

3. Make decision on job type
   - Document reasoning for final job type selection (one-off vs. cron)
   - Update configuration accordingly

4. Complete documentation updates in DCP
   - Include details on image location standardization
   - Document new policies and how they work
   - Add troubleshooting section for common issues
# AKS Deployment Validation Script

## Overview

This script handles the validation and preparation of Azure resource groups for AKS (Azure Kubernetes Service) deployments. It supports both GitLab CI and Azure DevOps (ADO) pipelines and implements governance controls for cluster deployments.

## Purpose

- Validates resource group existence and creates it if necessary
- Enforces the "one-cluster-per-resource-group" policy (when using new naming convention)
- Supports both old and new naming conventions via configuration
- Works in both GitLab CI and Azure DevOps pipelines

## Required Environment Variables

- `SUBSCRIPTION`: Azure subscription ID
- `ENV`: Environment name (dev, test, prod, etc.)
- `CLUSTER_SUFFIX`: Suffix for the cluster name
- `resourceGroupName`: Name of the resource group
- `location`: Azure region for deployment
- `billingReference`: (Optional) Billing reference tag
- `opEnvironment`: (Optional) Operating environment tag
- `cmdbReference`: (Optional) CMDB reference tag

## Configuration

The script looks for a configuration file at `env/$ENV.yml` where `$ENV` is the environment variable.

### New Naming Convention Flag

The script's behavior is controlled by the `common_useNewNamingConvention` property in your YAML config:

- When set to `"true"`: Uses the full validation logic, including cluster name validation and the one-cluster-per-resource-group policy
- When set to anything else (or missing): Uses simplified logic that only checks if the resource group exists and creates it if needed

Example YAML structure:
```yaml
# For GitLab
- variables:
    common_useNewNamingConvention: "true"  # or "false"
    common_newClusterName: "my-cluster"

# For ADO
-
  common_useNewNamingConvention: "true"  # or "false"
  common_newClusterName: "my-cluster"
```

## Behavior

### When `common_useNewNamingConvention` is not "true"

The script will:
1. Check if the resource group exists
2. If it doesn't exist, create it with optional tags
3. Skip all cluster name validation

### When `common_useNewNamingConvention` is "true"

The script will:
1. Check if the resource group exists
2. If it exists, check for existing clusters
3. If a cluster exists, validate that its name matches the target cluster name
4. If the names don't match, fail with an error (enforcing one-cluster-per-resource-group)
5. If the resource group doesn't exist, create it with optional tags

## Cross-Platform Compatibility

The script detects whether it's running in GitLab CI or Azure DevOps:

- In GitLab: Uses `.[].variables.common_*` YAML path
- In ADO: Uses `.[].common_*` YAML path

In ADO environments, the script makes the target cluster name available to subsequent pipeline steps using the ADO-specific variable syntax.

## Exit Codes

- `0`: Success
- `1`: Error (with descriptive error message)
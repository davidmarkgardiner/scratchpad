# Deployment Sequence Diagram

```
┌───────────┐          ┌───────────┐          ┌───────────┐          ┌───────────┐          ┌───────────┐
│           │          │           │          │           │          │  Azure    │          │           │
│  DevOps   │          │  Azure    │          │   AKS     │          │  Managed  │          │   Key     │
│  Pipeline │          │   CLI     │          │  Cluster  │          │  Identity │          │   Vault   │
└─────┬─────┘          └─────┬─────┘          └─────┬─────┘          └─────┬─────┘          └─────┬─────┘
      │                      │                      │                      │                      │
      │  Start Deployment    │                      │                      │                      │
      │──────────────────────>                      │                      │                      │
      │                      │                      │                      │                      │
      │                      │  Get Cluster Creds   │                      │                      │
      │                      │────────────────────> │                      │                      │
      │                      │                      │                      │                      │
      │                      │  Check Workload ID   │                      │                      │
      │                      │────────────────────> │                      │                      │
      │                      │                      │                      │                      │
      │                      │  Enable Workload ID  │                      │                      │
      │                      │────────────────────> │                      │                      │
      │                      │                      │                      │                      │
      │                      │  Create/Get Identity │                      │                      │
      │                      │────────────────────────────────────────────>│                      │
      │                      │                      │                      │                      │
      │                      │  Create Fed Credential                      │                      │
      │                      │────────────────────────────────────────────>│                      │
      │                      │                      │                      │                      │
      │                      │  Grant KV Access     │                      │                      │
      │                      │────────────────────────────────────────────────────────────────────>
      │                      │                      │                      │                      │
      │                      │  Create Service Account                     │                      │
      │                      │────────────────────> │                      │                      │
      │                      │                      │                      │                      │
      │                      │  Annotate SA with Client ID                 │                      │
      │                      │────────────────────> │                      │                      │
      │                      │                      │                      │                      │
      │                      │  Deploy Helm Chart   │                      │                      │
      │                      │────────────────────> │                      │                      │
      │                      │                      │                      │                      │
      │                      │  Verify Deployment   │                      │                      │
      │                      │────────────────────> │                      │                      │
      │                      │                      │                      │                      │
      │  Report Results      │                      │                      │                      │
      │ <──────────────────────                      │                      │                      │
      │                      │                      │                      │                      │
┌─────┴─────┐          ┌─────┴─────┐          ┌─────┴─────┐          ┌─────┴─────┐          ┌─────┴─────┐
│           │          │           │          │           │          │  Azure    │          │           │
│  DevOps   │          │  Azure    │          │   AKS     │          │  Managed  │          │   Key     │
│  Pipeline │          │   CLI     │          │  Cluster  │          │  Identity │          │   Vault   │
└───────────┘          └───────────┘          └───────────┘          └───────────┘          └───────────┘
```

## Runtime Authentication Flow

After deployment, the application authenticates to Key Vault using workload identity:

```
┌───────────┐          ┌───────────┐          ┌───────────┐          ┌───────────┐          ┌───────────┐
│           │          │           │          │           │          │  Azure    │          │           │
│   App     │          │  Service  │          │   OIDC    │          │   AD      │          │   Key     │
│   Pod     │          │  Account  │          │  Provider │          │  Service  │          │   Vault   │
└─────┬─────┘          └─────┬─────┘          └─────┬─────┘          └─────┬─────┘          └─────┬─────┘
      │                      │                      │                      │                      │
      │  Request Token       │                      │                      │                      │
      │──────────────────────>                      │                      │                      │
      │                      │                      │                      │                      │
      │                      │  Get OIDC Token      │                      │                      │
      │                      │────────────────────> │                      │                      │
      │                      │                      │                      │                      │
      │                      │  Return OIDC Token   │                      │                      │
      │                      │ <────────────────────│                      │                      │
      │                      │                      │                      │                      │
      │  Return OIDC Token   │                      │                      │                      │
      │ <──────────────────────                      │                      │                      │
      │                      │                      │                      │                      │
      │  Exchange for Azure Token                                          │                      │
      │─────────────────────────────────────────────────────────────────────>                      │
      │                      │                      │                      │                      │
      │  Return Azure Token  │                      │                      │                      │
      │ <─────────────────────────────────────────────────────────────────────                      │
      │                      │                      │                      │                      │
      │  Access Secret with Token                                                                │
      │─────────────────────────────────────────────────────────────────────────────────────────>│
      │                      │                      │                      │                      │
      │  Return Secret       │                      │                      │                      │
      │ <─────────────────────────────────────────────────────────────────────────────────────────│
      │                      │                      │                      │                      │
┌─────┴─────┐          ┌─────┴─────┐          ┌─────┴─────┐          ┌─────┴─────┐          ┌─────┴─────┐
│           │          │           │          │           │          │  Azure    │          │           │
│   App     │          │  Service  │          │   OIDC    │          │   AD      │          │   Key     │
│   Pod     │          │  Account  │          │  Provider │          │  Service  │          │   Vault   │
└───────────┘          └───────────┘          └───────────┘          └───────────┘          └───────────┘
```

This sequence demonstrates how the application pod authenticates to Azure Key Vault without needing any client secrets in the container or configuration files. The entire process leverages token-based authentication through the workload identity federation. 
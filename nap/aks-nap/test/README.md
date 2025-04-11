# AKS Node Auto Provisioning (NAP) Test

This test demonstrates deploying an AKS cluster with Node Auto Provisioning (NAP) enabled and configuring system workloads to run on the system node pool.

## Components

- AKS Cluster with NAP enabled
- Cert Manager (system workload)
- External Secrets (system workload)
- Kyverno (system workload)

## Directory Structure

```
test/
├── README.md
├── cluster/
│   └── create-cluster.sh
├── manifests/
│   ├── system-workloads.yaml
│   ├── cert-manager-values.yaml
│   ├── external-secrets-values.yaml
│   └── kyverno-values.yaml
└── deploy.sh
```

## Prerequisites

- Azure CLI installed
- `aks-preview` extension installed
- `NodeAutoProvisioningPreview` feature flag registered
- Helm 3.x installed

## Setup

1. Create the AKS cluster:
```bash
./cluster/create-cluster.sh
```

2. Deploy system workloads:
```bash
./deploy.sh
```

## Verification

To verify the setup:

```bash
# Check node pools
kubectl get nodes -L kubernetes.azure.com/scalesetpriority

# Check system workloads
kubectl get pods -n cert-manager
kubectl get pods -n external-secrets
kubectl get pods -n kyverno
``` 
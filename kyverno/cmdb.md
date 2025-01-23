# CMDB Reference Injection Using Kyverno

## Overview
This solution automatically injects CMDB references into all pods using Kyverno mutation policies. The CMDB reference is sourced from namespace labels.

## Prerequisites
- Kubernetes cluster
- Kyverno installed
- Namespaces labeled with `cmdbReference`

## Implementation

### 1. Label Verification
Ensure your namespace has the required label:
```bash
kubectl get namespace your-namespace --show-labels
# Should show: cmdbReference=at12345
```

### 2. Kyverno Policy
Apply the following policy:

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: inject-cmdb-reference
spec:
  background: false
  rules:
    - name: inject-cmdb-env
      match:
        any:
        - resources:
            kinds:
              - Pod
      mutate:
        patchStrategicMerge:
          spec:
            containers:
              - (name): "*"
                env:
                  - name: CMDB_REFERENCE
                    valueFrom:
                      fieldRef:
                        fieldPath: metadata.namespace
                        apiVersion: v1
                  - name: CMDB_REFERENCE_VALUE
                    valueFrom:
                      fieldRef:
                        fieldPath: metadata.labels['cmdbReference']
```

### 3. Verification
Check any pod in labeled namespace:
```bash
kubectl exec <pod-name> -n <namespace> -- env | grep CMDB
```

## Security Considerations
- CMDB reference is injected at pod creation
- Value is sourced from namespace labels
- Read-only within containers
- Available to vulnerability scanners

## Troubleshooting
1. Check namespace labels are correct
2. Verify Kyverno policy is active
3. Inspect pod environment variables
4. Check Kyverno admission logs

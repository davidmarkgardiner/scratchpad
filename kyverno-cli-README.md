# Kyverno CLI Deployment

This repository contains YAML files for deploying and using the Kyverno CLI in a Kubernetes cluster.

## What is Kyverno CLI?

The Kyverno CLI is a command-line tool that allows you to:
- Test Kyverno policies against Kubernetes resources
- Apply policies to resources without deploying them to a cluster
- Validate resources against policies
- Generate policy reports

## Files Included

1. `kyverno-cli-deployment.yaml` - Deploys the Kyverno CLI as a long-running container in your cluster
2. `kyverno-cli-job.yaml` - Example job that demonstrates how to use the Kyverno CLI to test policies

## Deployment Instructions

### 1. Deploy the Kyverno CLI

```bash
kubectl apply -f kyverno-cli-deployment.yaml
```

This will:
- Create a dedicated namespace `kyverno-cli`
- Create a ServiceAccount with appropriate permissions
- Deploy the Kyverno CLI container
- Create a ConfigMap with an example policy

### 2. Run the Example Job

```bash
kubectl apply -f kyverno-cli-job.yaml
```

This job demonstrates:
- How to apply a policy to test resources
- How to generate policy reports
- Testing both compliant and non-compliant resources

### 3. Check the Job Results

```bash
kubectl logs -n kyverno-cli job/kyverno-cli-apply-job
```

## Using the Deployed Kyverno CLI

You can exec into the running Kyverno CLI pod to run commands:

```bash
# Get the pod name
KYVERNO_CLI_POD=$(kubectl get pods -n kyverno-cli -l app=kyverno-cli -o jsonpath='{.items[0].metadata.name}')

# Exec into the pod
kubectl exec -it -n kyverno-cli $KYVERNO_CLI_POD -- /bin/sh

# Run Kyverno CLI commands
kyverno version
```

## Common Kyverno CLI Commands

1. Apply a policy to a resource:
```bash
kyverno apply /path/to/policy.yaml --resource /path/to/resource.yaml
```

2. Apply a policy to all resources in a cluster:
```bash
kyverno apply /path/to/policy.yaml --cluster
```

3. Generate a policy report:
```bash
kyverno apply /path/to/policy.yaml --resource /path/to/resource.yaml --policy-report
```

4. Test a policy with variables:
```bash
kyverno apply /path/to/policy.yaml --resource /path/to/resource.yaml --set variable1=value1,variable2=value2
```

## Additional Resources

- [Kyverno Documentation](https://kyverno.io/docs/)
- [Kyverno CLI Documentation](https://kyverno.io/docs/kyverno-cli/)
- [Kyverno GitHub Repository](https://github.com/kyverno/kyverno) 
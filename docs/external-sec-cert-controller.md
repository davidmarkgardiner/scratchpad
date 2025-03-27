# External Secrets Cert Controller Debugging Guide

This guide provides a systematic approach to debug issues with the External Secrets Cert Controller installed via Helm on an AKS cluster.

## 1. Verify Installation Status

```bash
# Check the namespace where External Secrets is installed
kubectl get pods -n external-secrets

# Check the status of all related pods
kubectl get pods -n external-secrets -o wide

# Check detailed pod status for any failing pods
kubectl describe pod -n external-secrets -l app.kubernetes.io/name=external-secrets-cert-controller
```

## 2. Check Logs

```bash
# Get logs from cert controller pods (adjust pod name as needed based on previous command)
kubectl logs -n external-secrets -l app.kubernetes.io/name=external-secrets-cert-controller --tail=100

# If there's a specific pod showing errors, check its logs directly
# kubectl logs -n external-secrets [pod-name] --tail=200

# Check events in the namespace
kubectl get events -n external-secrets --sort-by='.lastTimestamp'
```

## 3. Check Helm Release Status

```bash
# List all helm releases 
helm list -n external-secrets

# Check detailed information about the external-secrets release
helm status external-secrets -n external-secrets

# Get the values used in the helm installation
helm get values external-secrets -n external-secrets
```

## 4. Check for RBAC Issues

```bash
# Check associated ServiceAccounts
kubectl get serviceaccounts -n external-secrets -l app.kubernetes.io/name=external-secrets-cert-controller

# Check ClusterRoles and ClusterRoleBindings
kubectl get clusterrole,clusterrolebinding -l app.kubernetes.io/name=external-secrets-cert-controller

# Check Roles and RoleBindings in the namespace
kubectl get role,rolebinding -n external-secrets -l app.kubernetes.io/name=external-secrets-cert-controller
```

## 5. Check Certificate Resources

```bash
# Check certificate resources
kubectl get certificates,certificatesigningrequests -n external-secrets

# Check secrets related to certificates
kubectl get secrets -n external-secrets -l app.kubernetes.io/name=external-secrets-cert-controller
```

## 6. Check for Network Issues

```bash
# Check if the service is running correctly
kubectl get services -n external-secrets -l app.kubernetes.io/name=external-secrets-cert-controller

# Test connectivity from inside the cluster (create a temporary debug pod)
kubectl run temp-debug --rm -i --tty --image=mcr.microsoft.com/azure-cli --restart=Never -- bash

# Inside the debug pod, test connectivity to the cert controller service
# curl -k https://<service-name>.<namespace>.svc.cluster.local:<port>
# Exit when done
# exit
```

## 7. Check for AKS Specific Issues

```bash
# Check if the AKS cluster has the right addons enabled
az aks show -g <resource-group> -n <cluster-name> --query addonProfiles

# Check if there are any AKS-specific issues
az aks show -g <resource-group> -n <cluster-name> --query "provisioningState"
```

## 8. Resource Constraints

```bash
# Check if pods are being OOMKilled or have resource constraints
kubectl describe pods -n external-secrets -l app.kubernetes.io/name=external-secrets-cert-controller | grep -A 5 "Last State"

# Check resource usage
kubectl top pods -n external-secrets
```

## 9. Debug Helm Installation

If needed, you can uninstall and reinstall with debug flags:

```bash
# Uninstall the current release
helm uninstall external-secrets -n external-secrets

# Reinstall with debug
helm install external-secrets external-secrets/external-secrets \
  --namespace external-secrets \
  --create-namespace \
  --debug \
  --set certController.enabled=true \
  --set-string webhook.port=9443 \
  --set webhook.createService=true
```

## 10. Common Issues and Solutions

1. **Certificate Issues**: The cert controller may fail if it cannot issue or validate certificates
   - Solution: Check if cert-manager is installed and working properly

2. **RBAC Issues**: The controller may not have sufficient permissions
   - Solution: Ensure proper ClusterRoles and RoleBindings are created

3. **Webhook Configuration**: Incorrect webhook configuration can cause failures
   - Solution: Verify the webhook configuration and ensure the service is properly defined

4. **Resource Constraints**: Pod might be OOMKilled
   - Solution: Increase memory limits in Helm values

5. **AKS Network Policy Conflicts**: Network policies might block necessary communication
   - Solution: Check and adjust network policies

## 11. Useful Diagnostic Commands

```bash
# Get detailed information about the cert controller deployment
kubectl get deployment -n external-secrets -l app.kubernetes.io/name=external-secrets-cert-controller -o yaml

# Check webhook configurations
kubectl get validatingwebhookconfiguration,mutatingwebhookconfiguration -l app.kubernetes.io/name=external-secrets

# Check if the controller is able to reach the Kubernetes API
kubectl exec -it -n external-secrets <cert-controller-pod-name> -- wget -O- --timeout=2 https://kubernetes.default.svc/healthz -q
```

If you need further assistance after running these commands, please collect the output from the commands above and share the logs and error messages for more targeted help.
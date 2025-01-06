Let's break this down systematically as it's a common Kubernetes webhook issue that can affect cluster-wide operations.

The error you're seeing suggests that the Kyverno webhook is not functioning correctly, and since admission webhooks are cluster-wide resources, this is affecting operations across all namespaces. Here are the steps we should take to resolve this:

1. First, check if the webhook is reachable:
```bash
kubectl get pods -n kyverno
kubectl get svc -n kyverno
```

2. You can try to delete the webhook configurations directly:
```bash
kubectl delete mutatingwebhookconfigurations kyverno-policy-mutating-webhook-cfg
kubectl delete validatingwebhookconfigurations kyverno-policy-validating-webhook-cfg
kubectl delete validatingwebhookconfigurations kyverno-resource-validating-webhook-cfg
```

3. If that doesn't work, you might need to patch the webhook to remove finalizers:
```bash
kubectl patch mutatingwebhookconfigurations kyverno-policy-mutating-webhook-cfg -p '{"metadata":{"finalizers":[]}}' --type=merge
```

4. If you're still stuck, you can try to force delete the webhooks with this patch:
```bash
kubectl patch mutatingwebhookconfigurations kyverno-policy-mutating-webhook-cfg --type json -p='[{"op": "remove", "path": "/metadata/finalizers"}]'
```

5. As a last resort, you can temporarily disable the webhook admission configuration in the API server. This would require:
   - Accessing your kube-apiserver configuration
   - Removing or commenting out the MutatingAdmissionWebhook and ValidatingAdmissionWebhook from the enable-admission-plugins list
   - Restarting the API server

Have you tried any of these approaches yet? Also, it would be helpful to know:
- What version of Kubernetes are you running?
- What version of Kyverno were you using?
- Did this happen after an upgrade or any specific change?

## depoy policies

kustomize build clusters/dev/ > clusters/dev/output.yaml
k apply -f clusters/dev/output.yaml   

```

# get a formatted report for a specific policy:
kubectl get clusterpolicy -o custom-columns="NAME:.metadata.name,BACKGROUND:.spec.background,ACTION:.spec.validationFailureAction,READY:.status.ready"

# more detailed information about specific policy violations:
kubectl get policyreport -A -o custom-columns="NAMESPACE:.metadata.namespace,PASS:.summary.pass,FAIL:.summary.fail,WARN:.summary.warn,ERROR:.summary.error,SKIP:.summary.skip"

# more detailed information about specific policy violations:
kubectl get polr -A -o jsonpath="{range .items[*]}{'\n'}Namespace: {.metadata.namespace}{'\n'}Results: {range .results[*]}{'\n'}  - Policy: {.policy}{'\n'}    Rule: {.rule}{'\n'}    Message: {.message}{'\n'}{end}{end}" | grep -v "^$"


kubectl get polr -A -o jsonpath="{range .items[*]}{'\n'}Namespace: {.metadata.namespace}{'\n'}Results: {range .results[*]}{'\n'}  - Policy: {.policy}{'\n'}    Rule: {.rule}{'\n'}    Message: {.message}{'\n'}{end}{end}" | grep -v "^$"

kubectl get polr -A -o jsonpath="{range .items[*]}{'\n'}Namespace: {.metadata.namespace}{'\n'}Results: {range .results[*]}{if contains .message \"validation error\"}{'\n'}  - Policy: {.policy}{'\n'}    Rule: {.rule}{'\n'}    Message: {.message}{'\n'}{end}{end}{end}" | grep -v "^$" | grep -v "Results: $"
```


```

kubectl describe clusterpolicy | grep -A 10 "Status:"

kubectl get pods -n kyverno

```


```
Let me help you debug the Kyverno ClusterPolicy issues. Let's go through this systematically:

1. First, let's check if the Kyverno controller is running properly:
```bash
kubectl get pods -n kyverno
kubectl logs -n kyverno -l app.kubernetes.io/name=kyverno
```

2. Check the Kyverno admission webhook configuration:
```bash
kubectl get validatingwebhookconfigurations | grep kyverno
kubectl get mutatingwebhookconfigurations | grep kyverno
```

3. For the specific ClusterPolicies, let's get more detailed information:
```bash
kubectl describe clusterpolicy <policy-name>
```
Look for any errors or issues in the status and events sections.

4. For PolicyReports not being generated, check:
- If the background scan is enabled (which I see you're checking)
- The status of the PolicyReport controller:
```bash
kubectl get pods -n kyverno -l app.kubernetes.io/component=background-controller
```

5. Enable debug logging for Kyverno:
```bash
kubectl patch cm -n kyverno kyverno -p '{"data":{"log.level":"debug"}}'
```
Then restart the Kyverno pod:
```bash
kubectl rollout restart deployment -n kyverno kyverno
```

6. Check if there are any errors in the Kyverno webhook server:
```bash
kubectl logs -n kyverno -l app.kubernetes.io/component=kyverno
```

Would you be able to share:
1. The output of the Kyverno pod logs?
2. The result of `kubectl describe clusterpolicy` for one of the affected policies?

This would help identify if it's a configuration issue or a problem with the Kyverno deployment itself.

```


```

kubectl rollout restart deployment kyverno-admission-controller
kubectl rollout restart deployment kyverno-background-controller
kubectl rollout restart deployment kyverno-cleanup-controller
kubectl rollout restart deployment kyverno-reports-controller
```
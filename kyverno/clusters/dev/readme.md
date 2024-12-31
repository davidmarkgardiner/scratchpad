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
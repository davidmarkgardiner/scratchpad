To get the count of running pods in Kubernetes, you can use one of these commands:

```bash
# Count all running pods across all namespaces
kubectl get pods --all-namespaces --field-selector=status.phase=Running | wc -l

# Count running pods in current namespace
kubectl get pods --field-selector=status.phase=Running | wc -l

# For a specific namespace
kubectl get pods -n your-namespace --field-selector=status.phase=Running | wc -l
```

You can also use grep for a more readable format:
```bash
kubectl get pods --all-namespaces | grep "Running" | wc -l
```

If you want to see the count along with pod names, you can use:
```bash
# Shows running pods with their names
kubectl get pods --all-namespaces --field-selector=status.phase=Running
```

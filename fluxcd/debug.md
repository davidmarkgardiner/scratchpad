This error output shows you're having issues with a Flux HelmRelease that's stuck in a problematic state. Let me walk you through how to debug this:

1. First, check the basic status of your HelmRelease:
```bash
flux get helmreleases -A
```

2. For a more detailed view of the specific release that's failing (uk8s-core):
```bash
flux get helmrelease uk8s-core -n uk8s-core --verbose
```

3. Get the logs from the Helm controller to see more details:
```bash
kubectl logs -n flux-system deployment/helm-controller -f
```

4. Check if there are any issues with the Kubernetes cluster that might be preventing the Helm chart from installing properly:
```bash
kubectl get events -n uk8s-core --sort-by='.lastTimestamp'
```

5. Since you're seeing "context deadline exceeded", this suggests a timeout issue. You might need to check:
   - Network connectivity to the Helm repository
   - Resource constraints in your cluster
   - Large chart size causing slow deployment

6. Try to manually force the removal of the stuck release:
```bash
flux suspend helmrelease uk8s-core -n uk8s-core
kubectl patch helmreleases.helm.toolkit.fluxcd.io uk8s-core -n uk8s-core --type json -p '[{"op":"remove","path":"/status"}]'
helm uninstall uk8s-core -n uk8s-core
flux resume helmrelease uk8s-core -n uk8s-core
```

7. If the above doesn't work, you might need to delete and recreate the HelmRelease:
```bash
kubectl delete helmrelease uk8s-core -n uk8s-core
# Then apply your HelmRelease manifest again
```

8. Check for any finalizers that might be preventing proper cleanup:
```bash
kubectl get helmrelease uk8s-core -n uk8s-core -o json | jq '.metadata.finalizers'
```

If finalizers are present, you might need to remove them with a patch if the release is truly stuck.

The message "unable to determine state for release with status 'uninstalling'" suggests the Helm release is stuck in an uninstalling state, which often requires manual intervention.
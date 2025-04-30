I see the issue now. This error message reveals what's causing your ama-metrics pod to consume so much memory.

The key problem is in the error message: `"Permanent error: rpc error: code = ResourceExhausted desc = Received message larger than max (12737279 vs. 12582912)"`

What's happening is:
- The OpenTelemetry collector (used by Azure Monitor for containers) is trying to send a metrics batch that's too large
- The message size (12.7MB) exceeds the maximum allowed size (12.5MB)
- The configuration isn't set up to retry on failures (`retry_on_failure` option not enabled)
- As a result, it's dropping 7000 metric items each time this happens

This explains the high memory usage - the collector is accumulating large batches of metrics that can't be sent.

Here's how to address this:

1. Modify the OpenTelemetry collector configuration to:
   - Enable the retry mechanism
   - Reduce batch sizes
   - Increase sending frequency

2. Add or update these settings in your collector configuration:
```yaml
exporters:
  otlp:
    retry_on_failure:
      enabled: true
      initial_interval: 5s
      max_interval: 30s
      max_elapsed_time: 300s
    sending_queue:
      enabled: true
      num_consumers: 4
      queue_size: 1000
    timeout: 30s
```

3. You might also need to adjust the batch processor settings:
```yaml
processors:
  batch:
    send_batch_size: 8000  # Reduce from default or current setting
    send_batch_max_size: 10000000  # Ensure this is below the 12MB limit
    timeout: 10s  # Send more frequently
```

To implement these changes:

1. Find the ConfigMap for the ama-metrics settings:
```bash
kubectl get configmaps -n <namespace> | grep otel
```

2. Edit the ConfigMap with the adjusted settings:
```bash
kubectl edit configmap <configmap-name> -n <namespace>
```

3. Restart the ama-metrics pod:
```bash
kubectl delete pod <ama-metrics-pod-name> -n <namespace>
```

This issue is a common one with OpenTelemetry collectors in large Kubernetes environments where they collect metrics from many resources. The configuration changes should help regulate the memory usage while ensuring your metrics are still collected properly.
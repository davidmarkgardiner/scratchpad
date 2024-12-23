# Kubernetes Resource Management: Requests vs Limits

## Resource Requests
- What the node guarantees/reserves for the pod
- Used by scheduler for node placement decisions
- Guaranteed minimum resources available
- Pod will not be scheduled if node doesn't have these resources available

## Resource Limits
- Maximum resource ceiling for the pod
- CPU: Pod is throttled if it exceeds this limit
- Memory: Pod is terminated (OOMKilled) if it exceeds this limit
- Acts as a hard upper bound on resource usage

## Example Configuration
```yaml
resources:
  requests:
    memory: "256Mi"
    cpu: "500m"
  limits:
    memory: "512Mi"
    cpu: "1000m"
```

## What This Means
- Pod is guaranteed 500m CPU cores and 256Mi memory
- Pod can burst up to 1000m CPU and 512Mi memory
- CPU usage can float between request (500m) and limit (1000m)
- Memory usage above 512Mi triggers OOMKill

## Common Use Cases
- Web applications: Lower requests, higher limits for burst capacity
- Databases: Requests close to limits for consistent performance
- Batch jobs: High requests for guaranteed resources
- Development environments: Lower requests to pack more pods per node

## Best Practices
- Always set both requests and limits
- Keep request/limit ratio reasonable (e.g., 1:2 or 1:3)
- Monitor actual usage to optimize values
- Consider application behavior when setting limits

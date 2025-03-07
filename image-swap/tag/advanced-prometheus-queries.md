# Advanced Prometheus Queries for Image Push Jobs

This document contains useful Prometheus queries for monitoring and troubleshooting image push jobs in your AKS cluster.

## Basic Metrics

### Count of Failed Jobs
```
sum(kube_job_status_failed{job_name=~"image-push-job-.*"})
```

### Count of Successful Jobs
```
sum(kube_job_status_succeeded{job_name=~"image-push-job-.*"})
```

### Count of Active Jobs
```
sum(kube_job_status_active{job_name=~"image-push-job-.*"})
```

### Success Rate (as a percentage)
```
sum(kube_job_status_succeeded{job_name=~"image-push-job-.*"}) / (sum(kube_job_status_succeeded{job_name=~"image-push-job-.*"}) + sum(kube_job_status_failed{job_name=~"image-push-job-.*"})) * 100
```

## Time-Based Metrics

### Job Duration (for completed jobs)
```
(kube_job_status_completion_time - kube_job_status_start_time) * on(job_name) group_right kube_job_status_succeeded{job_name=~"image-push-job-.*"}
```

### Average Job Duration in Last Hour
```
avg_over_time((kube_job_status_completion_time - kube_job_status_start_time) * on(job_name) group_right kube_job_status_succeeded{job_name=~"image-push-job-.*"}[1h])
```

### Jobs Running Longer Than 15 Minutes
```
(time() - kube_job_status_start_time{job_name=~"image-push-job-.*"}) > 900 and kube_job_status_active{job_name=~"image-push-job-.*"} > 0
```

## Failure Analysis

### Jobs That Have Reached Backoff Limit
```
kube_job_spec_backoff_limit{job_name=~"image-push-job-.*"} - kube_job_status_failed{job_name=~"image-push-job-.*"} <= 0
```

### Failure Rate Over Time (5m intervals)
```
rate(kube_job_status_failed{job_name=~"image-push-job-.*"}[5m])
```

### Failure Count by Namespace
```
sum(kube_job_status_failed{job_name=~"image-push-job-.*"}) by (namespace)
```

## Resource Usage

### CPU Usage by Image Push Jobs
```
sum(rate(container_cpu_usage_seconds_total{pod=~"image-push-job-.*"}[5m])) by (pod)
```

### Memory Usage by Image Push Jobs
```
sum(container_memory_usage_bytes{pod=~"image-push-job-.*"}) by (pod)
```

### Network Traffic by Image Push Jobs
```
sum(rate(container_network_transmit_bytes_total{pod=~"image-push-job-.*"}[5m])) by (pod)
```

## Trend Analysis

### Job Creation Rate (new jobs per minute)
```
rate(kube_job_created{job_name=~"image-push-job-.*"}[5m])
```

### Weekly Success Rate Comparison
```
sum_over_time(kube_job_status_succeeded{job_name=~"image-push-job-.*"}[7d]) / (sum_over_time(kube_job_status_succeeded{job_name=~"image-push-job-.*"}[7d]) + sum_over_time(kube_job_status_failed{job_name=~"image-push-job-.*"}[7d])) * 100
```

### Failure Trend (increasing or decreasing)
```
delta(sum(kube_job_status_failed{job_name=~"image-push-job-.*"})[1d:1h])
```

## Using These Queries

You can use these queries in several ways:

1. **With the prometheus-query.sh script:**
   ```bash
   ./prometheus-query.sh 'sum(kube_job_status_failed{job_name=~"image-push-job-.*"}) by (namespace)'
   ```

2. **In Grafana:**
   - Create new panels in your dashboard
   - Paste these queries into the Prometheus query field

3. **In Prometheus UI:**
   ```bash
   kubectl port-forward svc/prometheus-operated 9090:9090 -n monitoring
   ```
   Then visit http://localhost:9090 and use the query explorer

4. **For creating new alerts:**
   - Add these queries to your PrometheusRule resource
   - Set appropriate thresholds and durations 
Looking at your Prometheus queries, you can query these metrics using several methods. Here are the main approaches:

## 1. Prometheus Web UI
Access your Prometheus instance (usually at `http://localhost:9090` or your configured URL) and paste these queries directly into the query box.

## 2. HTTP API
Use curl or any HTTP client to query the Prometheus API:

```bash
# CPU utilization query
curl -G 'http://your-prometheus:9090/api/v1/query' \
  --data-urlencode 'query=(sum by (namespace, pod) (rate(container_cpu_usage_seconds_total[5m]))) / (sum by (namespace, pod) (kube_pod_container_resource_requests{resource="cpu"}))'

# Memory utilization query  
curl -G 'http://your-prometheus:9090/api/v1/query' \
  --data-urlencode 'query=(sum by (namespace, pod) (container_memory_working_set_bytes)) / (sum by (namespace, pod) (kube_pod_container_resource_requests{resource="memory"}))'
```

## 3. PromQL Client Libraries
Use official Prometheus client libraries in your preferred language:

**Python example:**
```python
from prometheus_api_client import PrometheusConnect

prom = PrometheusConnect(url="http://your-prometheus:9090")

cpu_query = '''(sum by (namespace, pod) (rate(container_cpu_usage_seconds_total[5m]))) 
/ 
(sum by (namespace, pod) (kube_pod_container_resource_requests{resource="cpu"}))'''

result = prom.custom_query(query=cpu_query)
```

## 4. Grafana Dashboard
Create panels in Grafana using these queries to visualize resource utilization over time.

## Query Improvements
Your queries look good for calculating utilization ratios. You might want to add:

```promql
# CPU utilization with better handling of missing requests
(sum by (namespace, pod) (rate(container_cpu_usage_seconds_total[5m]))) 
/ 
(sum by (namespace, pod) (kube_pod_container_resource_requests{resource="cpu"}) > 0)

# Memory utilization as percentage
100 * (sum by (namespace, pod) (container_memory_working_set_bytes))
/
(sum by (namespace, pod) (kube_pod_container_resource_requests{resource="memory"}) > 0)
```

The `> 0` filter helps avoid division by zero errors when pods don't have resource requests set.

Which method are you planning to use to query these metrics?
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


---

Almost correct, but there's a subtle issue with the filtering approach. The `> 0` filter works on the metric values but doesn't ensure proper pairing between numerator and denominator. Here are the corrected versions:

## Better approach - Filter entire expression:

```promql
# CPU utilization with proper filtering
(
  sum by (namespace, pod) (rate(container_cpu_usage_seconds_total[5m])) 
  / 
  sum by (namespace, pod) (kube_pod_container_resource_requests{resource="cpu"})
) and on(namespace, pod) (sum by (namespace, pod) (kube_pod_container_resource_requests{resource="cpu"}) > 0)

# Memory utilization as percentage with proper filtering  
(
  100 * sum by (namespace, pod) (container_memory_working_set_bytes)
  /
  sum by (namespace, pod) (kube_pod_container_resource_requests{resource="memory"})
) and on(namespace, pod) (sum by (namespace, pod) (kube_pod_container_resource_requests{resource="memory"}) > 0)
```

## Even cleaner approach using `or`:

```promql
# CPU utilization - returns NaN for pods without requests instead of error
sum by (namespace, pod) (rate(container_cpu_usage_seconds_total[5m])) 
/ 
(sum by (namespace, pod) (kube_pod_container_resource_requests{resource="cpu"}) or vector(0))

# Memory utilization as percentage
100 * sum by (namespace, pod) (container_memory_working_set_bytes)
/
(sum by (namespace, pod) (kube_pod_container_resource_requests{resource="memory"}) or vector(0))
```

The issue with your original approach is that `kube_pod_container_resource_requests{resource="cpu"} > 0` filters the metric before the `sum by`, but the numerator might still have values for pods that don't appear in the filtered denominator, leading to incomplete results.

The corrected versions ensure you only get ratios for pods that actually have resource requests configured.

---

The parse error is likely due to the multi-line formatting. Prometheus queries need to be on single lines or properly formatted. Here are the corrected single-line versions:

## Single-line versions:

```promql
# CPU utilization
(sum by (namespace, pod) (rate(container_cpu_usage_seconds_total[5m]))) / (sum by (namespace, pod) (kube_pod_container_resource_requests{resource="cpu"}))

# Memory utilization as percentage
100 * (sum by (namespace, pod) (container_memory_working_set_bytes)) / (sum by (namespace, pod) (kube_pod_container_resource_requests{resource="memory"}))
```

## With filtering to avoid division by zero:

```promql
# CPU utilization with filtering
sum by (namespace, pod) (rate(container_cpu_usage_seconds_total[5m])) / (sum by (namespace, pod) (kube_pod_container_resource_requests{resource="cpu"}) or vector(0))

# Memory utilization as percentage with filtering
100 * sum by (namespace, pod) (container_memory_working_set_bytes) / (sum by (namespace, pod) (kube_pod_container_resource_requests{resource="memory"}) or vector(0))
```

The key changes:
1. **Single line**: No line breaks in the query
2. **Proper parentheses**: Each `sum by` expression is wrapped in parentheses
3. **Simplified filtering**: Using `or vector(0)` instead of complex `and on()` expressions

Try copying and pasting these single-line versions directly into your Prometheus query interface.


---

The error "unexpected number 100" suggests Prometheus is having trouble parsing the `100 *` at the beginning. Try these alternatives:

## Option 1: Multiply at the end
```promql
(sum by (namespace, pod) (container_memory_working_set_bytes)) / (sum by (namespace, pod) (kube_pod_container_resource_requests{resource="memory"})) * 100
```

## Option 2: Use parentheses around the multiplication
```promql
(100) * (sum by (namespace, pod) (container_memory_working_set_bytes)) / (sum by (namespace, pod) (kube_pod_container_resource_requests{resource="memory"}))
```

## Option 3: Skip the percentage conversion
```promql
(sum by (namespace, pod) (container_memory_working_set_bytes)) / (sum by (namespace, pod) (kube_pod_container_resource_requests{resource="memory"}))
```
*This gives you a ratio (0.0 to 1.0) instead of percentage*

## Complete working queries:

**CPU utilization (as ratio):**
```promql
sum by (namespace, pod) (rate(container_cpu_usage_seconds_total[5m])) / sum by (namespace, pod) (kube_pod_container_resource_requests{resource="cpu"})
```

**Memory utilization (as percentage):**
```promql
sum by (namespace, pod) (container_memory_working_set_bytes) / sum by (namespace, pod) (kube_pod_container_resource_requests{resource="memory"}) * 100
```

Try the simpler versions first - sometimes Prometheus can be picky about operator precedence and spacing.

---

These queries show **resource utilization ratios** - how much of the requested resources your Kubernetes pods are actually using. Here's what each one tells you:

## CPU Utilization Query
```promql
sum by (namespace, pod) (rate(container_cpu_usage_seconds_total[5m])) / sum by (namespace, pod) (kube_pod_container_resource_requests{resource="cpu"})
```

**What it shows:**
- **Numerator**: Average CPU cores used per pod over the last 5 minutes
- **Denominator**: CPU cores requested by each pod
- **Result**: Ratio of actual CPU usage vs requested CPU

**Example interpretations:**
- `0.5` = Pod is using 50% of its requested CPU
- `1.0` = Pod is using exactly its requested CPU  
- `2.0` = Pod is using 200% of its requested CPU (overutilized)
- `0.1` = Pod is using only 10% of its requested CPU (overprovisioned)

## Memory Utilization Query  
```promql
sum by (namespace, pod) (container_memory_working_set_bytes) / sum by (namespace, pod) (kube_pod_container_resource_requests{resource="memory"}) * 100
```

**What it shows:**
- **Numerator**: Current memory usage (working set) per pod in bytes
- **Denominator**: Memory requested by each pod in bytes  
- **Result**: Percentage of actual memory usage vs requested memory

**Example interpretations:**
- `75%` = Pod is using 75% of its requested memory
- `100%` = Pod is using exactly its requested memory
- `150%` = Pod is using 50% more memory than requested (potential OOMKill risk)
- `25%` = Pod is using only 25% of requested memory (overprovisioned)

## Why This Matters

**For Right-sizing Resources:**
- Values consistently below 50% suggest you can reduce requests (save money)
- Values consistently above 90% suggest you should increase requests (avoid performance issues)

**For Capacity Planning:**
- High utilization ratios indicate pods that might need more resources
- Low ratios indicate wasted cluster capacity

**For Monitoring:**
- CPU ratios > 1.0 indicate CPU throttling may occur
- Memory ratios > 1.0 risk out-of-memory kills (OOMKilled pods)

The queries help you optimize your Kubernetes resource allocation by showing the gap between what you've allocated and what you're actually using.
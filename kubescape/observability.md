Yes! Since Kubescape integrates with OpenTelemetry, you can send metrics to both Prometheus and Grafana. Here's what's possible:

1. **Prometheus Integration**
- OpenTelemetry can export metrics directly to Prometheus
- Metrics are exposed in Prometheus format for scraping
- Can track security posture, vulnerabilities, and compliance scores over time

2. **Grafana Visualization**
- Use Prometheus as a data source in Grafana
- Create dashboards for:
  - Security compliance trends
  - Risk scores
  - Vulnerability counts
  - Runtime threats
  - Network policy violations

Let me search for more specific implementation details.

Ran tool
Based on the search results, here's how to set up Kubescape with Prometheus and Grafana:

1. **Install Kubescape Prometheus Exporter**:
```bash
helm upgrade --install kubescape kubescape/kubescape-operator \
  -n kubescape \
  --create-namespace \
  --set capabilities.continuousScan=enable \
  --set clusterName=$(kubectl config current-context)
```

2. **Metrics Available**:
- Critical controls and vulnerabilities
- Cluster and namespace-scoped metrics
- Workload-level metrics (optional via `ENABLE_WORKLOAD_METRICS=true`)

3. **Access Points**:
- Raw metrics: `http://localhost:8080/metrics`
- Prometheus: `http://localhost:9090`
- Grafana: `http://localhost:3000`

4. **Useful Grafana Dashboards**:
- Security compliance trends
- Risk scores by namespace
- Critical vulnerabilities
- Runtime threats
- Network policy violations

The metrics are exposed in Prometheus format and can be scraped automatically, making them ready for visualization in Grafana.


Let me search for specific details about the Prometheus integration setup.

Search files...
Let me search for more specific information about the Prometheus integration.

Ran tool
Based on the search results, here's how Kubescape integrates with Prometheus:

1. **Prometheus Exporter**
- Kubescape includes a dedicated Prometheus exporter that exposes metrics at `http://localhost:8080/metrics`
- The metrics are automatically exposed in Prometheus format

2. **ServiceMonitor Configuration**
If you're using the Prometheus Operator, you can enable the ServiceMonitor during Helm installation:

```bash
helm upgrade --install kubescape kubescape/kubescape-operator \
  -n kubescape \
  --create-namespace \
  --set prometheus.serviceMonitor.enabled=true
```

3. **Manual Prometheus Configuration**
If you're not using the Prometheus Operator, you'll need to add a scrape config to your Prometheus configuration:

```yaml
scrape_configs:
  - job_name: 'kubescape'
    static_configs:
      - targets: ['kubescape-metrics:8080']
```

4. **Available Metrics**
- Security compliance metrics
- Critical vulnerabilities
- Risk scores
- Runtime threats
- Network policy violations

The Helm chart automatically sets up the necessary service and endpoints for Prometheus to discover and scrape the metrics. You don't need to manually create a ServiceMonitor unless you have specific customization needs.

For workload-level metrics, you can enable them with:
```bash
--set capabilities.workloadMetrics=true
```

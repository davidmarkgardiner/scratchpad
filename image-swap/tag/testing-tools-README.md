# Testing Tools for Image Push Job Monitoring

This directory contains several tools to help you test and verify your Prometheus monitoring setup for image push jobs.

## Available Tools

1. **run-prometheus-tests.sh** - Runs a comprehensive test suite for all alert conditions
2. **prometheus-query.sh** - Executes custom Prometheus queries with formatted output
3. **simulate-job-failures.sh** - Creates multiple failing jobs to test alerting at scale
4. **advanced-prometheus-queries.md** - Collection of useful Prometheus queries

## Test Jobs

1. **test-job-success.yaml** - A job that completes successfully
2. **test-job-failure.yaml** - A job that fails immediately
3. **test-job-stuck.yaml** - A job that runs for a long time to trigger the stuck job alert
4. **test-job-backoff-limit.yaml** - A job that fails repeatedly to trigger the backoff limit alert

## Running the Tests

### Basic Test Suite

To run the complete test suite:

```bash
./run-prometheus-tests.sh
```

This will:
1. Deploy all test jobs
2. Check their status
3. Query Prometheus for relevant metrics
4. Provide instructions for viewing alerts and dashboards

To clean up after testing:

```bash
./run-prometheus-tests.sh cleanup
```

### Custom Prometheus Queries

To run custom Prometheus queries:

```bash
./prometheus-query.sh 'kube_job_status_failed{job_name=~"image-push-job-.*"} > 0'
```

Options:
- `-f, --format FORMAT` - Output format: table, json, or raw (default: table)
- `-p, --port PORT` - Port to use for Prometheus port-forward (default: 9090)
- `-n, --namespace NS` - Namespace where Prometheus is deployed (default: monitoring)

### Simulating High Volume Job Failures

To simulate multiple job failures:

```bash
./simulate-job-failures.sh --count 10 --interval 5
```

Options:
- `-c, --count COUNT` - Number of jobs to create (default: 5)
- `-n, --namespace NS` - Namespace to create jobs in (default: default)
- `-i, --interval SEC` - Interval between job creation in seconds (default: 2)
- `--no-cleanup` - Don't clean up jobs after running

## Verifying Alerts

After running the tests, you can verify that alerts are firing:

1. Access AlertManager:
   ```bash
   kubectl port-forward svc/alertmanager-operated 9093:9093 -n monitoring
   ```
   Then open: http://localhost:9093/#/alerts

2. Check the Grafana dashboard:
   ```bash
   kubectl port-forward svc/grafana 3000:3000 -n monitoring
   ```
   Then open: http://localhost:3000/d/image-push-jobs/image-push-jobs-dashboard

## Troubleshooting

If you don't see alerts firing:

1. Check that Prometheus is scraping the metrics:
   ```bash
   ./prometheus-query.sh 'up{job="kube-state-metrics"}'
   ```

2. Verify that the alert rules are loaded:
   ```bash
   kubectl get prometheusrules -n monitoring
   ```

3. Check for any errors in Prometheus:
   ```bash
   kubectl logs -n monitoring -l app=prometheus -c prometheus
   ```

4. Ensure kube-state-metrics is running:
   ```bash
   kubectl get pods -n monitoring -l app.kubernetes.io/name=kube-state-metrics
   ``` 
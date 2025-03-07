# Enhanced Image Push Jobs Dashboard

This document provides information about the enhanced Grafana dashboard for monitoring image push jobs and the tools to help you test and visualize the dashboard.

## Dashboard Features

The enhanced dashboard includes the following features:

1. **Summary Statistics**
   - Failed Jobs Count
   - Successful Jobs Count
   - Active Jobs Count
   - Overall Success Rate (gauge)

2. **Time-Based Metrics**
   - Failed Jobs Over Time (graph)
   - Running Job Duration (graph with threshold line at 15 minutes)
   - Completed Job Duration (time series with min/max/avg statistics)

3. **Namespace Analysis**
   - Job Status by Namespace (bar chart)
   - Namespace filtering via template variable

4. **Detailed Information**
   - Failed Jobs Table (with job name, namespace, reason, and status)
   - Alert Annotations (visual indicators when alerts are firing)

5. **Visual Improvements**
   - Consistent color scheme (green for success, red for failure, yellow for warnings)
   - Responsive layout optimized for different screen sizes
   - Markdown header with dashboard description
   - Improved tooltips and legends

## Label-Based Monitoring

The monitoring system uses specific labels to target only the jobs created by our Kyverno policy:

1. **Job Labels**:
   - `monitoring: "true"` - Indicates the job should be monitored
   - `job-type: "image-push"` - Specifies the type of job
   - `generator: "kyverno-policy-v5"` - Identifies which system created the job

2. **Benefits of Label-Based Approach**:
   - Precise targeting of specific jobs
   - Reduced false positives in alerts
   - Ability to filter dashboard by job type
   - Clear separation between test jobs and production jobs
   - Future-proofing for additional job types

3. **Implementation**:
   - The Kyverno policy adds these labels to generated jobs
   - Prometheus rules filter based on these labels
   - Grafana dashboard queries include label selectors
   - Test scripts apply the same labels for consistency

## Installation

To install the enhanced dashboard:

1. Import the dashboard JSON file into Grafana:
   ```bash
   kubectl port-forward svc/grafana 3000:3000 -n monitoring
   ```
   Then open http://localhost:3000 in your browser, navigate to Dashboards > Import, and upload the `grafana-image-jobs-dashboard-enhanced.json` file.

2. Select your Prometheus data source when prompted.

## Testing Tools

### Generate Dashboard Data

The `generate-dashboard-data.sh` script creates test jobs to populate the dashboard with realistic data:

```bash
./generate-dashboard-data.sh
```

Options:
- `-s, --success COUNT` - Number of successful jobs to create (default: 8)
- `-f, --failure COUNT` - Number of failing jobs to create (default: 3)
- `-t, --stuck COUNT` - Number of stuck jobs to create (default: 1)
- `-n, --namespace NS` - Namespace to create jobs in (default: default)
- `-i, --interval SEC` - Interval between job creation in seconds (default: 5)
- `--no-cleanup` - Don't clean up jobs after running

Example:
```bash
./generate-dashboard-data.sh --success 10 --failure 5 --stuck 2 --interval 3 --no-cleanup
```

## Customization

### Adding New Panels

You can add new panels to the dashboard through the Grafana UI:

1. Click the "Add panel" button in the top navigation bar
2. Select "Add new panel"
3. Configure the panel with appropriate Prometheus queries
4. Adjust visualization settings and placement

### Modifying Existing Panels

To modify an existing panel:

1. Click on the panel title
2. Select "Edit"
3. Make your changes to the query, visualization, or other settings
4. Click "Apply" to save your changes

### Adding Alerts

The dashboard is configured to display alert annotations when alerts are firing. To add new alerts:

1. Edit your PrometheusRule to include additional alert rules
2. Ensure the alerts use the naming pattern `ImagePushJob*` to be captured by the dashboard annotations
3. Include the appropriate label selectors in your alert expressions

## Troubleshooting

If the dashboard is not displaying data correctly:

1. Check that Prometheus is scraping the kube-state-metrics service:
   ```bash
   ./prometheus-query.sh 'up{job="kube-state-metrics"}'
   ```

2. Verify that job metrics are being collected:
   ```bash
   ./prometheus-query.sh 'kube_job_info{job_name=~"image-push-job.*", label_job_type="image-push", label_monitoring="true"}'
   ```

3. Check that your PrometheusRule is correctly configured with the label `release: prometheus-stack`

4. Ensure that the Grafana dashboard is using the correct Prometheus data source

5. Verify that your jobs have the correct labels:
   ```bash
   kubectl get jobs --show-labels | grep image-push-job
   ```

## Best Practices

1. **Consistent Labeling**: Always use the same set of labels for all jobs that should be monitored together.

2. **Regular Testing**: Use the provided testing tools to regularly verify that your monitoring setup is working correctly.

3. **Dashboard Sharing**: Export and version control your dashboard JSON to share improvements with your team.

4. **Alert Thresholds**: Adjust alert thresholds based on your specific requirements and job characteristics.

5. **Dashboard Organization**: Keep related panels grouped together for easier navigation and understanding.

6. **Documentation**: Document any custom panels or queries you add to the dashboard for future reference. 
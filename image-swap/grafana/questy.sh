
Based on the dashboard you've provided, here are some example Prometheus queries you can use in Grafana to check if your data is available. These queries are extracted from the panels in your dashboard and can help you verify if your metrics are being collected properly.

## Basic Status Queries

1. **Check for Failed Jobs**
   ```
   sum(kube_job_status_failed{job_name=~"image-push-job-.*"})
   ```
   This will return the total count of failed jobs matching the pattern "image-push-job-*".

2. **Check for Successful Jobs**
   ```
   sum(kube_job_status_succeeded{job_name=~"image-push-job-.*"})
   ```
   This will return the total count of successful jobs.

3. **Check for Active Jobs**
   ```
   sum(kube_job_status_active{job_name=~"image-push-job-.*"})
   ```
   This will show you if any jobs are currently running.

## More Detailed Queries

4. **Success Rate Calculation**
   ```
   sum(kube_job_status_succeeded{job_name=~"image-push-job-.*"}) / (sum(kube_job_status_succeeded{job_name=~"image-push-job-.*"}) + sum(kube_job_status_failed{job_name=~"image-push-job-.*"})) * 100
   ```
   This calculates the percentage of successful jobs out of all completed jobs.

5. **Failed Jobs by Namespace and Job Name**
   ```
   sum(kube_job_status_failed{job_name=~"image-push-job-.*"}) by (namespace, job_name)
   ```
   This breaks down failed jobs by namespace and job name, giving you more granular information.

6. **Running Job Duration**
   ```
   (time() - kube_job_status_start_time{job_name=~"image-push-job-.*"}) * on(job_name) group_right kube_job_status_active{job_name=~"image-push-job-.*"}
   ```
   This shows how long currently active jobs have been running.

7. **Completed Job Duration**
   ```
   (kube_job_status_completion_time{job_name=~"image-push-job-.*"} - kube_job_status_start_time{job_name=~"image-push-job-.*"}) * on(job_name) group_right kube_job_status_succeeded{job_name=~"image-push-job-.*"}
   ```
   This shows how long successful jobs took to complete.

8. **Job Status by Namespace**
   ```
   sum(kube_job_status_succeeded{job_name=~"image-push-job-.*"}) by (namespace)
   ```
   and
   ```
   sum(kube_job_status_failed{job_name=~"image-push-job-.*"}) by (namespace)
   ```
   These queries show the count of succeeded and failed jobs grouped by namespace.

## Troubleshooting Queries

9. **Check if Job Metrics Exist**
   ```
   count(kube_job_info{job_name=~"image-push-job-.*"})
   ```
   This will tell you if there are any jobs matching your pattern in the metrics.

10. **List All Job Names**
    ```
    count(kube_job_info) by (job_name)
    ```
    This will show all job names in your metrics, which can help you verify if your job naming pattern is correct.

11. **Check for Specific Labels**
    ```
    kube_job_labels{job_name=~"image-push-job-.*"}
    ```
    This will show you what labels are available on your jobs, which might help with filtering.

12. **Check for Backoff Limit Reached**
    ```
    kube_job_spec_backoff_limit{job_name=~"image-push-job-.*"} - kube_job_status_failed{job_name=~"image-push-job-.*"} <= 0
    ```
    This will identify jobs that have reached their backoff limit.

## How to Use These Queries

1. In Grafana, go to "Explore" (compass icon in the left sidebar)
2. Select your Prometheus data source
3. Paste one of these queries into the query field
4. Click "Run Query"

If you see data returned, it means your metrics are being collected. If not, you might need to:
- Check if your jobs are actually running with the expected naming pattern
- Verify that Prometheus is scraping the Kubernetes API server
- Check if kube-state-metrics is properly deployed in your cluster, as it's responsible for exposing these job metrics

These queries should help you diagnose whether your image push job metrics are being collected properly and visible to Grafana.

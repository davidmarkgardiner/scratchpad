#!/bin/bash

# This script updates the Grafana dashboard for image push jobs
# It removes the label_job_type and label_monitoring filters that don't work
# and replaces them with simple job_name pattern matching

# Set your Grafana API key here
GRAFANA_API_KEY="your-api-key-here"
GRAFANA_URL="https://grafana.danatlab.com"
DASHBOARD_UID="image-push-jobs"

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required but not installed. Please install jq first."
    exit 1
fi

# Get the current dashboard JSON
echo "Fetching current dashboard..."
curl -s -H "Authorization: Bearer $GRAFANA_API_KEY" \
     "$GRAFANA_URL/api/dashboards/uid/$DASHBOARD_UID" > current-dashboard.json

if [ $? -ne 0 ]; then
    echo "Error: Failed to fetch dashboard. Check your API key and Grafana URL."
    exit 1
fi

# Extract the dashboard JSON
jq '.dashboard' current-dashboard.json > dashboard-only.json

# Update all queries to remove label_job_type and label_monitoring filters
cat dashboard-only.json | \
    sed 's/label_job_type="image-push", label_monitoring="true"//g' | \
    sed 's/job_name=~"image-push-job-.*", label_job_type="image-push", label_monitoring="true"/job_name=~"image-push-job-.*"/g' > updated-dashboard-content.json

# Prepare the dashboard for update
jq '{dashboard: ., overwrite: true}' updated-dashboard-content.json > dashboard-update.json

# Update the dashboard
echo "Updating dashboard..."
curl -X POST -H "Content-Type: application/json" \
     -H "Authorization: Bearer $GRAFANA_API_KEY" \
     -d @dashboard-update.json \
     "$GRAFANA_URL/api/dashboards/db"

if [ $? -eq 0 ]; then
    echo "Dashboard updated successfully!"
    echo "You can view it at: $GRAFANA_URL/d/$DASHBOARD_UID"
else
    echo "Error: Failed to update dashboard."
    exit 1
fi

# Clean up temporary files
rm current-dashboard.json dashboard-only.json updated-dashboard-content.json dashboard-update.json

echo "Done!" 
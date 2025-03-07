#!/bin/bash

# Set colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Starting Prometheus alert testing for image push jobs...${NC}"
echo

# Function to check if Prometheus is accessible
check_prometheus() {
  echo -e "${YELLOW}Checking Prometheus accessibility...${NC}"
  
  # Try to port-forward to Prometheus (non-blocking)
  kubectl port-forward svc/prometheus-operated 9090:9090 -n monitoring > /dev/null 2>&1 &
  PF_PID=$!
  
  # Give it a moment to establish
  sleep 3
  
  # Check if we can access Prometheus
  if curl -s http://localhost:9090/-/healthy > /dev/null; then
    echo -e "${GREEN}✓ Prometheus is accessible${NC}"
    return 0
  else
    echo -e "${RED}✗ Cannot access Prometheus. Please ensure it's running and try again.${NC}"
    kill $PF_PID 2>/dev/null
    return 1
  fi
}

# Function to deploy a test job
deploy_test_job() {
  local job_file=$1
  local job_name=$(grep "name:" $job_file | head -1 | awk '{print $2}' | tr -d '"')
  
  echo -e "${YELLOW}Deploying test job: ${job_name}${NC}"
  kubectl apply -f $job_file
  
  if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Job $job_name deployed successfully${NC}"
  else
    echo -e "${RED}✗ Failed to deploy job $job_name${NC}"
  fi
}

# Function to check job status
check_job_status() {
  local job_name=$1
  echo -e "${YELLOW}Checking status of job: ${job_name}${NC}"
  
  # Get job status
  local status=$(kubectl get job $job_name -o jsonpath='{.status}' 2>/dev/null)
  
  if [ -z "$status" ]; then
    echo -e "${RED}✗ Job $job_name not found${NC}"
    return
  fi
  
  echo -e "${GREEN}Job status: $status${NC}"
}

# Function to query Prometheus for job metrics
query_prometheus() {
  local job_name=$1
  local metric=$2
  
  echo -e "${YELLOW}Querying Prometheus for: $metric{job_name=\"$job_name\"}${NC}"
  
  # Query Prometheus using curl with proper URL encoding
  local query="$metric{job_name=\"$job_name\"}"
  local result=$(curl -G -s "http://localhost:9090/api/v1/query" --data-urlencode "query=$query" | jq -r '.data.result[0].value[1]' 2>/dev/null)
  
  if [ -z "$result" ] || [ "$result" == "null" ]; then
    echo -e "${RED}✗ No data found for $job_name in Prometheus${NC}"
  else
    echo -e "${GREEN}✓ Metric value: $result${NC}"
  fi
}

# Function to clean up test jobs
cleanup_jobs() {
  echo -e "${YELLOW}Cleaning up test jobs...${NC}"
  kubectl delete job image-push-job-test-failure 2>/dev/null
  kubectl delete job image-push-job-test-stuck 2>/dev/null
  kubectl delete job image-push-job-test-backoff 2>/dev/null
  kubectl delete job image-push-job-test-success 2>/dev/null
  echo -e "${GREEN}✓ Cleanup completed${NC}"
}

# Main test sequence
main() {
  # Check if jq is installed
  if ! command -v jq &> /dev/null; then
    echo -e "${RED}Error: jq is required but not installed. Please install jq and try again.${NC}"
    exit 1
  fi
  
  # Check if we can access Prometheus
  check_prometheus
  if [ $? -ne 0 ]; then
    echo -e "${YELLOW}Continuing without Prometheus verification...${NC}"
  fi
  
  # Clean up any existing test jobs
  cleanup_jobs
  
  echo
  echo -e "${YELLOW}=== Deploying Test Jobs ===${NC}"
  
  # Deploy success job
  deploy_test_job "test-job-success.yaml"
  sleep 2
  check_job_status "image-push-job-test-success"
  
  # Deploy failure job
  deploy_test_job "test-job-failure.yaml"
  sleep 2
  check_job_status "image-push-job-test-failure"
  
  # Deploy backoff limit job
  deploy_test_job "test-job-backoff-limit.yaml"
  sleep 2
  check_job_status "image-push-job-test-backoff"
  
  # Deploy stuck job
  deploy_test_job "test-job-stuck.yaml"
  sleep 2
  check_job_status "image-push-job-test-stuck"
  
  echo
  echo -e "${YELLOW}=== Waiting for jobs to process (30 seconds) ===${NC}"
  sleep 30
  
  echo
  echo -e "${YELLOW}=== Checking Final Job Statuses ===${NC}"
  check_job_status "image-push-job-test-success"
  check_job_status "image-push-job-test-failure"
  check_job_status "image-push-job-test-backoff"
  check_job_status "image-push-job-test-stuck"
  
  # If Prometheus is accessible, query for metrics
  if curl -s http://localhost:9090/-/healthy > /dev/null; then
    echo
    echo -e "${YELLOW}=== Querying Prometheus Metrics ===${NC}"
    
    # Query for success job
    query_prometheus "image-push-job-test-success" "kube_job_status_succeeded"
    
    # Query for failure job
    query_prometheus "image-push-job-test-failure" "kube_job_status_failed"
    
    # Query for backoff job
    query_prometheus "image-push-job-test-backoff" "kube_job_status_failed"
    
    # Query for stuck job
    query_prometheus "image-push-job-test-stuck" "kube_job_status_active"
    
    # Kill the port-forward process
    kill $PF_PID 2>/dev/null
  fi
  
  echo
  echo -e "${YELLOW}=== Test Summary ===${NC}"
  echo -e "${GREEN}✓ All test jobs deployed${NC}"
  echo -e "${YELLOW}To check alerts in Prometheus AlertManager:${NC}"
  echo "  kubectl port-forward svc/alertmanager-operated 9093:9093 -n monitoring"
  echo "  Then open: http://localhost:9093/#/alerts"
  echo
  echo -e "${YELLOW}To view the Grafana dashboard:${NC}"
  echo "  kubectl port-forward svc/grafana 3000:3000 -n monitoring"
  echo "  Then open: http://localhost:3000/d/image-push-jobs/image-push-jobs-dashboard"
  echo
  echo -e "${YELLOW}To clean up test jobs:${NC}"
  echo "  ./run-prometheus-tests.sh cleanup"
}

# Check if we're just cleaning up
if [ "$1" == "cleanup" ]; then
  cleanup_jobs
  exit 0
fi

# Run the main test sequence
main 
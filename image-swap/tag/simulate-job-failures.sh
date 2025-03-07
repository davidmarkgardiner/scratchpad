#!/bin/bash

# Set colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Default values
COUNT=5
NAMESPACE="default"
INTERVAL=2
CLEANUP=true

# Function to display usage
usage() {
  echo "Usage: $0 [options]"
  echo
  echo "Options:"
  echo "  -c, --count COUNT      Number of jobs to create (default: 5)"
  echo "  -n, --namespace NS     Namespace to create jobs in (default: default)"
  echo "  -i, --interval SEC     Interval between job creation in seconds (default: 2)"
  echo "  --no-cleanup           Don't clean up jobs after running"
  echo "  -h, --help             Display this help message"
  echo
  echo "This script creates multiple failing jobs to test Prometheus alerting."
  exit 1
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -c|--count)
      COUNT="$2"
      shift 2
      ;;
    -n|--namespace)
      NAMESPACE="$2"
      shift 2
      ;;
    -i|--interval)
      INTERVAL="$2"
      shift 2
      ;;
    --no-cleanup)
      CLEANUP=false
      shift
      ;;
    -h|--help)
      usage
      ;;
    *)
      echo -e "${RED}Unknown option: $1${NC}"
      usage
      ;;
  esac
done

# Validate count
if ! [[ "$COUNT" =~ ^[0-9]+$ ]]; then
  echo -e "${RED}Error: Count must be a positive integer${NC}"
  exit 1
fi

# Validate namespace
if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
  echo -e "${RED}Error: Namespace $NAMESPACE does not exist${NC}"
  exit 1
fi

# Validate interval
if ! [[ "$INTERVAL" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
  echo -e "${RED}Error: Interval must be a positive number${NC}"
  exit 1
fi

echo -e "${YELLOW}Starting job failure simulation...${NC}"
echo -e "${YELLOW}Creating $COUNT failing jobs in namespace $NAMESPACE${NC}"
echo -e "${YELLOW}Interval between jobs: $INTERVAL seconds${NC}"
echo

# Create the jobs
for i in $(seq 1 $COUNT); do
  JOB_NAME="image-push-job-test-failure-$i"
  
  echo -e "${YELLOW}Creating job $i of $COUNT: $JOB_NAME${NC}"
  
  # Create the job
  cat <<EOF | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: $JOB_NAME
  namespace: $NAMESPACE
  labels:
    skip-verify: "true"
    image-info: "test-failure-$i"
spec:
  template:
    metadata:
      labels:
        skip-verify: "true"
    spec:
      containers:
      - name: push-image
        image: mcr.microsoft.com/azure-cli
        command:
        - /bin/bash
        - -c
        - |
          echo "This job will fail to test alerting (job $i of $COUNT)"
          exit 1
      restartPolicy: Never
  backoffLimit: 2
EOF
  
  if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Job $JOB_NAME created successfully${NC}"
  else
    echo -e "${RED}✗ Failed to create job $JOB_NAME${NC}"
  fi
  
  # Wait for the specified interval before creating the next job
  if [ $i -lt $COUNT ]; then
    echo -e "${YELLOW}Waiting $INTERVAL seconds before creating next job...${NC}"
    sleep $INTERVAL
  fi
done

echo
echo -e "${GREEN}All $COUNT jobs created successfully${NC}"
echo -e "${YELLOW}Waiting for jobs to complete...${NC}"

# Wait for all jobs to complete
sleep 10

# Check job statuses
echo
echo -e "${YELLOW}Job statuses:${NC}"
kubectl get jobs -n $NAMESPACE -l "image-info=~test-failure-.*" -o wide

# Provide instructions for checking alerts
echo
echo -e "${YELLOW}To check alerts in Prometheus AlertManager:${NC}"
echo "  kubectl port-forward svc/alertmanager-operated 9093:9093 -n monitoring"
echo "  Then open: http://localhost:9093/#/alerts"
echo
echo -e "${YELLOW}To view the Grafana dashboard:${NC}"
echo "  kubectl port-forward svc/grafana 3000:3000 -n monitoring"
echo "  Then open: http://localhost:3000/d/image-push-jobs/image-push-jobs-dashboard"

# Clean up if requested
if [ "$CLEANUP" = true ]; then
  echo
  echo -e "${YELLOW}Cleaning up jobs in 60 seconds... Press Ctrl+C to cancel cleanup${NC}"
  sleep 60
  
  echo -e "${YELLOW}Cleaning up jobs...${NC}"
  kubectl delete jobs -n $NAMESPACE -l "image-info=~test-failure-.*"
  echo -e "${GREEN}Cleanup completed${NC}"
else
  echo
  echo -e "${YELLOW}Skipping cleanup as requested${NC}"
  echo -e "${YELLOW}To clean up manually:${NC}"
  echo "  kubectl delete jobs -n $NAMESPACE -l \"image-info=~test-failure-.*\""
fi 
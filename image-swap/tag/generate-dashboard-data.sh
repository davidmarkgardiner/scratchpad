#!/bin/bash

# Set colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Default values
SUCCESS_COUNT=8
FAILURE_COUNT=3
STUCK_COUNT=1
NAMESPACE="default"
INTERVAL=5
CLEANUP=true

# Function to display usage
usage() {
  echo "Usage: $0 [options]"
  echo
  echo "Options:"
  echo "  -s, --success COUNT    Number of successful jobs to create (default: 8)"
  echo "  -f, --failure COUNT    Number of failing jobs to create (default: 3)"
  echo "  -t, --stuck COUNT      Number of stuck jobs to create (default: 1)"
  echo "  -n, --namespace NS     Namespace to create jobs in (default: default)"
  echo "  -i, --interval SEC     Interval between job creation in seconds (default: 5)"
  echo "  --no-cleanup           Don't clean up jobs after running"
  echo "  -h, --help             Display this help message"
  echo
  echo "This script creates test jobs to populate the Grafana dashboard."
  exit 1
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -s|--success)
      SUCCESS_COUNT="$2"
      shift 2
      ;;
    -f|--failure)
      FAILURE_COUNT="$2"
      shift 2
      ;;
    -t|--stuck)
      STUCK_COUNT="$2"
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

# Validate counts
if ! [[ "$SUCCESS_COUNT" =~ ^[0-9]+$ ]] || ! [[ "$FAILURE_COUNT" =~ ^[0-9]+$ ]] || ! [[ "$STUCK_COUNT" =~ ^[0-9]+$ ]]; then
  echo -e "${RED}Error: Counts must be positive integers${NC}"
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

echo -e "${YELLOW}Starting dashboard data generation...${NC}"
echo -e "${YELLOW}Creating $SUCCESS_COUNT successful jobs, $FAILURE_COUNT failing jobs, and $STUCK_COUNT stuck jobs in namespace $NAMESPACE${NC}"
echo -e "${YELLOW}Interval between jobs: $INTERVAL seconds${NC}"
echo

# Create successful jobs
for i in $(seq 1 $SUCCESS_COUNT); do
  JOB_NAME="image-push-job-success-$i"
  
  echo -e "${YELLOW}Creating successful job $i of $SUCCESS_COUNT: $JOB_NAME${NC}"
  
  # Create the job
  cat <<EOF | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: $JOB_NAME
  namespace: $NAMESPACE
  labels:
    skip-verify: "true"
    image-info: "test-success-$i"
    monitoring: "true"
    job-type: "image-push"
    generator: "test-script"
spec:
  template:
    metadata:
      labels:
        skip-verify: "true"
        monitoring: "true"
        job-type: "image-push"
    spec:
      containers:
      - name: push-image
        image: mcr.microsoft.com/azure-cli
        command:
        - /bin/bash
        - -c
        - |
          echo "This job will succeed for dashboard testing"
          sleep $(( RANDOM % 10 + 1 ))
          exit 0
      restartPolicy: Never
  backoffLimit: 3
EOF
  
  if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Job $JOB_NAME created successfully${NC}"
  else
    echo -e "${RED}✗ Failed to create job $JOB_NAME${NC}"
  fi
  
  # Wait for the specified interval before creating the next job
  if [ $i -lt $SUCCESS_COUNT ]; then
    sleep $INTERVAL
  fi
done

# Create failing jobs
for i in $(seq 1 $FAILURE_COUNT); do
  JOB_NAME="image-push-job-failure-$i"
  
  echo -e "${YELLOW}Creating failing job $i of $FAILURE_COUNT: $JOB_NAME${NC}"
  
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
    monitoring: "true"
    job-type: "image-push"
    generator: "test-script"
spec:
  template:
    metadata:
      labels:
        skip-verify: "true"
        monitoring: "true"
        job-type: "image-push"
    spec:
      containers:
      - name: push-image
        image: mcr.microsoft.com/azure-cli
        command:
        - /bin/bash
        - -c
        - |
          echo "This job will fail for dashboard testing"
          sleep $(( RANDOM % 5 + 1 ))
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
  if [ $i -lt $FAILURE_COUNT ]; then
    sleep $INTERVAL
  fi
done

# Create stuck jobs
for i in $(seq 1 $STUCK_COUNT); do
  JOB_NAME="image-push-job-stuck-$i"
  
  echo -e "${YELLOW}Creating stuck job $i of $STUCK_COUNT: $JOB_NAME${NC}"
  
  # Create the job
  cat <<EOF | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: $JOB_NAME
  namespace: $NAMESPACE
  labels:
    skip-verify: "true"
    image-info: "test-stuck-$i"
    monitoring: "true"
    job-type: "image-push"
    generator: "test-script"
spec:
  template:
    metadata:
      labels:
        skip-verify: "true"
        monitoring: "true"
        job-type: "image-push"
    spec:
      containers:
      - name: push-image
        image: mcr.microsoft.com/azure-cli
        command:
        - /bin/bash
        - -c
        - |
          echo "This job will appear stuck for dashboard testing"
          sleep 3600
      restartPolicy: Never
  backoffLimit: 3
EOF
  
  if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Job $JOB_NAME created successfully${NC}"
  else
    echo -e "${RED}✗ Failed to create job $JOB_NAME${NC}"
  fi
  
  # Wait for the specified interval before creating the next job
  if [ $i -lt $STUCK_COUNT ]; then
    sleep $INTERVAL
  fi
done

echo
echo -e "${GREEN}All jobs created successfully${NC}"
echo -e "${YELLOW}Waiting for jobs to process...${NC}"

# Wait for jobs to process
sleep 30

# Check job statuses
echo
echo -e "${YELLOW}Job statuses:${NC}"
kubectl get jobs -n $NAMESPACE -l "job-type=image-push,monitoring=true" -o wide

# Provide instructions for viewing the dashboard
echo
echo -e "${YELLOW}To view the Grafana dashboard:${NC}"
echo "  kubectl port-forward svc/grafana 3000:3000 -n monitoring"
echo "  Then open: http://localhost:3000/d/image-push-jobs/image-push-jobs-dashboard"

# Clean up if requested
if [ "$CLEANUP" = true ]; then
  echo
  echo -e "${YELLOW}Jobs will be cleaned up in 10 minutes. Press Ctrl+C to cancel cleanup.${NC}"
  echo -e "${YELLOW}To clean up manually:${NC}"
  echo "  kubectl delete jobs -n $NAMESPACE -l \"job-type=image-push,monitoring=true,generator=test-script\""
  
  sleep 600
  
  echo -e "${YELLOW}Cleaning up jobs...${NC}"
  kubectl delete jobs -n $NAMESPACE -l "job-type=image-push,monitoring=true,generator=test-script"
  echo -e "${GREEN}Cleanup completed${NC}"
else
  echo
  echo -e "${YELLOW}Skipping cleanup as requested${NC}"
  echo -e "${YELLOW}To clean up manually:${NC}"
  echo "  kubectl delete jobs -n $NAMESPACE -l \"job-type=image-push,monitoring=true,generator=test-script\""
fi 
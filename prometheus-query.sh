#!/bin/bash

# Set colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Default values
PROMETHEUS_PORT=9090
NAMESPACE="monitoring"
FORMAT="table"

# Function to display usage
usage() {
  echo "Usage: $0 [options] <query>"
  echo
  echo "Options:"
  echo "  -p, --port PORT       Port to use for Prometheus port-forward (default: 9090)"
  echo "  -n, --namespace NS    Namespace where Prometheus is deployed (default: monitoring)"
  echo "  -f, --format FORMAT   Output format: table, json, or raw (default: table)"
  echo "  -h, --help            Display this help message"
  echo
  echo "Examples:"
  echo "  $0 'kube_job_status_failed'"
  echo "  $0 --format json 'sum(kube_job_status_succeeded) by (namespace)'"
  echo "  $0 'rate(kube_job_status_failed[5m])'"
  exit 1
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -p|--port)
      PROMETHEUS_PORT="$2"
      shift 2
      ;;
    -n|--namespace)
      NAMESPACE="$2"
      shift 2
      ;;
    -f|--format)
      FORMAT="$2"
      shift 2
      ;;
    -h|--help)
      usage
      ;;
    *)
      QUERY="$1"
      shift
      ;;
  esac
done

# Check if query is provided
if [ -z "$QUERY" ]; then
  echo -e "${RED}Error: No query provided${NC}"
  usage
fi

# Validate format
if [[ ! "$FORMAT" =~ ^(table|json|raw)$ ]]; then
  echo -e "${RED}Error: Invalid format. Must be one of: table, json, raw${NC}"
  exit 1
fi

# Start port-forward to Prometheus
echo -e "${YELLOW}Starting port-forward to Prometheus in namespace $NAMESPACE...${NC}"
kubectl port-forward svc/prometheus-operated $PROMETHEUS_PORT:9090 -n $NAMESPACE > /dev/null 2>&1 &
PF_PID=$!

# Give it a moment to establish
sleep 3

# Check if port-forward is successful
if ! curl -s http://localhost:$PROMETHEUS_PORT/-/healthy > /dev/null; then
  echo -e "${RED}Error: Failed to connect to Prometheus. Check if it's running in namespace $NAMESPACE.${NC}"
  kill $PF_PID 2>/dev/null
  exit 1
fi

echo -e "${GREEN}Connected to Prometheus${NC}"
echo -e "${YELLOW}Executing query: ${QUERY}${NC}"

# Execute the query using curl with proper URL encoding
RESULT=$(curl -G -s "http://localhost:$PROMETHEUS_PORT/api/v1/query" --data-urlencode "query=$QUERY")

# Check if query was successful
if echo "$RESULT" | grep -q "\"status\":\"success\""; then
  echo -e "${GREEN}Query successful${NC}"
  
  # Format the output based on user preference
  case $FORMAT in
    table)
      echo -e "${YELLOW}Results:${NC}"
      echo "$RESULT" | jq -r '.data.result[] | "\(.metric) => \(.value[1])"'
      ;;
    json)
      echo "$RESULT" | jq .
      ;;
    raw)
      echo "$RESULT"
      ;;
  esac
else
  echo -e "${RED}Query failed:${NC}"
  echo "$RESULT" | jq .
fi

# Clean up
echo -e "${YELLOW}Cleaning up...${NC}"
kill $PF_PID 2>/dev/null
echo -e "${GREEN}Done${NC}" 
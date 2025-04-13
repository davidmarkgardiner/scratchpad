#!/bin/bash

# Load environment variables
set -a
source .env
set +a

# Process template with envsubst
envsubst < cluster.yaml > cluster-processed.yaml

# Deploy using kubectl
kubectl apply -f cluster-processed.yaml

# Cleanup
rm cluster-processed.yaml 
#!/bin/bash

# Load environment variables
set -a
source .env
set +a

# Replace variables in extension.yaml
envsubst < extension.yaml > extension.tmp.yaml
mv extension.tmp.yaml extension.yaml

# Replace variables in fluxconfig.yaml
envsubst < fluxconfig.yaml > fluxconfig.tmp.yaml
mv fluxconfig.tmp.yaml fluxconfig.yaml

# Apply configurations
kubectl apply -f extension.yaml
kubectl apply -f fluxconfig.yaml 
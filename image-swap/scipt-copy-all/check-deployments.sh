#!/bin/bash

# Path to kubectl
KUBECTL="/Users/davidgardiner/.rd/bin/kubectl"

echo "Checking deployments..."
$KUBECTL get deployments

echo -e "\nChecking images in deployments..."
$KUBECTL get deployments -o jsonpath="{.items[*].spec.template.spec.containers[*].image}" | tr -s '[[:space:]]' '\n' 
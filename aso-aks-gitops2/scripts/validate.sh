#!/bin/bash
set -e

# Color codes for better visibility
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function for error handling
error_exit() {
    echo -e "${RED}Error: $1${NC}" >&2
    exit 1
}

# Function for success messages
success_msg() {
    echo -e "${GREEN}✓ $1${NC}"
}

# Function for warnings
warn_msg() {
    echo -e "${YELLOW}! $1${NC}"
}

echo "Starting validation checks..."

# Check if required tools are installed
for tool in yamllint kustomize kubectl kubeconform; do
    if ! command -v $tool &> /dev/null; then
        error_exit "$tool is required but not installed"
    fi
done
success_msg "Required tools check passed"

# Run YAML lint only on base and clusters directories
echo "Running YAML lint on base/ and clusters/..."
if ! yamllint base/ clusters/; then
    error_exit "YAML lint failed"
fi
success_msg "YAML lint passed"

# Validate kustomization files exist in base and clusters
for file in base/cluster-template/kustomization.yaml clusters/{dev,prod}/kustomization.yaml; do
    if [ ! -f "$file" ]; then
        error_exit "Required kustomization file $file not found"
    fi
done
success_msg "Kustomization files check passed"

# Run Kustomize build validation for each environment
echo "Running Kustomize build validation..."
for env in dev prod; do
    echo "Validating $env environment..."
    if ! kustomize build clusters/$env > /dev/null; then
        error_exit "Kustomize build failed for $env environment"
    fi
    
    # Validate against Kubernetes schemas
    echo "Running Kubernetes schema validation for $env..."
    if ! kustomize build clusters/$env | kubeconform --ignore-missing-schemas; then
        error_exit "Kubernetes schema validation failed for $env"
    fi
done
success_msg "Kustomize build validation passed"

# Check for ASO CRD validation
echo "Checking for ASO CRD validation..."
if ! kubectl get crd managedclusters.containerservice.azure.com -o yaml > aso-crd.yaml; then
    error_exit "Failed to get ASO CRD. Is ASO installed?"
fi

# Validate against ASO CRD
for env in dev prod; do
    echo "Validating $env against ASO CRD..."
    if ! kustomize build clusters/$env | kubectl apply --dry-run=client -f -; then
        error_exit "ASO CRD validation failed for $env"
    fi
done
success_msg "ASO CRD validation passed"

# Additional security checks only on base and clusters
echo "Running additional security checks..."

# Check for sensitive data
if grep -r "password\|secret\|key" base/ clusters/; then
    warn_msg "Potential sensitive data found in base/ or clusters/"
fi

# Check for default namespace usage
for env in dev prod; do
    if kustomize build clusters/$env | grep "namespace: default"; then
        warn_msg "Default namespace usage detected in $env environment"
    fi
done

# Check for resource limits in base template
if ! grep -r "resources:" base/cluster-template/; then
    warn_msg "Resource limits might be missing in base template"
fi

# Validate variables are set
for env in dev prod; do
    if [ -f "clusters/$env/cluster-config/variables.yaml" ]; then
        if grep -E "SUBSCRIPTION_ID: \"\"|ADMIN_GROUP_ID: \"\"" "clusters/$env/cluster-config/variables.yaml"; then
            warn_msg "Empty required variables found in $env/cluster-config/variables.yaml"
        fi
    fi
done

success_msg "All validations completed successfully!"
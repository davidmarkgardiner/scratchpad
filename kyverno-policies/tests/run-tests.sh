#!/bin/bash
set -e

# Script location
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check Rancher Desktop environment
check_rancher_desktop() {
    if command_exists "rancher-desktop"; then
        echo -e "${YELLOW}Rancher Desktop detected${NC}"
        return 0
    fi
    return 1
}

# Auto-detect container engine if not specified
if [ -z "$CONTAINER_ENGINE" ]; then
    if command_exists "nerdctl"; then
        CONTAINER_ENGINE="nerdctl"
    elif command_exists "docker"; then
        CONTAINER_ENGINE="docker"
    else
        echo -e "${RED}No container engine found. Please install Docker or Rancher Desktop${NC}"
        echo -e "${YELLOW}Falling back to local test execution...${NC}"
        cd "$PROJECT_ROOT"
        go test -v ./tests/...
        exit $?
    fi
fi

# Validate container engine
case $CONTAINER_ENGINE in
    docker|nerdctl|containerd)
        echo -e "${YELLOW}Using container engine: $CONTAINER_ENGINE${NC}"
        ;;
    *)
        echo -e "${RED}Invalid container engine: $CONTAINER_ENGINE${NC}"
        echo "Please use one of: docker, nerdctl, containerd"
        exit 1
        ;;
esac

echo -e "${YELLOW}🔧 Setting up test environment...${NC}"

# Initialize Go module if not exists
if [ ! -f "$PROJECT_ROOT/go.mod" ]; then
    echo -e "${YELLOW}📦 Initializing Go module...${NC}"
    cd "$PROJECT_ROOT"
    go mod init github.com/yourusername/kyverno-policies
    
    # Add required dependencies
    go get github.com/kyverno/kyverno@v1.8.0
    go get k8s.io/api@v0.26.0
    go get k8s.io/apimachinery@v0.26.0
    go get k8s.io/client-go@v0.26.0
    go get sigs.k8s.io/controller-runtime@v0.14.0
    go get istio.io/api@master
    go get istio.io/client-go@master
    go get github.com/Azure/azure-sdk-for-go@v67.0.0
    
    go mod tidy
fi

echo -e "${YELLOW}🐳 Building test container...${NC}"

# Build command based on container engine
build_cmd=""
run_cmd=""
case $CONTAINER_ENGINE in
    docker)
        build_cmd="docker build -t kyverno-policy-tests -f \"$SCRIPT_DIR/Dockerfile\" \"$PROJECT_ROOT\""
        run_cmd="docker run --rm -v \"${HOME}/.kube/config:/root/.kube/config:ro\" -v \"$PROJECT_ROOT:/app\" kyverno-policy-tests"
        ;;
    nerdctl)
        # Use Rancher Desktop's buildkit socket
        BUILDKIT_HOST="${BUILDKIT_HOST:-unix:///var/run/docker.sock}"
        build_cmd="nerdctl build --namespace k8s.io -t kyverno-policy-tests -f \"$SCRIPT_DIR/Dockerfile\" \"$PROJECT_ROOT\""
        run_cmd="nerdctl run --namespace k8s.io --rm -v \"${HOME}/.kube/config:/root/.kube/config:ro\" -v \"$PROJECT_ROOT:/app\" kyverno-policy-tests"
        ;;
    containerd)
        build_cmd="sudo containerd build -t kyverno-policy-tests -f \"$SCRIPT_DIR/Dockerfile\" \"$PROJECT_ROOT\""
        run_cmd="sudo containerd run --rm -v \"${HOME}/.kube/config:/root/.kube/config:ro\" -v \"$PROJECT_ROOT:/app\" kyverno-policy-tests"
        ;;
esac

# Execute build
echo -e "${YELLOW}Running: $build_cmd${NC}"
eval $build_cmd
if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Container build failed${NC}"
    echo -e "${YELLOW}Trying local test execution instead...${NC}"
    cd "$PROJECT_ROOT"
    go test -v ./tests/...
    exit $?
fi

echo -e "${YELLOW}🚀 Running tests...${NC}"

# Execute run
eval $run_cmd
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Tests completed successfully!${NC}"
else
    echo -e "${RED}❌ Tests failed!${NC}"
    exit 1
fi 
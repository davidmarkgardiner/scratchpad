# Running Kyverno Policy Tests

This directory contains integration tests for Kyverno policies. Tests can be run either locally or in a container.

## Prerequisites

Common requirements:
- `kubectl` configured with access to a Kubernetes cluster
- Kyverno installed in the cluster
- Go 1.19 or later installed

For Rancher Desktop:
- Rancher Desktop installed and running
- buildkit installed (`brew install buildkit` on macOS)

For Docker Desktop:
- Docker Desktop installed and running

## Quick Start

### Option 1: Local Execution (Recommended for Development)

The simplest way to run tests:
```bash
cd kyverno-policies
go test -v ./tests/...
```

### Option 2: Container Execution (Recommended for CI/CD)

#### Using Rancher Desktop

First-time setup:
```bash
# Install buildkit if not already installed
brew install buildkit  # macOS
# or
sudo apt-get install -y buildkit  # Ubuntu/Debian

# Start buildkit daemon if not running
buildkitd &
```

Run tests:
```bash
cd kyverno-policies/tests
chmod +x run-tests.sh
./run-tests.sh  # Auto-detects nerdctl if Rancher Desktop is installed
```

Or explicitly specify nerdctl:
```bash
CONTAINER_ENGINE=nerdctl ./run-tests.sh
```

#### Using Docker Desktop:
```bash
cd kyverno-policies/tests
chmod +x run-tests.sh
CONTAINER_ENGINE=docker ./run-tests.sh
```

## Manual Execution

### Local Go Test

1. Initialize the module (if not already done):
```bash
cd kyverno-policies
go mod init github.com/yourusername/kyverno-policies
go mod tidy
```

2. Run the tests:
```bash
go test -v ./tests/...
```

### Container Execution

#### With Rancher Desktop:
```bash
# Ensure buildkit is installed and running
brew install buildkit  # macOS
buildkitd &  # Start buildkit daemon

# Build and run
nerdctl build --buildkit-host unix:///run/buildkit/buildkitd.sock -t kyverno-policy-tests -f Dockerfile ..
nerdctl run --rm \
    -v "${HOME}/.kube/config:/root/.kube/config:ro" \
    -v "$(pwd)/..:/app" \
    kyverno-policy-tests
```

#### With Docker:
```bash
docker build -t kyverno-policy-tests -f Dockerfile ..
docker run --rm \
    -v "${HOME}/.kube/config:/root/.kube/config:ro" \
    -v "$(pwd)/..:/app" \
    kyverno-policy-tests
```

## Test Structure

The tests are organized in `policies_test.go` and cover:

- Spot Instance Configuration
- Resource Limits
- Istio Injection
- PeerAuthentication

## Troubleshooting

1. **Rancher Desktop Issues**
   - Ensure buildkit is installed: `brew install buildkit`
   - Start buildkit daemon: `buildkitd &`
   - Check if nerdctl is available: `nerdctl version`
   - Verify Rancher Desktop is running: `rancher-desktop version`
   - If container build fails, the script will automatically fall back to local test execution

2. **Kubeconfig Issues**
   - Ensure your kubeconfig is at `~/.kube/config`
   - Or set `KUBECONFIG` environment variable
   - For Rancher Desktop, check if the context is correct: `kubectl config current-context`

3. **Missing Kyverno**
   - Tests will skip if Kyverno is not installed
   - Install Kyverno: `helm install kyverno kyverno/kyverno`

4. **Missing Istio**
   - Istio-related tests will be skipped if Istio is not installed
   - This is expected in non-production environments

5. **Go Module Issues**
   - If you see dependency errors, try:
     ```bash
     rm go.mod go.sum
     go mod init github.com/yourusername/kyverno-policies
     go mod tidy
     ```

## CI/CD Integration

For CI/CD pipelines:
- Use the provided Dockerfile for containerized execution
- Example Azure DevOps pipeline available in `azure-pipelines.yaml`
- For non-Docker environments, use direct Go test execution
- Set `CONTAINER_ENGINE` environment variable to match your CI environment

## Environment Variables

The following environment variables are supported:

- `KUBECONFIG`: Path to kubeconfig file (default: ~/.kube/config)
- `TEST_NAMESPACE`: Namespace for test resources (default: kyverno-test)
- `TEST_TIMEOUT`: Timeout for policy evaluations (default: 3s)
- `CONTAINER_ENGINE`: Container runtime to use (auto-detected if not set)

## Choosing Between Local and Container Execution

- **Local Execution**:
  - Fastest option for development
  - No container runtime required
  - Direct access to local tools
  - Recommended for daily development

- **Container Execution**:
  - Consistent environment
  - Isolated dependencies
  - Matches CI/CD environment
  - Recommended for final verification
  - Falls back to local execution if container build fails 
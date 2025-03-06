# Get script location and project root
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir

# Function to write colored output
function Write-ColorOutput($ForegroundColor) {
    $fc = $host.UI.RawUI.ForegroundColor
    $host.UI.RawUI.ForegroundColor = $ForegroundColor
    if ($args) {
        Write-Output $args
    }
    $host.UI.RawUI.ForegroundColor = $fc
}

Write-ColorOutput Yellow "🔧 Setting up test environment..."

# Initialize Go module if not exists
if (-not (Test-Path "$ProjectRoot/go.mod")) {
    Write-ColorOutput Yellow "📦 Initializing Go module..."
    Push-Location $ProjectRoot
    try {
        # Initialize module
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
        
        # Tidy up dependencies
        go mod tidy
    }
    finally {
        Pop-Location
    }
}

Write-ColorOutput Yellow "🚀 Running tests..."
Push-Location $ProjectRoot
try {
    # Run the tests
    go test -v ./tests/...
    if ($LASTEXITCODE -eq 0) {
        Write-ColorOutput Green "✅ Tests completed successfully!"
    }
    else {
        Write-ColorOutput Red "❌ Tests failed!"
        exit $LASTEXITCODE
    }
}
finally {
    Pop-Location
} 
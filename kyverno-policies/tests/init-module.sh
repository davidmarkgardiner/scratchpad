#!/bin/bash
set -e

# Initialize Go module if not already initialized
if [ ! -f go.mod ]; then
    echo "Initializing Go module..."
    go mod init github.com/yourusername/kyverno-policies
fi

# Add required dependencies
go get github.com/kyverno/kyverno@v1.8.0
go get k8s.io/api@v0.26.0
go get k8s.io/apimachinery@v0.26.0
go get k8s.io/client-go@v0.26.0
go get sigs.k8s.io/controller-runtime@v0.14.0
go get istio.io/api@master
go get istio.io/client-go@master

# Tidy up the module
go mod tidy

echo "Module initialization complete!" 
# Use golang 1.19 as base image
FROM golang:1.19-alpine

# Install required packages
RUN apk add --no-cache \
    git \
    curl \
    bash \
    gcc \
    musl-dev

# Install kubectl
RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && \
    chmod +x kubectl && \
    mv kubectl /usr/local/bin/

# Set working directory
WORKDIR /app

# Copy go module files
COPY go.mod go.sum ./

# Copy test files
COPY tests/ ./tests/

# Initialize Go modules and get dependencies
RUN go mod download

# Set environment variables
ENV GO111MODULE=on \
    CGO_ENABLED=0 \
    GOOS=linux

# Default command to run tests
ENTRYPOINT ["go", "test", "-v", "./tests/..."] 
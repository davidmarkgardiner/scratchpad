FROM golang:1.21

WORKDIR /app

# Install kubectl
RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && \
    chmod +x kubectl && \
    mv kubectl /usr/local/bin/

# Copy go.mod first
COPY go.mod ./

# Initialize module and download dependencies
RUN go mod download && \
    go mod tidy

# Copy the test files
COPY tests/ ./tests/
COPY templates/ ./templates/

# Run tests
CMD ["go", "test", "-v", "./tests/..."] 
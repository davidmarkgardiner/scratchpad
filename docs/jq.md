# Download the binary
wget https://github.com/jqlang/jq/releases/download/jq-1.7.1/jq-linux-amd64

# Make it executable
chmod +x jq-linux-amd64

# Move to a directory in your PATH
sudo mv jq-linux-amd64 /usr/local/bin/jq

# Verify the installation
jq --version

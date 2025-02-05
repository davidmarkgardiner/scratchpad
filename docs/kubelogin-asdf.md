# Installing kubelogin and asdf on WSL

## 1. Installing asdf Version Manager

### Prerequisites
```bash
# Install required dependencies
sudo apt update
sudo apt install curl git wget unzip -y
```

### Install asdf
```bash
# Clone asdf
git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.13.1

# Add to bash profile (choose the one you use)
# For bash:
echo '. "$HOME/.asdf/asdf.sh"' >> ~/.bashrc
echo '. "$HOME/.asdf/completions/asdf.bash"' >> ~/.bashrc

# For zsh:
echo '. "$HOME/.asdf/asdf.sh"' >> ~/.zshrc
echo '. "$HOME/.asdf/completions/asdf.bash"' >> ~/.zshrc

# Reload shell configuration (use appropriate one)
source ~/.bashrc
# OR
source ~/.zshrc
```

### Verify asdf Installation
```bash
asdf --version
```

## 2. Installing kubelogin using asdf

### Add kubelogin Plugin
```bash
# Add kubelogin plugin
asdf plugin add kubelogin https://github.com/calexandre/asdf-kubelogin.git

# Install latest version
asdf install kubelogin latest

# Set it as global version
asdf global kubelogin latest
```

### Alternative: Direct Installation of kubelogin

If you prefer not to use asdf, you can install kubelogin directly:

```bash
# Download latest version
KUBELOGIN_VERSION=$(curl -s https://api.github.com/repos/Azure/kubelogin/releases/latest | grep '"tag_name":' | cut -d'"' -f4)
wget https://github.com/Azure/kubelogin/releases/download/${KUBELOGIN_VERSION}/kubelogin-linux-amd64.zip

# Unzip and install
unzip kubelogin-linux-amd64.zip
sudo mv bin/linux_amd64/kubelogin /usr/local/bin/
rm -rf bin/ kubelogin-linux-amd64.zip

# Make executable
sudo chmod +x /usr/local/bin/kubelogin
```

## 3. Verify Installations

```bash
# Verify asdf
asdf --version

# Verify kubelogin
kubelogin --version
```

## 4. Common Issues and Solutions

### asdf Command Not Found
If you encounter "command not found" after installing asdf:
1. Ensure you added the initialization to the correct shell configuration file
2. Make sure you sourced the configuration file
3. Verify the installation path exists: `ls ~/.asdf`

### kubelogin Installation Issues
If kubelogin fails to install through asdf:
1. Verify plugin installation: `asdf plugin list`
2. Try reinstalling the plugin: 
```bash
asdf plugin remove kubelogin
asdf plugin add kubelogin
```
3. Check for system dependencies: `sudo apt install curl unzip`

## 5. Useful asdf Commands

```bash
# List all plugins
asdf plugin list

# List all available versions for kubelogin
asdf list all kubelogin

# Install specific version
asdf install kubelogin x.y.z

# Set local version (project specific)
asdf local kubelogin x.y.z

# Set global version
asdf global kubelogin x.y.z

# Show current version
asdf current kubelogin
```

## 6. Updating

### Update asdf
```bash
asdf update
```

### Update kubelogin via asdf
```bash
asdf plugin update kubelogin
asdf install kubelogin latest
asdf global kubelogin latest
```

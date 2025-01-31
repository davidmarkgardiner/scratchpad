I'll help you install the Azure CLI and AKS CLI tools on WSL. Here's a step-by-step guide:

1. First, install Azure CLI:
```bash
# Get Microsoft signing key and repository
curl -sL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/microsoft.gpg > /dev/null
AZ_REPO=$(lsb_release -cs)
echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ $AZ_REPO main" | sudo tee /etc/apt/sources.list.d/azure-cli.list

# Install Azure CLI
sudo apt-get update
sudo apt-get install azure-cli
```

2. Install kubectl:
```bash
sudo az aks install-cli
```

3. Install kubelogin for AKS authentication:
```bash
sudo az aks install-kubelogin
```

4. Add useful AKS aliases to your `.zshrc`:
```bash
# AKS aliases
alias azl='az login'
alias azs='az account set --subscription'
alias azls='az account list --output table'
alias azaks='az aks'
alias azaksc='az aks get-credentials'
alias azaksl='az aks list --output table'
```

5. Verify installations:
```bash
# Check Azure CLI version
az --version

# Check kubectl version
kubectl version --client

# Check kubelogin version
kubelogin --version
```

6. Login to Azure:
```bash
az login
```

7. Get AKS credentials:
```bash
# List your clusters
az aks list -o table

# Get credentials for a specific cluster
az aks get-credentials --resource-group <resource-group> --name <cluster-name>
```

Would you like me to explain any of these steps in more detail?

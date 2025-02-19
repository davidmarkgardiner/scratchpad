Yes, there are several tools to enhance kubectl output with colors! Here are the main ones:

1. Install `kubecolor` for colored kubectl output:
```bash
go install github.com/hidetatz/kubecolor/cmd/kubecolor@latest
```

Add to `.zshrc`:
```bash
alias k="kubecolor"
```

2. Install `kubectl-neat` to clean up kubectl output:
```bash
kubectl krew install neat
```

3. Use `yq` for colored YAML:
```bash
sudo wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/bin/yq && sudo chmod +x /usr/bin/yq
```

4. Add colored aliases to `.zshrc`:
```bash
# Colorized kubectl get pods
alias kgp='kubectl get pods --output=custom-columns="NAME:.metadata.name,STATUS:.status.phase,NODE:.spec.nodeName" --no-headers | grep -v "Completed" | GREP_COLORS="mt=01;32" grep --color=always "Running\|$" | GREP_COLORS="mt=01;31" grep --color=always "Error\|CrashLoopBackOff\|$" | GREP_COLORS="mt=01;33" grep --color=always "Pending\|$"'

# Colorized kubectl get nodes
alias kgn='kubectl get nodes --output=custom-columns="NAME:.metadata.name,STATUS:.status.conditions[?(@.type==\"Ready\")].status" --no-headers | GREP_COLORS="mt=01;32" grep --color=always "True\|$" | GREP_COLORS="mt=01;31" grep --color=always "False\|$" | GREP_COLORS="mt=01;33" grep --color=always "Unknown\|$"'
```

5. Install `stern` for colored pod logs:
```bash
go install github.com/stern/stern@latest
```

Example usage:
```bash
# Watch colored pod logs
stern my-pod-name

# Watch all pods in namespace
stern . -n my-namespace
```

These tools will make your kubectl output much more readable with color coding. Would you like me to explain any of them in more detail?

I'll show you the most practical ways to run Kubescape locally:

1. First, install Kubescape:
```bash
curl -s https://raw.githubusercontent.com/kubescape/kubescape/master/install.sh | /bin/bash
```

2. Basic Local Scanning Examples:

```bash
# Scan your current cluster context
kubescape scan

# Scan specific YAML files in a directory
kubescape scan ./k8s-manifests/

# Scan a specific Helm chart
kubescape scan ./my-helm-chart/

# Scan with NSA framework
kubescape scan framework nsa

# Scan with MITRE framework
kubescape scan framework mitre
```

3. Focused Scanning:
```bash
# Scan specific namespaces
kubescape scan --include-namespaces dev,staging

# Scan a specific workload
kubescape scan workload deployment/my-app -n my-namespace

# Scan for a specific security control
kubescape scan control c-0016 -v
```

4. Local Development Scanning:
```bash
# Scan local kubernetes manifests before applying
kubescape scan deployment.yaml

# Scan multiple files
kubescape scan *.yaml

# Scan with pretty HTML output
kubescape scan deployment.yaml --format html --output scan-results.html
```

5. Scan with Custom Configuration:
```bash
# Scan with custom compliance threshold
kubescape scan --compliance-threshold 85

# Exclude system namespaces
kubescape scan --exclude-namespaces kube-system,kube-public

# Scan with custom configuration
kubescape scan --use-default-config=false --enable-host-scan=true
```

6. VS Code Integration (Alternative to Cursor):
```bash
# Install VS Code extension
code --install-extension kubescape.kubescape
```
Then you can:
- Right-click on any YAML file
- Select "Scan with Kubescape"
- View results in the Problems panel

7. Real-time Scanning:
```bash
# Watch mode for development
kubescape scan --watch ./k8s-manifests/

# Scan and show only failed controls
kubescape scan --fail-threshold 100
```

8. Scanning with Different Output Formats:
```bash
# JSON output (good for parsing)
kubescape scan --format json --output results.json

# JUnit output (good for CI integration)
kubescape scan --format junit --output results.xml

# PDF report
kubescape scan --format pdf --output security-report.pdf
```

9. Offline Scanning:
```bash
# Download artifacts for offline use
kubescape download artifacts --output ./offline-artifacts

# Scan using offline artifacts
kubescape scan --use-artifacts-from ./offline-artifacts
```

10. Scan with Exception Handling:
```bash
# Create exceptions file
cat > exceptions.json <<EOF
{
  "rules": [
    {
      "name": "rule-name",
      "match": {
        "namespaces": ["dev"]
      }
    }
  ]
}
EOF

# Scan with exceptions
kubescape scan --exceptions exceptions.json
```

Pro Tips:
- Use `-v` flag for verbose output when debugging
- Use `--format json | jq` for better JSON formatting
- Save common scan configurations in a `.kubescape` directory
- Use `kubescape list` to see available frameworks and controls

Let me know if you want to dive deeper into any of these examples or need help with specific scanning scenarios!

Let me help you understand Kubescape and its implementation across different environments. I'll break this down into key sections:

1. First, let's search for more specific implementation details:

Ran tool
Let me break down the implementation of Kubescape across your requested environments:

1. **Installation in Cursor**
add extension and run

`brew install kubescape`

2. **GitLab CI Implementation**
Here's a practical example for `.gitlab-ci.yml`:

```yaml
kubescape_scan:
  image: 
    name: kubescape/kubescape:latest
    entrypoint: [""]
  stage: security_scan
  script:
    - kubescape scan framework nsa --format junit --output results.xml
    - kubescape scan framework mitre --format sarif --output results.sarif
  artifacts:
    reports:
      junit: results.xml
    paths:
      - results.sarif
  rules:
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
```

3. **Azure DevOps Pipeline**
Here's an example `azure-pipelines.yml`:

```yaml
trigger:
  - main

pool:
  vmImage: 'ubuntu-latest'

steps:
- script: |
    curl -s https://raw.githubusercontent.com/kubescape/kubescape/master/install.sh | /bin/bash
    kubescape scan framework nsa --format sarif --output results.sarif
  displayName: 'Run Kubescape Scan'

- task: PublishBuildArtifacts@1
  inputs:
    pathToPublish: 'results.sarif'
    artifactName: 'KubescapeScan'
```

4. **Helm Integration**
For continuous scanning in your Helm-based environments:

```bash
# Add Kubescape Helm repo
helm repo add kubescape https://kubescape.github.io/helm-charts/

# Install Kubescape operator
helm install kubescape-operator kubescape/kubescape-operator \
  --namespace kubescape \
  --create-namespace
```

Key Features Available:
- Configuration scanning
- Vulnerability scanning
- Runtime analysis
- Network policy generation

5. **Scanning Options**:
```bash
# Scan specific namespaces
kubescape scan --include-namespaces development,staging,production

# Scan Helm charts
kubescape scan /path/to/helm/charts

# Scan with compliance threshold
kubescape scan --compliance-threshold 85
```

6. **Output Formats**:
```bash
# JSON output
kubescape scan --format json --output results.json

# SARIF for Azure DevOps/GitHub
kubescape scan --format sarif --output results.sarif

# HTML report
kubescape scan --format html --output results.html
```

For air-gapped environments:
```bash
# Download artifacts
kubescape download artifacts --output path/to/local/dir

# Scan using downloaded artifacts
kubescape scan --use-artifacts-from path/to/local/dir
```

Sources:
- Kubescape GitHub repository
- ARMO Platform documentation
- Kubescape official documentation

Let me know if you need more specific examples for any of these implementations or have questions about particular security controls!

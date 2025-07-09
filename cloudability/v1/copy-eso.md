There are several ways to copy secrets from one namespace to another in Kubernetes:

## 1. **Reflector** (Popular Tool)
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: source-secret
  namespace: source-ns
  annotations:
    reflector.v1.k8s.emberstack.com/reflection-allowed: "true"
    reflector.v1.k8s.emberstack.com/reflection-auto-enabled: "true"
    reflector.v1.k8s.emberstack.com/reflection-allowed-namespaces: "target-ns1,target-ns2"
```

## 2. **Kubernetes Replicator**
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: source-secret
  namespace: source-ns
  annotations:
    replicator.v1.mittwald.de/replicate-to: "target-ns1,target-ns2"
```

## 3. **kubectl Copy Command**
```bash
# Copy secret from one namespace to another
kubectl get secret my-secret -n source-ns -o yaml | \
sed 's/namespace: source-ns/namespace: target-ns/' | \
kubectl apply -f -

# Or using kubectl create
kubectl get secret my-secret -n source-ns -o yaml --export | \
kubectl apply -n target-ns -f -
```

## 4. **Custom Script/CronJob**
```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: secret-copier
spec:
  schedule: "*/5 * * * *"
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: secret-copier
            image: bitnami/kubectl
            command:
            - /bin/sh
            - -c
            - |
              kubectl get secret source-secret -n source-ns -o yaml | \
              sed 's/namespace: source-ns/namespace: target-ns/' | \
              kubectl apply -f -
```

## 5. **Helm with External Secrets**
```yaml
# Using Helm to template across namespaces
{{- range .Values.targetNamespaces }}
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: {{ $.Values.secretName }}
  namespace: {{ . }}
spec:
  secretStoreRef:
    name: {{ $.Values.secretStore }}
    kind: ClusterSecretStore
  target:
    name: {{ $.Values.secretName }}
  data: {{ $.Values.secretData | toYaml | nindent 2 }}
---
{{- end }}
```

## 6. **Kubernetes Jobs**
```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: copy-secret-job
spec:
  template:
    spec:
      containers:
      - name: secret-copier
        image: bitnami/kubectl
        command: ["kubectl", "get", "secret", "my-secret", "-n", "source-ns", "-o", "yaml"]
        # Add logic to modify and apply to target namespace
      restartPolicy: Never
```

## 7. **Using Operators like Secrets Store CSI Driver**
```yaml
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: app-secrets
  namespace: target-ns
spec:
  provider: # your provider
  secretObjects:
  - secretName: copied-secret
    type: Opaque
```

**Recommendation**: For production use, **Reflector** or **Kubernetes Replicator** are the most robust solutions as they handle updates automatically and have proper RBAC controls.


---

To copy a secret from one namespace to another using kubectl, you have a few options:

## Method 1: Export and Import (Recommended)

```bash
# Export the secret from source namespace and apply to target namespace
kubectl get secret <secret-name> -n <source-namespace> -o yaml | \
sed 's/namespace: <source-namespace>/namespace: <target-namespace>/' | \
kubectl apply -f -
```

## Method 2: Using kubectl get with output redirection

```bash
# Get the secret and pipe it to create in new namespace
kubectl get secret <secret-name> -n <source-namespace> -o yaml | \
kubectl apply -n <target-namespace> -f -
```

## Method 3: Clean export (removes metadata)

```bash
# Export without metadata that might cause conflicts
kubectl get secret <secret-name> -n <source-namespace> -o yaml | \
grep -v '^\s*namespace:\|^\s*resourceVersion:\|^\s*uid:\|^\s*creationTimestamp:' | \
kubectl apply -n <target-namespace> -f -
```

## Method 4: One-liner with jq (if you have jq installed)

```bash
kubectl get secret <secret-name> -n <source-namespace> -o json | \
jq 'del(.metadata.namespace,.metadata.resourceVersion,.metadata.uid,.metadata.creationTimestamp)' | \
kubectl apply -n <target-namespace> -f -
```

## Example

```bash
# Copy secret "my-secret" from "default" namespace to "production" namespace
kubectl get secret my-secret -n default -o yaml | \
sed 's/namespace: default/namespace: production/' | \
kubectl apply -f -
```

The first method is usually the most reliable as it explicitly handles the namespace change. Make sure both namespaces exist before running the command.
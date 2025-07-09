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
Let me help you with the Kubernetes RBAC configuration needed for pod service discovery. Here's what you need:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-service-discovery
  namespace: your-namespace
rules:
- apiGroups: [""]
  resources: ["pods", "services", "endpoints"]
  verbs: ["get", "list", "watch"]
```

And the corresponding RoleBinding:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: pod-service-discovery-binding
  namespace: your-namespace
subjects:
- kind: ServiceAccount
  name: your-service-account
  namespace: your-namespace
roleRef:
  kind: Role
  name: pod-service-discovery
  apiGroup: rbac.authorization.k8s.io
```

This configuration:
- Allows reading pods, services, and endpoints in the namespace
- Uses "get", "list", and "watch" permissions which are needed for service discovery
- Is scoped to a single namespace (if you need cluster-wide access, you'd use ClusterRole instead)

Make sure to replace `your-namespace` and `your-service-account` with your actual values.

Would you like me to explain any part of this configuration in more detail?

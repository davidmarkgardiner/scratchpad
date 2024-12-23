

# How to Remove a Stuck Kubernetes Namespace

When a Kubernetes namespace is stuck in `Terminating` state, follow these steps to force its removal.

## 1. Check Stuck Resources

First, check what resources might be preventing deletion:

```bash
kubectl get all -n kyverno
```

## 2. Method 1: Using JSON and Proxy

### a. Save namespace to JSON
```bash
kubectl get namespace kyverno -o json > kyverno-ns.json
```

### b. Remove finalizers using jq
```bash
kubectl get namespace kyverno -o json | jq '.spec.finalizers=[]' > kyverno-ns.json
```

### c. Start kubectl proxy
```bash
kubectl proxy &
```

### d. Make API call to force removal
```bash
curl -k -H "Content-Type: application/json" -X PUT --data-binary @kyverno-ns.json http://127.0.0.1:8001/api/v1/namespaces/kyverno/finalize
```

## 3. Method 2: Using kubectl patch

If Method 1 doesn't work, try this simpler approach:

```bash
kubectl patch namespace kyverno -p '{"metadata":{"finalizers":null}}'
```

## 4. Method 3: Direct API Call (Most Aggressive)

If all else fails, try this more aggressive approach:

```bash
NAMESPACE=kyverno
kubectl get namespace $NAMESPACE -o json \
  | tr -d "\n" | sed "s/\"finalizers\": \[[^]]\+\]/\"finalizers\": []/" \
  | kubectl replace --raw /api/v1/namespaces/$NAMESPACE/finalize -f -
```

## 5. Verify Removal

Check if the namespace has been removed:

```bash
kubectl get namespaces | grep kyverno
```

> **Note**: If you're still experiencing issues, check for error messages and additional stuck resources that might need to be removed manually.

# Understanding Kubernetes Resource Management

## Resource Requests vs ResourceQuota

### 🎯 Resource Requests (Pod Level)
Resource requests define the minimum guaranteed resources for a pod.

**Key Points:**
- Requests are a minimum guarantee, not a limit
- Pods can exceed their requests if the node has spare capacity
- Used by the scheduler to decide which node to place the pod on

**Example:**
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: my-pod
spec:
  containers:
  - name: app
    resources:
      requests:
        cpu: "200m"    # Minimum guarantee
```
This pod:
- Is guaranteed at least 200m CPU
- Can use more CPU if available
- Will be scheduled on a node with at least 200m CPU free

### 🔒 ResourceQuota (Namespace Level)
ResourceQuota controls the total resource allocation within a namespace.

**Key Points:**
- Limits the sum of all pod requests in the namespace
- Affects pod scheduling, not runtime behavior
- Prevents overcommitting resources at namespace level

**Example:**
```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: compute-quota
spec:
  hard:
    requests.cpu: "1"    # Total CPU requests allowed
```

### 📊 How They Work Together

Consider a namespace with 1 CPU quota:

1. **Pod Scheduling:**
   - Can schedule 5 pods requesting 200m CPU each (5 × 200m = 1 CPU)
   - Cannot schedule a 6th pod (6 × 200m > 1 CPU quota)

2. **Runtime Behavior:**
   - Each pod can use more than its 200m request
   - Total CPU usage might exceed 1 CPU
   - But total requests must stay within quota

### 🎬 Real-world Scenario
```plaintext
Namespace Quota: 1 CPU

Pod A (request: 400m) ✅ Scheduled (400m/1000m used)
Pod B (request: 400m) ✅ Scheduled (800m/1000m used)
Pod C (request: 400m) ❌ Blocked (would exceed quota)

Runtime:
- Pod A might use 600m CPU
- Pod B might use 700m CPU
- Total usage: 1.3 CPU (allowed, despite quota)
```

The key distinction is that ResourceQuota controls scheduling decisions, while actual resource usage at runtime is controlled by limits (if set) or node capacity. 

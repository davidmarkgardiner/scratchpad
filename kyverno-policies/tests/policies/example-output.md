kyverno test . -f all-tests.yaml

WARNING: test file (all-tests.yaml) uses a deprecated schema that will be removed in 1.14
Loading test  ( all-tests.yaml ) ...
  Loading values/variables ...
  Loading policies ...
  Loading resources ...
  Loading exceptions ...
  Applying 5 policies to 10 resources ...

policy mutate-cluster-namespace-istiolabel applied to default/Deployment/test-deployment-fail:
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-deployment-fail
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - image: nginx:latest
        name: nginx
        resources:
          requests:
            cpu: 250m
            memory: 256Mi

---


Mutation:
Mutation has been applied successfully.
policy mutate-ns-deployment-spotaffinity applied to default/Deployment/test-deployment-fail:
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-deployment-fail
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - image: nginx:latest
        name: nginx
        resources:
          requests:
            cpu: 250m
            memory: 256Mi

---


Mutation:
Mutation has been applied successfully.
policy mutate-cluster-namespace-istiolabel applied to spot-namespace/Deployment/test-deployment-1:
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: nginx
  name: test-deployment-1
  namespace: spot-namespace
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - image: nginx:latest
        name: nginx

---


Mutation:
Mutation has been applied successfully.
policy mutate-ns-deployment-spotaffinity applied to spot-namespace/Deployment/test-deployment-1:
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: nginx
  name: test-deployment-1
  namespace: spot-namespace
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      affinity:
        nodeAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - preference:
              matchExpressions:
              - key: kubernetes.azure.com/scalesetpriority
                operator: In
                values:
                - spot
            weight: 100
          - preference:
              matchExpressions:
              - key: worker
                operator: In
                values:
                - "true"
            weight: 1
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: app
                  operator: In
                  values:
                  - nginx
              topologyKey: kubernetes.io/hostname
            weight: 100
      containers:
      - image: nginx:latest
        name: nginx
      tolerations:
      - effect: NoSchedule
        key: kubernetes.azure.com/scalesetpriority
        operator: Equal
        value: spot

---


Mutation:
Mutation has been applied successfully.
policy mutate-cluster-namespace-istiolabel applied to default/Namespace/test-namespace-fail:
apiVersion: v1
kind: Namespace
metadata:
  labels:
    istio-injection: enabled
  name: test-namespace-fail
  namespace: default

---


Mutation:
Mutation has been applied successfully.
policy mutate-ns-deployment-spotaffinity applied to default/Namespace/test-namespace-fail:
apiVersion: v1
kind: Namespace
metadata:
  labels:
    istio-injection: enabled
  name: test-namespace-fail
  namespace: default

---


Mutation:
Mutation has been applied successfully.
policy mutate-cluster-namespace-istiolabel applied to default/Namespace/test-namespace-1:
apiVersion: v1
kind: Namespace
metadata:
  labels:
    istio.io/rev: asm-1-23
  name: test-namespace-1
  namespace: default

---


Mutation:
Mutation has been applied successfully.
policy mutate-ns-deployment-spotaffinity applied to default/Namespace/test-namespace-1:
apiVersion: v1
kind: Namespace
metadata:
  labels:
    istio.io/rev: asm-1-23
  name: test-namespace-1
  namespace: default

---


Mutation:
Mutation has been applied successfully.
policy mutate-cluster-namespace-istiolabel applied to default/Namespace/test-namespace-2:
apiVersion: v1
kind: Namespace
metadata:
  labels:
    istio.io/rev: asm-1-23
  name: test-namespace-2
  namespace: default

---


Mutation:
Mutation has been applied successfully.
policy mutate-ns-deployment-spotaffinity applied to default/Namespace/test-namespace-2:
apiVersion: v1
kind: Namespace
metadata:
  labels:
    istio.io/rev: asm-1-23
  name: test-namespace-2
  namespace: default

---


Mutation:
Mutation has been applied successfully.
policy mutate-cluster-namespace-istiolabel applied to non-spot-namespace/Deployment/test-deployment-2:
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: nginx
  name: test-deployment-2
  namespace: non-spot-namespace
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - image: nginx:latest
        name: nginx

---


Mutation:
Mutation has been applied successfully.
policy mutate-ns-deployment-spotaffinity applied to non-spot-namespace/Deployment/test-deployment-2:
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: nginx
  name: test-deployment-2
  namespace: non-spot-namespace
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - image: nginx:latest
        name: nginx

---


Mutation:
Mutation has been applied successfully.
policy mutate-cluster-namespace-istiolabel applied to istio-system/PeerAuthentication/test-peer-auth-pass:
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: test-peer-auth-pass
  namespace: istio-system
spec:
  mtls:
    mode: STRICT

---


Mutation:
Mutation has been applied successfully.
policy mutate-ns-deployment-spotaffinity applied to istio-system/PeerAuthentication/test-peer-auth-pass:
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: test-peer-auth-pass
  namespace: istio-system
spec:
  mtls:
    mode: STRICT

---


Mutation:
Mutation has been applied successfully.
policy mutate-cluster-namespace-istiolabel applied to istio-system/PeerAuthentication/test-peer-auth-fail:
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  annotations:
    policies.kyverno.io/scored: "false"
  name: test-peer-auth-fail
  namespace: istio-system
spec:
  mtls:
    mode: PERMISSIVE

---


Mutation:
Mutation has been applied successfully.
policy mutate-ns-deployment-spotaffinity applied to istio-system/PeerAuthentication/test-peer-auth-fail:
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  annotations:
    policies.kyverno.io/scored: "false"
  name: test-peer-auth-fail
  namespace: istio-system
spec:
  mtls:
    mode: PERMISSIVE

---


Mutation:
Mutation has been applied successfully.
policy mutate-cluster-namespace-istiolabel applied to default/Deployment/test-deployment-pass:
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-deployment-pass
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - image: nginx:latest
        name: nginx
        resources:
          limits:
            cpu: 500m
            memory: 512Mi
          requests:
            cpu: 250m
            memory: 256Mi

---


Mutation:
Mutation has been applied successfully.
policy mutate-ns-deployment-spotaffinity applied to default/Deployment/test-deployment-pass:
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-deployment-pass
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - image: nginx:latest
        name: nginx
        resources:
          limits:
            cpu: 500m
            memory: 512Mi
          requests:
            cpu: 250m
            memory: 256Mi

---


Mutation:
Mutation has been applied successfully.
policy mutate-cluster-namespace-istiolabel applied to default/Namespace/test-namespace-pass:
apiVersion: v1
kind: Namespace
metadata:
  labels:
    istio-injection: disabled
  name: test-namespace-pass
  namespace: default

---


Mutation:
Mutation has been applied successfully.
policy mutate-ns-deployment-spotaffinity applied to default/Namespace/test-namespace-pass:
apiVersion: v1
kind: Namespace
metadata:
  labels:
    istio-injection: disabled
  name: test-namespace-pass
  namespace: default

---


Mutation:
Mutation has been applied successfully.  Checking results ...

│────│───────────────────────────────────────│─────────────────────────────│────────────────────────────────────────│────────│──────────│
│ ID │ POLICY                                │ RULE                        │ RESOURCE                               │ RESULT │ REASON   │
│────│───────────────────────────────────────│─────────────────────────────│────────────────────────────────────────│────────│──────────│
│ 1  │ require-resource-limits               │ check-resource-limits       │ Deployment/test-deployment-pass        │ Pass   │ Ok       │
│ 2  │ validate-ns-istio-injection           │ check-istio-injection-label │ Namespace/test-namespace-pass          │ Pass   │ Ok       │
│ 3  │ validate-ns-istio-injection           │ check-istio-injection-label │ Namespace/test-namespace-fail          │ Pass   │ Ok       │
│ 4  │ mutate-cluster-namespace-istiolabel   │ add-istio-revision-label    │ Namespace/test-namespace-1             │ Pass   │ Ok       │
│ 5  │ mutate-cluster-namespace-istiolabel   │ add-istio-revision-label    │ Namespace/test-namespace-2             │ Pass   │ Ok       │
│ 6  │ mutate-ns-deployment-spotaffinity     │ insert-pod-antiaffinity     │ Deployment/test-deployment-1           │ Pass   │ Ok       │
│ 7  │ mutate-ns-deployment-spotaffinity     │ insert-pod-antiaffinity     │ Deployment/test-deployment-2           │ Pass   │ Excluded │
│ 8  │ audit-cluster-peerauthentication-mtls │ validate-mtls               │ PeerAuthentication/test-peer-auth-pass │ Pass   │ Ok       │
│ 9  │ audit-cluster-peerauthentication-mtls │ validate-mtls               │ PeerAuthentication/test-peer-auth-fail │ Pass   │ Ok       │
│────│───────────────────────────────────────│─────────────────────────────│────────────────────────────────────────│────────│──────────│


Test Summary: 9 tests passed and 0 tests failed

(base) 
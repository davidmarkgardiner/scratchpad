I'll help you set up a test cluster using Kind (Kubernetes in Docker). Let's create a cluster with multiple nodes and some common configurations.

1. First, make sure Kind is installed:
```bash
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind
```

2. Create a Kind configuration file (`kind-config.yaml`):
```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
- role: worker
- role: worker
networking:
  podSubnet: "192.168.0.0/16"
  serviceSubnet: "10.96.0.0/12"
```

3. Create the cluster:
```bash
kind create cluster --name test-cluster --config kind-config.yaml
```

4. Install essential components:

Install Metallb for load balancing:
```bash
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.7/config/manifests/metallb-native.yaml

# Wait for metallb to be ready
kubectl wait --namespace metallb-system \
                --for=condition=ready pod \
                --selector=app=metallb \
                --timeout=90s

# Configure MetalLB
cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: default
  namespace: metallb-system
spec:
  addresses:
  - 172.18.255.200-172.18.255.250
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: empty
  namespace: metallb-system
EOF
```

5. Install Nginx Ingress Controller:
```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/static/provider/kind/deploy.yaml
```

6. Verify the cluster:
```bash
# Check nodes
kubectl get nodes

# Check pods in all namespaces
kubectl get pods -A

# Check the ingress controller
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=90s
```

7. Test the cluster with a sample application:
```bash
# Create a test deployment
kubectl create deployment nginx --image=nginx

# Expose it
kubectl expose deployment nginx --port=80

# Create an ingress
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: nginx
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: nginx
            port:
              number: 80
EOF
```

8. Optional: Add metrics-server:
```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Patch metrics-server to work with Kind
kubectl patch deployment metrics-server -n kube-system --patch '{"spec":{"template":{"spec":{"containers":[{"name":"metrics-server","args":["--cert-dir=/tmp","--secure-port=4443","--kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname","--kubelet-use-node-status-port","--metric-resolution=15s","--kubelet-insecure-tls"]}]}}}}'
```

Useful commands for managing your Kind cluster:
```bash
# List clusters
kind get clusters

# Delete cluster
kind delete cluster --name test-cluster

# Load local Docker image into Kind
kind load docker-image my-image:tag --name test-cluster

# Export logs
kind export logs --name test-cluster ./logs
```

To clean up:
```bash
kind delete cluster --name test-cluster
```

Would you like me to explain any part in more detail or help you set up any specific workloads on the cluster?

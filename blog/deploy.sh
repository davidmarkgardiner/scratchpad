#!/bin/bash

# AKS Platform Demo Deployment Script
# This script deploys the demo to your shared AKS platform with Istio

set -e

# Configuration
NAMESPACE="${NAMESPACE:-your-namespace}"
DOMAIN="${DOMAIN:-demo.your-domain.com}"
TLS_SECRET="${TLS_SECRET:-demo-tls-secret}"

echo "🚀 Deploying AKS Platform Demo to ${NAMESPACE}"
echo "🌐 Domain: ${DOMAIN}"

# Check if namespace exists, create if not
echo "📋 Checking namespace..."
if ! kubectl get namespace ${NAMESPACE} > /dev/null 2>&1; then
    echo "Creating namespace ${NAMESPACE}..."
    kubectl create namespace ${NAMESPACE}
    
    # Enable Istio sidecar injection
    kubectl label namespace ${NAMESPACE} istio-injection=enabled
else
    echo "Namespace ${NAMESPACE} already exists"
fi

# Replace placeholders in manifests
echo "📝 Preparing manifests..."
sed -i.bak "s/your-namespace/${NAMESPACE}/g" k8s-manifests.yaml
sed -i.bak "s/demo.your-domain.com/${DOMAIN}/g" k8s-manifests.yaml
sed -i.bak "s/demo-tls-secret/${TLS_SECRET}/g" k8s-manifests.yaml

# Apply manifests
echo "🛠️ Applying Kubernetes manifests..."
kubectl apply -f k8s-manifests.yaml

# Wait for deployment
echo "⏳ Waiting for deployment to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/aks-platform-demo -n ${NAMESPACE}

# Check Istio sidecar injection
echo "🔍 Checking Istio sidecar injection..."
kubectl get pods -n ${NAMESPACE} -l app=aks-platform-demo

# Get service information
echo "📊 Service Information:"
kubectl get service aks-platform-demo-service -n ${NAMESPACE}

# Get Istio gateway status
echo "🌐 Istio Gateway Status:"
kubectl get gateway aks-platform-demo-gateway -n ${NAMESPACE}

# Get VirtualService status
echo "🔀 VirtualService Status:"
kubectl get virtualservice aks-platform-demo-vs -n ${NAMESPACE}

echo ""
echo "✅ Deployment Complete!"
echo ""
echo "🔗 Access your demo at: https://${DOMAIN}"
echo "📊 Monitor with: kubectl get pods -n ${NAMESPACE} -w"
echo "📜 Logs: kubectl logs -f deployment/aks-platform-demo -n ${NAMESPACE}"
echo ""
echo "🔍 To troubleshoot Istio:"
echo "   kubectl describe virtualservice aks-platform-demo-vs -n ${NAMESPACE}"
echo "   kubectl describe gateway aks-platform-demo-gateway -n ${NAMESPACE}"
echo ""
echo "🚀 Your demo is now running on the shared AKS platform with Istio!"

# Optional: Show some platform features in action
echo ""
echo "🎯 Platform Features Demonstrated:"
echo "   ✅ mTLS automatically enabled (check DestinationRule)"
echo "   ✅ Horizontal Pod Autoscaling configured"
echo "   ✅ Network policies applied (Cilium)"
echo "   ✅ Security context enforced (non-root, read-only filesystem)"
echo "   ✅ Resource limits set"
echo "   ✅ Istio service mesh integration"
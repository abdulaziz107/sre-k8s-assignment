#!/bin/bash

# Minikube-specific deployment script for SRE Assignment
set -e

echo "🚀 Starting SRE Assignment deployment on Minikube..."

# Check if minikube is running
if ! minikube status >/dev/null 2>&1; then
    echo "❌ Minikube is not running. Please start minikube first:"
    echo "minikube start"
    exit 1
fi

echo "✅ Minikube is running"

# Check if registry is accessible
if ! curl -s http://127.0.0.1:5000/v2/_catalog > /dev/null; then
    echo "❌ Registry not accessible at http://127.0.0.1:5000"
    echo "Please ensure your registry is running"
    exit 1
fi

echo "✅ Registry is accessible"

# Build and push images
echo "🔨 Building and pushing images..."
./scripts/build-and-push.sh

# Deploy to minikube
echo "📦 Deploying to minikube..."

# Create namespaces
kubectl apply -f k8s/namespaces/

# Deploy infrastructure
kubectl apply -f k8s/infrastructure/

# Wait for infrastructure to be ready
echo "⏳ Waiting for infrastructure to be ready..."
kubectl wait --for=condition=ready pod -l app=postgresql -n infrastructure --timeout=300s
kubectl wait --for=condition=ready pod -l app=minio -n infrastructure --timeout=300s

# Deploy secrets
kubectl apply -f k8s/secrets/

# Deploy network policies
kubectl apply -f k8s/network-policies/

# Deploy services
kubectl apply -f k8s/deployments/
kubectl apply -f k8s/services/

# Deploy autoscaling
kubectl apply -f k8s/autoscaling/

# Wait for services to be ready
echo "⏳ Waiting for services to be ready..."
kubectl wait --for=condition=ready pod -l app=auth-service -n auth --timeout=300s
kubectl wait --for=condition=ready pod -l app=api-service -n api --timeout=300s
kubectl wait --for=condition=ready pod -l app=image-storage-service -n image-storage --timeout=300s

echo "🎉 Deployment completed successfully!"
echo ""
echo "📊 Check deployment status:"
echo "kubectl get pods -A"
echo ""
echo "🌐 Access services:"
echo "kubectl port-forward svc/api-service 8080:80 -n api"
echo "kubectl port-forward svc/auth-service 3001:80 -n auth"
echo "kubectl port-forward svc/image-storage-service 3003:80 -n image-storage"
echo ""
echo "📈 Access monitoring (after installing):"
echo "kubectl port-forward svc/grafana 3000:80 -n monitoring"
echo "kubectl port-forward svc/prometheus 9090:9090 -n monitoring" 
#!/bin/bash

# Deployment script for SRE Assignment
set -e

echo "🚀 Starting SRE Assignment deployment..."

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl is not installed. Please install kubectl first."
    exit 1
fi

# Check if cluster is accessible
if ! kubectl cluster-info &> /dev/null; then
    echo "❌ Cannot connect to Kubernetes cluster. Please check your configuration."
    exit 1
fi

echo "📋 Deploying namespaces..."
kubectl apply -f k8s/namespaces/

echo "📦 Deploying infrastructure..."
kubectl apply -f k8s/infrastructure/

echo "🔐 Deploying secrets..."
kubectl apply -f k8s/secrets/

echo "🌐 Deploying network policies..."
kubectl apply -f k8s/network-policies/

echo "📦 Deploying services..."
kubectl apply -f k8s/deployments/
kubectl apply -f k8s/services/

echo "🔗 Deploying ingress..."
kubectl apply -f k8s/ingress/

echo "⚡ Deploying autoscaling..."
kubectl apply -f k8s/autoscaling/

echo "📊 Deploying monitoring..."
kubectl apply -f k8s/monitoring/
echo "🔔 Deploying Alertmanager configuration..."
kubectl apply -f k8s/monitoring/alertmanager-config.yaml

echo "⏳ Waiting for all pods to be ready..."
kubectl wait --for=condition=ready pod -l app=auth-service -n auth --timeout=300s
kubectl wait --for=condition=ready pod -l app=api-service -n api --timeout=300s
kubectl wait --for=condition=ready pod -l app=image-storage-service -n image-storage --timeout=300s
kubectl wait --for=condition=ready pod -l app=postgresql -n infrastructure --timeout=300s
kubectl wait --for=condition=ready pod -l app=minio -n infrastructure --timeout=300s

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
echo "📈 Access monitoring:"
echo "kubectl port-forward svc/grafana 3000:80 -n monitoring"
echo "kubectl port-forward svc/prometheus 9090:9090 -n monitoring" 
#!/bin/bash

# Ensure minikube is in PATH for PowerShell users
if [[ "$OS" == "Windows_NT" ]]; then
  export PATH="$PATH:/c/minikube"
fi

# Monitoring setup script for Minikube
set -e

echo "📊 Setting up monitoring stack on Minikube..."

# Check if minikube is running
if ! minikube status >/dev/null 2>&1; then
    echo "❌ Minikube is not running. Please start minikube first:"
    echo "minikube start"
    exit 1
fi

# Check if Helm is installed
if ! command -v helm &> /dev/null; then
    echo "❌ Helm is not installed. Please install Helm first."
    exit 1
fi

# Add Prometheus Helm repository
echo "📦 Adding Prometheus Helm repository..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Deploy monitoring stack
echo "🚀 Deploying monitoring stack..."
helm install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --set grafana.enabled=true \
  --set prometheus.enabled=true \
  --set alertmanager.enabled=true \
  --set prometheus.prometheusSpec.retention=1d \
  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage=1Gi

echo "⏳ Waiting for monitoring stack to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=grafana -n monitoring --timeout=300s
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=prometheus -n monitoring --timeout=300s

echo "✅ Monitoring stack deployed successfully!"
echo ""
echo "📈 Access monitoring:"
echo "Grafana: kubectl port-forward svc/monitoring-grafana 3000:80 -n monitoring"
echo "Prometheus: kubectl port-forward svc/monitoring-kube-prometheus-prometheus 9090:9090 -n monitoring"
echo ""
echo "🔐 Grafana credentials:"
echo "Username: admin"
echo "Password: prom-operator"
echo ""
echo "📊 To view all monitoring resources:"
echo "kubectl get pods -n monitoring" 
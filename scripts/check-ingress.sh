#!/bin/bash

echo "🔍 Checking Ingress Resources..."
echo "=================================="

# Check all namespaces for ingress resources
echo "📋 All Ingress Resources:"
kubectl get ingress -A

echo ""
echo "🔍 Detailed Ingress Information:"
echo "=================================="

# Check each namespace specifically
for namespace in api auth image-storage; do
    echo ""
    echo "📁 Namespace: $namespace"
    echo "----------------------------------"
    kubectl get ingress -n $namespace 2>/dev/null || echo "No ingress resources found in $namespace"
done

echo ""
echo "🌐 Ingress Controller Status:"
echo "=============================="
kubectl get pods -n ingress-nginx

echo ""
echo "🔗 Services Available:"
echo "======================"
kubectl get services -A | grep -E "(auth-service|api-service|image-storage-service)"

echo ""
echo "📊 Ingress Details:"
echo "==================="
for namespace in api auth image-storage; do
    echo ""
    echo "🔍 Ingress in $namespace namespace:"
    kubectl describe ingress -n $namespace 2>/dev/null | grep -E "(Name:|Host:|Backends:|Address:)" || echo "No ingress found in $namespace"
done 
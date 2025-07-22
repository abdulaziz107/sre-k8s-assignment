#!/bin/bash

# Failure simulation script for SRE Assignment
set -e

echo "🧪 Starting failure simulation scenarios..."

# Function to wait and check recovery
wait_and_check() {
    local service=$1
    local namespace=$2
    echo "⏳ Waiting for $service to recover..."
    sleep 30
    kubectl get pods -n $namespace -l app=$service
    echo "✅ $service recovery check completed"
}

# Function to check service health
check_service_health() {
    local service=$1
    local namespace=$2
    local port=$3
    
    echo "🏥 Checking $service health..."
    kubectl port-forward svc/$service $port:80 -n $namespace &
    PF_PID=$!
    sleep 5
    
    if curl -s http://localhost:$port/health > /dev/null; then
        echo "✅ $service is healthy"
    else
        echo "❌ $service is not responding"
    fi
    
    kill $PF_PID 2>/dev/null || true
}

echo "📊 Current cluster state:"
kubectl get pods -A

echo ""
echo "🔥 Scenario 1: Database Crash Simulation"
echo "Deleting PostgreSQL pod..."
kubectl delete pod -l app=postgresql -n infrastructure --force --grace-period=0
wait_and_check "postgresql" "infrastructure"
check_service_health "auth-service" "auth" "3001"

echo ""
echo "🔥 Scenario 2: Auth Service Crash Simulation"
echo "Deleting auth-service pods..."
kubectl delete pod -l app=auth-service -n auth --force --grace-period=0
wait_and_check "auth-service" "auth"
check_service_health "auth-service" "auth" "3001"

echo ""
echo "🔥 Scenario 3: High Traffic Simulation on Image Service"
echo "Scaling up image-storage-service to handle load..."
kubectl scale deployment image-storage-service -n image-storage --replicas=5
sleep 10
kubectl get pods -n image-storage -l app=image-storage-service

echo ""
echo "🔥 Scenario 4: Node Failure Simulation"
echo "Cordoning a node to simulate failure..."
NODE=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
echo "Cordoning node: $NODE"
kubectl cordon $NODE
echo "Draining node: $NODE"
kubectl drain $NODE --ignore-daemonsets --delete-emptydir-data --force
sleep 30
echo "Uncordoning node: $NODE"
kubectl uncordon $NODE

echo ""
echo "🔥 Scenario 5: Resource Exhaustion Simulation"
echo "Simulating high CPU usage on API service..."
kubectl exec -n api deployment/api-service -- sh -c "while true; do : ; done" &
STRESS_PID=$!
sleep 30
kill $STRESS_PID 2>/dev/null || true

echo ""
echo "📊 Final cluster state:"
kubectl get pods -A

echo ""
echo "📈 Checking HPA status:"
kubectl get hpa -A

echo ""
echo "🔍 Checking events:"
kubectl get events --sort-by='.lastTimestamp' | tail -20

echo ""
echo "✅ Failure simulation completed!"
echo "📋 Key observations:"
echo "- Pods should have been rescheduled automatically"
echo "- Services should remain available during failures"
echo "- HPA should have scaled services based on load"
echo "- Network policies should have maintained security" 
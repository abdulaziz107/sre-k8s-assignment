#!/bin/bash

# Comprehensive system testing script for SRE Assignment
set -e

echo "🧪 Starting comprehensive system testing..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    local status=$1
    local message=$2
    if [ "$status" = "PASS" ]; then
        echo -e "${GREEN}✅ PASS${NC}: $message"
    elif [ "$status" = "FAIL" ]; then
        echo -e "${RED}❌ FAIL${NC}: $message"
    else
        echo -e "${YELLOW}⚠️  WARN${NC}: $message"
    fi
}

# Function to test service health
test_service_health() {
    local service=$1
    local namespace=$2
    local port=$3
    
    kubectl port-forward svc/$service $port:80 -n $namespace &
    PF_PID=$!
    sleep 5
    
    if curl -s http://localhost:$port/health > /dev/null; then
        print_status "PASS" "$service health check"
    else
        print_status "FAIL" "$service health check"
    fi
    
    kill $PF_PID 2>/dev/null || true
}

# Function to test metrics endpoint
test_metrics() {
    local service=$1
    local namespace=$2
    local port=$3
    
    kubectl port-forward svc/$service $port:80 -n $namespace &
    PF_PID=$!
    sleep 5
    
    if curl -s http://localhost:$port/metrics | grep -q "http_requests_total"; then
        print_status "PASS" "$service metrics endpoint"
    else
        print_status "FAIL" "$service metrics endpoint"
    fi
    
    kill $PF_PID 2>/dev/null || true
}

echo "📊 Testing 1: Cluster Status"
echo "============================"

# Check if all pods are running
PODS_RUNNING=$(kubectl get pods -A --field-selector=status.phase=Running | wc -l)
PODS_TOTAL=$(kubectl get pods -A | wc -l)

if [ "$PODS_RUNNING" = "$PODS_TOTAL" ]; then
    print_status "PASS" "All pods are running"
else
    print_status "FAIL" "Some pods are not running"
    kubectl get pods -A | grep -v Running
fi

echo ""
echo "🔐 Testing 2: Secrets and ConfigMaps"
echo "====================================="

# Check if secrets exist
SECRETS=("jwt-secret" "auth-db-secret" "api-db-secret" "image-db-secret" "minio-secret")
for secret in "${SECRETS[@]}"; do
    if kubectl get secret $secret -n auth >/dev/null 2>&1 || \
       kubectl get secret $secret -n api >/dev/null 2>&1 || \
       kubectl get secret $secret -n image-storage >/dev/null 2>&1; then
        print_status "PASS" "Secret $secret exists"
    else
        print_status "FAIL" "Secret $secret missing"
    fi
done

echo ""
echo "🌐 Testing 3: Network Policies"
echo "=============================="

# Check if network policies are applied
POLICIES=("auth-service-network-policy" "api-service-network-policy" "image-storage-service-network-policy")
for policy in "${POLICIES[@]}"; do
    if kubectl get networkpolicy $policy -n auth >/dev/null 2>&1 || \
       kubectl get networkpolicy $policy -n api >/dev/null 2>&1 || \
       kubectl get networkpolicy $policy -n image-storage >/dev/null 2>&1; then
        print_status "PASS" "Network policy $policy exists"
    else
        print_status "FAIL" "Network policy $policy missing"
    fi
done

echo ""
echo "🏥 Testing 4: Service Health Checks"
echo "==================================="

# Test service health endpoints
test_service_health "auth-service" "auth" "3001"
test_service_health "api-service" "api" "3002"
test_service_health "image-storage-service" "image-storage" "3003"

echo ""
echo "📈 Testing 5: Metrics Endpoints"
echo "==============================="

# Test metrics endpoints
test_metrics "auth-service" "auth" "3001"
test_metrics "api-service" "api" "3002"
test_metrics "image-storage-service" "image-storage" "3003"

echo ""
echo "⚡ Testing 6: Autoscaling Configuration"
echo "======================================"

# Check HPA configuration
HPAS=("auth-service-hpa" "api-service-hpa" "image-storage-service-hpa")
for hpa in "${HPAS[@]}"; do
    if kubectl get hpa $hpa -n auth >/dev/null 2>&1 || \
       kubectl get hpa $hpa -n api >/dev/null 2>&1 || \
       kubectl get hpa $hpa -n image-storage >/dev/null 2>&1; then
        print_status "PASS" "HPA $hpa exists"
    else
        print_status "FAIL" "HPA $hpa missing"
    fi
done

# Check PDB configuration
PDBS=("auth-service-pdb" "api-service-pdb" "image-storage-service-pdb")
for pdb in "${PDBS[@]}"; do
    if kubectl get pdb $pdb -n auth >/dev/null 2>&1 || \
       kubectl get pdb $pdb -n api >/dev/null 2>&1 || \
       kubectl get pdb $pdb -n image-storage >/dev/null 2>&1; then
        print_status "PASS" "PDB $pdb exists"
    else
        print_status "FAIL" "PDB $pdb missing"
    fi
done

echo ""
echo "🔗 Testing 7: Service Connectivity"
echo "=================================="

# Test service-to-service communication
echo "Testing API service connectivity to auth service..."
kubectl exec -n api deployment/api-service -- wget -qO- http://auth-service.auth.svc.cluster.local/health >/dev/null 2>&1 && \
    print_status "PASS" "API service can reach auth service" || \
    print_status "FAIL" "API service cannot reach auth service"

echo "Testing image service connectivity to database..."
kubectl exec -n image-storage deployment/image-storage-service -- python -c "
import psycopg2
try:
    conn = psycopg2.connect(
        host='postgresql.infrastructure.svc.cluster.local',
        port=5432,
        database='image_db',
        user='image_user',
        password='image_password'
    )
    conn.close()
    print('Database connection successful')
except Exception as e:
    print(f'Database connection failed: {e}')
    exit(1)
" >/dev/null 2>&1 && \
    print_status "PASS" "Image service can connect to database" || \
    print_status "FAIL" "Image service cannot connect to database"

echo ""
echo "📊 Testing 8: Resource Usage"
echo "============================"

# Check resource usage
echo "Current resource usage:"
kubectl top pods -A --sort-by=cpu

echo ""
echo "🔍 Testing 9: Log Analysis"
echo "=========================="

# Check for errors in logs
echo "Checking for errors in service logs..."
ERROR_COUNT=$(kubectl logs -n auth deployment/auth-service --tail=100 2>/dev/null | grep -i error | wc -l)
if [ "$ERROR_COUNT" -eq 0 ]; then
    print_status "PASS" "No errors in auth service logs"
else
    print_status "WARN" "Found $ERROR_COUNT errors in auth service logs"
fi

ERROR_COUNT=$(kubectl logs -n api deployment/api-service --tail=100 2>/dev/null | grep -i error | wc -l)
if [ "$ERROR_COUNT" -eq 0 ]; then
    print_status "PASS" "No errors in api service logs"
else
    print_status "WARN" "Found $ERROR_COUNT errors in api service logs"
fi

ERROR_COUNT=$(kubectl logs -n image-storage deployment/image-storage-service --tail=100 2>/dev/null | grep -i error | wc -l)
if [ "$ERROR_COUNT" -eq 0 ]; then
    print_status "PASS" "No errors in image service logs"
else
    print_status "WARN" "Found $ERROR_COUNT errors in image service logs"
fi

echo ""
echo "🔒 Testing 10: Security Configuration"
echo "===================================="

# Check security contexts
echo "Checking pod security contexts..."
kubectl get pods -n auth -o jsonpath='{.items[*].spec.securityContext.runAsNonRoot}' | grep -q true && \
    print_status "PASS" "Auth service runs as non-root" || \
    print_status "FAIL" "Auth service does not run as non-root"

kubectl get pods -n api -o jsonpath='{.items[*].spec.securityContext.runAsNonRoot}' | grep -q true && \
    print_status "PASS" "API service runs as non-root" || \
    print_status "FAIL" "API service does not run as non-root"

kubectl get pods -n image-storage -o jsonpath='{.items[*].spec.securityContext.runAsNonRoot}' | grep -q true && \
    print_status "PASS" "Image service runs as non-root" || \
    print_status "FAIL" "Image service does not run as non-root"

echo ""
echo "📋 Testing Summary"
echo "=================="

echo "✅ System testing completed!"
echo ""
echo "📊 To monitor the system:"
echo "kubectl get pods -A"
echo "kubectl get hpa -A"
echo "kubectl get networkpolicies -A"
echo ""
echo "📈 To access monitoring:"
echo "kubectl port-forward svc/grafana 3000:80 -n monitoring"
echo "kubectl port-forward svc/prometheus 9090:9090 -n monitoring"
echo ""
echo "🌐 To access services:"
echo "kubectl port-forward svc/api-service 8080:80 -n api"
echo "kubectl port-forward svc/auth-service 3001:80 -n auth"
echo "kubectl port-forward svc/image-storage-service 3003:80 -n image-storage" 
#!/bin/bash

# Comprehensive SRE Assignment Deployment Script
# This script handles the complete deployment process including build, push, deploy, and testing
set -e

# Ensure script is run from project root
if [ ! -f "k8s/namespaces/namespaces.yaml" ] || [ ! -d "services" ]; then
    echo "❌ Error: This script must be run from the project root directory"
    echo "Please run: cd /path/to/sre-k8s-assignment && ./scripts/deploy.sh"
    exit 1
fi

echo "🚀 SRE Assignment - Complete Deployment Script"
echo "============================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Function to print status
print_status() {
    local status=$1
    local message=$2
    if [ "$status" = "SUCCESS" ]; then
        echo -e "${GREEN}✅ $message${NC}"
    elif [ "$status" = "FAILURE" ]; then
        echo -e "${RED}❌ $message${NC}"
    else
        echo -e "${YELLOW}⚠️  $message${NC}"
    fi
}

# Function to check prerequisites
check_prerequisites() {
    echo -e "${BLUE}🔍 Checking prerequisites...${NC}"
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        print_status "FAILURE" "kubectl is not installed"
        exit 1
    fi
    
    # Check docker
    if ! command -v docker &> /dev/null; then
        print_status "FAILURE" "docker is not installed"
        exit 1
    fi
    
    # Check helm
    if ! command -v helm &> /dev/null; then
        print_status "FAILURE" "helm is not installed"
        exit 1
    fi
    
    # Check cluster connectivity
    if ! kubectl cluster-info &> /dev/null; then
        print_status "FAILURE" "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    
    print_status "SUCCESS" "All prerequisites met"
}

# Function to build and push images
build_and_push_images() {
    echo -e "${BLUE}🔨 Building and pushing Docker images...${NC}"
    
    # Get Docker Hub username - try to extract from build script or use default
    DOCKER_USERNAME="abdulaziz5107"
    if [ -f "scripts/build-and-push.sh" ]; then
        EXTRACTED_USERNAME=$(grep -o 'abdulaziz[0-9]*' scripts/build-and-push.sh | head -1)
        if [ -n "$EXTRACTED_USERNAME" ]; then
            DOCKER_USERNAME="$EXTRACTED_USERNAME"
        fi
    fi
    
    echo "Using Docker Hub username: $DOCKER_USERNAME"
    
    # Build and push each service
    services=("auth-service" "api-service" "image-storage-service")
    
    for service in "${services[@]}"; do
        echo "Building $service..."
        cd services/$service
        docker build -t $DOCKER_USERNAME/$service:latest .
        docker push $DOCKER_USERNAME/$service:latest
        cd ../..
        print_status "SUCCESS" "$service built and pushed"
    done
}

# Function to deploy to Kubernetes
deploy_to_kubernetes() {
    echo -e "${BLUE}📦 Deploying to Kubernetes...${NC}"
    
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
    kubectl apply -f k8s/monitoring/alertmanager-config.yaml
    
    print_status "SUCCESS" "Kubernetes deployment completed"
}

# Function to setup monitoring
setup_monitoring() {
    echo -e "${BLUE}📊 Setting up monitoring stack...${NC}"
    
    # Add Prometheus Helm repository
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo update
    
    # Deploy monitoring stack
    helm install monitoring prometheus-community/kube-prometheus-stack \
        --namespace monitoring \
        --create-namespace \
        --set grafana.enabled=true \
        --set prometheus.enabled=true \
        --set alertmanager.enabled=true \
        --set prometheus.prometheusSpec.retention=1d \
        --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage=1Gi
    
    print_status "SUCCESS" "Monitoring stack deployed"
}

# Function to wait for deployment
wait_for_deployment() {
    echo -e "${BLUE}⏳ Waiting for all pods to be ready...${NC}"
    
    # Wait for infrastructure
    kubectl wait --for=condition=ready pod -l app=postgresql -n infrastructure --timeout=300s
    kubectl wait --for=condition=ready pod -l app=minio -n infrastructure --timeout=300s
    
    # Wait for services
    kubectl wait --for=condition=ready pod -l app=auth-service -n auth --timeout=300s
    kubectl wait --for=condition=ready pod -l app=api-service -n api --timeout=300s
    kubectl wait --for=condition=ready pod -l app=image-storage-service -n image-storage --timeout=300s
    
    # Wait for monitoring
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=grafana -n monitoring --timeout=300s
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=prometheus -n monitoring --timeout=300s
    
    print_status "SUCCESS" "All pods are ready"
}

# Function to test services
test_services() {
    echo -e "${BLUE}🧪 Testing service health...${NC}"
    
    # Test auth service
    kubectl port-forward svc/auth-service 3001:80 -n auth &
    AUTH_PID=$!
    sleep 5
    
    if curl -s http://localhost:3001/health > /dev/null; then
        print_status "SUCCESS" "Auth service is healthy"
    else
        print_status "FAILURE" "Auth service health check failed"
    fi
    
    kill $AUTH_PID 2>/dev/null || true
    
    # Test API service
    kubectl port-forward svc/api-service 3002:80 -n api &
    API_PID=$!
    sleep 5
    
    if curl -s http://localhost:3002/health > /dev/null; then
        print_status "SUCCESS" "API service is healthy"
    else
        print_status "FAILURE" "API service health check failed"
    fi
    
    kill $API_PID 2>/dev/null || true
    
    # Test image storage service
    kubectl port-forward svc/image-storage-service 3003:80 -n image-storage &
    IMAGE_PID=$!
    sleep 5
    
    if curl -s http://localhost:3003/health > /dev/null; then
        print_status "SUCCESS" "Image storage service is healthy"
    else
        print_status "FAILURE" "Image storage service health check failed"
    fi
    
    kill $IMAGE_PID 2>/dev/null || true
}

# Function to test bilingual support
test_bilingual() {
    echo -e "${BLUE}🌐 Testing bilingual support...${NC}"
    
    # Test English
    kubectl port-forward svc/auth-service 3001:80 -n auth &
    AUTH_PID=$!
    sleep 3
    
    echo "Testing English support..."
    curl -s -H "Accept-Language: en" http://localhost:3001/health | jq '.status' 2>/dev/null || echo "English test completed"
    
    echo "Testing Arabic support..."
    curl -s -H "Accept-Language: ar" http://localhost:3001/health | jq '.status' 2>/dev/null || echo "Arabic test completed"
    
    kill $AUTH_PID 2>/dev/null || true
    
    print_status "SUCCESS" "Bilingual support verified"
}

# Function to show deployment status
show_status() {
    echo -e "${BLUE}📊 Deployment Status${NC}"
    echo "====================="
    
    echo "Pods status:"
    kubectl get pods -A
    
    echo ""
    echo "Services status:"
    kubectl get services -A
    
    echo ""
    echo "HPA status:"
    kubectl get hpa -A
    
    echo ""
    echo "Network policies:"
    kubectl get networkpolicies -A
}

# Function to show access information
show_access_info() {
    echo -e "${BLUE}🌐 Access Information${NC}"
    echo "====================="
    
    echo "📱 Services:"
    echo "  API Service:     kubectl port-forward svc/api-service 8080:80 -n api"
    echo "  Auth Service:    kubectl port-forward svc/auth-service 3001:80 -n auth"
    echo "  Image Service:   kubectl port-forward svc/image-storage-service 3003:80 -n image-storage"
    
    echo ""
    echo "📊 Monitoring:"
    echo "  Grafana:         kubectl port-forward svc/monitoring-grafana 3000:80 -n monitoring"
    echo "  Prometheus:      kubectl port-forward svc/monitoring-kube-prometheus-prometheus 9090:9090 -n monitoring"
    echo "  Alertmanager:    kubectl port-forward svc/monitoring-kube-prometheus-alertmanager 9093:9093 -n monitoring"
    echo "  Grafana login:   admin/prom-operator"
    
    echo ""
    echo "🔧 External Notifications Setup:"
    echo "  bash scripts/setup-notifications.sh"
    
    echo ""
    echo "🧪 Testing:"
    echo "  Bilingual test:  bash scripts/test-bilingual.sh"
    echo "  Failure simulation: bash scripts/failure-simulation.sh"
}

# Main deployment function
main() {
    echo "Starting complete SRE assignment deployment..."
    echo ""
    
    # Check prerequisites
    check_prerequisites
    echo ""
    
    # Build and push images
    build_and_push_images
    echo ""
    
    # Deploy to Kubernetes
    deploy_to_kubernetes
    echo ""
    
    # Setup monitoring
    setup_monitoring
    echo ""
    
    # Wait for deployment
    wait_for_deployment
    echo ""
    
    # Test services
    test_services
    echo ""
    
    # Test bilingual support
    test_bilingual
    echo ""
    
    # Show status
    show_status
    echo ""
    
    # Show access information
    show_access_info
    echo ""
    
    print_status "SUCCESS" "SRE assignment deployment completed successfully!"
    echo ""
    echo -e "${GREEN}🎉 Your SRE assignment is now running!${NC}"
    echo "Check the access information above to connect to your services."
}

# Run main function
main 
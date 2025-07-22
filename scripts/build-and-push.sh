#!/bin/bash

# Build and push script for SRE Assignment
set -e

REGISTRY="127.0.0.1:5000"
SERVICES=("auth-service" "api-service" "image-storage-service")

echo "🚀 Starting build and push process..."

# Check if registry is running
REGISTRY_RESPONSE=$(curl -s http://127.0.0.1:5000/v2/_catalog 2>/dev/null || echo "ERROR")
if [[ "$REGISTRY_RESPONSE" == "ERROR" ]]; then
    echo "📦 Registry not accessible at http://127.0.0.1:5000"
    echo "Please ensure your registry is running and accessible"
    exit 1
fi

# Build and push each service
for service in "${SERVICES[@]}"; do
    echo "🔨 Building $service..."
    cd "services/$service"
    
    # Build the image
    docker build -t "$REGISTRY/$service:latest" .
    
    # Push to registry
    echo "📤 Pushing $service to registry..."
    docker push "$REGISTRY/$service:latest"
    
    cd ../..
    echo "✅ $service built and pushed successfully"
done

echo "🎉 All services built and pushed successfully!"
echo "📋 Available images:"
docker images | grep 127.0.0.1:5000 
#!/bin/bash

# Multi-Architecture Docker Build and Push Script
# Builds and pushes images for linux/amd64 and linux/arm64
set -e

# Ensure script is run from project root
if [ ! -f "k8s/namespaces/namespaces.yaml" ] || [ ! -d "services" ]; then
    echo "❌ Error: This script must be run from the project root directory"
    echo "Please run: cd /path/to/sre-k8s-assignment && ./scripts/build-multiarch.sh"
    exit 1
fi

echo "🐳 Multi-Architecture Docker Build and Push"
echo "=========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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
    
    # Check docker
    if ! command -v docker &> /dev/null; then
        print_status "FAILURE" "docker is not installed"
        exit 1
    fi
    
    # Check docker buildx
    if ! docker buildx version &> /dev/null; then
        print_status "FAILURE" "docker buildx is not available"
        exit 1
    fi
    
    # Check if logged in to Docker Hub
    if ! docker info | grep -q "Username"; then
        print_status "WARNING" "Not logged in to Docker Hub. Please run: docker login"
        echo "You can continue, but pushing will fail if not logged in."
    fi
    
    print_status "SUCCESS" "Prerequisites checked"
}

# Function to setup buildx
setup_buildx() {
    echo -e "${BLUE}🔧 Setting up Docker Buildx...${NC}"
    
    # Create and use a new builder instance
    docker buildx create --name multiarch-builder --use 2>/dev/null || true
    
    # Inspect the builder to ensure it's ready
    docker buildx inspect --bootstrap
    
    print_status "SUCCESS" "Buildx setup completed"
}

# Function to build and push multi-arch images
build_and_push_multiarch() {
    echo -e "${BLUE}🔨 Building and pushing multi-architecture images...${NC}"
    
    # Get Docker Hub username
    DOCKER_USERNAME="abdulaziz5107"
    if [ -f "scripts/build-and-push.sh" ]; then
        EXTRACTED_USERNAME=$(grep -o 'abdulaziz[0-9]*' scripts/build-and-push.sh | head -1)
        if [ -n "$EXTRACTED_USERNAME" ]; then
            DOCKER_USERNAME="$EXTRACTED_USERNAME"
        fi
    fi
    
    echo "Using Docker Hub username: $DOCKER_USERNAME"
    echo "Target architectures: linux/amd64, linux/arm64"
    echo ""
    
    # Build and push each service
    services=("auth-service" "api-service" "image-storage-service")
    
    for service in "${services[@]}"; do
        echo "Building $service for multiple architectures..."
        
        # Build and push multi-arch image
        docker buildx build \
            --platform linux/amd64,linux/arm64 \
            --tag $DOCKER_USERNAME/$service:latest \
            --tag $DOCKER_USERNAME/$service:multiarch \
            --file services/$service/Dockerfile \
            --push \
            services/$service/
        
        if [ $? -eq 0 ]; then
            print_status "SUCCESS" "$service multi-arch image built and pushed"
        else
            print_status "FAILURE" "$service build failed"
            exit 1
        fi
    done
}

# Function to verify images
verify_images() {
    echo -e "${BLUE}🔍 Verifying multi-architecture images...${NC}"
    
    DOCKER_USERNAME="abdulaziz5107"
    if [ -f "scripts/build-and-push.sh" ]; then
        EXTRACTED_USERNAME=$(grep -o 'abdulaziz[0-9]*' scripts/build-and-push.sh | head -1)
        if [ -n "$EXTRACTED_USERNAME" ]; then
            DOCKER_USERNAME="$EXTRACTED_USERNAME"
        fi
    fi
    
    services=("auth-service" "api-service" "image-storage-service")
    
    for service in "${services[@]}"; do
        echo "Verifying $service..."
        
        # Check if image exists and has multiple architectures
        if docker manifest inspect $DOCKER_USERNAME/$service:latest &> /dev/null; then
            echo "  ✅ Image exists in registry"
            
            # Show architecture information
            echo "  📋 Architecture details:"
            docker manifest inspect $DOCKER_USERNAME/$service:latest | \
                jq -r '.manifests[] | "    - " + .platform.architecture + "/" + .platform.os' 2>/dev/null || \
                echo "    (Unable to parse architecture info)"
        else
            print_status "FAILURE" "$service image not found in registry"
        fi
        echo ""
    done
}

# Function to show usage information
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --help              Show this help message"
    echo "  --verify-only       Only verify existing images (skip build)"
    echo "  --no-verify         Skip verification step"
    echo ""
    echo "Examples:"
    echo "  $0                  # Build and push all multi-arch images"
    echo "  $0 --verify-only    # Only verify existing images"
    echo "  $0 --no-verify      # Build and push without verification"
}

# Main function
main() {
    # Parse command line arguments
    VERIFY_ONLY=false
    SKIP_VERIFY=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --help)
                show_usage
                exit 0
                ;;
            --verify-only)
                VERIFY_ONLY=true
                shift
                ;;
            --no-verify)
                SKIP_VERIFY=true
                shift
                ;;
            *)
                echo "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    if [ "$VERIFY_ONLY" = true ]; then
        echo "🔍 Multi-Architecture Image Verification Only"
        echo "============================================"
        echo ""
        verify_images
        exit 0
    fi
    
    echo "🐳 Multi-Architecture Docker Build and Push"
    echo "=========================================="
    echo ""
    
    check_prerequisites
    setup_buildx
    build_and_push_multiarch
    
    if [ "$SKIP_VERIFY" = false ]; then
        verify_images
    fi
    
    print_status "SUCCESS" "Multi-architecture build and push completed!"
    echo ""
    echo "📋 Summary:"
    echo "  - Built images for: linux/amd64, linux/arm64"
    echo "  - Services: auth-service, api-service, image-storage-service"
    echo "  - Tags: latest, multiarch"
    echo ""
    echo "🔗 Images available at:"
    echo "  https://hub.docker.com/r/$DOCKER_USERNAME/"
}

# Run main function with all arguments
main "$@" 
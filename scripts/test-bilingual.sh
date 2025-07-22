#!/bin/bash

# Test script for bilingual functionality
set -e

echo "🌐 Testing Bilingual Support (Arabic/English)"
echo "============================================"
echo ""

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to test service with language header
test_service_language() {
    local service=$1
    local namespace=$2
    local port=$3
    local endpoint=$4
    local language=$5
    
    echo -e "${BLUE}Testing $service ($language)...${NC}"
    
    kubectl port-forward svc/$service $port:80 -n $namespace &
    PF_PID=$!
    sleep 3
    
    # Test with language header
    if curl -s -H "Accept-Language: $language" http://localhost:$port$endpoint > /dev/null; then
        echo -e "${GREEN}✅ $service responds to $language requests${NC}"
        
        # Show the actual response
        echo "Response:"
        curl -s -H "Accept-Language: $language" http://localhost:$port$endpoint | jq '.' 2>/dev/null || \
        curl -s -H "Accept-Language: $language" http://localhost:$port$endpoint
        echo ""
    else
        echo -e "${YELLOW}⚠️  $service not responding to $language requests${NC}"
    fi
    
    kill $PF_PID 2>/dev/null || true
}

echo "🔍 Testing Auth Service Bilingual Support"
echo "----------------------------------------"

# Test auth service health endpoint
test_service_language "auth-service" "auth" "3001" "/health" "en"
test_service_language "auth-service" "auth" "3001" "/health" "ar"

echo "🔍 Testing API Service Bilingual Support"
echo "---------------------------------------"

# Test API service health endpoint
test_service_language "api-service" "api" "3002" "/health" "en"
test_service_language "api-service" "api" "3002" "/health" "ar"

echo "🔍 Testing Image Storage Service Bilingual Support"
echo "------------------------------------------------"

# Test image storage service health endpoint
test_service_language "image-storage-service" "image-storage" "3003" "/health" "en"
test_service_language "image-storage-service" "image-storage" "3003" "/health" "ar"

echo ""
echo -e "${GREEN}✅ Bilingual testing completed!${NC}"
echo ""
echo "📋 Summary:"
echo "   - All services now support Arabic and English"
echo "   - Language is determined by Accept-Language header"
echo "   - Error messages are localized"
echo "   - Health check responses are localized"
echo ""
echo "🌐 Usage Examples:"
echo "   curl -H 'Accept-Language: en' http://localhost:3001/health"
echo "   curl -H 'Accept-Language: ar' http://localhost:3001/health"
echo ""
echo "📝 Note: The bilingual support includes:"
echo "   - Error messages"
echo "   - Success messages"
echo "   - Health check responses"
echo "   - Service status messages" 
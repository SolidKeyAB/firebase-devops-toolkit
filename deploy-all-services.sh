#!/bin/bash

# Deploy all ESG microservices to Firebase emulator
echo "🚀 Deploying all ESG microservices to Firebase emulator..."

# Set environment variables
export FIRESTORE_PROJECT_ID="your-project-id"

# Function to deploy a service
deploy_service() {
    local service_name=$1
    local port=$2
    
    echo "📦 Deploying $service_name on port $port..."
    
    cd "services/$service_name"
    
    # Install dependencies
    npm install
    
    # Create firebase.json for this service if it doesn't exist
    if [ ! -f "firebase.json" ]; then
        cat > firebase.json << EOF
{
  "functions": {
    "source": ".",
    "runtime": "nodejs18"
  },
  "emulators": {
    "functions": {
      "port": $port
    },
    "ui": {
      "enabled": false
    }
  }
}
EOF
    fi
    
    # Wait for service to be available (the emulator should already be running)
    sleep 3
    
    # Test health endpoint
    curl -s "http://localhost:$port/esg-$service_name/us-central1/health" > /dev/null
    if [ $? -eq 0 ]; then
        echo "✅ $service_name is available on port $port"
        return 0
    else
        echo "❌ $service_name is not available on port $port"
        return 1
    fi
    
    cd ../..
}

# Deploy all services
echo "🔄 Checking services in Firebase emulator..."

deploy_service "category-extraction-service" "5001"
deploy_service "product-extraction-service" "5002" 
deploy_service "embedding-service" "5003"
deploy_service "orchestrator-service" "5004"
deploy_service "product-data-enrichment-service" "5005"
deploy_service "ai-logging-service" "5007"
deploy_service "vector-search-service" "5008"

echo "🎉 Service deployment check completed!"
echo ""
echo "📊 Service Status:"
echo "  Category Extraction: http://localhost:5001"
echo "  Product Extraction:  http://localhost:5002"
echo "  Embedding Service:   http://localhost:5003"
echo "  Orchestrator:        http://localhost:5004"
echo "  Enrichment Service:  http://localhost:5005"
echo "  AI Logging Service:  http://localhost:5007"
echo "  Vector Search:       http://localhost:5008"
echo "  Firestore:           http://localhost:8080"
echo "  Firebase UI:         http://127.0.0.1:4000"
echo ""
echo "🔧 To stop all services: ./stop-all-services.sh" 
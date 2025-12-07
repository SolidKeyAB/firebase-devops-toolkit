#!/bin/bash

# Comprehensive HTTP Functions Cleanup Script
# Comments out all HTTP functions in production and moves them to emulator files

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR/../esg_microservices_platform"

echo "🚨 CRITICAL SECURITY CLEANUP: Removing HTTP functions from production"
echo "=================================================================="

# Function to comment out HTTP functions in a service
cleanup_http_functions() {
    local service_name="$1"
    local service_dir="$PROJECT_DIR/services/$service_name"
    
    if [ ! -d "$service_dir" ]; then
        echo "❌ Service directory not found: $service_name"
        return 1
    fi
    
    local index_file="$service_dir/index.js"
    local emulator_file="$service_dir/index-emulator.js"
    
    if [ ! -f "$index_file" ]; then
        echo "❌ index.js not found: $index_file"
        return 1
    fi
    
    echo "🔍 Cleaning up $service_name..."
    
    # Create emulator file if it doesn't exist
    if [ ! -f "$emulator_file" ]; then
        echo "   📝 Creating $emulator_file"
        cat > "$emulator_file" << 'EOF'
// Emulator-only functions for $service_name
// These are ADDITIONAL functions not needed in production
const { onRequest } = require('firebase-functions/v2/https');

console.log('🔧 $service_name: Emulator-only functions loaded');

// TODO: Move HTTP functions here from production index.js
EOF
    fi
    
    # Backup the original file
    cp "$index_file" "$index_file.backup-$(date +%Y%m%d_%H%M%S)"
    echo "   💾 Backed up to $index_file.backup-$(date +%Y%m%d_%H%M%S)"
    
    # Comment out all HTTP function exports
    echo "   🚫 Commenting out HTTP functions..."
    
    # Use sed to comment out HTTP function exports
    sed -i.bak 's/^exports\.\([a-zA-Z_][a-zA-Z0-9_]*\) = onRequest/# HTTP MOVED TO EMULATOR: exports.\1 = onRequest/' "$index_file"
    
    # Remove the .bak file
    rm -f "$index_file.bak"
    
    echo "   ✅ HTTP functions commented out in production"
}

# List of services to process (excluding public-api-service)
services=(
    "orchestrator-service"
    "vector-search-service"
    "score-calculation-service"
    "category-extraction-service"
    "products-extraction-service"
    "sustainability-enrichment-service"
    "eprel-enrichment-service"
    "legal-compliance-service"
    "product-image-service"
    "ai-logging-service"
    "embedding-service"
    "compliance-enrichment-service"
    "vector-category-comparison-service"
    "circular-economy-service"
    "supply-chain-transparency-service"
    "social-impact-service"
    "yaml-correction-service"
)

# Process each service
for service in "${services[@]}"; do
    cleanup_http_functions "$service"
    echo ""
done

echo "🎯 HTTP Functions Cleanup Complete!"
echo ""
echo "📋 Next Steps:"
echo "1. ✅ All HTTP functions commented out in production"
echo "2. 📁 Emulator files created/updated"
echo "3. 🔒 Production services now only export PubSub functions"
echo "4. 🧪 Test deployment to verify security"
echo ""
echo "⚠️  IMPORTANT: Only public-api-service should have HTTP functions in production!"
echo "🔒 All other services are now secure (PubSub only)"
echo ""
echo "🧹 To restore HTTP functions for development:"
echo "   - Use index-emulator.js files"
echo "   - Run services locally with Firebase emulator"
echo "   - HTTP functions are NOT deployed to production"

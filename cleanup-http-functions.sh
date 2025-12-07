#!/bin/bash

# Cleanup HTTP Functions Script
# Moves HTTP functions from production index.js to index-emulator.js for security

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR/../esg_microservices_platform"

echo "🧹 Cleaning up HTTP functions from production services..."
echo "=================================================="

# Function to backup and move HTTP functions
move_http_functions() {
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
    
    echo "🔍 Processing $service_name..."
    
    # Create emulator file if it doesn't exist
    if [ ! -f "$emulator_file" ]; then
        echo "   📝 Creating $emulator_file"
        cat > "$emulator_file" << 'EOF'
// Emulator-only functions for $service_name
// These are ADDITIONAL functions not needed in production
const { onRequest } = require('firebase-functions/v2/https');

console.log('🔧 $service_name: Emulator-only functions loaded');
EOF
    fi
    
    # Find HTTP functions in index.js
    local http_functions=$(grep -n "exports\.[a-zA-Z_][a-zA-Z0-9_]* = onRequest" "$index_file" | head -10)
    
    if [ -n "$http_functions" ]; then
        echo "   🚨 Found HTTP functions in production:"
        echo "$http_functions" | sed 's/^/      /'
        
        # Backup the original file
        cp "$index_file" "$index_file.backup-$(date +%Y%m%d_%H%M%S)"
        echo "   💾 Backed up to $index_file.backup-$(date +%Y%m%d_%H%M%S)"
        
        # TODO: Implement function extraction logic
        echo "   ⚠️  Manual cleanup required for $service_name"
    else
        echo "   ✅ No HTTP functions found in production"
    fi
}

# List of services to process
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
    move_http_functions "$service"
    echo ""
done

echo "🎯 Next steps:"
echo "1. Review each service's HTTP functions"
echo "2. Move them to index-emulator.js"
echo "3. Keep only PubSub functions in production index.js"
echo "4. Test deployment to ensure no HTTP functions remain"
echo ""
echo "⚠️  IMPORTANT: Only public-api-service should have HTTP functions in production!"

#!/bin/bash

# Fix Firebase Initialization Issues
# Updates all service files to use shared Firebase admin utility

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔧 Fixing Firebase initialization issues...${NC}"

# Navigate to services directory
cd ../../../services

# List of services that need Firebase admin fixes
SERVICES=(
    "ai-logging-service"
    "compliance-enrichment-service"
    "embedding-service"
    "eprel-enrichment-service"
    "fao-agricultural-enrichment-service"
    "oecd-sustainability-service"
    "orchestrator-service"
    "product-enrichment-service"
    "product-extraction-service"
    "product-image-service"
    "sustainability-enrichment-service"
    "vector-category-comparison-service"
    "vector-search-service"
)

# Function to fix a service file
fix_service_file() {
    local service_dir=$1
    local service_name=${service_dir%/}
    
    if [ -f "${service_dir}index.js" ]; then
        echo -e "${BLUE}📝 Fixing ${service_name}...${NC}"
        
        # Create backup
        cp "${service_dir}index.js" "${service_dir}index.js.backup"
        
        # Check if the service uses Firebase admin
        if grep -q "firebase-admin" "${service_dir}index.js"; then
            echo -e "${BLUE}🔍 Found Firebase admin usage in ${service_name}${NC}"
            
            # Replace Firebase admin initialization with shared utility
            sed -i.bak 's/const admin = require.*firebase-admin.*/const { getFirestore, getAuth } = require("..\/libs\/shared\/firebaseAdmin");/g' "${service_dir}index.js"
            sed -i.bak 's/admin\.initializeApp()/\/\/ Firebase admin initialized via shared utility/g' "${service_dir}index.js"
            sed -i.bak 's/admin\.firestore()/getFirestore()/g' "${service_dir}index.js"
            sed -i.bak 's/admin\.auth()/getAuth()/g' "${service_dir}index.js"
            
            echo -e "${GREEN}✅ Fixed ${service_name}${NC}"
        else
            echo -e "${YELLOW}⚠️  No Firebase admin usage found in ${service_name}${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️  No index.js found in ${service_name}${NC}"
    fi
}

# Fix each service
for service_dir in "${SERVICES[@]}"; do
    if [ -d "$service_dir" ]; then
        fix_service_file "$service_dir"
    else
        echo -e "${YELLOW}⚠️  Service directory $service_dir not found${NC}"
    fi
done

echo -e "${GREEN}✅ Firebase initialization fixes completed!${NC}"
echo -e "${BLUE}📋 Services updated:${NC}"
for service in "${SERVICES[@]}"; do
    if [ -d "$service" ]; then
        echo -e "${GREEN}✅ $service${NC}"
    fi
done 
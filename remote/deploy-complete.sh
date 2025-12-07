#!/bin/bash

# Complete Microservices Deployment Script
# Deploys all microservices with proper error handling and status reporting

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_ID="${PROJECT_ID:-your-firebase-project-id}"
REGION="${REGION:-us-central1}"
BASE_URL="https://${REGION}-${PROJECT_ID}.cloudfunctions.net"

# Check if we're in the correct directory
if [ ! -f "../../../firebase.json" ]; then
    echo -e "${RED}❌ Error: firebase.json not found. Please run this script from the remote directory.${NC}"
    exit 1
fi

echo -e "${BLUE}🚀 Starting Complete Microservices Deployment (project: $PROJECT_ID)${NC}"
echo -e "${BLUE}📋 Project: $PROJECT_ID${NC}"
echo -e "${BLUE}🌍 Region: $REGION${NC}"
echo -e "${BLUE}🔗 Base URL: $BASE_URL${NC}"
echo ""

# Function to check Firebase CLI and login
check_firebase_cli() {
    echo -e "${BLUE}🔍 Checking Firebase CLI...${NC}"
    if ! command -v firebase &> /dev/null; then
        echo -e "${RED}❌ Firebase CLI not found. Please install it first.${NC}"
        exit 1
    fi
    
    if ! firebase projects:list &> /dev/null; then
        echo -e "${YELLOW}⚠️  Firebase not logged in. Please run 'firebase login' first.${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Firebase CLI is ready${NC}"
}

# Function to set project
set_project() {
    echo -e "${BLUE}🎯 Setting Firebase project...${NC}"
    firebase use "$PROJECT_ID"
    echo -e "${GREEN}✅ Project set to $PROJECT_ID${NC}"
}

# Function to grant necessary permissions
grant_permissions() {
    echo -e "${BLUE}🔐 Granting build service account permissions...${NC}"
    PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format="value(projectNumber)")
    BUILD_SERVICE_ACCOUNT="${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com"
    COMPUTE_SERVICE_ACCOUNT="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"
    
    echo -e "${BLUE}📋 Granting permissions to: $BUILD_SERVICE_ACCOUNT${NC}"
    
    # Grant Cloud Build permissions
    gcloud projects add-iam-policy-binding $PROJECT_ID --member="serviceAccount:$BUILD_SERVICE_ACCOUNT" --role="roles/cloudfunctions.developer"
    gcloud projects add-iam-policy-binding $PROJECT_ID --member="serviceAccount:$BUILD_SERVICE_ACCOUNT" --role="roles/storage.objectViewer"
    gcloud projects add-iam-policy-binding $PROJECT_ID --member="serviceAccount:$BUILD_SERVICE_ACCOUNT" --role="roles/run.admin"
    gcloud projects add-iam-policy-binding $PROJECT_ID --member="serviceAccount:$BUILD_SERVICE_ACCOUNT" --role="roles/iam.serviceAccountUser"
    gcloud projects add-iam-policy-binding $PROJECT_ID --member="serviceAccount:$BUILD_SERVICE_ACCOUNT" --role="roles/cloudbuild.builds.builder"
    
    # Grant Compute Engine permissions
    gcloud projects add-iam-policy-binding $PROJECT_ID --member="serviceAccount:$COMPUTE_SERVICE_ACCOUNT" --role="roles/storage.objectViewer"
    
    echo -e "${GREEN}✅ Permissions granted successfully${NC}"
}

# Function to prepare services for deployment
prepare_services() {
    echo -e "${BLUE}🔧 Preparing services for deployment...${NC}"
    
    # Ensure all services use the shared Firebase admin
    cd ../../../services
    
    # Update all service files to use shared Firebase admin
    for service_dir in */; do
        if [ -d "$service_dir" ] && [ -f "${service_dir}index.js" ]; then
            echo -e "${BLUE}📝 Updating ${service_dir%/}...${NC}"
            
            # Check if the service uses Firebase admin
            if grep -q "firebase-admin" "${service_dir}index.js"; then
                # Replace direct Firebase admin initialization with shared utility
                sed -i.bak 's/const admin = require.*firebase-admin.*/const { getFirestore, getAuth } = require("..\/libs\/shared\/firebaseAdmin");/g' "${service_dir}index.js"
                sed -i.bak 's/admin\.initializeApp()/\/\/ Firebase admin initialized via shared utility/g' "${service_dir}index.js"
                sed -i.bak 's/admin\.firestore()/getFirestore()/g' "${service_dir}index.js"
                sed -i.bak 's/admin\.auth()/getAuth()/g' "${service_dir}index.js"
            fi
        fi
    done
    
    echo -e "${GREEN}✅ Services prepared for deployment${NC}"
}

# Function to deploy functions
deploy_functions() {
    echo -e "${BLUE}📦 Deploying Firebase Functions...${NC}"
    
    if [ ! -f "../../../services/index.js" ]; then
        echo -e "${RED}❌ Error: services/index.js not found${NC}"
        return 1
    fi
    
    echo -e "${BLUE}🔄 Deploying functions to Firebase...${NC}"
    
    # Deploy with increased timeout and retry logic
    MAX_RETRIES=3
    RETRY_COUNT=0
    
    while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
        if firebase deploy --only functions; then
            echo -e "${GREEN}✅ Successfully deployed Firebase Functions${NC}"
            return 0
        else
            RETRY_COUNT=$((RETRY_COUNT + 1))
            echo -e "${YELLOW}⚠️  Deployment attempt $RETRY_COUNT failed. Retrying...${NC}"
            sleep 10
        fi
    done
    
    echo -e "${RED}❌ Failed to deploy Firebase Functions after $MAX_RETRIES attempts${NC}"
    return 1
}

# Function to list deployed functions
list_functions() {
    echo -e "${BLUE}📋 Listing deployed functions...${NC}"
    firebase functions:list
}

# Function to test deployed functions
test_functions() {
    echo -e "${BLUE}🧪 Testing deployed functions...${NC}"
    
    # Test main health endpoint
    echo -e "${BLUE}🔍 Testing main health endpoint...${NC}"
    HEALTH_RESPONSE=$(curl -s -w "%{http_code}" "$BASE_URL/health" -o /tmp/health_response)
    
    if [ "$HEALTH_RESPONSE" = "200" ]; then
        echo -e "${GREEN}✅ Main health endpoint is working${NC}"
        cat /tmp/health_response | jq '.' 2>/dev/null || cat /tmp/health_response
    else
        echo -e "${YELLOW}⚠️  Main health endpoint returned status $HEALTH_RESPONSE${NC}"
    fi
    
    # Test individual service health checks
    SERVICES=(
        "healthCategoryExtraction"
        "healthProductExtraction"
        "healthEmbeddingService"
        "healthOrchestratorService"
        "healthProductEnrichment"
        "healthAiLogging"
        "healthVectorSearch"
        "healthSustainabilityEnrichment"
        "healthComplianceEnrichment"
        "healthEprelEnrichment"
        "healthFaoAgricultural"
        "healthOecdSustainability"
        "healthProductImage"
        "healthVectorCategoryComparison"
        "healthYamlCorrection"
    )
    
    for service in "${SERVICES[@]}"; do
        echo -e "${BLUE}🔍 Testing $service...${NC}"
        RESPONSE=$(curl -s -w "%{http_code}" "$BASE_URL/$service" -o /tmp/service_response)
        
        if [ "$RESPONSE" = "200" ]; then
            echo -e "${GREEN}✅ $service is working${NC}"
        else
            echo -e "${YELLOW}⚠️  $service returned status $RESPONSE${NC}"
        fi
    done
}

# Function to show deployment summary
show_summary() {
    echo -e "${BLUE}📊 Deployment Summary${NC}"
    echo -e "${BLUE}==================${NC}"
    echo -e "${BLUE}🌐 Project: $PROJECT_ID${NC}"
    echo -e "${BLUE}🌍 Region: $REGION${NC}"
    echo -e "${BLUE}🔗 Base URL: $BASE_URL${NC}"
    echo ""
    echo -e "${BLUE}📋 Available Endpoints:${NC}"
    echo -e "${GREEN}✅ Main Health: $BASE_URL/health${NC}"
    echo -e "${GREEN}✅ Category Extraction: $BASE_URL/categoryExtraction${NC}"
    echo -e "${GREEN}✅ YAML Correction: $BASE_URL/yamlCorrection${NC}"
    echo ""
    echo -e "${BLUE}🔍 Health Check Endpoints:${NC}"
    SERVICES=(
        "healthCategoryExtraction"
        "healthProductExtraction"
        "healthEmbeddingService"
        "healthOrchestratorService"
        "healthProductEnrichment"
        "healthAiLogging"
        "healthVectorSearch"
        "healthSustainabilityEnrichment"
        "healthComplianceEnrichment"
        "healthEprelEnrichment"
        "healthFaoAgricultural"
        "healthOecdSustainability"
        "healthProductImage"
        "healthVectorCategoryComparison"
        "healthYamlCorrection"
    )
    
    for service in "${SERVICES[@]}"; do
        echo -e "${GREEN}✅ $service: $BASE_URL/$service${NC}"
    done
}

# Main execution
main() {
    echo -e "${BLUE}🚀 Starting Complete ESG Microservices Deployment${NC}"
    echo ""
    
    # Step 1: Check Firebase CLI
    check_firebase_cli
    
    # Step 2: Set project
    set_project
    
    # Step 3: Grant permissions
    grant_permissions
    
    # Step 4: Prepare services
    prepare_services
    
    # Step 5: Deploy functions
    if deploy_functions; then
        echo -e "${GREEN}✅ Deployment completed successfully!${NC}"
        
        # Step 6: List functions
        list_functions
        
        # Step 7: Test functions
        test_functions
        
        # Step 8: Show summary
        show_summary
        
        echo -e "${GREEN}🎉 Complete deployment finished successfully!${NC}"
    else
        echo -e "${RED}❌ Deployment failed. Please check the logs above.${NC}"
        exit 1
    fi
}

# Run main function
main "$@" 
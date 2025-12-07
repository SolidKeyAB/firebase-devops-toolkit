#!/bin/bash

# Microservices Deployment Monitor
# Monitors the status of deployed services and provides detailed reporting

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
PROJECT_ID="${PROJECT_ID:-your-firebase-project-id}"
REGION="${REGION:-us-central1}"
BASE_URL="https://${REGION}-${PROJECT_ID}.cloudfunctions.net"

# Service definitions
MAIN_SERVICES=(
    "categoryExtraction"
    "productExtraction"
    "embeddingService"
    "orchestratorService"
    "productEnrichment"
    "aiLogging"
    "vectorSearch"
    "sustainabilityEnrichment"
    "complianceEnrichment"
    "eprelEnrichment"
    "faoAgricultural"
    "oecdSustainability"
    "productImage"
    "vectorCategoryComparison"
    "yamlCorrection"
)

HEALTH_SERVICES=(
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

# Function to test an endpoint
test_endpoint() {
    local endpoint=$1
    local service_name=$2
    local url="$BASE_URL/$endpoint"
    
    echo -e "${BLUE}🔍 Testing $service_name...${NC}"
    
    # Test with timeout
    RESPONSE=$(timeout 10 curl -s -w "%{http_code}" "$url" -o /tmp/response_$endpoint 2>/dev/null || echo "000")
    
    if [ "$RESPONSE" = "200" ]; then
        echo -e "${GREEN}✅ $service_name is working (HTTP $RESPONSE)${NC}"
        return 0
    elif [ "$RESPONSE" = "000" ]; then
        echo -e "${RED}❌ $service_name is not responding (timeout)${NC}"
        return 1
    else
        echo -e "${YELLOW}⚠️  $service_name returned status $RESPONSE${NC}"
        return 1
    fi
}

# Function to check function deployment status
check_deployment_status() {
    echo -e "${PURPLE}📋 Checking deployment status...${NC}"
    
    # Get list of deployed functions
    DEPLOYED_FUNCTIONS=$(firebase functions:list --format="value(name)" 2>/dev/null || echo "")
    
    echo -e "${BLUE}📊 Deployment Status Summary:${NC}"
    echo -e "${BLUE}============================${NC}"
    
    # Check main services
    echo -e "${CYAN}🔧 Main Services:${NC}"
    main_services_deployed=0
    for service in "${MAIN_SERVICES[@]}"; do
        if echo "$DEPLOYED_FUNCTIONS" | grep -q "$service"; then
            echo -e "${GREEN}✅ $service - DEPLOYED${NC}"
            ((main_services_deployed++))
        else
            echo -e "${RED}❌ $service - NOT DEPLOYED${NC}"
        fi
    done
    
    echo ""
    echo -e "${CYAN}🏥 Health Check Services:${NC}"
    health_services_deployed=0
    for service in "${HEALTH_SERVICES[@]}"; do
        if echo "$DEPLOYED_FUNCTIONS" | grep -q "$service"; then
            echo -e "${GREEN}✅ $service - DEPLOYED${NC}"
            ((health_services_deployed++))
        else
            echo -e "${RED}❌ $service - NOT DEPLOYED${NC}"
        fi
    done
    
    echo ""
    echo -e "${PURPLE}📈 Summary:${NC}"
    echo -e "${BLUE}   Main Services: $main_services_deployed/${#MAIN_SERVICES[@]} deployed${NC}"
    echo -e "${BLUE}   Health Services: $health_services_deployed/${#HEALTH_SERVICES[@]} deployed${NC}"
    echo -e "${BLUE}   Total: $((main_services_deployed + health_services_deployed))/$(( ${#MAIN_SERVICES[@]} + ${#HEALTH_SERVICES[@]} )) deployed${NC}"
}

# Function to test all endpoints
test_all_endpoints() {
    echo -e "${PURPLE}🧪 Testing all endpoints...${NC}"
    echo -e "${BLUE}========================${NC}"
    
    # Test main health endpoint
    echo -e "${CYAN}🏥 Main Health Check:${NC}"
    test_endpoint "health" "Main Health"
    
    echo ""
    echo -e "${CYAN}🔧 Main Services:${NC}"
    main_services_working=0
    for service in "${MAIN_SERVICES[@]}"; do
        if test_endpoint "$service" "$service"; then
            ((main_services_working++))
        fi
    done
    
    echo ""
    echo -e "${CYAN}🏥 Health Check Services:${NC}"
    health_services_working=0
    for service in "${HEALTH_SERVICES[@]}"; do
        if test_endpoint "$service" "$service"; then
            ((health_services_working++))
        fi
    done
    
    echo ""
    echo -e "${PURPLE}📊 Test Results Summary:${NC}"
    echo -e "${BLUE}   Main Services: $main_services_working/${#MAIN_SERVICES[@]} working${NC}"
    echo -e "${BLUE}   Health Services: $health_services_working/${#HEALTH_SERVICES[@]} working${NC}"
    echo -e "${BLUE}   Total: $((main_services_working + health_services_working))/$(( ${#MAIN_SERVICES[@]} + ${#HEALTH_SERVICES[@]} )) working${NC}"
}

# Function to show detailed service information
show_service_details() {
    echo -e "${PURPLE}📋 Service Details:${NC}"
    echo -e "${BLUE}==================${NC}"
    echo -e "${BLUE}🌐 Project: $PROJECT_ID${NC}"
    echo -e "${BLUE}🌍 Region: $REGION${NC}"
    echo -e "${BLUE}🔗 Base URL: $BASE_URL${NC}"
    echo ""
    
    echo -e "${CYAN}🔧 Main Service Endpoints:${NC}"
    for service in "${MAIN_SERVICES[@]}"; do
        echo -e "${GREEN}   $service: $BASE_URL/$service${NC}"
    done
    
    echo ""
    echo -e "${CYAN}🏥 Health Check Endpoints:${NC}"
    for service in "${HEALTH_SERVICES[@]}"; do
        echo -e "${GREEN}   $service: $BASE_URL/$service${NC}"
    done
}

# Function to check function logs
check_logs() {
    echo -e "${PURPLE}📝 Checking recent function logs...${NC}"
    echo -e "${BLUE}==============================${NC}"
    
    # Check logs for the last 10 minutes
    firebase functions:log --only health --limit 5 2>/dev/null || echo -e "${YELLOW}⚠️  No logs available for health function${NC}"
}

# Function to show deployment recommendations
show_recommendations() {
    echo -e "${PURPLE}💡 Deployment Recommendations:${NC}"
    echo -e "${BLUE}==============================${NC}"
    
    # Get deployment status
    DEPLOYED_FUNCTIONS=$(firebase functions:list --format="value(name)" 2>/dev/null || echo "")
    
    # Count deployed services
    main_deployed=0
    health_deployed=0
    
    for service in "${MAIN_SERVICES[@]}"; do
        if echo "$DEPLOYED_FUNCTIONS" | grep -q "$service"; then
            ((main_deployed++))
        fi
    done
    
    for service in "${HEALTH_SERVICES[@]}"; do
        if echo "$DEPLOYED_FUNCTIONS" | grep -q "$service"; then
            ((health_deployed++))
        fi
    done
    
    if [ $main_deployed -lt ${#MAIN_SERVICES[@]} ]; then
        echo -e "${YELLOW}⚠️  Some main services are not deployed. Run the complete deployment script.${NC}"
    fi
    
    if [ $health_deployed -lt ${#HEALTH_SERVICES[@]} ]; then
        echo -e "${YELLOW}⚠️  Some health check services are not deployed. Run the complete deployment script.${NC}"
    fi
    
    if [ $main_deployed -eq ${#MAIN_SERVICES[@]} ] && [ $health_deployed -eq ${#HEALTH_SERVICES[@]} ]; then
        echo -e "${GREEN}✅ All services are deployed!${NC}"
    fi
}

# Main execution
main() {
    echo -e "${BLUE}🔍 ESG Microservices Deployment Monitor${NC}"
    echo -e "${BLUE}=====================================${NC}"
    echo ""
    
    # Check if we're in the correct directory
    if [ ! -f "../../../firebase.json" ]; then
        echo -e "${RED}❌ Error: firebase.json not found. Please run this script from the remote directory.${NC}"
        exit 1
    fi
    
    # Set project
    firebase use "$PROJECT_ID" >/dev/null 2>&1
    
    # Run all checks
    check_deployment_status
    echo ""
    test_all_endpoints
    echo ""
    show_service_details
    echo ""
    check_logs
    echo ""
    show_recommendations
    
    echo -e "${GREEN}🎉 Monitoring completed!${NC}"
}

# Run main function
main "$@" 
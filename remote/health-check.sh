#!/bin/bash

# ESG Pipeline Microservices Health Check Script
# This script tests all deployed microservices and their health endpoints

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration (override with env vars)
PROJECT_ID="${PROJECT_ID:-your-firebase-project-id}"
REGION="${REGION:-us-central1}"
BASE_URL="${BASE_URL:-https://${REGION}-${PROJECT_ID}.cloudfunctions.net}"

echo -e "${BLUE}🏥 Starting ESG Pipeline Health Check${NC}"

# Function to test an endpoint
test_endpoint() {
    local endpoint=$1
    local description=$2
    
    echo -e "${BLUE}📡 Testing $description...${NC}"
    
    # Make the request
    response=$(curl -s -w "%{http_code}" "$BASE_URL/$endpoint" 2>/dev/null)
    http_code="${response: -3}"
    body="${response%???}"
    
    if [ "$http_code" = "200" ]; then
        echo -e "${GREEN}✅ $description is healthy (HTTP $http_code)${NC}"
        echo -e "${BLUE}   Response: $body${NC}"
        return 0
    else
        echo -e "${RED}❌ $description is unhealthy (HTTP $http_code)${NC}"
        return 1
    fi
}

# Function to test main services
test_main_services() {
    echo -e "${BLUE}🔧 Testing main services...${NC}"
    
    local services=(
        "categoryExtraction:Category Extraction Service"
        "productExtraction:Product Extraction Service"
        "embeddingService:Embedding Service"
        "orchestratorService:Orchestrator Service"
        "productEnrichment:Product Enrichment Service"
        "aiLogging:AI Logging Service"
        "vectorSearch:Vector Search Service"
        "sustainabilityEnrichment:Sustainability Enrichment Service"
        "complianceEnrichment:Compliance Enrichment Service"
        "eprelEnrichment:EPREL Enrichment Service"
        "faoAgricultural:FAO Agricultural Service"
        "oecdSustainability:OECD Sustainability Service"
        "productImage:Product Image Service"
        "vectorCategoryComparison:Vector Category Comparison Service"
        "yamlCorrection:YAML Correction Service"
    )
    
    local healthy_count=0
    local total_count=0
    
    for service in "${services[@]}"; do
        IFS=':' read -r endpoint description <<< "$service"
        if test_endpoint "$endpoint" "$description"; then
            ((healthy_count++))
        fi
        ((total_count++))
    done
    
    echo -e "${BLUE}📊 Main Services Health Summary: $healthy_count/$total_count healthy${NC}"
    return $((total_count - healthy_count))
}

# Function to test health check endpoints
test_health_checks() {
    echo -e "${BLUE}🏥 Testing health check endpoints...${NC}"
    
    local health_checks=(
        "health:Main Health Check"
        "healthCategoryExtraction:Category Extraction Health"
        "healthProductExtraction:Product Extraction Health"
        "healthEmbeddingService:Embedding Service Health"
        "healthOrchestratorService:Orchestrator Service Health"
        "healthProductEnrichment:Product Enrichment Health"
        "healthAiLogging:AI Logging Health"
        "healthVectorSearch:Vector Search Health"
        "healthSustainabilityEnrichment:Sustainability Enrichment Health"
        "healthComplianceEnrichment:Compliance Enrichment Health"
        "healthEprelEnrichment:EPREL Enrichment Health"
        "healthFaoAgricultural:FAO Agricultural Health"
        "healthOecdSustainability:OECD Sustainability Health"
        "healthProductImage:Product Image Health"
        "healthVectorCategoryComparison:Vector Category Comparison Health"
        "healthYamlCorrection:YAML Correction Health"
    )
    
    local healthy_count=0
    local total_count=0
    
    for health_check in "${health_checks[@]}"; do
        IFS=':' read -r endpoint description <<< "$health_check"
        if test_endpoint "$endpoint" "$description"; then
            ((healthy_count++))
        fi
        ((total_count++))
    done
    
    echo -e "${BLUE}📊 Health Checks Summary: $healthy_count/$total_count healthy${NC}"
    return $((total_count - healthy_count))
}

# Function to show detailed status
show_detailed_status() {
    echo -e "${BLUE}📋 Detailed Status Report${NC}"
    echo -e "${BLUE}🌐 Base URL: $BASE_URL${NC}"
    echo -e "${BLUE}📅 Timestamp: $(date)${NC}"
    echo -e "${BLUE}🔧 Project: $PROJECT_ID${NC}"
    
    # Test main health endpoint first
    echo -e "${BLUE}🏥 Testing main health endpoint...${NC}"
    main_health_response=$(curl -s "$BASE_URL/health")
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Main health endpoint is accessible${NC}"
        echo -e "${BLUE}   Response: $main_health_response${NC}"
    else
        echo -e "${RED}❌ Main health endpoint is not accessible${NC}"
    fi
}

# Function to show summary
show_summary() {
    echo -e "${BLUE}📊 Health Check Summary${NC}"
    echo -e "${GREEN}✅ Health check completed${NC}"
    echo -e "${BLUE}🌐 All endpoints tested against: $BASE_URL${NC}"
    echo -e "${BLUE}📅 Check completed at: $(date)${NC}"
}

# Main health check process
main() {
    echo -e "${BLUE}🎯 Starting comprehensive health check...${NC}"
    
    # Show detailed status
    show_detailed_status
    
    # Test health check endpoints
    local health_check_failures=0
    if ! test_health_checks; then
        health_check_failures=$?
    fi
    
    # Test main services
    local service_failures=0
    if ! test_main_services; then
        service_failures=$?
    fi
    
    # Show summary
    show_summary
    
    # Exit with appropriate code
    local total_failures=$((health_check_failures + service_failures))
    if [ $total_failures -eq 0 ]; then
        echo -e "${GREEN}🎉 All services are healthy!${NC}"
        exit 0
    else
        echo -e "${YELLOW}⚠️  $total_failures services have issues${NC}"
        exit 1
    fi
}

# Run main function
main "$@" 
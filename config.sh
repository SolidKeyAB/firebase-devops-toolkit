#!/bin/bash

# Generic Firebase Emulator Configuration
# This file can be reused across different projects
# Customize the variables below for your specific project

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# =============================================================================
# PROJECT-SPECIFIC CONFIGURATION
# =============================================================================
# Customize these variables for your project

# Firebase Project Configuration
# Only set defaults if not already set by .env file
export FIREBASE_PROJECT_ID=${FIREBASE_PROJECT_ID:-"your-project-id"}
export FIREBASE_REGION=${FIREBASE_REGION:-"us-central1"}

# Emulator Configuration
export FIREBASE_EMULATOR_HOST=${FIREBASE_EMULATOR_HOST:-"127.0.0.1"}
export FIREBASE_EMULATOR_PORT=${FIREBASE_EMULATOR_PORT:-"8080"}
export FIREBASE_UI_PORT=${FIREBASE_UI_PORT:-"4000"}
export FIREBASE_HUB_PORT=${FIREBASE_HUB_PORT:-"4400"}

# =============================================================================
# SERVICE CONFIGURATION
# =============================================================================
# Customize these arrays for your project's services
# Format: "service-name:port"

export FIREBASE_SERVICES=(
    "category-extraction-service:5001"
    "product-extraction-service:5002"
    "embedding-service:5003"
    "orchestrator-service:5004"
    "product-enrichment-service:5005"
    "eprel-enrichment-service:5006"
    "ai-logging-service:5007"
    "vector-search-service:5008"
    "sustainability-enrichment-service:5009"
    "oecd-sustainability-service:5010"
    "fao-agricultural-enrichment-service:5011"
    "product-image-service:5012"
    "yaml-correction-service:5013"
)

# =============================================================================
# FUNCTION NAMING CONFIGURATION
# =============================================================================
# Customize how function names are generated from service names
# This makes the script adaptable to different naming conventions

export FUNCTION_NAME_PREFIX=${FUNCTION_NAME_PREFIX:-""}
export FUNCTION_NAME_SUFFIX=${FUNCTION_NAME_SUFFIX:-""}
export FUNCTION_NAME_TRANSFORM=${FUNCTION_NAME_TRANSFORM:-"default"}

# Function name transformation logic
transform_function_name() {
    local service_name=$1
    local function_name=""
    
    case "$FUNCTION_NAME_TRANSFORM" in
        "default")
            # Default: remove "-service" suffix and replace hyphens with underscores
            function_name=$(echo "$service_name" | sed 's/-service$//' | sed 's/-/_/g')
            ;;
        "kebab")
            # Kebab case: remove "-service" suffix, keep hyphens
            function_name=$(echo "$service_name" | sed 's/-service$//')
            ;;
        "snake")
            # Snake case: remove "-service" suffix, replace hyphens with underscores
            function_name=$(echo "$service_name" | sed 's/-service$//' | sed 's/-/_/g')
            ;;
        "camel")
            # Camel case: remove "-service" suffix, convert to camelCase
            function_name=$(echo "$service_name" | sed 's/-service$//' | sed 's/-\([a-z]\)/\U\1/g')
            ;;
        "custom")
            # Custom transformation - use environment variable
            function_name=${CUSTOM_FUNCTION_NAME:-$(echo "$service_name" | sed 's/-service$//')}
            ;;
        *)
            # Default fallback
            function_name=$(echo "$service_name" | sed 's/-service$//' | sed 's/-/_/g')
            ;;
    esac
    
    echo "${FUNCTION_NAME_PREFIX}${function_name}${FUNCTION_NAME_SUFFIX}"
}

# =============================================================================
# PORT CONFIGURATION
# =============================================================================
# Add/remove ports based on your project needs

export FIREBASE_PORTS=(
    "8080"  # Firestore
    "5001"  # Functions
    "4000"  # UI
    "4400"  # Hub
    "4500"  # Logging
    "9150"  # Firestore WebSocket
)

# =============================================================================
# HEALTH CHECK ENDPOINTS
# =============================================================================
# Customize these endpoints based on your service naming convention
# The script will automatically generate these based on FIREBASE_SERVICES

generate_health_endpoints() {
    local endpoints=()
    for service_config in "${FIREBASE_SERVICES[@]}"; do
        IFS=':' read -r service_name port <<< "$service_config"
        # Use the transform function for consistent naming
        local function_name=$(transform_function_name "$service_name")
        # For Firebase Functions, use the correct endpoint structure
        # The actual functions run on the Firebase emulator port (5001)
        endpoints+=("http://localhost:5001/$FIREBASE_PROJECT_ID/$FIREBASE_REGION/$function_name")
    done
    echo "${endpoints[@]}"
}

export FIREBASE_HEALTH_ENDPOINTS=($(generate_health_endpoints))

# =============================================================================
# PRODUCTION URL GENERATION
# =============================================================================
# Generate production URLs based on project configuration

generate_production_urls() {
    local urls=()
    for service_config in "${FIREBASE_SERVICES[@]}"; do
        IFS=':' read -r service_name port <<< "$service_config"
        # Use the transform function for consistent naming
        local function_name=$(transform_function_name "$service_name")
        urls+=("https://$FIREBASE_REGION-$FIREBASE_PROJECT_ID.cloudfunctions.net/$function_name")
    done
    echo "${urls[@]}"
}

export FIREBASE_PRODUCTION_URLS=($(generate_production_urls))

# =============================================================================
# TIMEOUT CONFIGURATION
# =============================================================================

export FIREBASE_STARTUP_TIMEOUT=${FIREBASE_STARTUP_TIMEOUT:-30}
export FIREBASE_HEALTH_CHECK_TIMEOUT=${FIREBASE_HEALTH_CHECK_TIMEOUT:-10}
export FIREBASE_CLEANUP_TIMEOUT=${FIREBASE_CLEANUP_TIMEOUT:-5}

# =============================================================================
# LOGGING CONFIGURATION
# =============================================================================

export FIREBASE_LOG_LEVEL=${FIREBASE_LOG_LEVEL:-"info"}
export FIREBASE_DEBUG_LOG=${FIREBASE_DEBUG_LOG:-"firebase-debug.log"}
export FIRESTORE_DEBUG_LOG=${FIRESTORE_DEBUG_LOG:-"firestore-debug.log"}

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

log_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

# =============================================================================
# SERVICE URL GENERATION FUNCTIONS
# =============================================================================

# Function to get local service URLs
get_local_service_urls() {
    local urls=()
    for service_config in "${FIREBASE_SERVICES[@]}"; do
        IFS=':' read -r service_name port <<< "$service_config"
        # Use the transform function for consistent naming
        local function_name=$(transform_function_name "$service_name")
        # Convert service name to display name
        local display_name=$(echo "$service_name" | sed 's/-service$//' | sed 's/-/ /g' | sed 's/\b\w/\U&/g')
        urls+=("$display_name: http://localhost:$port/$function_name/$FIREBASE_REGION")
    done
    echo "${urls[@]}"
}

# Function to get production service URLs
get_production_service_urls() {
    local urls=()
    for i in "${!FIREBASE_SERVICES[@]}"; do
        local service_config="${FIREBASE_SERVICES[$i]}"
        local production_url="${FIREBASE_PRODUCTION_URLS[$i]}"
        IFS=':' read -r service_name port <<< "$service_config"
        # Use the transform function for consistent naming
        local function_name=$(transform_function_name "$service_name")
        # Convert service name to display name
        local display_name=$(echo "$service_name" | sed 's/-service$//' | sed 's/-/ /g' | sed 's/\b\w/\U&/g')
        urls+=("$display_name: $production_url")
    done
    echo "${urls[@]}"
}

# =============================================================================
# CONFIGURATION VALIDATION
# =============================================================================

validate_config() {
    log_info "Validating Firebase configuration..."
    
    # Check if project ID is set
    if [ -z "$FIREBASE_PROJECT_ID" ] || [ "$FIREBASE_PROJECT_ID" = "your-project-id" ]; then
        log_error "FIREBASE_PROJECT_ID is not set or is using default value"
        log_info "Please set FIREBASE_PROJECT_ID environment variable or update config.sh"
        return 1
    fi
    
    # Check if services are configured
    if [ ${#FIREBASE_SERVICES[@]} -eq 0 ]; then
        log_error "No services configured in FIREBASE_SERVICES"
        return 1
    fi
    
    # Check if ports are configured
    if [ ${#FIREBASE_PORTS[@]} -eq 0 ]; then
        log_error "No ports configured in FIREBASE_PORTS"
        return 1
    fi
    
    log_success "Configuration validation passed"
    log_info "Project ID: $FIREBASE_PROJECT_ID"
    log_info "Region: $FIREBASE_REGION"
    log_info "Function naming: $FUNCTION_NAME_TRANSFORM"
    return 0
}

# Validate configuration on load (only when this script is run directly, not when sourced)
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    validate_config
fi 
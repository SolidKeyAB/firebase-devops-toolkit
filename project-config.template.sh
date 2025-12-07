#!/bin/bash

# 🔥 Firebase Scripts - Project Configuration Template
# Copy this file to 'project-config.sh' and customize for your project

# =============================================================================
# REQUIRED: FIREBASE PROJECT CONFIGURATION
# =============================================================================

# Your Firebase project ID (REQUIRED)
export FIREBASE_PROJECT_ID="your-project-id"

# Your preferred Firebase region
export FIREBASE_REGION="us-central1"  # or europe-west1, asia-northeast1, etc.

# =============================================================================
# OPTIONAL: SERVICE CONFIGURATION
# =============================================================================

# Define your Firebase Functions/Services
# Format: "service-name:port"
export FIREBASE_SERVICES=(
    "api-gateway:5001"
    "user-service:5002"
    "notification-service:5003"
    "data-processor:5004"
    "webhook-handler:5005"
)

# =============================================================================
# OPTIONAL: FUNCTION NAMING CONFIGURATION
# =============================================================================

# How to transform service names to function names
# Options: "default", "kebab", "snake", "camel", "custom"
export FUNCTION_NAME_TRANSFORM="default"

# Prefix/suffix for function names (optional)
export FUNCTION_NAME_PREFIX=""
export FUNCTION_NAME_SUFFIX=""

# =============================================================================
# OPTIONAL: EMULATOR CONFIGURATION
# =============================================================================

# Emulator host and ports (if you need to override defaults)
export FIREBASE_EMULATOR_HOST="127.0.0.1"
export FIREBASE_UI_PORT="4000"
export FIREBASE_HUB_PORT="4400"
export FIREBASE_EMULATOR_PORT="8080"

# Additional ports for your services
export FIREBASE_PORTS=(
    "8080"  # Firestore
    "5001"  # Functions
    "4000"  # UI
    "4400"  # Hub
    "4500"  # Logging
    "9150"  # Firestore WebSocket
    "5002"  # Your custom service port
    "5003"  # Your custom service port
)

# =============================================================================
# OPTIONAL: AI/EXTERNAL SERVICE CONFIGURATION
# =============================================================================

# AI Services (if you use AI functions)
export AI_PROVIDER="gemini"
export AI_MODEL="gemini-2.0-flash-exp"
# export GEMINI_API_KEY="your-gemini-api-key"  # Set in environment or .env

# Google Services (if you use search/maps)
# export GOOGLE_SEARCH_API_KEY="your-google-search-key"  # Set in environment
# export GOOGLE_CSE_ID="your-custom-search-engine-id"   # Set in environment

# Vector Database (if you use vector search)
# export QDRANT_URL="your-qdrant-url"          # Set in environment
# export QDRANT_API_KEY="your-qdrant-key"      # Set in environment

# =============================================================================
# OPTIONAL: DEPLOYMENT CONFIGURATION
# =============================================================================

# Production deployment settings
export PRODUCTION_REGION="us-central1"
export PRODUCTION_MEMORY="1GB"
export PRODUCTION_TIMEOUT="300s"

# Development settings
export DEV_MEMORY="512MB"
export DEV_TIMEOUT="60s"

# =============================================================================
# OPTIONAL: LOGGING AND MONITORING
# =============================================================================

export FIREBASE_LOG_LEVEL="info"  # debug, info, warn, error
export FIREBASE_DEBUG_LOG="firebase-debug.log"
export FIRESTORE_DEBUG_LOG="firestore-debug.log"

# =============================================================================
# PROJECT-SPECIFIC FUNCTIONS (ADVANCED)
# =============================================================================

# Custom validation function for your project
validate_project_config() {
    log_info "Validating project-specific configuration..."

    # Example: Check if required environment variables are set
    if [ -z "$GEMINI_API_KEY" ] && grep -q "gemini" <<< "${FIREBASE_SERVICES[@]}"; then
        log_warning "GEMINI_API_KEY not set but AI services detected"
    fi

    # Example: Validate project ID format
    if [[ ! "$FIREBASE_PROJECT_ID" =~ ^[a-z0-9-]+$ ]]; then
        log_error "Invalid project ID format: $FIREBASE_PROJECT_ID"
        return 1
    fi

    # Example: Check if project exists
    if command -v firebase &> /dev/null; then
        if ! firebase projects:list --token "$FIREBASE_TOKEN" 2>/dev/null | grep -q "$FIREBASE_PROJECT_ID"; then
            log_warning "Project $FIREBASE_PROJECT_ID not found in your Firebase projects"
        fi
    fi

    log_success "Project configuration validation passed"
    return 0
}

# Custom setup function for your project
setup_project_environment() {
    log_info "Setting up project-specific environment..."

    # Example: Create project-specific directories
    mkdir -p logs/
    mkdir -p temp/
    mkdir -p backups/

    # Example: Set up project-specific git hooks
    if [ -d .git/hooks ]; then
        # cp scripts/hooks/pre-commit .git/hooks/
        chmod +x .git/hooks/pre-commit 2>/dev/null || true
    fi

    # Example: Initialize project-specific configuration files
    if [ ! -f .env ]; then
        cat > .env << EOF
# Project Environment Variables
FIREBASE_PROJECT_ID=$FIREBASE_PROJECT_ID
FIREBASE_REGION=$FIREBASE_REGION
NODE_ENV=development

# Add your API keys here
# GEMINI_API_KEY=your-gemini-api-key
# GOOGLE_SEARCH_API_KEY=your-search-key
# QDRANT_URL=your-qdrant-url
EOF
        log_success "Created .env file with project defaults"
    fi

    log_success "Project environment setup completed"
}

# =============================================================================
# LOAD BASE CONFIGURATION
# =============================================================================

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source the main configuration
if [ -f "$SCRIPT_DIR/config.sh" ]; then
    source "$SCRIPT_DIR/config.sh"
else
    echo "❌ Error: config.sh not found. Make sure firebase-scripts is properly installed."
    exit 1
fi

# Run project-specific validation (if this script is executed directly)
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    validate_project_config
    setup_project_environment
fi

# =============================================================================
# USAGE EXAMPLES
# =============================================================================

# This configuration file enables you to:
#
# 1. Quick setup:
#    source project-config.sh
#    ./manage.sh start-local
#
# 2. Custom deployment:
#    ./unified-deploy.sh production --project-id $FIREBASE_PROJECT_ID
#
# 3. Testing with your config:
#    ./remote/test-functions-consolidated.sh
#
# 4. Environment-specific deployment:
#    FIREBASE_PROJECT_ID=staging-project ./unified-deploy.sh simple
#
# 5. Advanced validation:
#    source project-config.sh && validate_project_config
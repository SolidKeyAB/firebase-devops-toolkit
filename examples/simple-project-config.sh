#!/bin/bash

# Example: Simple Project Configuration
# Copy this file and customize it for your project

# Source the generic configuration first
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config.sh"

# =============================================================================
# PROJECT-SPECIFIC OVERRIDES
# =============================================================================

# Override generic defaults with your project values
export FIREBASE_PROJECT_ID="my-simple-app"
export FIREBASE_REGION="us-central1"

# Function naming convention for this project
export FUNCTION_NAME_TRANSFORM="default"

# No prefix or suffix needed for simple projects
export FUNCTION_NAME_PREFIX=""
export FUNCTION_NAME_SUFFIX=""

# =============================================================================
# PROJECT-SPECIFIC VALIDATION
# =============================================================================

validate_project_config() {
    log_info "Validating simple project configuration..."
    
    if [ "$FIREBASE_PROJECT_ID" = "my-simple-app" ]; then
        log_success "Simple project configuration detected"
    fi
    
    log_info "Project: $FIREBASE_PROJECT_ID"
    log_info "Region: $FIREBASE_REGION"
    log_info "Function naming: $FUNCTION_NAME_TRANSFORM"
}

# Run project validation
validate_project_config

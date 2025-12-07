#!/bin/bash

# Example: Enterprise Project Configuration
# Copy this file and customize it for your enterprise project

# Source the generic configuration first
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config.sh"

# =============================================================================
# PROJECT-SPECIFIC OVERRIDES
# =============================================================================

# Override generic defaults with your project values
export FIREBASE_PROJECT_ID="enterprise-api-platform"
export FIREBASE_REGION="asia-southeast1"

# Function naming convention for enterprise projects
export FUNCTION_NAME_TRANSFORM="custom"

# Enterprise projects often use company prefixes
export FUNCTION_NAME_PREFIX="enterprise-"
export FUNCTION_NAME_SUFFIX="-v1"

# =============================================================================
# PROJECT-SPECIFIC SERVICE CONFIGURATION
# =============================================================================
# Override services for enterprise needs

export FIREBASE_SERVICES=(
    "user-management-service:5001"
    "authentication-service:5002"
    "authorization-service:5003"
    "audit-logging-service:5004"
    "data-processing-service:5005"
    "reporting-service:5006"
    "integration-service:5007"
    "monitoring-service:5008"
)

# =============================================================================
# PROJECT-SPECIFIC VALIDATION
# =============================================================================

validate_project_config() {
    log_info "Validating enterprise project configuration..."
    
    if [ "$FIREBASE_PROJECT_ID" = "enterprise-api-platform" ]; then
        log_success "Enterprise project configuration detected"
    fi
    
    # Validate enterprise-specific requirements
    if [ "$FUNCTION_NAME_PREFIX" = "enterprise-" ]; then
        log_success "Enterprise naming convention detected"
    fi
    
    log_info "Project: $FIREBASE_PROJECT_ID"
    log_info "Region: $FIREBASE_REGION"
    log_info "Function prefix: $FUNCTION_NAME_PREFIX"
    log_info "Function suffix: $FUNCTION_NAME_SUFFIX"
    log_info "Services configured: ${#FIREBASE_SERVICES[@]}"
}

# Run project validation
validate_project_config

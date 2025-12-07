#!/bin/bash

# Generic Firebase Services Deployment Script (Remote)
# This script deploys all services to Firebase production

# Source configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Try to source project-specific config first, fall back to generic config
if [ -f "$SCRIPT_DIR/../project-config.sh" ]; then
    source "$SCRIPT_DIR/../project-config.sh"
else
    source "$SCRIPT_DIR/../config.sh"
fi

# Function to check if user is logged in to Firebase
check_firebase_auth() {
    log_info "Checking Firebase authentication..."
    
    if ! firebase projects:list > /dev/null 2>&1; then
        log_error "Not authenticated with Firebase"
        log_info "Please run: firebase login"
        return 1
    fi
    
    log_success "Firebase authentication verified"
    return 0
}

# Function to check if project exists
check_project_exists() {
    log_info "Checking if project $FIREBASE_PROJECT_ID exists..."
    
    if ! firebase projects:list | grep -q "$FIREBASE_PROJECT_ID"; then
        log_error "Project $FIREBASE_PROJECT_ID not found"
        log_info "Available projects:"
        firebase projects:list
        return 1
    fi
    
    log_success "Project $FIREBASE_PROJECT_ID exists"
    return 0
}

# Function to deploy a single service
deploy_service() {
    local service_name=$1
    local port=$2
    
    log_info "Deploying $service_name to Firebase production..."
    
    # Use SERVICES_DIR if set, otherwise default to services/
    local services_path="${SERVICES_DIR:-services}/$service_name"
    
    # Check if service directory exists
    if [ ! -d "$services_path" ]; then
        log_error "Service directory $services_path not found"
        return 1
    fi
    
    cd "$services_path"
    
    # Install dependencies
    log_info "Installing dependencies for $service_name..."
    npm install --silent
    
    # Create firebase.json for this service if it doesn't exist
    if [ ! -f "firebase.json" ]; then
        log_info "Creating firebase.json for $service_name..."
        cat > firebase.json << EOF
{
  "functions": {
    "source": ".",
    "runtime": "nodejs18",
    "region": "$FIREBASE_REGION",
    "gen": 2
  }
}
EOF
    fi
    
    # Deploy to Firebase production
    log_info "Deploying $service_name to Firebase production..."
    if firebase deploy --only functions --project "$FIREBASE_PROJECT_ID" --force; then
        log_success "✅ $service_name deployed successfully"
        cd ../..
        return 0
    else
        log_error "❌ Failed to deploy $service_name"
        cd ../..
        return 1
    fi
}

# Function to deploy all services
deploy_all_services() {
    log_info "Deploying all services to Firebase production..."
    
    local success_count=0
    local total_services=${#FIREBASE_SERVICES[@]}
    
    for service_config in "${FIREBASE_SERVICES[@]}"; do
        IFS=':' read -r service_name port <<< "$service_config"
        
        if deploy_service "$service_name" "$port"; then
            ((success_count++))
        fi
    done
    
    log_info "Deployment summary: $success_count/$total_services services deployed"
    
    if [ $success_count -eq $total_services ]; then
        log_success "🎉 All services deployed successfully"
        return 0
    else
        log_warning "⚠️  Some services failed to deploy"
        return 1
    fi
}

# Function to show production URLs
show_production_urls() {
    log_header "Production Service URLs"
    
    # Get production URLs from config
    local production_urls=($(get_production_service_urls))
    
    for url in "${production_urls[@]}"; do
        echo "  $url"
    done
    echo ""
}

# Main function
main() {
    log_header "Firebase Services Deployment (Remote)"
    
    # Check authentication
    if ! check_firebase_auth; then
        exit 1
    fi
    
    # Check project exists
    if ! check_project_exists; then
        exit 1
    fi
    
    # Deploy all services
    deploy_all_services
    
    # Show production URLs
    show_production_urls
    
    log_header "Deployment Completed"
    log_info "All services are now deployed to Firebase production"
}

# Run main function
main "$@" 
#!/bin/bash

# Generic Firebase Services Deployment Script (Local)
# This script deploys all services to Firebase emulator

# Source configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Try to source project-specific config first, fall back to generic config
if [ -f "$SCRIPT_DIR/../project-config.sh" ]; then
    source "$SCRIPT_DIR/../project-config.sh"
else
    source "$SCRIPT_DIR/../config.sh"
fi

# Function to check if Firebase emulator is running
check_emulator() {
    log_info "Checking if Firebase emulator is running..."
    if curl -s "http://localhost:$FIREBASE_EMULATOR_PORT" > /dev/null 2>&1; then
        log_success "✅ Firebase emulator is running"
        return 0
    else
        log_error "❌ Firebase emulator is not running"
        return 1
    fi
}

# Function to set emulator environment variables
set_emulator_env() {
    log_info "Setting emulator environment variables..."
    export FIRESTORE_EMULATOR_HOST="localhost:$FIREBASE_EMULATOR_PORT"
    export FIRESTORE_PROJECT_ID="$FIREBASE_PROJECT_ID"
    export FUNCTIONS_EMULATOR="true"
    export NODE_ENV="development"
    log_success "✅ Emulator environment variables set"
}

# Function to install dependencies for all services
install_dependencies() {
    log_header "Installing Dependencies"
    
    # Go to the main project directory
    cd "$SCRIPT_DIR/../../.."
    
    local installed_count=0
    local total_services=${#FIREBASE_SERVICES[@]}
    
    for service_config in "${FIREBASE_SERVICES[@]}"; do
        IFS=':' read -r service_name port <<< "$service_config"
        local service_dir="services/$service_name"
        
        if [ -d "$service_dir" ] && [ -f "$service_dir/package.json" ]; then
            log_info "Installing dependencies for $service_name..."
            cd "$service_dir" && npm install --silent
            cd - > /dev/null
            ((installed_count++))
        fi
    done
    
    log_info "Dependencies installed for $installed_count/$total_services services"
}

# Function to start Firebase emulator with all functions
start_firebase_emulator() {
    log_header "Starting Firebase Emulator with All Functions"
    
    # Go to the main project directory FIRST
    log_info "SCRIPT_DIR: $SCRIPT_DIR"
    log_info "Target directory: $SCRIPT_DIR/.."
    cd "$SCRIPT_DIR/.."
    log_info "Changed to directory: $(pwd)"
    
    # Set environment variables
    set_emulator_env
    
    # Set additional resource limits to prevent memory issues
    export NODE_OPTIONS="--max-old-space-size=512 --max-semi-space-size=64"
    export UV_THREADPOOL_SIZE=4
    
    # Start Firebase emulator with resource limits to prevent overload
    log_info "Starting Firebase emulator with resource limits..."
    log_info "Current working directory: $(pwd)"
    log_info "Firebase config location: $(pwd)/firebase.json"
    log_info "Resource limits: maxInstances=1, concurrency=1"
    
    # Set resource limits via environment variables
    export FIREBASE_FUNCTIONS_MAX_INSTANCES=1
    export FIREBASE_FUNCTIONS_CONCURRENCY=1
    
    FIRESTORE_EMULATOR_HOST="localhost:$FIREBASE_EMULATOR_PORT" \
    FIRESTORE_PROJECT_ID="$FIREBASE_PROJECT_ID" \
    FUNCTIONS_EMULATOR="true" \
    firebase emulators:start --only functions,firestore,pubsub,ui --project "$FIREBASE_PROJECT_ID" &
    
    local emulator_pid=$!
    
    # Store PID for cleanup
    echo "$emulator_pid" > /tmp/firebase_emulator.pid
    
    # Wait for emulator to start
    log_info "Waiting for Firebase emulator to start..."
    local attempts=0
    while [ $attempts -lt 30 ]; do
        if curl -s "http://localhost:$FIREBASE_EMULATOR_PORT" > /dev/null 2>&1; then
            log_success "✅ Firebase emulator started successfully"
            return 0
        fi
        sleep 2
        attempts=$((attempts + 1))
    done
    
    log_error "❌ Firebase emulator failed to start within timeout"
    return 1
}

# Function to check service health
check_service_health() {
    log_header "Checking Service Health"
    
    # Wait for services to be ready (reduced wait time to prevent resource buildup)
    log_info "Waiting for services to be ready..."
    sleep 8
    
    local healthy_count=0
    local total_services=${#FIREBASE_SERVICES[@]}
    
    for service_config in "${FIREBASE_SERVICES[@]}"; do
        IFS=':' read -r service_name port <<< "$service_config"
        local function_name=$(echo "$service_name" | sed 's/-service$//' | sed 's/-/_/g')
        local health_url="http://localhost:5001/esg-$function_name/$FIREBASE_REGION/health"
        
        if curl -s "$health_url" > /dev/null 2>&1; then
            log_success "✅ $service_name is healthy"
            ((healthy_count++))
        else
            log_warning "⚠️  $service_name is not responding"
        fi
    done
    
    log_info "Health check summary: $healthy_count/$total_services services healthy"
    
    if [ $healthy_count -lt $total_services ]; then
        log_warning "⚠️  Some services may need more time to start"
        log_info "Waiting additional time for services to start..."
        sleep 10
        
        # Check again
        healthy_count=0
        for service_config in "${FIREBASE_SERVICES[@]}"; do
            IFS=':' read -r service_name port <<< "$service_config"
            local function_name=$(echo "$service_name" | sed 's/-service$//' | sed 's/-/_/g')
            local health_url="http://localhost:5001/esg-$function_name/$FIREBASE_REGION/health"
            
            if curl -s "$health_url" > /dev/null 2>&1; then
                log_success "✅ $service_name is now healthy"
                ((healthy_count++))
            else
                log_warning "⚠️  $service_name still not responding"
            fi
        done
        
        log_info "Final health check: $healthy_count/$total_services services healthy"
    fi
}

# Main deployment function
main() {
    log_header "Firebase Services Deployment (Local)"
    
    # Install dependencies
    install_dependencies
    
    # Start Firebase emulator
    if ! start_firebase_emulator; then
        log_error "Failed to start Firebase emulator"
        exit 1
    fi
    
    # Wait for services to be ready (reduced wait time to prevent resource buildup)
    log_info "Waiting for services to be ready..."
    sleep 8
    
    # Check service health
    check_service_health
    
    # Service URLs
    log_header "Service URLs"
    for service_config in "${FIREBASE_SERVICES[@]}"; do
        IFS=':' read -r service_name port <<< "$service_config"
        local function_name=$(echo "$service_name" | sed 's/-service$//' | sed 's/-/_/g')
        echo "  $service_name: http://localhost:5001/esg-$function_name/$FIREBASE_REGION"
    done
    echo "  Firestore:           http://localhost:$FIREBASE_EMULATOR_PORT"
    echo "  Firebase UI:         http://127.0.0.1:$FIREBASE_UI_PORT"
    
    log_header "Deployment Completed"
    log_info "All services are now available in the Firebase emulator"
    log_info "You can now run your pipeline scripts"
}

# Run main function
main "$@" 
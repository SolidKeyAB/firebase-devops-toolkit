#!/bin/bash

# Generic Firebase Emulator Start Script (Local)
# This script starts Firebase emulators locally and can be reused across projects

# Source configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Try to source project-specific config first, fall back to generic config
if [ -f "$SCRIPT_DIR/../project-config.sh" ]; then
    source "$SCRIPT_DIR/../project-config.sh"
else
    source "$SCRIPT_DIR/../config.sh"
fi

# Function to check if a port is in use
check_port() {
    local port=$1
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null ; then
        log_warning "Port $port is already in use"
        return 1
    else
        log_success "Port $port is available"
        return 0
    fi
}

# Function to check if all required ports are available
check_ports() {
    log_info "Checking port availability..."
    local all_ports_available=true
    
    # Check essential ports only
    local essential_ports=("$FIREBASE_EMULATOR_PORT" "$FIREBASE_UI_PORT" "$FIREBASE_HUB_PORT" "5001")
    for port in "${essential_ports[@]}"; do
        if ! check_port $port; then
            all_ports_available=false
        fi
    done
    
    if [ "$all_ports_available" = false ]; then
        log_error "Some ports are in use. Please stop existing services first."
        return 1
    fi
    
    log_success "All ports are available"
    return 0
}

# Function to kill existing Firebase processes
cleanup_firebase() {
    log_info "Cleaning up existing Firebase processes..."
    pkill -f "firebase" 2>/dev/null || true
    pkill -f "java.*firestore" 2>/dev/null || true
    sleep $FIREBASE_CLEANUP_TIMEOUT
    
    # Clean up Firebase hub locator files that cause false "multiple instances" warnings
    log_info "Cleaning up Firebase hub locator files..."
    find /var/folders -name "*hub-${FIREBASE_PROJECT_ID:-*}*" -delete 2>/dev/null || true
    find /tmp -name "*hub-${FIREBASE_PROJECT_ID:-*}*" -delete 2>/dev/null || true
    find /var/tmp -name "*hub-${FIREBASE_PROJECT_ID:-*}*" -delete 2>/dev/null || true
    
    log_success "Cleanup completed"
}

# Function to load essential services from file
load_essential_services() {
    local essential_file=""

    # Check multiple possible locations for essential services file
    if [ -n "$PROJECT_ROOT" ] && [ -f "$PROJECT_ROOT/essential-pipeline-services.txt" ]; then
        essential_file="$PROJECT_ROOT/essential-pipeline-services.txt"
    elif [ -f "$SCRIPT_DIR/../../../essential-pipeline-services.txt" ]; then
        essential_file="$SCRIPT_DIR/../../../essential-pipeline-services.txt"
    elif [ -f "$SCRIPT_DIR/../../essential-pipeline-services.txt" ]; then
        essential_file="$SCRIPT_DIR/../../essential-pipeline-services.txt"
    fi

    if [ -f "$essential_file" ]; then
        log_info "Loading essential services from: $essential_file"
        # Read services from file and create FIREBASE_SERVICES array
        FIREBASE_SERVICES=()
        local port_counter=5001
        while IFS= read -r service_name; do
            # Skip empty lines and comments
            if [ -n "$service_name" ] && [[ ! "$service_name" =~ ^# ]]; then
                FIREBASE_SERVICES+=("$service_name:$port_counter")
                ((port_counter++))
            fi
        done < "$essential_file"
        log_success "Loaded ${#FIREBASE_SERVICES[@]} essential services"
    else
        log_warning "⚠️  Essential services file not found"
        log_info "Searched for essential-pipeline-services.txt in:"
        log_info "  - $PROJECT_ROOT/essential-pipeline-services.txt"
        log_info "  - $SCRIPT_DIR/../../../essential-pipeline-services.txt"
        log_info "  - $SCRIPT_DIR/../../essential-pipeline-services.txt"
        echo ""
        read -p "Enter path to essential services file (or press Enter to use default services): " user_file
        if [ -n "$user_file" ] && [ -f "$user_file" ]; then
            log_info "Using user-specified file: $user_file"
            FIREBASE_SERVICES=()
            local port_counter=5001
            while IFS= read -r service_name; do
                if [ -n "$service_name" ] && [[ ! "$service_name" =~ ^# ]]; then
                    FIREBASE_SERVICES+=("$service_name:$port_counter")
                    ((port_counter++))
                fi
            done < "$user_file"
            log_success "Loaded ${#FIREBASE_SERVICES[@]} services from user file"
        else
            log_warning "Using default services from config.sh"
        fi
    fi
}

# Function to install dependencies for all services
install_dependencies() {
    log_header "Installing Dependencies"

    # Load essential services first
    load_essential_services

    # Go to the main project directory
    if [ -n "$PROJECT_ROOT" ] && [ -d "$PROJECT_ROOT" ]; then
        cd "$PROJECT_ROOT"
    else
        cd "$SCRIPT_DIR/../../.."
    fi

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

# Function to prepare emulator-specific function files
prepare_emulator_functions() {
    log_header "Preparing Emulator-Specific Functions"

    # Go to the main project directory
    if [ -n "$PROJECT_ROOT" ] && [ -d "$PROJECT_ROOT" ]; then
        cd "$PROJECT_ROOT"
    else
        cd "$SCRIPT_DIR/../../.."
    fi

    local prepared_count=0
    local total_services=${#FIREBASE_SERVICES[@]}

    for service_config in "${FIREBASE_SERVICES[@]}"; do
        IFS=':' read -r service_name port <<< "$service_config"
        local service_dir="services/$service_name"

        if [ -d "$service_dir" ]; then
            # Check if index-emulator.js exists
            if [ -f "$service_dir/index-emulator.js" ]; then
                log_info "Preparing emulator functions for $service_name..."

                # Backup original index.js if it exists
                if [ -f "$service_dir/index.js" ]; then
                    cp "$service_dir/index.js" "$service_dir/index-production.js.backup" 2>/dev/null || true
                fi

                # Use index-emulator.js as index.js for emulator mode
                cp "$service_dir/index-emulator.js" "$service_dir/index.js"
                log_success "✅ $service_name now using emulator functions"
                ((prepared_count++))
            else
                log_info "ℹ️  $service_name using production functions (no emulator file)"
            fi
        fi
    done

    log_success "Prepared emulator functions for $prepared_count/$total_services services"
}

# Function to restore production function files
restore_production_functions() {
    log_info "Restoring production function files..."

    # Go to the main project directory
    if [ -n "$PROJECT_ROOT" ] && [ -d "$PROJECT_ROOT" ]; then
        cd "$PROJECT_ROOT"
    else
        cd "$SCRIPT_DIR/../../.."
    fi

    for service_config in "${FIREBASE_SERVICES[@]}"; do
        IFS=':' read -r service_name port <<< "$service_config"
        local service_dir="services/$service_name"

        if [ -d "$service_dir" ] && [ -f "$service_dir/index-production.js.backup" ]; then
            mv "$service_dir/index-production.js.backup" "$service_dir/index.js"
            log_info "Restored production functions for $service_name"
        fi
    done
}

# Function to start single Firebase emulator with all functions
start_firebase_emulator() {
    log_header "Starting Single Firebase Emulator with All Functions"

    # Set trap to restore production functions on exit
    trap 'restore_production_functions' EXIT INT TERM

    # Prepare emulator-specific functions
    prepare_emulator_functions

    # Go to the project directory where firebase.json is located
    if [ -n "$PROJECT_ROOT" ] && [ -d "$PROJECT_ROOT" ]; then
        cd "$PROJECT_ROOT"
        log_info "Changed to project directory: $PROJECT_ROOT"
    else
        log_warning "PROJECT_ROOT not set or doesn't exist, using firebase-scripts directory"
        cd "$SCRIPT_DIR/.."
    fi
    
    # Set environment variables
    export FIRESTORE_EMULATOR_HOST="localhost:$FIREBASE_EMULATOR_PORT"
    export FIRESTORE_PROJECT_ID="$FIREBASE_PROJECT_ID"
    export FUNCTIONS_EMULATOR="true"
    export NODE_ENV="development"
  
  # Optional: limit which functions to load and whether to start the UI, controlled via env
  # - FUNCTIONS_FILTER: comma-separated list of function ids (e.g., "category_extraction,product_extraction_pubsub")

  # - FUNCTION_MAX_INSTANCES / FUNCTION_CONCURRENCY: passed through to functions as env (for app-level caps)
  if [ -n "$FUNCTION_MAX_INSTANCES" ]; then
    log_info "Function maxInstances (env) = $FUNCTION_MAX_INSTANCES"
    export FUNCTION_MAX_INSTANCES
  fi
  if [ -n "$FUNCTION_CONCURRENCY" ]; then
    log_info "Function concurrency (env) = $FUNCTION_CONCURRENCY"
    export FUNCTION_CONCURRENCY
  fi

  local functions_only_arg="functions"
  if [ -n "$FUNCTIONS_FILTER" ]; then
    log_info "Loading only functions: $FUNCTIONS_FILTER"
    functions_only_arg="functions:$FUNCTIONS_FILTER"
  fi

  local only_list="$functions_only_arg,firestore,pubsub,ui"
    
  log_info "Starting Firebase emulator with: --only $only_list"
    FIRESTORE_EMULATOR_HOST="localhost:$FIREBASE_EMULATOR_PORT" \
    FIRESTORE_PROJECT_ID="$FIREBASE_PROJECT_ID" \
    FUNCTIONS_EMULATOR="true" \
    PUBSUB_EMULATOR_HOST="localhost:8085" \
  firebase emulators:start --only "$only_list" --project "$FIREBASE_PROJECT_ID" &
    
    local emulator_pid=$!
    
    # Wait for emulator to start
    log_info "Waiting for Firebase emulator to start (${FIREBASE_STARTUP_TIMEOUT}s)..."
    local attempts=0
    while [ $attempts -lt 30 ]; do
        local main_emulator_ready=false
        if curl -s "http://localhost:$FIREBASE_EMULATOR_PORT" > /dev/null 2>&1; then
            main_emulator_ready=true
        fi

        local pubsub_emulator_ready=false
        if curl -s "http://localhost:8085" > /dev/null 2>&1; then # Check Pub/Sub port 8085
            pubsub_emulator_ready=true
        fi

            if $main_emulator_ready && $pubsub_emulator_ready; then
        log_success "✅ Firebase emulator (including Pub/Sub) started successfully"
        

        
        return 0
    fi

        sleep 2
        attempts=$((attempts + 1))
    done
    
    log_error "❌ Firebase emulator (including Pub/Sub) failed to start within timeout"
    return 1
}



# Function to check service health
check_service_health() {
    log_header "Checking Service Health"
    
    # Wait for services to be ready
    log_info "Waiting for services to be ready..."
    sleep 15
    
    local healthy_count=0
    local total_services=${#FIREBASE_SERVICES[@]}
    
    for service_config in "${FIREBASE_SERVICES[@]}"; do
        IFS=':' read -r service_name port <<< "$service_config"
        local function_name=$(echo "$service_name" | sed 's/-service$//' | sed 's/-/_/g')
        local health_url="http://localhost:5001/$FIREBASE_PROJECT_ID-$function_name/$FIREBASE_REGION/health"
        
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
            local health_url="http://localhost:5001/$FIREBASE_PROJECT_ID-$function_name/$FIREBASE_REGION/health"
            
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

# Main function
main() {
    log_header "Starting Firebase Emulator (Local)"
    
    # Check ports
    if ! check_ports; then
        exit 1
    fi
    
    # Cleanup existing processes
    cleanup_firebase
    
    # Install dependencies
    install_dependencies
    
    # Start single Firebase emulator
    if ! start_firebase_emulator; then
        exit 1
    fi
    
    # Check service health
    check_service_health
    
    # Summary
    log_header "Firebase Emulator Started Successfully"
    log_info "Services available at:"
    echo "  Firestore: http://localhost:$FIREBASE_EMULATOR_PORT"
    echo "  Firebase UI: http://127.0.0.1:$FIREBASE_UI_PORT"
    echo "  Emulator Hub: http://127.0.0.1:$FIREBASE_HUB_PORT"
    echo "  Functions: http://localhost:5001"
    echo "  Pub/Sub: localhost:8085"
    echo ""
    log_info "To stop emulator: ./scripts/firebase/local/stop-emulator.sh"
    log_info "You can now run your pipeline scripts"
    log_info "To test Pub/Sub: node verify-pubsub-topics.js"
}

# Run main function
main "$@" 
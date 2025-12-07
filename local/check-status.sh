#!/bin/bash

# Generic Firebase Status Check Script (Local)
# This script checks the status of local Firebase emulator and services

# Source configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Try to source project-specific config first, fall back to generic config
if [ -f "$SCRIPT_DIR/../project-config.sh" ]; then
    source "$SCRIPT_DIR/../project-config.sh"
else
    source "$SCRIPT_DIR/../config.sh"
fi

# Function to check if a port is in use
check_port_status() {
    local port=$1
    local service_name=$2
    
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
        log_success "✅ $service_name (Port $port): RUNNING"
        return 0
    else
        log_error "❌ $service_name (Port $port): STOPPED"
        return 1
    fi
}

# Function to check service health
check_service_health() {
    local endpoint=$1
    local service_name=$2
    
    if curl -s "$endpoint" > /dev/null 2>&1; then
        log_success "✅ $service_name: HEALTHY"
        return 0
    else
        log_warning "⚠️  $service_name: UNHEALTHY"
        return 1
    fi
}

# Function to check Firebase processes
check_firebase_processes() {
    log_info "Checking Firebase processes..."
    
    local firebase_processes=$(pgrep -f "firebase" | wc -l)
    local firestore_processes=$(pgrep -f "java.*firestore" | wc -l)
    
    if [ $firebase_processes -gt 0 ]; then
        log_success "✅ Firebase processes: $firebase_processes running"
    else
        log_error "❌ Firebase processes: None running"
    fi
    
    if [ $firestore_processes -gt 0 ]; then
        log_success "✅ Firestore emulator: $firestore_processes running"
    else
        log_error "❌ Firestore emulator: None running"
    fi
}

# Function to check port status
check_ports_status() {
    log_info "Checking port status..."
    
    local running_ports=0
    local total_ports=${#FIREBASE_PORTS[@]}
    
    for port in "${FIREBASE_PORTS[@]}"; do
        if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
            ((running_ports++))
        fi
    done
    
    log_info "Ports: $running_ports/$total_ports active"
    
    # Check specific important ports
    check_port_status "8080" "Firestore"
    check_port_status "4000" "Firebase UI"
    check_port_status "4400" "Emulator Hub"
}

# Function to check service health
check_services_health() {
    log_info "Checking service health..."
    
    local healthy_services=0
    local total_services=${#FIREBASE_HEALTH_ENDPOINTS[@]}
    
    for endpoint in "${FIREBASE_HEALTH_ENDPOINTS[@]}"; do
        if curl -s "$endpoint" > /dev/null 2>&1; then
            ((healthy_services++))
        fi
    done
    
    log_info "Services: $healthy_services/$total_services healthy"
    
    # Check specific services
    check_service_health "http://localhost:5001/$FIREBASE_PROJECT_ID/$FIREBASE_REGION/category_extraction" "Category Extraction"
    check_service_health "http://localhost:5001/$FIREBASE_PROJECT_ID/$FIREBASE_REGION/product_extraction" "Product Extraction"
    check_service_health "http://localhost:5001/$FIREBASE_PROJECT_ID/$FIREBASE_REGION/embedding_service" "Embedding Service"
    check_service_health "http://localhost:5001/$FIREBASE_PROJECT_ID/$FIREBASE_REGION/orchestrator" "Orchestrator"
    check_service_health "http://localhost:5001/$FIREBASE_PROJECT_ID/$FIREBASE_REGION/sustainability_analysis" "Sustainability Analysis"
    check_service_health "http://localhost:5001/$FIREBASE_PROJECT_ID/$FIREBASE_REGION/eprel_enrichment" "EPREL Enrichment"
    check_service_health "http://localhost:5001/$FIREBASE_PROJECT_ID/$FIREBASE_REGION/oecd_sustainability" "OECD Sustainability"
    check_service_health "http://localhost:5001/$FIREBASE_PROJECT_ID/$FIREBASE_REGION/product_image" "Product Image"
    check_service_health "http://localhost:5001/$FIREBASE_PROJECT_ID/$FIREBASE_REGION/health" "Main Health Check"
}

# Function to check Firestore connection
check_firestore_connection() {
    log_info "Checking Firestore connection..."
    
    if curl -s "http://localhost:$FIREBASE_EMULATOR_PORT" > /dev/null 2>&1; then
        log_success "✅ Firestore emulator is responding"
        return 0
    else
        log_error "❌ Firestore emulator is not responding"
        return 1
    fi
}

# Function to check Firebase UI
check_firebase_ui() {
    log_info "Checking Firebase UI..."
    
    if curl -s "http://$FIREBASE_EMULATOR_HOST:$FIREBASE_UI_PORT" > /dev/null 2>&1; then
        log_success "✅ Firebase UI is accessible"
        return 0
    else
        log_warning "⚠️  Firebase UI is not accessible"
        return 1
    fi
}

# Function to get summary
get_summary() {
    local firebase_processes=$(pgrep -f "firebase" | wc -l)
    local firestore_processes=$(pgrep -f "java.*firestore" | wc -l)
    local running_ports=0
    local healthy_services=0
    
    for port in "${FIREBASE_PORTS[@]}"; do
        if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
            ((running_ports++))
        fi
    done
    
    for endpoint in "${FIREBASE_HEALTH_ENDPOINTS[@]}"; do
        if curl -s "$endpoint" > /dev/null 2>&1; then
            ((healthy_services++))
        fi
    done
    
    log_header "Status Summary"
    echo "  Firebase Processes: $firebase_processes"
    echo "  Firestore Processes: $firestore_processes"
    echo "  Active Ports: $running_ports/${#FIREBASE_PORTS[@]}"
    echo "  Healthy Services: $healthy_services/${#FIREBASE_HEALTH_ENDPOINTS[@]}"
    echo ""
    
    if [ $firebase_processes -gt 0 ] && [ $firestore_processes -gt 0 ] && [ $running_ports -gt 5 ]; then
        log_success "🎉 Firebase emulator is running properly"
        return 0
    else
        log_error "💥 Firebase emulator has issues"
        return 1
    fi
}

# Main function
main() {
    log_header "Firebase Emulator Status Check (Local)"
    
    # Check Firebase processes
    check_firebase_processes
    
    # Check ports
    check_ports_status
    
    # Check Firestore connection
    check_firestore_connection
    
    # Check Firebase UI
    check_firebase_ui
    
    # Check service health
    check_services_health
    
    # Get summary
    get_summary
}

# Run main function
main "$@" 
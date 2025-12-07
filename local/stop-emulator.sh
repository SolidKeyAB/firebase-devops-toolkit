#!/bin/bash

# Generic Firebase Emulator Stop Script (Local)
# This script stops Firebase emulators locally and can be reused across projects

# Source configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Try to source project-specific config first, fall back to generic config
if [ -f "$SCRIPT_DIR/../project-config.sh" ]; then
    source "$SCRIPT_DIR/../project-config.sh"
else
    source "$SCRIPT_DIR/../config.sh"
fi

# Function to stop Firebase emulator
stop_emulator() {
    log_info "Stopping Firebase emulator..."
    
    # Kill all firebase emulator processes
    pkill -f "firebase" 2>/dev/null || true
    pkill -f "java.*firestore" 2>/dev/null || true
    
    # Kill processes on specific ports
    for port in "${FIREBASE_PORTS[@]}"; do
        lsof -ti:$port | xargs kill -9 2>/dev/null || true
    done
    
    # Kill any remaining node processes that might be running our services
    pkill -f "run-complete-brand-pipeline" 2>/dev/null || true
    pkill -f "quick-status" 2>/dev/null || true
    pkill -f "monitor-pipeline" 2>/dev/null || true
    
    # Wait for processes to stop
    sleep $FIREBASE_CLEANUP_TIMEOUT
    
    log_success "Firebase emulator stopped"
}

# Function to check if emulator is still running
check_emulator_status() {
    log_info "Checking emulator status..."
    
    local running_processes=0
    
    # Check for Firebase processes
    if pgrep -f "firebase" > /dev/null; then
        log_warning "Firebase processes are still running"
        running_processes=$((running_processes + 1))
    fi
    
    # Check for Java Firestore processes
    if pgrep -f "java.*firestore" > /dev/null; then
        log_warning "Firestore emulator is still running"
        running_processes=$((running_processes + 1))
    fi
    
    # Check ports
    for port in "${FIREBASE_PORTS[@]}"; do
        if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
            log_warning "Port $port is still in use"
            running_processes=$((running_processes + 1))
        fi
    done
    
    if [ $running_processes -eq 0 ]; then
        log_success "All Firebase emulator processes stopped"
        return 0
    else
        log_warning "$running_processes processes/ports still active"
        return 1
    fi
}

# Function to force kill if needed
force_kill() {
    log_info "Force killing remaining processes..."
    
    # Force kill all Firebase related processes
    pkill -9 -f "firebase" 2>/dev/null || true
    pkill -9 -f "java.*firestore" 2>/dev/null || true
    
    # Force kill processes on ports
    for port in "${FIREBASE_PORTS[@]}"; do
        lsof -ti:$port | xargs kill -9 2>/dev/null || true
    done
    
    sleep 2
    log_success "Force kill completed"
}

# Main function
main() {
    log_header "Stopping Firebase Emulator (Local)"
    
    # Stop emulator
    stop_emulator
    
    # Check status
    if ! check_emulator_status; then
        log_warning "Some processes may still be running"
        read -p "Force kill remaining processes? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            force_kill
            check_emulator_status
        fi
    fi
    
    log_header "Firebase Emulator Stopped"
    log_info "All services have been stopped"
}

# Run main function
main "$@" 
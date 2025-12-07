#!/bin/bash

# Resource Monitoring Script for Firebase Emulator
# This script monitors resource usage and prevents overload

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config.sh"

# Resource limits
MAX_MEMORY_MB=1024
MAX_CPU_PERCENT=80
MAX_NODE_PROCESSES=20

log_info() {
    echo "ℹ️  $1"
}

log_warning() {
    echo "⚠️  $1"
}

log_error() {
    echo "❌ $1"
}

log_success() {
    echo "✅ $1"
}

# Function to check memory usage
check_memory() {
    local memory_usage=$(ps -o rss= -p $(pgrep -f "firebase.*emulator" | head -1) 2>/dev/null | awk '{print int($1/1024)}')
    if [ ! -z "$memory_usage" ] && [ "$memory_usage" -gt "$MAX_MEMORY_MB" ]; then
        log_warning "High memory usage: ${memory_usage}MB (limit: ${MAX_MEMORY_MB}MB)"
        return 1
    fi
    return 0
}

# Function to check CPU usage
check_cpu() {
    local cpu_usage=$(ps -o %cpu= -p $(pgrep -f "firebase.*emulator" | head -1) 2>/dev/null | awk '{print int($1)}')
    if [ ! -z "$cpu_usage" ] && [ "$cpu_usage" -gt "$MAX_CPU_PERCENT" ]; then
        log_warning "High CPU usage: ${cpu_usage}% (limit: ${MAX_CPU_PERCENT}%)"
        return 1
    fi
    return 0
}

# Function to check Node.js processes
check_node_processes() {
    local node_count=$(pgrep -c "node.*firebase" 2>/dev/null || echo "0")
    if [ "$node_count" -gt "$MAX_NODE_PROCESSES" ]; then
        log_warning "Too many Node.js processes: $node_count (limit: $MAX_NODE_PROCESSES)"
        return 1
    fi
    return 0
}

# Function to cleanup excess processes
cleanup_excess_processes() {
    local node_processes=$(pgrep -f "node.*firebase" 2>/dev/null)
    if [ ! -z "$node_processes" ]; then
        local count=$(echo "$node_processes" | wc -l)
        if [ "$count" -gt "$MAX_NODE_PROCESSES" ]; then
            log_warning "Cleaning up excess Node.js processes..."
            echo "$node_processes" | tail -n +$((MAX_NODE_PROCESSES + 1)) | xargs kill -9 2>/dev/null
            log_success "Cleaned up excess processes"
        fi
    fi
}

# Function to monitor resources continuously
monitor_resources() {
    log_info "Starting resource monitoring..."
    
    while true; do
        # Check all resource metrics
        local issues_found=false
        
        if ! check_memory; then
            issues_found=true
        fi
        
        if ! check_cpu; then
            issues_found=true
        fi
        
        if ! check_node_processes; then
            issues_found=true
            cleanup_excess_processes
        fi
        
        if [ "$issues_found" = true ]; then
            log_warning "Resource issues detected - consider restarting emulator"
        else
            log_success "Resources OK - Memory: $(ps -o rss= -p $(pgrep -f "firebase.*emulator" | head -1) 2>/dev/null | awk '{print $1/1024}')MB, CPU: $(ps -o %cpu= -p $(pgrep -f "firebase.*emulator" | head -1) 2>/dev/null)%"
        fi
        
        # Wait before next check
        sleep 30
    done
}

# Main execution
case "${1:-monitor}" in
    "monitor")
        monitor_resources
        ;;
    "check")
        check_memory && check_cpu && check_node_processes
        if [ $? -eq 0 ]; then
            log_success "All resource checks passed"
        else
            log_error "Resource issues detected"
            exit 1
        fi
        ;;
    "cleanup")
        cleanup_excess_processes
        ;;
    *)
        echo "Usage: $0 [monitor|check|cleanup]"
        exit 1
        ;;
esac

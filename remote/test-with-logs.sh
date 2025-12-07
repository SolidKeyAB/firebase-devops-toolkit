#!/bin/bash

# 🚀 TEST PIPELINE WITH REAL-TIME LOGS
# This script runs the pipeline test and watches logs simultaneously

echo "🚀 Testing ESG Pipeline with Real-Time Logs"
echo "=========================================="

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to run the pipeline test
run_pipeline_test() {
    print_info "Running pipeline test..."
    node test-complete-pipeline.js
    print_success "Pipeline test completed!"
}

# Function to watch logs in background
watch_logs_background() {
    print_info "Starting log watcher in background..."
    
    # Create a temporary log file
    LOG_FILE="/tmp/firebase-logs-$(date +%s).log"
    
    # Start watching logs in background (use PROJECT_ID env or default)
    firebase functions:log --project "${PROJECT_ID:-your-firebase-project-id}" --follow > "$LOG_FILE" 2>&1 &
    LOG_PID=$!
    
    print_success "Log watcher started (PID: $LOG_PID)"
    print_info "Logs are being saved to: $LOG_FILE"
    
    # Wait a moment for logs to start
    sleep 3
    
    return $LOG_PID
}

# Function to monitor log file in real-time
monitor_logs() {
    local log_file=$1
    print_info "Monitoring logs in real-time..."
    
    # Use tail to follow the log file
    tail -f "$log_file" | grep -E "(🎯|✅|❌|trigger|orchestrator|category|product|embedding|sustainability)" --color=always
}

# Function to show log summary
show_log_summary() {
    local log_file=$1
    print_info "=== LOG SUMMARY ==="
    
    if [ -f "$log_file" ]; then
        echo ""
        echo "🎯 Trigger Events:"
        grep -c "🎯" "$log_file" || echo "0"
        
        echo "✅ Success Events:"
        grep -c "✅" "$log_file" || echo "0"
        
        echo "❌ Error Events:"
        grep -c "❌" "$log_file" || echo "0"
        
        echo ""
        echo "📊 Recent Activity:"
        tail -10 "$log_file" | grep -E "(🎯|✅|❌)" --color=always
    else
        print_warning "No log file found"
    fi
}

# Main execution
echo ""
print_info "Step 1: Starting log watcher in background..."
LOG_PID=$(watch_logs_background)

echo ""
print_info "Step 2: Running pipeline test..."
run_pipeline_test

echo ""
print_info "Step 3: Monitoring logs in real-time..."
print_info "Press Ctrl+C to stop monitoring and see summary"
echo ""

# Monitor logs for 30 seconds
timeout 30s tail -f "/tmp/firebase-logs-$(date +%s).log" | grep -E "(🎯|✅|❌|trigger|orchestrator|category|product|embedding|sustainability)" --color=always || true

echo ""
print_info "Step 4: Showing log summary..."
show_log_summary "/tmp/firebase-logs-$(date +%s).log"

echo ""
print_success "🎉 Pipeline test with logs completed!"
print_info "You can continue monitoring logs manually with:"
print_info "  firebase functions:log --project \"${PROJECT_ID:-your-firebase-project-id}\" --follow"
print_info "  ./watch-logs.sh" 
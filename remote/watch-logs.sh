#!/bin/bash

# 🎯 REAL-TIME FIREBASE FUNCTIONS LOG WATCHER
# This script watches logs by polling in real-time during pipeline execution

echo "🎯 Starting real-time log watcher..."
echo "Press Ctrl+C to stop watching logs"
echo ""

# Colors for output
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

# Function to watch all function logs with polling
watch_all_logs() {
    print_info "Watching ALL function logs in real-time (polling every 5 seconds)..."
    local project_id="${PROJECT_ID:-${FIREBASE_PROJECT:-your-firebase-project-id}}"
    while true; do
        firebase functions:log --project "$project_id" --lines 10
        echo ""
        echo "⏳ Waiting 5 seconds for new logs..."
        sleep 5
        clear
    done
}

# Function to watch specific function logs with polling
watch_specific_logs() {
    local function_name=$1
    print_info "Watching logs for function: $function_name (polling every 5 seconds)..."
    local project_id="${PROJECT_ID:-${FIREBASE_PROJECT:-your-firebase-project-id}}"
    while true; do
        firebase functions:log --project "$project_id" --only "$function_name" --lines 10
        echo ""
        echo "⏳ Waiting 5 seconds for new logs..."
        sleep 5
        clear
    done
}

# Function to watch trigger logs with polling
watch_trigger_logs() {
    print_info "Watching Firestore trigger logs (polling every 5 seconds)..."
    local project_id="${PROJECT_ID:-${FIREBASE_PROJECT:-your-firebase-project-id}}"
    while true; do
        firebase functions:log --project "$project_id" --only triggerOrchestratorOnBrandUpdate,triggerOrchestratorOnControl,triggerCategoryExtraction,triggerProductExtraction --lines 10
        echo ""
        echo "⏳ Waiting 5 seconds for new logs..."
        sleep 5
        clear
    done
}

# Function to watch orchestrator logs with polling
watch_orchestrator_logs() {
    print_info "Watching orchestrator logs (polling every 5 seconds)..."
    local project_id="${PROJECT_ID:-${FIREBASE_PROJECT:-your-firebase-project-id}}"
    while true; do
        firebase functions:log --project "$project_id" --only orchestratorService --lines 10
        echo ""
        echo "⏳ Waiting 5 seconds for new logs..."
        sleep 5
        clear
    done
}

# Function to watch service logs with polling
watch_service_logs() {
    print_info "Watching service logs (polling every 5 seconds)..."
    local project_id="${PROJECT_ID:-${FIREBASE_PROJECT:-your-firebase-project-id}}"
    while true; do
        firebase functions:log --project "$project_id" --only categoryExtraction,productExtraction,embeddingService,sustainabilityEnrichment --lines 10
        echo ""
        echo "⏳ Waiting 5 seconds for new logs..."
        sleep 5
        clear
    done
}

# Main menu
echo "🎯 Choose what to watch:"
echo "1. All function logs"
echo "2. Firestore trigger logs only"
echo "3. Orchestrator logs only"
echo "4. Service logs only"
echo "5. Custom function logs"
echo ""

read -p "Enter your choice (1-5): " choice

case $choice in
    1)
        watch_all_logs
        ;;
    2)
        watch_trigger_logs
        ;;
    3)
        watch_orchestrator_logs
        ;;
    4)
        watch_service_logs
        ;;
    5)
        echo ""
    echo "Available functions:"
    local project_id="${PROJECT_ID:-${FIREBASE_PROJECT:-your-firebase-project-id}}"
    firebase functions:list --project "$project_id" | grep -E "(trigger|orchestrator|category|product|embedding|sustainability)" | head -10
        echo ""
        read -p "Enter function name: " function_name
        watch_specific_logs $function_name
        ;;
    *)
        print_error "Invalid choice. Exiting."
        exit 1
        ;;
esac 
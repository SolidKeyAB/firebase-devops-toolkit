#!/bin/bash

# Setup Pub/Sub Topics for Firebase Emulator
# This script creates the required Pub/Sub topics that the orchestrator service needs

# Source configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Try to source project-specific config first, fall back to generic config
if [ -f "$SCRIPT_DIR/../project-config.sh" ]; then
    source "$SCRIPT_DIR/../project-config.sh"
else
    source "$SCRIPT_DIR/../config.sh"
fi

# Function to log messages
log_info() {
    echo "ℹ️  $1"
}

log_success() {
    echo "✅ $1"
}

log_warning() {
    echo "⚠️  $1"
}

log_error() {
    echo "❌ $1"
}

log_header() {
    echo ""
    echo "🔧 $1"
    echo "=================================="
}

# Function to check if Pub/Sub emulator is running
check_pubsub_emulator() {
    log_info "Checking if Pub/Sub emulator is running..."
    
    if curl -s "http://localhost:8085" > /dev/null 2>&1; then
        log_success "Pub/Sub emulator is running on port 8085"
        return 0
    else
        log_error "Pub/Sub emulator is not running on port 8085"
        log_info "Please start the Firebase emulator first:"
        log_info "  ./firebase-scripts/local/start-emulator.sh"
        return 1
    fi
}

# Function to create a Pub/Sub topic
create_topic() {
    local topic_name=$1
    local project_id=$2
    
    log_info "Attempting to create topic: $topic_name"
    
    # For local emulator, we should use HTTP API directly, not gcloud
    # gcloud with --project flag still tries to connect to real Google Cloud
    
    # Check if topic already exists via HTTP API
    local check_response=$(curl -s -w "%{http_code}" \
        "http://localhost:8085/v1/projects/$project_id/topics/$topic_name" \
        -H "Content-Type: application/json" 2>/dev/null)
    
    local http_code="${check_response: -3}"
    local response_body="${check_response%???}"
    
    if [ "$http_code" = "200" ]; then
        log_success "Topic $topic_name already exists. Skipping creation."
        return 0
    fi
    
    # Create topic via HTTP API (this is the correct way for local emulator)
    log_info "Creating topic via local emulator HTTP API..."
    local create_response=$(curl -s -w "%{http_code}" -X PUT \
        "http://localhost:8085/v1/projects/$project_id/topics/$topic_name" \
        -H "Content-Type: application/json" \
        -d '{}' 2>/dev/null)
    
    local create_http_code="${create_response: -3}"
    local create_response_body="${create_response%???}"
    
    if [ "$create_http_code" = "200" ] || [ "$create_http_code" = "409" ]; then
        log_success "Created topic: $topic_name via local emulator"
        return 0
    else
        log_error "Failed to create topic: $topic_name via local emulator. HTTP Code: $create_http_code, Response: $create_response_body"
        return 1
    fi
}

# Function to create a Pub/Sub subscription
create_subscription() {
    local topic_name=$1
    local subscription_name=$2
    local project_id=$3
    
    log_info "Attempting to create subscription: $subscription_name for topic: $topic_name"
    
    # For local emulator, we should use HTTP API directly, not gcloud
    # gcloud with --project flag still tries to connect to real Google Cloud
    
    # Check if subscription already exists via HTTP API
    local check_response=$(curl -s -w "%{http_code}" \
        "http://localhost:8085/v1/projects/$project_id/subscriptions/$subscription_name" \
        -H "Content-Type: application/json" 2>/dev/null)
    
    local http_code="${check_response: -3}"
    local response_body="${check_response%???}"
    
    if [ "$http_code" = "200" ]; then
        log_success "Subscription $subscription_name already exists. Skipping creation."
        return 0
    fi
    
    # Create subscription via HTTP API (this is the correct way for local emulator)
    log_info "Creating subscription via local emulator HTTP API..."
    local create_response=$(curl -s -w "%{http_code}" -X PUT \
        "http://localhost:8085/v1/projects/$project_id/subscriptions/$subscription_name" \
        -H "Content-Type: application/json" \
        -d "{\"topic\": \"projects/$project_id/topics/$topic_name\", \"ackDeadlineSeconds\": 10}" 2>/dev/null)
    
    local create_http_code="${create_response: -3}"
    local create_response_body="${create_response%???}"
    
    if [ "$create_http_code" = "200" ] || [ "$create_http_code" = "409" ]; then
        log_success "Created subscription: $subscription_name via local emulator"
        return 0
    else
        log_error "Failed to create subscription: $subscription_name via local emulator. HTTP Code: $create_http_code, Response: $create_response_body"
        return 1
    fi
}

# Function to list existing topics
list_topics() {
    local project_id=$1
    
    log_info "Listing existing topics in project: $project_id"
    
    # Use local emulator HTTP API instead of gcloud
    local response=$(curl -s "http://localhost:8085/v1/projects/$project_id/topics" \
        -H "Content-Type: application/json" 2>/dev/null)
    
    if [ $? -eq 0 ] && [ -n "$response" ]; then
        # Use jq to parse JSON response properly
        if command -v jq &> /dev/null; then
            local topics=$(echo "$response" | jq -r '.topics[].name' 2>/dev/null | sed "s|projects/$project_id/topics/||g")
            if [ -n "$topics" ]; then
                echo "$topics" | while read -r topic; do
                    echo "  📢 $topic"
                done
                local topic_count=$(echo "$topics" | wc -l | tr -d ' ')
                log_success "Found $topic_count topics"
            else
                log_info "No topics found in response"
            fi
        else
            # Fallback to grep if jq is not available
            if echo "$response" | grep -q '"topics"'; then
                local topics=$(echo "$response" | grep -o '"name":"[^"]*"' | sed 's/"name":"//g' | sed 's/"//g' | sed "s|projects/$project_id/topics/||g")
                if [ -n "$topics" ]; then
                    echo "$topics" | while read -r topic; do
                        echo "  📢 $topic"
                    done
                    local topic_count=$(echo "$topics" | wc -l | tr -d ' ')
                    log_success "Found $topic_count topics"
                else
                    log_info "No topics found in response"
                fi
            else
                log_info "No topics found in response"
            fi
        fi
    else
        log_info "No topics found or error occurred"
        log_info "This is normal for a fresh emulator"
    fi
}

# Function to list existing subscriptions
list_subscriptions() {
    local project_id=$1
    
    log_info "Listing existing subscriptions in project: $project_id"
    
    # Use local emulator HTTP API instead of gcloud
    local response=$(curl -s "http://localhost:8085/v1/projects/$project_id/subscriptions" \
        -H "Content-Type: application/json" 2>/dev/null)
    
    if [ $? -eq 0 ] && [ -n "$response" ]; then
        # Use jq to parse JSON response properly
        if command -v jq &> /dev/null; then
            local subscriptions=$(echo "$response" | jq -r '.subscriptions[].name' 2>/dev/null | sed "s|projects/$project_id/subscriptions/||g")
            if [ -n "$subscriptions" ]; then
                echo "$subscriptions" | while read -r subscription; do
                    echo "  📨 $subscription"
                done
                local subscription_count=$(echo "$subscriptions" | wc -l | tr -d ' ')
                log_success "Found $subscription_count subscriptions"
            else
                log_info "No subscriptions found in response"
            fi
        else
            # Fallback to grep if jq is not available
            if echo "$response" | grep -q '"subscriptions"'; then
                local subscriptions=$(echo "$response" | grep -o '"name":"[^"]*"' | sed 's/"name":"//g' | sed 's/"//g' | sed "s|projects/$project_id/subscriptions/||g")
                if [ -n "$subscriptions" ]; then
                    echo "$subscriptions" | while read -r subscription; do
                        echo "  📨 $subscription"
                    done
                    local subscription_count=$(echo "$subscriptions" | wc -l | tr -d ' ')
                    log_success "Found $subscription_count subscriptions"
                else
                    log_info "No subscriptions found in response"
                fi
            else
                log_info "No subscriptions found in response"
            fi
        fi
    else
        log_info "No subscriptions found or error occurred"
        log_info "This is normal for a fresh emulator"
    fi
}

# Function to set up all required Pub/Sub topics and subscriptions
setup_all_pubsub_resources() { # Renamed main to setup_all_pubsub_resources
    log_header "Setting up Pub/Sub Topics for Firebase Emulator"
    
    # Check if Pub/Sub emulator is running
    if ! check_pubsub_emulator; then
        log_error "Pub/Sub emulator is not available. Cannot set up topics/subscriptions." # Changed exit to error log
        return 1 # Return an error status instead of exiting the entire script
    fi
    
    # Get project ID from config or use default
    local project_id=${FIREBASE_PROJECT_ID:-"your-project-id"}
    log_info "Using project ID: $project_id"
    
    # List existing topics
    list_topics "$project_id"
    
    # Define required topics and subscriptions for all services
    local topics=(
      
        "product-extraction-topic"
        "product-enrichment-topic"
        "sustainability-enrichment-topic"
        "eprel-enrichment-topic"
        "oecd-sustainability-topic"
        "fao-agricultural-topic"
        "product-image-topic"
        "orchestrator-topic"
  "category-extraction-topic"
        "ai-logging-topic"
        "embedding-generation-topic"
        "vector-search-topic"
        "yaml-correction-topic"
        "compliance-enrichment-topic"
        "on-demand-query-topic"
    )
    
    local subscriptions=(
        "emulator-sub-category-extraction-topic"
        "emulator-sub-product-extraction-topic"
        "emulator-sub-product-enrichment-topic"
        "emulator-sub-sustainability-enrichment-topic"
        "emulator-sub-eprel-enrichment-topic"
        "emulator-sub-oecd-sustainability-topic"
        "emulator-sub-fao-agricultural-topic"
        "emulator-sub-product-image-topic"
        "emulator-sub-orchestrator-topic"
        "emulator-sub-ai-logging-topic"
        "emulator-sub-embedding-generation-topic"
        "emulator-sub-vector-search-topic"
        "emulator-sub-yaml-correction-topic"
        "emulator-sub-compliance-enrichment-topic"
        "emulator-sub-on-demand-query-topic"
    )
    
    # Create topics
    log_header "Creating Required Topics"
    local topics_created=0
    local topics_failed=0
    
    for topic in "${topics[@]}"; do
        if create_topic "$topic" "$project_id"; then
            ((topics_created++))
        else
            ((topics_failed++))
        fi
    done
    
    # Create subscriptions
    log_header "Creating Required Subscriptions"
    local subscriptions_created=0
    local subscriptions_failed=0
    
    for i in "${!topics[@]}"; do
        local topic="${topics[$i]}"
        local subscription="${subscriptions[$i]}"
        
        if create_subscription "$topic" "$subscription" "$project_id"; then
            ((subscriptions_created++))
        else
            ((subscriptions_failed++))
        fi
    done
    
    # Summary
    log_header "Setup Summary"
    log_info "Topics created: $topics_created/${#topics[@]}"
    log_info "Subscriptions created: $subscriptions_created/${#subscriptions[@]}"
    
    if [ $topics_failed -eq 0 ] && [ $subscriptions_failed -eq 0 ]; then
        log_success "All Pub/Sub resources created successfully!"
        return 0 # Indicate success
    else
        log_warning "Some resources failed to create. Check the logs above."
        return 1 # Indicate failure
    fi
    
    # List final state
    log_header "Final State"
    list_topics "$project_id"
    list_subscriptions "$project_id"
    
    log_info ""
    log_info "Pub/Sub setup complete! The orchestrator service should now work properly."
    log_info "You can restart the orchestrator service to test the connection."
}

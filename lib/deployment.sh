#!/bin/bash

# Deployment Library - Core deployment functions for Firebase services
# Part of the manage.sh orchestration system

# Deploy from prepared directory with validation
deploy_from_directory() {
    local deployment_dir="$1"
    local project_id="$2"
    
    log_header "🚀 Deploying from Prepared Directory"
    log_info "Directory: $deployment_dir"
    log_info "Project: $project_id"
    
    # Clean deployment directory first
    clean_deployment_directory "$deployment_dir"
    
    # Validate deployment directory
    if ! validate_deployment_directory "$deployment_dir"; then
        log_error "Deployment directory validation failed"
        return 1
    fi
    
    # Change to deployment directory
    cd "$deployment_dir" || {
        log_error "Cannot access deployment directory: $deployment_dir"
        return 1
    }
    
    # Show deployment summary
    show_deployment_summary "$deployment_dir"
    
    # Confirm deployment
    echo ""
    log_warning "⚠️  About to deploy to production project: $project_id"
    read -p "Continue with deployment? (y/N): " confirm
    
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        log_info "Deployment cancelled by user"
        return 1
    fi
    
    # Create temporary directory for Firebase CLI dependencies (outside deployment)
    local temp_deps_dir="/tmp/firebase-deps-$(date +%s)"
    mkdir -p "$temp_deps_dir"
    
    # Install minimal Firebase CLI dependencies in separate location
    log_info "🔧 Installing minimal Firebase dependencies for CLI analysis..."
    (
        cd "$temp_deps_dir"
        npm init -y >/dev/null 2>&1
        npm install firebase-functions firebase-admin --production --silent >/dev/null 2>&1
    )
    
    # Set NODE_PATH to include our temp dependencies
    export NODE_PATH="$temp_deps_dir/node_modules:$NODE_PATH"
    
    log_success "✅ Minimal dependencies installed"
    
    # Deploy to Firebase (dependencies are resolved via NODE_PATH, not in deployment dir)
    log_info "🚀 Deploying to Firebase..."
    if firebase deploy --only functions --project "$project_id"; then
        log_success "🎉 Deployment completed successfully!"
        
        # Cleanup temporary dependencies directory
        log_info "🧹 Cleaning up temporary dependencies..."
        rm -rf "$temp_deps_dir"
        unset NODE_PATH
        
        # Show deployed functions
        show_deployed_functions "$project_id"
        
        return 0
    else
        log_error "❌ Deployment failed"
        return 1
    fi
}

# Show deployment summary before deploying
show_deployment_summary() {
    local deployment_dir="$1"
    
    echo ""
    log_header "📊 Deployment Summary"
    
    # Count services
    local service_count=$(find "$deployment_dir/services" -maxdepth 1 -type d ! -name "services" ! -name "__*" ! -name ".*" ! -name "libs" | wc -l | tr -d ' ')
    log_info "Services to deploy: $service_count"
    
    # List services
    echo "📁 Services:"
    find "$deployment_dir/services" -maxdepth 1 -type d ! -name "services" ! -name "__*" ! -name ".*" ! -name "libs" -exec basename {} \; | sort | sed 's/^/   - /'
    
    # Check for unwanted directories
    local unwanted=$(find "$deployment_dir/services" -maxdepth 1 -name "__*" -type d | wc -l | tr -d ' ')
    if [ "$unwanted" -gt 0 ]; then
        log_warning "⚠️  Found $unwanted unwanted directories:"
        find "$deployment_dir/services" -maxdepth 1 -name "__*" -type d -exec basename {} \; | sed 's/^/   - /'
    fi
    
    # Check deployment size
    local size=$(du -sh "$deployment_dir" | cut -f1)
    log_info "Deployment size: $size"
    
    # Check for essential services
    if [ -f "/tmp/essential-pipeline-services.txt" ]; then
        local essential_count=$(cat /tmp/essential-pipeline-services.txt | wc -l)
        log_info "Essential services expected: $essential_count"
        
        # Check if all essential services are present
        local missing_essential=""
        while IFS= read -r service; do
            if [ ! -d "$deployment_dir/services/$service" ]; then
                missing_essential="$missing_essential$service "
            fi
        done < /tmp/essential-pipeline-services.txt
        
        if [ -n "$missing_essential" ]; then
            log_warning "⚠️  Missing essential services: $missing_essential"
        else
            log_success "✅ All essential services present"
        fi
    fi
}

# Show deployed functions after successful deployment
show_deployed_functions() {
    local project_id="$1"
    
    log_info "📝 Deployed functions:"
    if command -v gcloud >/dev/null 2>&1; then
        gcloud functions list --project="$project_id" --format="table(name,status,trigger.eventTrigger.eventType,trigger.httpsTrigger:label=HTTP)" 2>/dev/null || {
            log_warning "Could not list functions with gcloud"
        }
    else
        log_info "Install gcloud CLI to see deployed functions list"
    fi
}

# Selective deployment - only deploy specified services
deploy_selective_services() {
    local deployment_dir="$1"
    local project_id="$2"
    local services_list="$3"  # Comma-separated or file path
    
    log_header "🎯 Selective Service Deployment"
    
    # Create temporary deployment with only selected services
    local temp_deployment="/tmp/selective-deployment-$(date +%s)"
    mkdir -p "$temp_deployment"
    
    # Copy base files
    cp -r "$deployment_dir"/{firebase.json,package.json,.env} "$temp_deployment/" 2>/dev/null || true
    mkdir -p "$temp_deployment/services"
    
    # Parse services list
    local services_array
    if [ -f "$services_list" ]; then
        # Read from file
        IFS=$'\n' read -d '' -r -a services_array < "$services_list" || true
    else
        # Parse comma-separated string
        IFS=',' read -r -a services_array <<< "$services_list"
    fi
    
    # Copy selected services
    for service in "${services_array[@]}"; do
        service=$(echo "$service" | xargs)  # trim whitespace
        if [ -d "$deployment_dir/services/$service" ]; then
            log_info "Including service: $service"
            cp -r "$deployment_dir/services/$service" "$temp_deployment/services/"
        else
            log_warning "Service not found: $service"
        fi
    done
    
    # Deploy from temporary directory
    deploy_from_directory "$temp_deployment" "$project_id"
    local result=$?
    
    # Cleanup
    rm -rf "$temp_deployment"
    
    return $result
}

# Clean deployment directory by removing unwanted services
clean_deployment_directory() {
    local deployment_dir="$1"
    
    log_header "🧹 Cleaning Deployment Directory"
    
    # Remove any remaining unwanted directories (should be rare since they're excluded during copy)
    local unwanted_dirs=("node_modules")
    local cleaned_count=0
    
    for dir in "${unwanted_dirs[@]}"; do
        local target_path="$deployment_dir/services/$dir"
        if [ -d "$target_path" ]; then
            log_info "Removing unwanted directory: services/$dir"
            rm -rf "$target_path"
            ((cleaned_count++))
        fi
    done
    
    # Also remove any __* directories that might have slipped through
    find "$deployment_dir/services" -maxdepth 1 -name "__*" -type d | while read -r dir; do
        log_info "Removing unwanted directory: $(basename "$dir")"
        rm -rf "$dir"
        ((cleaned_count++))
    done
    
    # Remove development and test files
    find "$deployment_dir/services" -name "*.test.js" -o -name "*.spec.js" -o -name ".env.local" -o -name ".env.development" | while read -r file; do
        log_info "Removing development file: $(basename "$file")"
        rm -f "$file"
        ((cleaned_count++))
    done
    
    if [ $cleaned_count -eq 0 ]; then
        log_success "✅ Deployment directory is already clean"
    else
        log_success "✅ Cleaned $cleaned_count items from deployment directory"
    fi
    
    return 0
}

#!/bin/bash

# Validation Library - Deployment validation and analysis functions
# Part of the manage.sh orchestration system

# Validate deployment directory structure and contents
validate_deployment_directory() {
    local deployment_dir="$1"
    
    log_info "🔍 Validating deployment directory..."
    
    # Check if directory exists
    if [ ! -d "$deployment_dir" ]; then
        log_error "Deployment directory does not exist: $deployment_dir"
        return 1
    fi
    
    # Check for required files
    local required_files=("firebase.json" "package.json")
    local optional_files=("firestore.rules" "firestore.indexes.json" ".firebaserc")
    
    for file in "${required_files[@]}"; do
        if [ ! -f "$deployment_dir/$file" ]; then
            log_error "Missing required file: $file"
            return 1
        fi
    done
    
    # Check for important optional files
    for file in "${optional_files[@]}"; do
        if [ ! -f "$deployment_dir/$file" ]; then
            log_warning "⚠️  Missing optional file: $file (deployment may have limited functionality)"
        fi
    done
    
    # Check for services directory
    if [ ! -d "$deployment_dir/services" ]; then
        log_error "Missing services directory"
        return 1
    fi
    
    # Check for unwanted directories
    local unwanted_dirs=("__NEEDS_UPDATES__" "__OBSOLETE__" "node_modules")
    local found_unwanted=false
    
    for dir in "${unwanted_dirs[@]}"; do
        if [ -d "$deployment_dir/services/$dir" ]; then
            log_warning "⚠️  Found unwanted directory: services/$dir"
            found_unwanted=true
        fi
    done
    
    # Check for suspicious services (likely not production-ready)
    local suspicious_services=("test-" "debug-" "dev-" "experimental-")
    for pattern in "${suspicious_services[@]}"; do
        if find "$deployment_dir/services" -maxdepth 1 -name "${pattern}*" -type d | grep -q .; then
            log_warning "⚠️  Found suspicious services matching: ${pattern}*"
            find "$deployment_dir/services" -maxdepth 1 -name "${pattern}*" -type d -exec basename {} \; | sed 's/^/   - /'
        fi
    done
    
    # Validate service structure
    validate_services_structure "$deployment_dir/services"
    
    # Check deployment size
    validate_deployment_size "$deployment_dir"
    
    if [ "$found_unwanted" = true ]; then
        echo ""
        log_warning "⚠️  Deployment directory contains unwanted files/directories"
        log_info "Consider cleaning up before deployment"
        read -p "Continue anyway? (y/N): " continue_anyway
        
        if [ "$continue_anyway" != "y" ] && [ "$continue_anyway" != "Y" ]; then
            log_info "Validation cancelled by user"
            return 1
        fi
    fi
    
    log_success "✅ Deployment directory validation passed"
    return 0
}

# Validate individual services structure
validate_services_structure() {
    local services_dir="$1"
    local issues=0
    
    log_info "🔍 Validating service structures..."
    
    # Find all service directories (exclude special directories)
    while IFS= read -r -d '' service_dir; do
        local service_name=$(basename "$service_dir")
        
        # Skip special directories
        case "$service_name" in
            __*|.*|libs|node_modules) continue ;;
        esac
        
        # Check for required files
        if [ ! -f "$service_dir/index.js" ]; then
            log_warning "⚠️  Service $service_name missing index.js"
            ((issues++))
        fi
        
        if [ ! -f "$service_dir/package.json" ]; then
            log_warning "⚠️  Service $service_name missing package.json"
            ((issues++))
        fi
        
        # Check for node_modules in service (should not exist in deployment)
        if [ -d "$service_dir/node_modules" ]; then
            log_warning "⚠️  Service $service_name contains node_modules (will slow deployment)"
            ((issues++))
        fi
        
        # Check for obvious development files
        local dev_files=(".env.local" ".env.development" "test/" ".git/")
        for dev_file in "${dev_files[@]}"; do
            if [ -e "$service_dir/$dev_file" ]; then
                log_warning "⚠️  Service $service_name contains development file: $dev_file"
                ((issues++))
            fi
        done
        
    done < <(find "$services_dir" -maxdepth 1 -type d -print0)
    
    if [ $issues -eq 0 ]; then
        log_success "✅ All services have valid structure"
    else
        log_warning "⚠️  Found $issues structural issues in services"
    fi
    
    return 0
}

# Validate deployment size and check for bloat
validate_deployment_size() {
    local deployment_dir="$1"
    
    # CRITICAL: Check for node_modules before anything else
    log_info "🔍 Checking for node_modules directories..."
    local node_modules_found=$(find "$deployment_dir" -name "node_modules" -type d 2>/dev/null)
    if [ -n "$node_modules_found" ]; then
        log_error "❌ CRITICAL: Found node_modules directories in deployment!"
        echo "$node_modules_found" | sed 's/^/   /'
        log_error "node_modules should NEVER be in deployment - they cause massive bloat and timeouts"
        
        # Show sizes
        echo "$node_modules_found" | while read -r dir; do
            if [ -d "$dir" ]; then
                local size=$(du -sh "$dir" 2>/dev/null | cut -f1)
                log_error "   $dir: $size"
            fi
        done
        
        echo ""
        read -p "Remove node_modules and continue? (y/N): " remove_modules
        if [ "$remove_modules" = "y" ] || [ "$remove_modules" = "Y" ]; then
            echo "$node_modules_found" | xargs rm -rf
            log_success "✅ Removed node_modules directories"
        else
            log_error "Deployment aborted - contains node_modules"
            return 1
        fi
    fi
    
    # Check individual service sizes (Firebase Functions limit is ~500MB but should be much smaller)
    log_info "📏 Checking individual service sizes..."
    local large_services=()
    local critical_services=()
    
    if [ -d "$deployment_dir/services" ]; then
        while IFS= read -r -d '' service_dir; do
            local service_name=$(basename "$service_dir")
            
            # Skip special directories
            case "$service_name" in
                libs|__*|.*|node_modules) continue ;;
            esac
            
            # Get service size in MB
            local size_kb=$(du -sk "$service_dir" | cut -f1)
            local size_mb=$((size_kb / 1024))
            
            if [ $size_mb -gt 50 ]; then
                critical_services+=("$service_name: ${size_mb}MB")
                log_error "❌ CRITICAL: Service $service_name is ${size_mb}MB (should be <10MB)"
            elif [ $size_mb -gt 10 ]; then
                large_services+=("$service_name: ${size_mb}MB")
                log_warning "⚠️  Large service: $service_name is ${size_mb}MB (recommend <10MB)"
            else
                log_success "✅ $service_name: ${size_mb}MB"
            fi
            
        done < <(find "$deployment_dir/services" -maxdepth 1 -type d -print0)
    fi
    
    # Report on problematic services
    if [ ${#critical_services[@]} -gt 0 ]; then
        log_error "❌ CRITICAL services found:"
        printf '   %s\n' "${critical_services[@]}"
        
        echo ""
        read -p "Deploy anyway? These may cause timeouts (y/N): " deploy_anyway
        if [ "$deploy_anyway" != "y" ] && [ "$deploy_anyway" != "Y" ]; then
            log_error "Deployment aborted due to oversized services"
            return 1
        fi
    fi
    
    if [ ${#large_services[@]} -gt 0 ]; then
        log_warning "⚠️  Large services found:"
        printf '   %s\n' "${large_services[@]}"
    fi
    
    # Overall deployment size
    local total_size_kb=$(du -sk "$deployment_dir" | cut -f1)
    local total_size_mb=$((total_size_kb / 1024))
    
    log_info "📊 Total deployment size: ${total_size_mb}MB"
    
    if [ $total_size_mb -gt 200 ]; then
        log_error "❌ Total deployment (${total_size_mb}MB) is very large - expect slow deployment"
    elif [ $total_size_mb -gt 100 ]; then
        log_warning "⚠️  Total deployment (${total_size_mb}MB) is moderately large"
    else
        log_success "✅ Reasonable total deployment size (${total_size_mb}MB)"
    fi
}

# Analyze and report on deployment contents
analyze_deployment() {
    local deployment_dir="$1"
    
    log_header "📊 Deployment Analysis"
    
    # Basic statistics
    local service_count=$(find "$deployment_dir/services" -maxdepth 1 -type d ! -name "services" ! -name "__*" ! -name ".*" ! -name "libs" | wc -l | tr -d ' ')
    local file_count=$(find "$deployment_dir" -type f | wc -l | tr -d ' ')
    local js_files=$(find "$deployment_dir" -name "*.js" | wc -l | tr -d ' ')
    local json_files=$(find "$deployment_dir" -name "*.json" | wc -l | tr -d ' ')
    
    echo "📈 Statistics:"
    echo "   Services: $service_count"
    echo "   Total files: $file_count"
    echo "   JavaScript files: $js_files"  
    echo "   JSON files: $json_files"
    
    # Service breakdown
    echo ""
    echo "📁 Services:"
    find "$deployment_dir/services" -maxdepth 1 -type d ! -name "services" ! -name "__*" ! -name ".*" ! -name "libs" -exec basename {} \; | sort | sed 's/^/   - /'
    
    # Check against essential services if available
    local essential_services_file="$SCRIPT_DIR/config/essential-services.txt"
    if [ -f "$essential_services_file" ]; then
        echo ""
        echo "🎯 Essential Services Check:"
        while IFS= read -r service; do
            if [ -d "$deployment_dir/services/$service" ]; then
                echo "   ✅ $service"
            else
                echo "   ❌ $service (missing)"
            fi
        done < "$essential_services_file"
    fi
    
    # Show any unwanted directories
    local unwanted=$(find "$deployment_dir/services" -maxdepth 1 -name "__*" -o -name ".*" -o -name "node_modules" | head -5)
    if [ -n "$unwanted" ]; then
        echo ""
        echo "⚠️  Unwanted directories found:"
        echo "$unwanted" | sed 's/^/   - /'
    fi
}

# Pre-deployment checklist
pre_deployment_checklist() {
    local deployment_dir="$1"
    local project_id="$2"
    
    log_header "✅ Pre-Deployment Checklist"
    
    local checks_passed=0
    local total_checks=6
    
    # Check 1: Deployment directory validation
    if validate_deployment_directory "$deployment_dir" >/dev/null 2>&1; then
        echo "✅ Deployment directory structure valid"
        ((checks_passed++))
    else
        echo "❌ Deployment directory has issues"
    fi
    
    # Check 2: Project ID configuration
    if grep -q "$project_id" "$deployment_dir/firebase.json" 2>/dev/null; then
        echo "✅ Project ID configured in firebase.json"
        ((checks_passed++))
    else
        echo "⚠️  Project ID not found in firebase.json (using CLI default)"
        ((checks_passed++))  # Not critical
    fi
    
    # Check 3: No development files
    if ! find "$deployment_dir" -name "*.test.js" -o -name "*.spec.js" -o -name ".env.local" | grep -q .; then
        echo "✅ No development files detected"
        ((checks_passed++))
    else
        echo "⚠️  Development files detected"
    fi
    
    # Check 4: Service count reasonable
    local service_count=$(find "$deployment_dir/services" -maxdepth 1 -type d ! -name "services" ! -name "__*" ! -name ".*" ! -name "libs" | wc -l | tr -d ' ')
    if [ $service_count -le 20 ] && [ $service_count -ge 5 ]; then
        echo "✅ Service count reasonable ($service_count services)"
        ((checks_passed++))
    else
        echo "⚠️  Unusual service count: $service_count services"
    fi
    
    # Check 5: No node_modules in deployment
    if ! find "$deployment_dir" -name "node_modules" -type d | grep -q .; then
        echo "✅ No node_modules in deployment"
        ((checks_passed++))
    else
        echo "❌ node_modules found in deployment (will slow deployment)"
    fi
    
    # Check 6: Firebase CLI available
    if command -v firebase >/dev/null 2>&1; then
        echo "✅ Firebase CLI available"
        ((checks_passed++))
    else
        echo "❌ Firebase CLI not installed"
    fi
    
    echo ""
    echo "📊 Checklist Score: $checks_passed/$total_checks"
    
    if [ $checks_passed -eq $total_checks ]; then
        log_success "🎉 All checks passed - ready for deployment!"
        return 0
    elif [ $checks_passed -ge $((total_checks * 3 / 4)) ]; then
        log_warning "⚠️  Most checks passed - deployment should work but may have issues"
        return 0
    else
        log_error "❌ Multiple issues detected - deployment likely to fail"
        return 1
    fi
}

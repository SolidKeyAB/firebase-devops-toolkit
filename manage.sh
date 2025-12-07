#!/bin/bash

# Generic Firebase Management Script
# This script provides a unified interface for managing Firebase emulators and services
# Can be reused across different projects

# Source configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load environment variables from .env file FIRST (before any configs)
# BUT skip this for production commands to avoid overriding project IDs
# Only set PROJECT_ROOT if not already set by environment
if [ -z "$PROJECT_ROOT" ]; then
    PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
fi
if [ -f "$PROJECT_ROOT/.env" ] && [[ ! "$1" =~ ^(deploy-production|deploy-production-selective|deploy-function|remove-function)$ ]]; then
    echo "Loading environment variables from .env file..."
    export $(grep -v '^#' "$PROJECT_ROOT/.env" | xargs)
    echo "✅ Environment variables loaded from .env"
fi

# Try to source project-specific config first, fall back to generic config
# BUT skip this for production commands to avoid overriding project IDs
if [ -f "$SCRIPT_DIR/project-config.sh" ] && [[ ! "$1" =~ ^(deploy-production|deploy-production-selective|deploy-function|remove-function)$ ]]; then
    source "$SCRIPT_DIR/project-config.sh"
    echo "Using project-specific configuration"
elif [ -f "$SCRIPT_DIR/config.sh" ] && [[ ! "$1" =~ ^(deploy-production|deploy-production-selective|deploy-function|remove-function)$ ]]; then
    source "$SCRIPT_DIR/config.sh"
    echo "Using generic configuration (consider creating project-config.sh)"
else
    echo "Skipping project config for production command: $1"
fi

# Source Pub/Sub setup script to use its topic creation logic
# BUT skip this for production commands to avoid loading old project config
if [[ ! "$1" =~ ^(deploy-production|deploy-production-selective|deploy-function|remove-function)$ ]]; then
    source "$SCRIPT_DIR/local/setup-pubsub-topics.sh"
fi

# Define logging functions locally (so they work even when config is skipped)
log_info() { echo "ℹ️  $1"; }
log_success() { echo "✅ $1"; }
log_warning() { echo "⚠️  $1"; }
log_error() { echo "❌ $1"; }
log_header() { echo ""; echo "🔧 $1"; echo "=================================="; }

# Function to clean remote Firebase functions and data
clean_remote() {
    log_header "Cleaning Remote Firebase Functions and Data"
    
    echo "⚠️  This will clean up remote Firebase functions and infrastructure!"
    echo "   • Delete all deployed functions"
    echo "   • Clean up Pub/Sub topics"
    echo ""
    
    read -p "Continue with function and topic cleanup? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Remote cleanup cancelled"
        return 0
    fi
    
    local _project_id="${FIREBASE_PROJECT_ID:-your-firebase-project-id}"
    log_info "Step 1: Listing current functions (project: $_project_id)..."
    firebase functions:list --project "$_project_id"
    
    log_info "Step 2: Deleting all functions..."
    firebase functions:delete --all --project "$_project_id" --force
    
    log_info "Step 3: Cleaning Pub/Sub topics..."
    firebase pubsub:topics:delete --all --project "$_project_id" --force
    
    # Ask about data sources separately
    echo ""
    echo "🗄️  Data Sources Cleanup Options:"
    echo "   • Firestore collections (products, brands, scores, etc.)"
    echo "   • Vector database (Qdrant) collections"
    echo ""
    
    read -p "Delete Firestore data collections? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "Step 4: Cleaning Firestore collections..."
        log_info "Using Firebase CLI to delete all collections..."
        firebase firestore:delete --all-collections --project "$_project_id" --force
        if [ $? -eq 0 ]; then
            log_success "✅ Firestore collections deleted successfully"
        else
            log_warning "⚠️  Firestore cleanup had issues, but continuing..."
        fi
    else
        log_info "Skipping Firestore data cleanup"
    fi
    
    read -p "Delete Vector database (Qdrant) collections? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "Step 5: Cleaning Vector database..."
        if [ -f "cleanup-all-collections.js" ]; then
            # The cleanup script already includes Qdrant cleanup
            log_info "Vector database cleanup included in Firestore cleanup script"
        else
            log_warning "cleanup-all-collections.js not found, cannot clean vector database"
        fi
    else
        log_info "Skipping Vector database cleanup"
    fi
    
    log_success "🎉 Remote cleanup completed successfully"
    log_info "Selected components have been cleaned up"
}

# Function to show usage
show_usage() {
    echo "Firebase Management Script"
    echo ""
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo ""
    echo "Commands:"
    echo "  start-local [--concurrency=N] [--max-instances=N] [--services=svc1,svc2]"
    echo "              Start Firebase emulator locally with optional resource controls"
    echo "  start-local-min Start emulator in minimal mode (reduced functions/UI)"
    echo "  stop-local      Stop Firebase emulator locally"
    echo "  status-local    Check status of local Firebase emulator"
    echo "  deploy-local    Deploy services to local emulator"
    echo "  deploy-remote   Deploy services to Firebase production"
    echo "                   Usage: deploy-remote [--services-dir PATH]"
    echo "  prepare-deploy  --project-dir PATH --services-dir PATH [--install-deps] [--public-api-only]"
    echo "                   Prepare deployment folder from custom project structure"
    echo "  deploy-from     --dir PATH --project PROJECT_ID"
    echo "                   Deploy from prepared deployment directory"
    echo "  deploy-function --function NAME"
    echo "                   Deploy a specific function to production"
    echo "  remove-function --function NAME"
    echo "                   Remove a specific function from production"
    echo "  restart-local   Restart local Firebase emulator"
    echo "  clean-local     Clean up local Firebase processes"
    echo "  clean-remote    Clean up remote Firebase functions and data"
    echo "  force-clean     Force clean all processes and ports"
    echo "  fresh-deploy    Force clean and deploy fresh"
    echo "  preserve-data   Export/import Firestore data (local/production aware)"
    echo "  infer-schema    Infer Firestore schema via REST API (samples collections)"
    echo ""
    echo "Pub/Sub Management:"
    echo "  check-topics    List all Pub/Sub topics in emulator"
    echo "  create-topic    Create a specific Pub/Sub topic"
    echo "  create-topics   Create all required topics for the pipeline"
    echo "  ensure-topics   Check and create missing topics (recommended)"
    echo "  check-subs      List all Pub/Sub subscriptions"
    echo "  delete-topic    Delete a specific Pub/Sub topic"
    echo "  test-pubsub     Test Pub/Sub pipeline with test message"
    echo "  pubsub-status   Check Pub/Sub emulator status"
    echo ""
    echo "Resource Management:"
    echo "  monitor-resources Start resource monitoring to prevent overload"
    echo "  check-resources  Check current resource usage"
    echo "  cleanup-resources Clean up excess processes"
    echo ""
    echo "Examples:"
    echo "  $0 start-local"
    echo "  $0 deploy-local"
    echo "  $0 status-local"
    echo "  $0 deploy-remote"
    echo "  $0 clean-remote"
    echo "  $0 simple-deploy"
    echo "  $0 prepare-deploy --project-dir ../microservices_platform --services-dir services"
    echo "  $0 prepare-deploy --project-dir ../microservices_platform --services-dir services --install-deps"
    echo "  $0 check-topics"
    echo "  $0 create-topics"
    echo "  $0 ensure-topics"
    echo "  $0 test-pubsub"
    echo ""
    echo "start-local options:"
    echo "  --concurrency=N       Function concurrency limit (default: 1 in emulator)"
    echo "  --max-instances=N     Function max instances (default: 1 in emulator)"
    echo "  --services=svc1,svc2  Only load specific services (e.g., product_*,category_*)"
    echo ""
    echo ""
    echo "Examples with options:"
    echo "  $0 start-local --concurrency=2 --max-instances=3"
    echo "  $0 start-local --services=product_extraction_pubsub,product_enrichment_pubsub"
    echo "  $0 start-local --concurrency=1"
    echo ""
}

# Function to start local emulator
start_local() {
    log_header "Starting Firebase Emulator (Local)"
    "$SCRIPT_DIR/local/start-emulator.sh"
}

# Function to stop local emulator
stop_local() {
    log_header "Stopping Firebase Emulator (Local)"
    "$SCRIPT_DIR/local/stop-emulator.sh"
}

# Function to check local status
status_local() {
    log_header "Checking Firebase Emulator Status (Local)"
    "$SCRIPT_DIR/local/check-status.sh"
}

# Function to deploy to local emulator
deploy_local() {
    log_header "Deploying Services to Local Emulator"
    "$SCRIPT_DIR/local/deploy-services.sh"
}

# Function to deploy to remote
deploy_remote() {
    log_header "Deploying Services to Firebase Production"
    
    # Use prepare-deploy + deploy-from approach
    local project_dir="${PROJECT_ROOT:-$(pwd)}"
    local services_dir="${SERVICES_DIR:-services}"
    local project_id="${FIREBASE_PROJECT_ID:-your-firebase-project-id}"
    local region="${FIREBASE_REGION:-europe-west1}"
    
    # If services_dir is not absolute, make it relative to project_dir
    if [[ ! "$services_dir" = /* ]]; then
        services_dir="$project_dir/$services_dir"
    fi
    
    log_info "Preparing deployment from project: $project_dir"
    log_info "Services directory: $services_dir"
    log_info "Target project: $project_id"
    
    # Prepare deployment
    local deployment_dir=$(mktemp -d)
    log_info "Created deployment directory: $deployment_dir"
    
    # Copy project files
    log_info "Copying project files..."
    cp "$project_dir/firebase.json" "$deployment_dir/" 2>/dev/null || log_warning "firebase.json not found"
    cp "$project_dir/LAB/package.json" "$deployment_dir/" 2>/dev/null || log_warning "package.json not found"
    
    # Update firebase.json to point to services directory
    if [ -f "$deployment_dir/firebase.json" ]; then
        log_info "Updating firebase.json to use services directory..."
        # Replace any "LAB" references with "services" in firebase.json
        sed -i '' 's/"LAB"/"services"/g' "$deployment_dir/firebase.json" 2>/dev/null || true
    fi
    
    # Copy services
    log_info "Copying services from $services_dir..."
    mkdir -p "$deployment_dir/services"
    
    if [ -d "$services_dir" ]; then
        # Copy services but exclude node_modules to avoid dependency conflicts
        rsync -av --exclude='node_modules' "$services_dir/" "$deployment_dir/services/" 2>/dev/null || cp -r "$services_dir"/* "$deployment_dir/services/" 2>/dev/null || true
        log_success "Services copied successfully"
    else
        log_error "Services directory not found: $services_dir"
        return 1
    fi
    
    # Install dependencies
    log_info "Installing dependencies..."
    cd "$deployment_dir"
    
    # Clean install to avoid dependency conflicts
    rm -rf node_modules package-lock.json 2>/dev/null || true
    npm install --silent
    
    # Deploy from prepared directory
    log_info "Deploying from prepared directory..."
    firebase deploy --only functions --project "$project_id"
    
    # Cleanup
    rm -rf "$deployment_dir"
    log_success "🎉 Deployment completed successfully"
}




# Function to prepare deployment with custom project and services directories
prepare_deploy() {
    local project_dir=""
    local services_dir=""
    local project_id=""
    local region="europe-west1"
    local install_deps=false
    local public_api_only=false
    local services_file=""
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --project-dir)
                project_dir="$2"
                shift 2
                ;;
            --services-dir)
                services_dir="$2"
                shift 2
                ;;
            --project)
                project_id="$2"
                shift 2
                ;;
            --region)
                region="$2"
                shift 2
                ;;
            --install-deps)
                install_deps=true
                shift
                ;;
            --public-api-only)
                public_api_only=true
                shift
                ;;
            --services-file)
                services_file="$2"
                shift 2
                ;;
            --help|-h)
                echo "Usage: $0 prepare-deploy --project-dir PATH --services-dir PATH [--project PROJECT_ID] [--region REGION] [--install-deps] [--services-file FILE]"
                echo "Options:"
                echo "  --install-deps    Install all dependencies (slower but ensures compatibility)"
                echo "  --services-file   File containing list of services to deploy (one per line)"
                echo "Example: $0 prepare-deploy --project-dir ../microservices_platform --services-dir services --services-file essential-services.txt"
                exit 0
                ;;
            prepare-deploy)
                # Skip command name
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                echo "Usage: $0 prepare-deploy --project-dir PATH --services-dir PATH [--project PROJECT_ID] [--region REGION] [--services-file FILE]"
                exit 1
                ;;
        esac
    done
    
    # Validate required arguments
    if [ -z "$project_dir" ]; then
        log_error "Project directory is required. Use --project-dir PATH"
        echo "Usage: $0 prepare-deploy --project-dir PATH --services-dir PATH"
        exit 1
    fi
    
    if [ -z "$services_dir" ]; then
        log_error "Services directory is required. Use --services-dir PATH"
        echo "Usage: $0 prepare-deploy --project-dir PATH --services-dir PATH"
        exit 1
    fi
    
    # Convert to absolute paths
    project_dir="$(cd "$SCRIPT_DIR" && cd "$project_dir" && pwd)"
    local full_services_path="$project_dir/$services_dir"
    
    # Validate paths exist
    if [ ! -d "$project_dir" ]; then
        log_error "Project directory not found: $project_dir"
        exit 1
    fi
    
    if [ ! -d "$full_services_path" ]; then
        log_error "Services directory not found: $full_services_path"
        exit 1
    fi
    
    log_header "Preparing Custom Project Deployment"
    log_info "Project directory: $project_dir"
    log_info "Services directory: $full_services_path"
    log_info "Target project: $project_id"
    log_info "Region: $region"
    
    # Create deployment directory
    local deployment_dir="/tmp/firebase-deployment-$(date +%s)"
    mkdir -p "$deployment_dir"
    log_info "Created deployment directory: $deployment_dir"
    
    # Copy project structure to deployment directory
    log_info "Copying project files..."
    
    # Copy firebase.json (use public-api-only version if requested)
    if [ "$public_api_only" = true ] && [ -f "$project_dir/firebase-public-api-only.json" ]; then
        cp "$project_dir/firebase-public-api-only.json" "$deployment_dir/firebase.json"
        log_success "Copied firebase-public-api-only.json as firebase.json"
    elif [ -f "$project_dir/firebase.json" ]; then
        cp "$project_dir/firebase.json" "$deployment_dir/"
        log_success "Copied firebase.json"
    fi

    # Copy Firestore configuration files
    if [ -f "$project_dir/firestore.indexes.json" ]; then
        cp "$project_dir/firestore.indexes.json" "$deployment_dir/"
        log_success "Copied firestore.indexes.json"
    fi

    if [ -f "$project_dir/firestore.rules" ]; then
        cp "$project_dir/firestore.rules" "$deployment_dir/"
        log_success "Copied firestore.rules"
    fi
    
    # Copy package.json if it exists
    if [ -f "$project_dir/package.json" ]; then
        cp "$project_dir/package.json" "$deployment_dir/"
        log_success "Copied package.json"
    fi
    
    # Create production .env file (override emulator settings)
    if [ -f "$project_dir/.env" ]; then
        log_info "Creating production .env file (overriding emulator settings)..."
        # Copy .env but remove emulator settings
        grep -v "EMULATOR\|localhost" "$project_dir/.env" > "$deployment_dir/.env"
        
        # Add production-specific environment variables
        cat >> "$deployment_dir/.env" << EOF

# Production overrides (added by prepare-deploy)
NODE_ENV=production
FUNCTIONS_EMULATOR=false
FIRESTORE_EMULATOR_HOST=
PUBSUB_EMULATOR_HOST=
FIREBASE_PROJECT_ID=$project_id
EOF
        log_success "Created production .env file"
    else
        log_info "Creating minimal production .env file..."
        cat > "$deployment_dir/.env" << EOF
# Production environment (created by prepare-deploy)
NODE_ENV=production
FUNCTIONS_EMULATOR=false
FIRESTORE_EMULATOR_HOST=
PUBSUB_EMULATOR_HOST=
FIREBASE_PROJECT_ID=$project_id
EOF
        log_success "Created minimal production .env file"
    fi
    
    # Copy shared libraries if they exist
    if [ -d "$project_dir/shared" ]; then
        cp -r "$project_dir/shared" "$deployment_dir/"
        log_success "Copied shared libraries"
    fi
    
    if [ -d "$project_dir/libs" ]; then
        rsync -r --exclude='**/node_modules' --exclude='node_modules' "$project_dir/libs/" "$deployment_dir/libs/"
        log_success "Copied libs directory (excluded node_modules)"
    fi
    
    # Note: scripts/firebase has been moved to separate firebase-scripts repo
    # Services should use shared/firebaseAdmin.js instead of scripts/firebase/firebaseConfig
    
    # Copy services directory with only essential files
    log_info "Copying services directory..."
    mkdir -p "$deployment_dir/services"
    
    # We'll handle index.js after copying all services
    
    # Copy services/package.json if it exists
    if [ -f "$full_services_path/package.json" ]; then
        cp "$full_services_path/package.json" "$deployment_dir/services/"
        log_success "Copied services/package.json"
    fi
    
    # Copy services/libs if they exist
    if [ -d "$full_services_path/libs" ]; then
        cp -r "$full_services_path/libs" "$deployment_dir/services/"
        log_success "Copied services/libs"
    fi
    
    # Determine which services to process
    local services_to_process=()

    if [ -n "$services_file" ]; then
        if [ ! -f "$services_file" ]; then
            log_error "Services file not found: $services_file"
            exit 1
        fi
        log_info "Reading services from file: $services_file"

        # Read services from file, one per line, ignoring empty lines and comments
        while IFS= read -r line; do
            # Skip empty lines and comments
            [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
            services_to_process+=("$line")
        done < "$services_file"

        log_info "Found ${#services_to_process[@]} services to deploy: ${services_to_process[*]}"
    fi

    # Copy services based on flags
    if [ "$public_api_only" = true ]; then
        log_info "Copying only public-api-service..."

        # Copy only the public-api-service directory
        # Using -r (recursive) instead of -av to prevent backup file creation
        if [ -d "$full_services_path/public-api-service" ]; then
            rsync -r --exclude='**/node_modules' --exclude='node_modules' "$full_services_path/public-api-service/" "$deployment_dir/services/public-api-service/"
            log_success "Copied public-api-service (excluded node_modules)"
        else
            log_error "public-api-service directory not found at $full_services_path/public-api-service"
            exit 1
        fi

        # Copy only essential service files that don't contain hardcoded project IDs
        if [ -f "$full_services_path/package.json" ]; then
            cp "$full_services_path/package.json" "$deployment_dir/services/"
        fi
    elif [ ${#services_to_process[@]} -gt 0 ]; then
        log_info "Copying selected services from file (excluding node_modules)..."

        # Copy only the services listed in the services file
        for service in "${services_to_process[@]}"; do
            if [ -d "$full_services_path/$service" ]; then
                rsync -r --exclude='**/node_modules' --exclude='node_modules' "$full_services_path/$service/" "$deployment_dir/services/$service/"
                log_info "Copied service: $service"
            else
                log_warning "Service directory not found: $full_services_path/$service"
            fi
        done

        log_success "Copied ${#services_to_process[@]} selected services (excluded node_modules)"
    else
        log_info "Copying all services (excluding node_modules)..."

        # Use rsync to copy everything except node_modules (recursively)
        rsync -r --exclude='**/node_modules' --exclude='node_modules' "$full_services_path"/ "$deployment_dir/services/"

        log_success "Copied all services (excluded node_modules)"
    fi
    
    # Create or copy services/index.js (main exports file) AFTER copying services
    if [ "$public_api_only" = true ]; then
        log_info "Creating public-api-only services/index.js..."
        cat > "$deployment_dir/services/index.js" << 'EOF'
// Public API Service Only - Generated by prepare-deploy
const publicApiService = require('./public-api-service');

// Export only public API functions
exports.queryProductScores = publicApiService.queryProductScores;
exports.queryBrandScores = publicApiService.queryBrandScores;
exports.searchScores = publicApiService.searchScores;
exports.publicApiHealth = publicApiService.health;
EOF
        log_success "Created public-api-only services/index.js"
    elif [ ${#services_to_process[@]} -gt 0 ]; then
        log_info "Creating services/index.js for selected services..."
        cat > "$deployment_dir/services/index.js" << 'EOF'
// Selected Services - Generated by prepare-deploy
EOF

        # Add require statements for each selected service
        for service in "${services_to_process[@]}"; do
            if [ -d "$deployment_dir/services/$service" ]; then
                # Convert hyphens to underscores for valid JavaScript variable names
                var_name=$(echo "$service" | sed 's/-/_/g')
                echo "const ${var_name}Service = require('./$service');" >> "$deployment_dir/services/index.js"
            fi
        done

        echo "" >> "$deployment_dir/services/index.js"
        echo "// Export all functions from selected services" >> "$deployment_dir/services/index.js"

        # Add export statements for each service
        for service in "${services_to_process[@]}"; do
            if [ -d "$deployment_dir/services/$service" ]; then
                # Convert hyphens to underscores for valid JavaScript variable names
                var_name=$(echo "$service" | sed 's/-/_/g')
                echo "// Exports from $service" >> "$deployment_dir/services/index.js"
                # Try to get function names from the service's index.js if it exists
                if [ -f "$deployment_dir/services/$service/index.js" ]; then
                    # Extract function names from exports
                    grep -E "^exports\." "$deployment_dir/services/$service/index.js" | sed 's/exports\.//' | sed 's/ =.*//' | while read -r func_name; do
                        echo "exports.$func_name = ${var_name}Service.$func_name;" >> "$deployment_dir/services/index.js"
                    done
                fi
            fi
        done

        log_success "Created services/index.js for selected services"
    fi
    
    log_info "No dependencies installed - deployment directory is clean"
    log_info "Dependencies will be installed temporarily during deployment"
    
    log_success "🎉 Deployment directory prepared!"
    log_info "Location: $deployment_dir"
    
    log_info "To deploy, run: $0 deploy-from --dir $deployment_dir --project $project_id"
    
    # Return the deployment directory path for further use
    echo "$deployment_dir"
}

# Deploy from prepared deployment directory
deploy_from_directory() {
    local deployment_dir="$1"
    local project_id="$2"
    local force_deploy="${3:-false}"

    if [ ! -d "$deployment_dir" ]; then
        log_error "Deployment directory not found: $deployment_dir"
        exit 1
    fi

    log_info "🚀 Starting deployment from: $deployment_dir"
    log_info "Target project: $project_id"
    if [ "$force_deploy" = "true" ]; then
        log_info "Force mode: Will delete old functions automatically"
    fi

    cd "$deployment_dir"

    # Install minimal Firebase dependencies for CLI analysis
    # This allows Firebase to analyze the code without installing all dependencies
    log_info "Installing minimal Firebase dependencies for CLI analysis..."
    cd services
    npm install firebase-functions firebase-admin --production --no-save --no-package-lock --silent
    log_success "Minimal dependencies installed"

    cd ..

    # Deploy
    log_info "Deploying to Firebase..."
    if [ "$force_deploy" = "true" ]; then
        firebase deploy --project "$project_id" --force
    else
        firebase deploy --project "$project_id"
    fi

    if [ $? -eq 0 ]; then
        log_success "🎉 Deployment successful!"

        # Clean up node_modules after successful deployment
        log_info "Cleaning up temporary dependencies..."
        rm -rf services/node_modules
        log_success "Cleanup complete"
    else
        log_error "Deployment failed"
        exit 1
    fi
}







    

    

    

    



# Function to deploy a specific function
deploy_specific_function() {
    local function_name=""
    local project_id=""
    local region="europe-west1"
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --function)
                function_name="$2"
                shift 2
                ;;
            --project)
                project_id="$2"
                shift 2
                ;;
            --region)
                region="$2"
                shift 2
                ;;
            --help|-h)
                echo "Usage: $0 deploy-function --function FUNCTION_NAME [--project PROJECT_ID] [--region REGION]"
                echo "Example: $0 deploy-function --function extractCategoriesPubSub"
                exit 0
                ;;
            deploy-function|remove-function|test-pipeline)
                # Skip command names
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                echo "Usage: $0 deploy-function --function FUNCTION_NAME [--project PROJECT_ID] [--region REGION]"
                exit 1
                ;;
        esac
    done
    
    if [ -z "$function_name" ]; then
        log_error "Function name is required. Use --function FUNCTION_NAME"
        echo "Usage: $0 deploy-function --function FUNCTION_NAME [--project PROJECT_ID] [--region REGION]"
        exit 1
    fi
    
    log_header "Deploying Specific Function: $function_name"
    log_info "Project: $project_id, Region: $region"
    
    # Override environment variables and clear emulator settings
    export FIREBASE_PROJECT_ID="$project_id"
    export FIREBASE_REGION="$region"
    export FUNCTIONS_EMULATOR=""
    export FIRESTORE_EMULATOR_HOST=""
    export NODE_ENV="production"
    export FIREBASE_EMULATOR=""
    
    # Step 1: Deploy specific function directly
    log_info "🚀 Step 1: Deploying function: $function_name"
    firebase deploy --only functions:"$function_name" --project "$project_id"
    
    log_success "🎉 Function $function_name deployed successfully!"
}

# Function to set API key for functions
set_api_key() {
    local api_key=""
    local project_id=""
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --key)
                api_key="$2"
                shift 2
                ;;
            --project)
                project_id="$2"
                shift 2
                ;;
            --help|-h)
                echo "Usage: $0 set-api-key --key API_KEY [--project PROJECT_ID]"
                echo "Example: $0 set-api-key --key your-actual-api-key"
                exit 0
                ;;
            set-api-key)
                # Skip command name
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                echo "Usage: $0 set-api-key --key API_KEY [--project PROJECT_ID]"
                exit 1
                ;;
        esac
    done
    
    if [ -z "$api_key" ]; then
        log_error "API key is required. Use --key API_KEY"
        echo "Usage: $0 set-api-key --key API_KEY [--project PROJECT_ID]"
        exit 1
    fi
    
    log_header "Setting API Key for Functions"
    log_info "Project: $project_id"
    
    # Set the environment variable for all functions
    firebase functions:config:set gemini.api_key="$api_key" --project "$project_id"
    
    log_success "🎉 API key set successfully!"
    log_info "You may need to redeploy functions for the changes to take effect"
}

# Function to remove a specific function
remove_specific_function() {
    local function_name=""
    local project_id=""
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --function)
                function_name="$2"
                shift 2
                ;;
            --project)
                project_id="$2"
                shift 2
                ;;
            --help|-h)
                echo "Usage: $0 remove-function --function FUNCTION_NAME [--project PROJECT_ID]"
                echo "Example: $0 remove-function --function extractCategoriesPubSub"
                exit 0
                ;;
            deploy-function|remove-function|test-pipeline)
                # Skip command names
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                echo "Usage: $0 remove-function --function FUNCTION_NAME [--project PROJECT_ID]"
                exit 1
                ;;
        esac
    done
    
    if [ -z "$function_name" ]; then
        log_error "Function name is required. Use --function FUNCTION_NAME"
        echo "Usage: $0 remove-function --function FUNCTION_NAME [--project PROJECT_ID]"
        exit 1
    fi
    
    log_header "Removing Specific Function: $function_name"
    log_info "Project: $project_id"
    
    # Set Firebase project
    firebase use "$project_id"
    
    # Remove the function
    log_info "🗑️  Removing function: $function_name"
    echo "y" | firebase functions:delete "$function_name" --project "$project_id" --force
    
    log_success "🎉 Function $function_name removed successfully!"
}

# Function to test the pipeline trigger by adding a brand to Firestore
test_pipeline_trigger() {
    local project_id=""
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --project)
                project_id="$2"
                shift 2
                ;;
            --help|-h)
                echo "Usage: $0 test-pipeline [--project PROJECT_ID]"
                echo "Example: $0 test-pipeline"
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                echo "Usage: $0 test-pipeline [--project PROJECT_ID]"
                exit 1
                ;;
        esac
    done
    
    log_header "Testing Pipeline Trigger"
    log_info "Project: $project_id"
    log_info "This will add a test brand to Firestore to trigger the pipeline"
    
    # Set Firebase project
    firebase use "$project_id"
    
    # Create a simple test brand document
    log_info "📝 Creating test brand document in Firestore..."
    
    # Use Firebase CLI to add a document (more reliable than Node.js scripts)
    cat > /tmp/test-brand.json << EOF
{
  "name": "Test Brand $(date +%s)",
  "description": "Test brand to trigger pipeline",
  "sector": "Technology",
  "website": "https://test.example.com",
  "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "updated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "status": "active",
  "pipeline_status": "pending",
  "test_brand": true
}
EOF
    
    log_info "📄 Test brand data created:"
    cat /tmp/test-brand.json
    
    log_info "🚀 Adding brand to Firestore (this should trigger onBrandAdded)..."
    log_info "💡 Check the Firebase Console > Functions > Logs for onBrandAdded function"
    log_info "💡 Or use: firebase functions:log --only onBrandAdded --project $project_id"
    
    # Note: Firebase CLI doesn't have direct document creation, so we'll guide the user
    log_warning "⚠️  Firebase CLI doesn't support direct document creation"
    log_info "📋 Please manually add the brand document to Firestore:"
    log_info "   1. Go to: https://console.firebase.google.com/project/$project_id/firestore"
    log_info "   2. Click 'Start collection' or add to 'brands' collection"
    log_info "   3. Use the data from /tmp/test-brand.json"
    log_info "   4. Watch the Functions logs for onBrandAdded trigger"
    
    log_success "🎯 Pipeline test setup completed!"
    log_info "📁 Test brand data saved to: /tmp/test-brand.json"
}

# Function to restart local emulator
restart_local() {
    log_header "Restarting Firebase Emulator (Local)"
    clean_local
    sleep 3
    "$SCRIPT_DIR/local/start-emulator.sh"
}

# Function to clean local processes
clean_local() {
    log_header "Cleaning Local Firebase Processes"
    "$SCRIPT_DIR/local/stop-emulator.sh"
    
    # Additional cleanup for any remaining processes
    log_info "Cleaning up any remaining Firebase processes..."
    pkill -f "firebase\|firestore\|pubsub" 2>/dev/null || true
    pkill -f "java.*firestore" 2>/dev/null || true
    
    log_info "All Firebase processes have been cleaned up"
}

# Function to force clean all processes and ports
force_clean() {
    log_header "Force Cleaning All Firebase Processes and Ports"
    
    # Stop emulator first
    "$SCRIPT_DIR/local/stop-emulator.sh"
    
    # Force kill all Firebase-related processes
    log_info "Force killing all Firebase processes..."
    pkill -9 -f "firebase\|firestore\|pubsub" 2>/dev/null || true
    pkill -9 -f "java.*firestore" 2>/dev/null || true
    
    # Clean up specific ports
    log_info "Cleaning up Firebase ports..."
    local ports=(8080 4000 4400 5001 8085 4500 9150)
    for port in "${ports[@]}"; do
        local pid=$(lsof -ti:$port 2>/dev/null)
        if [ ! -z "$pid" ]; then
            log_info "Killing process using port $port (PID: $pid)"
            kill -9 "$pid" 2>/dev/null || true
        fi
    done
    
    # Wait a moment for cleanup
    sleep 2
    

}

# Function to run full local setup
setup_local() {
    log_header "Setting up Firebase Emulator (Local)"
    log_info "This will start the emulator and deploy all services"
    
    # Start emulator
    if ! start_local; then
        log_error "Failed to start emulator"
        exit 1
    fi
    
    # Wait a bit for emulator to be ready
    sleep 10
    
    # Deploy services
    if ! deploy_local; then
        log_error "Failed to deploy services"
        exit 1
    fi
    
    log_success "🎉 Local Firebase setup completed successfully"
}

# Function to force clean and deploy
force_clean_and_deploy() {
    log_header "Force Clean and Deploy Local Firebase"
    log_info "This will force clean all processes and ports, then deploy fresh"
    
    # Force clean everything
    force_clean
    
    # Wait for cleanup to complete
    sleep 3
    
    # Deploy fresh
    if ! deploy_local; then
        log_error "Failed to deploy services after cleanup"
        exit 1
    fi
    
    log_success "🎉 Force clean and deploy completed successfully"
}

# Function to check Pub/Sub emulator status
pubsub_status() {
    log_header "Checking Pub/Sub Emulator Status"
    
    # Check if Pub/Sub emulator is running
    if curl -s "http://localhost:8085" >/dev/null 2>&1; then
        log_success "✅ Pub/Sub emulator is running on port 8085"
    else
        log_error "❌ Pub/Sub emulator is not running on port 8085"
        return 1
    fi
    
    # Check if gcloud is available
    if command -v gcloud >/dev/null 2>&1; then
        log_info "✅ gcloud CLI is available"
    else
        log_warning "⚠️  gcloud CLI not found. Install it to use Pub/Sub commands"
        return 1
    fi
}

# Function to list all Pub/Sub topics
check_topics() {
    log_header "Listing Pub/Sub Topics"
    
    if ! pubsub_status >/dev/null 2>&1; then
        log_error "Pub/Sub emulator is not available"
        return 1
    fi
    
    log_info "Fetching topics from Pub/Sub emulator..."
    
    # Use the list_topics function from the sourced script instead of gcloud
    if list_topics "$FIREBASE_PROJECT_ID"; then
        log_success "✅ Topics listed successfully"
    else
        log_warning "⚠️  No topics found or error occurred"
        log_info "This is normal for a fresh emulator"
    fi
}

# Function to create a specific Pub/Sub topic (command handler)
create_single_pubsub_topic_command() { # RENAMED FUNCTION
    local topic_name=${1:-""}
    
    if [ -z "$topic_name" ]; then
        log_error "Topic name is required"
        echo "Usage: $0 create-topic <topic-name>"
        return 1
    fi
    
    log_header "Creating Pub/Sub Topic: $topic_name"
    
    if ! pubsub_status >/dev/null 2>&1; then
        log_error "Pub/Sub emulator is not available"
        return 1
    fi
    
    log_info "Creating topic: $topic_name"
    
    # Use the create_topic function from setup-pubsub-topics.sh which handles gcloud/curl logic
    if create_topic "$topic_name" "$FIREBASE_PROJECT_ID"; then # THIS CALL IS NOW CORRECT
        log_success "✅ Topic '$topic_name' created successfully"
    else
        log_error "❌ Failed to create topic '$topic_name'"
        return 1
    fi
}

# Function to create all required topics for the pipeline
create_topics() {
    log_header "Creating Required Pub/Sub Topics for Pipeline"
    
    if ! pubsub_status >/dev/null 2>&1; then
        log_error "Pub/Sub emulator is not available"
        return 1
    fi
    
    # List of required topics for the ESG pipeline
    local required_topics=(
        "category-extraction-topic"
        "product-extraction-topic"
        "product-enrichment-topic"
        "embedding-generation-topic"
        "sustainability-enrichment-topic"
        "eprel-enrichment-topic"
        "oecd-enrichment-topic"
        "image-enrichment-topic"
        "orchestrator-feedback-topic"
        "orchestrator-requests-topic"
    )
    
    log_info "Creating ${#required_topics[@]} required topics..."
    
    local created_count=0
    local failed_count=0
    
    for topic in "${required_topics[@]}"; do
        log_info "Creating topic: $topic"
        if create_topic "$topic" "$FIREBASE_PROJECT_ID"; then
            log_success "✅ Created: $topic"
            ((created_count++))
        else
            log_warning "⚠️  Topic '$topic' already exists or failed to create"
            ((failed_count++))
        fi
    done
    
    log_info "📊 Results: $created_count created, $failed_count failed/skipped"
    
    if [ $failed_count -eq 0 ]; then
        log_success "🎉 All required topics created successfully"
    else
        log_warning "⚠️  Some topics may already exist (this is normal)"
    fi
}

# Function to ensure all required topics exist (create if missing)
ensure_topics() {
    log_header "Ensuring Required Pub/Sub Topics Exist"
    
    if ! pubsub_status >/dev/null 2>&1; then
        log_error "Pub/Sub emulator is not available"
        return 1
    fi
    
    # List of required topics for the ESG pipeline
    local required_topics=(
        "category-extraction-topic"
        "product-extraction-topic"
        "product-enrichment-topic"
        "embedding-generation-topic"
        "sustainability-enrichment-topic"
        "eprel-enrichment-topic"
        "oecd-enrichment-topic"
        "image-enrichment-topic"
        "orchestrator-feedback-topic"
        "orchestrator-requests-topic"
    )
    
    log_info "Checking ${#required_topics[@]} required topics..."
    
    local existing_count=0
    local missing_count=0
    local missing_topics=()
    
    # Check which topics exist using HTTP API for reliability
    for topic in "${required_topics[@]}"; do
        # DEBUG: Write raw debug info directly to a file
        echo "$(date +%H:%M:%S) -- DEBUG_FILE: Checking topic: $topic for project: $FIREBASE_PROJECT_ID using PUBSUB_EMULATOR_HOST: $PUBSUB_EMULATOR_HOST" >> /tmp/manage_debug_loop.log
        local curl_command="curl -s -o /dev/null -w \"%{http_code}\" \"http://localhost:8085/v1/projects/$FIREBASE_PROJECT_ID/topics/$topic\""
        echo "$(date +%H:%M:%S) -- DEBUG_FILE: Executing: $curl_command" >> /tmp/manage_debug_loop.log
        local response_code=$(eval $curl_command)
        echo "$(date +%H:%M:%S) -- DEBUG_FILE: Received HTTP status code: $response_code" >> /tmp/manage_debug_loop.log
        if [ "$response_code" -eq 200 ]; then
            log_success "✅ Topic exists: $topic"
            ((existing_count++))
        else
            log_warning "⚠️  Topic missing: $topic (HTTP status: $response_code)"
            missing_topics+=("$topic")
            ((missing_count++))
        fi
    done
    
    if [ $missing_count -eq 0 ]; then
        log_success "🎉 All required topics already exist"
        return 0
    fi
    
    log_info "📊 Found $existing_count existing topics, $missing_count missing topics"
    
    # Create missing topics
    if [ ${#missing_topics[@]} -gt 0 ]; then
        log_info "Creating missing topics..."
        for topic in "${missing_topics[@]}"; do
            # Use the create_topic function from setup-pubsub-topics.sh which handles gcloud/curl logic
            if create_topic "$topic" "$FIREBASE_PROJECT_ID"; then
                log_success "✅ Created missing topic: $topic"
            else
                log_error "❌ Failed to create topic: $topic"
                return 1
            fi
        done
        log_success "🎉 All missing topics created successfully"
    fi
}

# Function to list all Pub/Sub subscriptions
check_subs() {
    log_header "Listing Pub/Sub Subscriptions"
    
    if ! pubsub_status >/dev/null 2>&1; then
        log_error "Pub/Sub emulator is not available"
        return 1
    fi
    
    log_info "Fetching subscriptions from Pub/Sub emulator..."
    
    # Use the list_subscriptions function from the sourced script instead of malformed jq
    if list_subscriptions "$FIREBASE_PROJECT_ID"; then
        log_success "✅ Subscriptions listed successfully"
    else
        log_warning "⚠️  No subscriptions found or error occurred"
        log_info "This is normal for a fresh emulator"
    fi
}

# Function to delete a specific Pub/Sub topic
delete_topic() {
    local topic_name=${1:-""}
    
    if [ -z "$topic_name" ]; then
        log_error "Topic name is required"
        echo "Usage: $0 delete-topic <topic-name>"
        return 1
    fi
    
    log_header "Deleting Pub/Sub Topic: $topic_name"
    
    if ! pubsub_status >/dev/null 2>&1; then
        log_error "Pub/Sub emulator is not available"
        return 1
    fi
    
    log_warning "⚠️  This will delete the topic and all its messages!"
    read -p "Are you sure you want to delete topic '$topic_name'? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "Deleting topic: $topic_name"
        
    if gcloud pubsub topics delete "$topic_name" --project="$_project_id" --host-port=localhost:8085 2>/dev/null; then
            log_success "✅ Topic '$topic_name' deleted successfully"
        else
            log_error "❌ Failed to delete topic '$topic_name'"
            return 1
        fi
    else
        log_info "Topic deletion cancelled"
    fi
}

# Function to test Pub/Sub pipeline by publishing a test message
test_pubsub() {
    local topic_name=${1:-"category-extraction-topic"}
    
    log_header "Testing Pub/Sub Pipeline: $topic_name"
    
    if ! pubsub_status >/dev/null 2>&1; then
        log_error "Pub/Sub emulator is not available"
        return 1
    fi
    
    # Check if topic exists using local emulator HTTP API
    local topic_check=$(curl -s -w "%{http_code}" \
        "http://localhost:8085/v1/projects/$FIREBASE_PROJECT_ID/topics/$topic_name" \
        -H "Content-Type: application/json" 2>/dev/null)
    
    local http_code="${topic_check: -3}"
    if [ "$http_code" != "200" ]; then
        log_error "Topic '$topic_name' does not exist"
        log_info "Create it first with: $0 create-topic $topic_name"
        return 1
    fi
    
    # Create test message
    local test_message='{"test": true, "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'", "message": "Test message from manage.sh"}'
    
    log_info "Publishing test message to topic: $topic_name"
    log_info "Message: $test_message"
    
    # Publish test message using local emulator HTTP API
    local publish_response=$(curl -s -w "%{http_code}" -X POST \
        "http://localhost:8085/v1/projects/$FIREBASE_PROJECT_ID/topics/$topic_name:publish" \
        -H "Content-Type: application/json" \
        -d "{\"messages\": [{\"data\": \"$(echo "$test_message" | base64)\"}]}" 2>/dev/null)
    
    local publish_http_code="${publish_response: -3}"
    if [ "$publish_http_code" = "200" ]; then
        log_success "✅ Test message published successfully to $topic_name"
        log_info "Check the Firebase Functions logs to see if the message was received"
    else
        log_error "❌ Failed to publish test message to $topic_name. HTTP Code: $publish_http_code"
        return 1
    fi
}

# Main function
main() {
    local command=${1:-"help"}
    local services_dir=""
    
    # Parse global options first
    while [[ $# -gt 0 ]]; do
        case $1 in
            --services-dir=*)
                services_dir="${1#*=}"
                export SERVICES_DIR="$services_dir"
                log_info "Services directory set to: $services_dir"
                shift
                ;;
            --services-dir)
                services_dir="$2"
                export SERVICES_DIR="$services_dir"
                log_info "Services directory set to: $services_dir"
                shift 2
                ;;
            *)
                break
                ;;
        esac
    done
    
    case $command in
        "start-local-min")
            # Minimal local start: disable UI and limit functions to a small subset unless overridden
            if [ -z "$FUNCTIONS_FILTER" ]; then
              export FUNCTIONS_FILTER="category_extraction,product_extraction_pubsub,product_enrichment_pubsub"
              log_info "Default minimal FUNCTIONS_FILTER applied: $FUNCTIONS_FILTER"
            fi
    
            start_local
            ;;
        "start-local")
            # Parse optional arguments for start-local
            shift # Remove the command itself
            while [[ $# -gt 0 ]]; do
                case $1 in
                    --concurrency=*)
                        export FUNCTION_CONCURRENCY="${1#*=}"
                        log_info "Function concurrency set to: $FUNCTION_CONCURRENCY"
                        shift
                        ;;
                    --max-instances=*)
                        export FUNCTION_MAX_INSTANCES="${1#*=}"
                        log_info "Function max instances set to: $FUNCTION_MAX_INSTANCES"
                        shift
                        ;;
                    --services=*)
                        export FUNCTIONS_FILTER="${1#*=}"
                        log_info "Functions filter set to: $FUNCTIONS_FILTER"
                        shift
                        ;;

                    *)
                        log_error "Unknown option: $1"
                        show_usage
                        exit 1
                        ;;
                esac
            done
            start_local
            ;;
        "stop-local")
            stop_local
            ;;
        "status-local")
            status_local
            ;;
        "deploy-local")
            deploy_local
            ;;
        "deploy-remote")
            deploy_remote
            ;;
        "prepare-deploy")
            prepare_deploy "$@"
            ;;
        "deploy-from")
            # Parse deploy-from arguments
            deployment_dir=""
            project_id=""
            force_deploy="false"
            shift
            while [[ $# -gt 0 ]]; do
                case $1 in
                    --dir)
                        deployment_dir="$2"
                        shift 2
                        ;;
                    --project)
                        project_id="$2"
                        shift 2
                        ;;
                    --force)
                        force_deploy="true"
                        shift
                        ;;
                    *)
                        echo "Unknown option: $1"
                        echo "Usage: $0 deploy-from --dir PATH --project PROJECT_ID [--force]"
                        exit 1
                        ;;
                esac
            done

            if [ -z "$deployment_dir" ] || [ -z "$project_id" ]; then
                echo "Usage: $0 deploy-from --dir PATH --project PROJECT_ID [--force]"
                exit 1
            fi

            deploy_from_directory "$deployment_dir" "$project_id" "$force_deploy"
            ;;
        "deploy-function")
            deploy_specific_function "$@"
            ;;
        "remove-function")
            remove_specific_function "$@"
            ;;
        "test-pipeline")
            test_pipeline_trigger "$@"
            ;;
        "set-api-key")
            set_api_key "$@"
            ;;
        "restart-local")
            restart_local
            ;;
        "clean-local")
            clean_local
            ;;
        "preserve-data")
            # Forward all args to local helper script
            log_header "Firestore export/import helper"
            "$SCRIPT_DIR/local/firestore-preserve.sh" "${2:-}" "${3:-}" "${4:-}"
            ;;
        "infer-schema")
            log_header "Inferring Firestore schema (REST)"
            # forward all remaining args
            shift
            "$SCRIPT_DIR/local/infer-firestore-schema-rest.js" "$@"
            ;;
        "clean-remote")
            clean_remote
            ;;
        "force-clean")
            force_clean
            ;;
        "fresh-deploy")
            force_clean_and_deploy
            ;;
        "setup-local")
            setup_local
            ;;
        # Pub/Sub Management Commands
        "check-topics")
            check_topics
            ;;
        "create-topic")
            create_single_pubsub_topic_command "$2" # CALL NEW FUNCTION NAME
            ;;
        "create-topics")
            create_topics
            ;;
        "ensure-topics")
            # Call the dedicated setup function from the sourced script
            setup_all_pubsub_resources
            ;;
        # Resource Management Commands
        "monitor-resources")
            log_header "Starting Resource Monitoring"
            "$SCRIPT_DIR/local/monitor-resources.sh" monitor
            ;;
        "check-resources")
            log_header "Checking Resource Usage"
            "$SCRIPT_DIR/local/monitor-resources.sh" check
            ;;
        "cleanup-resources")
            log_header "Cleaning Up Resources"
            "$SCRIPT_DIR/local/monitor-resources.sh" cleanup
            ;;
        "check-subs")
            check_subs
            ;;
        "delete-topic")
            delete_topic "$2"
            ;;
        "test-pubsub")
            test_pubsub "$2"
            ;;
        "pubsub-status")
            pubsub_status
            ;;
        "help"|"--help"|"-h")
            show_usage
            ;;
        *)
            log_error "Unknown command: $command"
            show_usage
            exit 1
            ;;
    esac
}

# Run main function
main "$@"

#!/bin/bash

# =============================================================================
# Firebase Production Deployment Preparation Script
# =============================================================================
# This script prepares a clean deployment directory for Firebase Functions
# It's designed for PRODUCTION deployment only (not local emulator)
# =============================================================================

# Firebase project configuration
DEFAULT_PROJECT_ID=""  # Production project ID
DEFAULT_REGION="us-central1"      # Production region

# =============================================================================
# Configuration
# =============================================================================

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# List of essential pipeline services (in deployment order)
SERVICES=(
    "orchestrator-service"
    "category-extraction-service"
    "products-extraction-service"
    "product-image-service"
    "sustainability-enrichment-service"
    "eprel-enrichment-service"
    "oecd-sustainability-enrichment-service"
    "fao-agricultural-enrichment-service"
    "legal-compliance-service"
)

# Files to copy for each service (ONLY essential source files)
SERVICE_FILES=(
    "index.js"           # Main service entry point
    "package.json"        # Dependencies and metadata
    "pipeline-config.js"  # Pipeline configuration
    "sequential-orchestrator.js"  # Core orchestrator logic
    "index-pubsub.js"     # Pub/Sub handlers
    "index-async.js"      # Async handlers
    "pubsub-handler.js"   # Pub/Sub utilities
    "queue-manager.js"    # Queue management
    "scheduler-handler.js" # Scheduler utilities
)

# Files to exclude from deployment
EXCLUDE_PATTERNS=(
    "*.test.js"
    "*.spec.js"
    "test/"
    "tests/"
    "docs/"
    "README.md"
    ".env"
    ".git/"
    "node_modules/.cache/"
)

# =============================================================================
# Functions
# =============================================================================

# Function to show usage
show_usage() {
    echo "Firebase Production Deployment Preparation Script"
    echo ""
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo ""
    echo "Commands:"
    echo "  prepare     Prepare deployment directory only (production-ready)"
    echo "  deploy      Prepare and deploy to Firebase production"
    echo "  clean       Clean up deployment directory"
    echo ""
    echo "Options:"
    echo "  --project PROJECT_ID    Firebase project ID (default: $DEFAULT_PROJECT_ID)"
    echo "  --region REGION         Firebase region (default: $DEFAULT_REGION)"
    echo "  --production            Force production mode (default for this script)"
    echo "  --help                  Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 prepare                    # Prepare production deployment directory"
    echo "  $0 deploy                     # Deploy to $DEFAULT_PROJECT_ID"
    echo "  $0 deploy --project myproject # Deploy to custom project"
    echo ""
    echo "Note: This script is designed for PRODUCTION deployment only."
    echo "Use manage.sh for local emulator operations."
}

# Function to log messages (redirect to stderr to avoid interfering with stdout output)
log_info() { echo "ℹ️  $1" >&2; }
log_success() { echo "✅ $1" >&2; }
log_warning() { echo "⚠️  $1" >&2; }
log_error() { echo "❌ $1" >&2; }
log_header() { echo "" >&2; echo "🔧 $1" >&2; echo "==================================" >&2; }

# Function to create production-ready index.js for a service
create_production_index() {
    local service_name="$1"
    local service_dir="$2"
    local target_dir="$3"
    
    log_info "Creating production index.js for $service_name..."
    
    # Copy the original index.js
    cp "$service_dir/index.js" "$target_dir/index.js"
    
    # Add production environment overrides at the top
    cat > "$target_dir/index.js.tmp" << 'EOF'
// Production environment overrides
process.env.GOOGLE_CLOUD_PROJECT = process.env.FIREBASE_PROJECT_ID || 'your-project-id';
process.env.FIREBASE_PROJECT_ID = process.env.FIREBASE_PROJECT_ID || 'your-project-id';
process.env.FIREBASE_REGION = process.env.FIREBASE_REGION || 'us-central1';
process.env.NODE_ENV = 'production';
process.env.FUNCTIONS_EMULATOR = 'false';
process.env.FIRESTORE_EMULATOR_HOST = '';
process.env.PUBSUB_EMULATOR_HOST = '';

EOF
    
    # Append the original content with fixed import paths
    sed 's|require("\.\./libs/|require("../../libs/|g; s|require("\./libs/|require("../../libs/|g' "$target_dir/index.js" >> "$target_dir/index.js.tmp"
    
    # Replace the original
    mv "$target_dir/index.js.tmp" "$target_dir/index.js"
    
    log_success "Production index.js created for $service_name"
}

# Function to prepare deployment directory
prepare_deployment() {
    local project_id="${1:-$DEFAULT_PROJECT_ID}"
    local region="${2:-$DEFAULT_REGION}"
    local is_production="${3:-true}"
    
    log_header "Preparing Production Deployment Directory"
    log_info "Project: $project_id"
    log_info "Region: $region"
    log_info "Mode: Production"
    
    # Create temporary deployment directory
    local deployment_dir="/tmp/firebase-deployment-$(date +%s)"
    mkdir -p "$deployment_dir"
    
    log_info "Created deployment directory: $deployment_dir"
    
    # Create services directory
    local services_dir="$deployment_dir/services"
    mkdir -p "$services_dir"
    
    # Copy shared libraries to root (needed by services)
    if [ -d "$SCRIPT_DIR/../libs" ]; then
        log_info "Copying shared libraries..."
        cp -r "$SCRIPT_DIR/../libs" "$deployment_dir/"
        log_success "Copied shared libraries"
    fi
    
    # Copy services shared libraries (needed by individual services)
    if [ -d "$SCRIPT_DIR/../services/libs" ]; then
        log_info "Copying services shared libraries..."
        cp -r "$SCRIPT_DIR/../services/libs" "$deployment_dir/services/"
        log_success "Copied services shared libraries"
        
        # Copy firebaseAdmin.js to root libs/shared/ (needed by orchestrator)
        if [ -f "$SCRIPT_DIR/../services/libs/shared/firebaseAdmin.js" ]; then
            log_info "Copying firebaseAdmin.js to root libs..."
            cp "$SCRIPT_DIR/../services/libs/shared/firebaseAdmin.js" "$deployment_dir/libs/shared/"
            log_success "Copied firebaseAdmin.js to root libs"
        fi
    else
        log_warning "Services shared libraries directory not found, services may fail"
    fi
    
    # Copy each service to services subdirectory (keep original structure)
    for service in "${SERVICES[@]}"; do
        local source_dir="$SCRIPT_DIR/../services/$service"
        local target_dir="$deployment_dir/services/$service"
        
        if [ ! -d "$source_dir" ]; then
            log_warning "Service directory not found: $service"
            continue
        fi
        
        log_info "Processing service: $service"
        mkdir -p "$target_dir"
        
        # Copy only essential source files (no node_modules, no unnecessary files)
        for file_pattern in "${SERVICE_FILES[@]}"; do
            if [ -e "$source_dir/$file_pattern" ]; then
                if [[ "$file_pattern" == */ ]]; then
                    # Directory - copy as-is
                    cp -r "$source_dir/$file_pattern" "$target_dir/"
                else
                    # File - copy as-is
                    cp "$source_dir/$file_pattern" "$target_dir/"
                fi
            fi
        done
        
        # Create production-ready index.js
        create_production_index "$service" "$source_dir" "$target_dir"
    done
    
    # Create production firebase.json
    cat > "$deployment_dir/firebase.json" << EOF
{
  "functions": {
    "source": ".",
    "runtime": "nodejs18",
    "codebase": "default"
  }
}
EOF
    
    # Create root index.js that exports all functions (Firebase v2 requirement)
    cat > "$deployment_dir/index.js" << 'EOF'
// Root entry point for Firebase Functions v2
// This file exports all functions from the services subdirectories
const functions = require('firebase-functions');

// Import and export orchestrator functions
const orchestrator = require('./services/orchestrator-service/index.js');
Object.assign(exports, orchestrator);

// Import and export category extraction functions
const categoryExtraction = require('./services/category-extraction-service/index.js');
Object.assign(exports, categoryExtraction);

// Import and export product extraction functions
const productExtraction = require('./services/products-extraction-service/index.js');
Object.assign(exports, productExtraction);

// Import and export product image functions
const productImage = require('./services/product-image-service/index.js');
Object.assign(exports, productImage);

// Import and export sustainability functions
const sustainability = require('./services/sustainability-enrichment-service/index.js');
Object.assign(exports, sustainability);

// Import and export EPREL functions
const eprel = require('./services/eprel-enrichment-service/index.js');
Object.assign(exports, eprel);

// Import and export FAO functions
const fao = require('./services/fao-agricultural-enrichment-service/index.js');
Object.assign(exports, fao);

// Import and export Legal Compliance functions
const legalCompliance = require('./services/legal-compliance-service/index.js');
Object.assign(exports, legalCompliance);

// Export a health check function
exports.health = functions.https.onRequest((req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});
EOF

    # Create production .env file
    cat > "$deployment_dir/.env" << EOF
# Production Environment Variables
PROJECT_ID=$project_id
REGION=$region
NODE_ENV=production
FUNCTIONS_EMULATOR=false
FIRESTORE_EMULATOR_HOST=
PUBSUB_EMULATOR_HOST=

# AI Provider Configuration
AI_PROVIDER=gemini
AI_MODEL=gemini-2.5-flash-lite
AI_API_KEY=\${GEMINI_API_KEY}
GEMINI_API_KEY=\${GEMINI_API_KEY}
GOOGLE_API_KEY=\${GOOGLE_API_KEY}
AI_USE_SDK=true

# Google Search API
GOOGLE_SEARCH_API_KEY=\${GOOGLE_SEARCH_API_KEY}
GOOGLE_CSE_ID=\${GOOGLE_CSE_ID}
EOF
    
    # Create package.json for deployment
    cat > "$deployment_dir/package.json" << EOF
{
  "name": "your-project-id",
  "version": "1.0.0",
  "description": "ESG Pipeline Production Deployment",
  "main": "index.js",
  "scripts": {
    "deploy": "firebase deploy --only functions --project $project_id"
  },
  "engines": {
    "node": "18"
  },
  "dependencies": {
    "firebase-functions": "^4.0.0"
  },
  "type": "commonjs"
}
EOF
    
    log_success "Deployment directory prepared successfully!"
    log_info "Location: $deployment_dir"
    log_info "Next step: cd $deployment_dir && firebase deploy --only functions --project $project_id"
    
    # Return the deployment directory path (this should be the only output to stdout)
    echo "$deployment_dir" >&1
}

# Function to deploy to Firebase
deploy_to_firebase() {
    local project_id="${1:-$DEFAULT_PROJECT_ID}"
    local region="${2:-$DEFAULT_REGION}"
    
    log_header "Deploying to Firebase Production"
    log_info "Project: $project_id"
    log_info "Region: $region"
    
    # Prepare deployment directory
    local deployment_dir=$(prepare_deployment "$project_id" "$region" "true")
    
    if [ -z "$deployment_dir" ]; then
        log_error "Failed to prepare deployment directory"
        return 1
    fi
    
    # Change to deployment directory
    cd "$deployment_dir" || {
        log_error "Failed to change to deployment directory"
        return 1
    }
    
    # Install all required dependencies
    log_info "Installing required dependencies..."
    npm install firebase-functions axios firebase-admin @google-cloud/pubsub
    
    # Deploy to Firebase
    log_info "Deploying to Firebase..."
    if firebase deploy --only functions --project "$project_id"; then
        log_success "Deployment completed successfully!"
    else
        log_error "Deployment failed!"
        return 1
    fi
    
    # Clean up
    log_info "Cleaning up deployment directory..."
    cd - > /dev/null
    rm -rf "$deployment_dir"
    
    log_success "Deployment process completed!"
}

# Function to clean up deployment directory
clean_deployment() {
    log_header "Cleaning Up Deployment Directory"
    
    local deployment_dirs=($(find /tmp -maxdepth 1 -name "firebase-deployment-*" -type d 2>/dev/null))
    
    if [ ${#deployment_dirs[@]} -eq 0 ]; then
        log_info "No deployment directories found to clean"
        return 0
    fi
    
    log_info "Found ${#deployment_dirs[@]} deployment directory(ies) to clean"
    
    for dir in "${deployment_dirs[@]}"; do
        log_info "Removing: $dir"
        rm -rf "$dir"
    done
    
    log_success "Cleanup completed!"
}

# =============================================================================
# Main Script Logic
# =============================================================================

# Parse command line arguments
COMMAND=""
PROJECT_ID="$DEFAULT_PROJECT_ID"
REGION="$DEFAULT_REGION"
IS_PRODUCTION="true"

while [[ $# -gt 0 ]]; do
    case $1 in
        prepare|deploy|clean)
            COMMAND="$1"
            shift
            ;;
        --project)
            PROJECT_ID="$2"
            shift 2
            ;;
        --region)
            REGION="$2"
            shift 2
            ;;
        --production)
            IS_PRODUCTION="true"
            shift
            ;;
        --help|-h)
            show_usage
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Validate command
if [ -z "$COMMAND" ]; then
    log_error "No command specified"
    show_usage
    exit 1
fi

# Execute command
case "$COMMAND" in
    prepare)
        prepare_deployment "$PROJECT_ID" "$REGION" "$IS_PRODUCTION"
        ;;
    deploy)
        deploy_to_firebase "$PROJECT_ID" "$REGION"
        ;;
    clean)
        clean_deployment
        ;;
    *)
        log_error "Unknown command: $COMMAND"
        show_usage
        exit 1
        ;;
esac

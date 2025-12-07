#!/bin/bash

# Unified Firebase Deployment Script
# Consolidated deployment functionality with multiple modes
# Usage: ./unified-deploy.sh [MODE] [OPTIONS]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default configuration
PROJECT_ID=""
REGION="us-central1"
DEPLOYMENT_DIR="/tmp/firebase-deployment"
PROJECT_DIR=""
SERVICES_DIR=""
MODE="simple"
DRY_RUN=false
INSTALL_DEPS=false

# Essential services for deployment
ESSENTIAL_SERVICES=(
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

# Logging functions
log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }
log_header() { echo -e "${BLUE}========================================${NC}"; echo -e "${BLUE}$1${NC}"; echo -e "${BLUE}========================================${NC}"; }

# Show usage information
show_usage() {
    echo "🚀 Unified Firebase Deployment Script"
    echo ""
    echo "MODES:"
    echo "  simple      Quick deployment with minimal configuration"
    echo "  generic     Full deployment from any project structure"
    echo "  production  Production-ready deployment with optimizations"
    echo ""
    echo "Usage: $0 [MODE] [OPTIONS]"
    echo ""
    echo "OPTIONS:"
    echo "  --project-id ID       Firebase project ID"
    echo "  --region REGION       Firebase region (default: us-central1)"
    echo "  --project-dir PATH    Main project directory (generic mode)"
    echo "  --services-dir PATH   Services directory relative to project-dir (generic mode)"
    echo "  --install-deps        Install dependencies before deployment"
    echo "  --dry-run            Show what would be deployed without deploying"
    echo "  --help               Show this help message"
    echo ""
    echo "EXAMPLES:"
    echo "  $0 simple --project-id my-project"
    echo "  $0 generic --project-dir /path/to/project --services-dir services --project-id my-project"
    echo "  $0 production --project-id my-project --region europe-west1 --install-deps"
    echo ""
    echo "ENVIRONMENT VARIABLES:"
    echo "  FIREBASE_PROJECT_ID   Default project ID"
    echo "  FIREBASE_REGION      Default region"
    echo "  GEMINI_API_KEY       API key for AI services"
    echo "  GOOGLE_SEARCH_API_KEY, GOOGLE_CSE_ID, QDRANT_URL  Optional service keys"
}

# Validate requirements
validate_requirements() {
    log_info "Validating deployment requirements..."

    # Check Firebase CLI
    if ! command -v firebase &> /dev/null; then
        log_error "Firebase CLI is not installed. Install with: npm install -g firebase-tools"
        exit 1
    fi

    # Check project ID
    if [ -z "$PROJECT_ID" ]; then
        PROJECT_ID=${FIREBASE_PROJECT_ID:-""}
        if [ -z "$PROJECT_ID" ]; then
            log_error "Project ID is required. Set --project-id or FIREBASE_PROJECT_ID environment variable"
            exit 1
        fi
    fi

    # Check authentication
    if ! firebase projects:list &> /dev/null; then
        log_error "Firebase authentication required. Run: firebase login"
        exit 1
    fi

    log_success "Requirements validation passed"
}

# Create deployment directory
setup_deployment_dir() {
    log_info "Setting up deployment directory: $DEPLOYMENT_DIR"

    rm -rf "$DEPLOYMENT_DIR"
    mkdir -p "$DEPLOYMENT_DIR"
    mkdir -p "$DEPLOYMENT_DIR/services"

    log_success "Deployment directory created"
}

# Create firebase.json configuration
create_firebase_config() {
    log_info "Creating firebase.json configuration..."

    cat > "$DEPLOYMENT_DIR/firebase.json" << EOF
{
  "functions": {
    "source": ".",
    "runtime": "nodejs18",
    "region": "$REGION",
    "environmentVariables": {
      "PROJECT_ID": "$PROJECT_ID",
      "FIREBASE_PROJECT_ID": "$PROJECT_ID",
      "FIREBASE_REGION": "$REGION",
      "NODE_ENV": "production",
      "AI_PROVIDER": "gemini",
      "AI_MODEL": "gemini-2.0-flash-exp",
      "AI_API_KEY": "\${GEMINI_API_KEY}",
      "GEMINI_API_KEY": "\${GEMINI_API_KEY}",
      "GOOGLE_API_KEY": "\${GOOGLE_API_KEY}",
      "GOOGLE_SEARCH_API_KEY": "\${GOOGLE_SEARCH_API_KEY}",
      "GOOGLE_CSE_ID": "\${GOOGLE_CSE_ID}",
      "QDRANT_URL": "\${QDRANT_URL}",
      "LOG_EXECUTION_ID": "true"
    }
  }
}
EOF

    log_success "Firebase configuration created"
}

# Create environment file
create_env_file() {
    log_info "Creating environment configuration..."

    cat > "$DEPLOYMENT_DIR/.env" << EOF
# Firebase Configuration
PROJECT_ID=$PROJECT_ID
FIREBASE_PROJECT_ID=$PROJECT_ID
FIREBASE_REGION=$REGION
NODE_ENV=production

# AI Configuration
AI_PROVIDER=gemini
AI_MODEL=gemini-2.0-flash-exp
AI_API_KEY=\${GEMINI_API_KEY}
GEMINI_API_KEY=\${GEMINI_API_KEY}
GOOGLE_API_KEY=\${GOOGLE_API_KEY}
AI_USE_SDK=true

# Search API Configuration
GOOGLE_SEARCH_API_KEY=\${GOOGLE_SEARCH_API_KEY}
GOOGLE_CSE_ID=\${GOOGLE_CSE_ID}

# Vector Database Configuration
QDRANT_URL=\${QDRANT_URL}
QDRANT_API_KEY=

# Logging Configuration
LOG_EXECUTION_ID=true
EOF

    log_success "Environment configuration created"
}

# Create package.json
create_package_json() {
    log_info "Creating package.json..."

    cat > "$DEPLOYMENT_DIR/package.json" << EOF
{
  "name": "firebase-functions-deployment",
  "version": "1.0.0",
  "description": "Unified Firebase Functions deployment",
  "main": "index.js",
  "scripts": {
    "deploy": "firebase deploy --only functions --project $PROJECT_ID",
    "serve": "firebase emulators:start",
    "test": "echo \\"No tests specified\\" && exit 0"
  },
  "engines": {
    "node": "18"
  },
  "dependencies": {
    "firebase-functions": "^4.0.0",
    "firebase-admin": "^11.0.0"
  },
  "type": "commonjs"
}
EOF

    log_success "Package.json created"
}

# Simple deployment mode
deploy_simple() {
    log_header "Simple Deployment Mode"

    setup_deployment_dir
    create_firebase_config
    create_env_file
    create_package_json

    # Copy .env to services directory
    cp "$DEPLOYMENT_DIR/.env" "$DEPLOYMENT_DIR/services/"

    # Create minimal index.js
    cat > "$DEPLOYMENT_DIR/index.js" << 'EOF'
const functions = require('firebase-functions');

// Health check function
exports.health = functions.https.onRequest((req, res) => {
  res.json({
    status: 'ok',
    timestamp: new Date().toISOString(),
    project: process.env.PROJECT_ID
  });
});

// Add your function imports here
// Example: exports.myFunction = require('./services/my-service/index.js').myFunction;
EOF

    log_success "Simple deployment structure created"
}

# Generic deployment mode
deploy_generic() {
    log_header "Generic Deployment Mode"

    if [ -z "$PROJECT_DIR" ] || [ -z "$SERVICES_DIR" ]; then
        log_error "Generic mode requires --project-dir and --services-dir"
        exit 1
    fi

    if [ ! -d "$PROJECT_DIR" ]; then
        log_error "Project directory not found: $PROJECT_DIR"
        exit 1
    fi

    setup_deployment_dir
    create_firebase_config
    create_env_file
    create_package_json

    # Copy services if they exist
    local full_services_path="$PROJECT_DIR/$SERVICES_DIR"
    if [ -d "$full_services_path" ]; then
        log_info "Copying services from: $full_services_path"
        cp -r "$full_services_path"/* "$DEPLOYMENT_DIR/services/" 2>/dev/null || true
    fi

    # Copy shared libraries if they exist
    if [ -d "$PROJECT_DIR/libs" ]; then
        log_info "Copying shared libraries..."
        cp -r "$PROJECT_DIR/libs" "$DEPLOYMENT_DIR/"
    fi

    # Create root index.js
    create_root_index

    log_success "Generic deployment structure created"
}

# Production deployment mode
deploy_production() {
    log_header "Production Deployment Mode"

    deploy_generic

    # Additional production optimizations
    log_info "Applying production optimizations..."

    # Update firebase.json for production
    cat > "$DEPLOYMENT_DIR/firebase.json" << EOF
{
  "functions": {
    "source": ".",
    "runtime": "nodejs18",
    "region": "$REGION",
    "memory": "1GB",
    "timeout": "300s",
    "environmentVariables": {
      "PROJECT_ID": "$PROJECT_ID",
      "FIREBASE_PROJECT_ID": "$PROJECT_ID",
      "FIREBASE_REGION": "$REGION",
      "NODE_ENV": "production",
      "AI_PROVIDER": "gemini",
      "AI_MODEL": "gemini-2.0-flash-exp",
      "AI_API_KEY": "\${GEMINI_API_KEY}",
      "GEMINI_API_KEY": "\${GEMINI_API_KEY}",
      "GOOGLE_API_KEY": "\${GOOGLE_API_KEY}",
      "GOOGLE_SEARCH_API_KEY": "\${GOOGLE_SEARCH_API_KEY}",
      "GOOGLE_CSE_ID": "\${GOOGLE_CSE_ID}",
      "QDRANT_URL": "\${QDRANT_URL}",
      "LOG_EXECUTION_ID": "true"
    }
  }
}
EOF

    log_success "Production optimizations applied"
}

# Create root index.js for function exports
create_root_index() {
    log_info "Creating root index.js for function exports..."

    cat > "$DEPLOYMENT_DIR/index.js" << 'EOF'
// Root entry point for Firebase Functions
// This file exports all functions from the services subdirectories
const functions = require('firebase-functions');

// Health check function
exports.health = functions.https.onRequest((req, res) => {
  res.json({
    status: 'ok',
    timestamp: new Date().toISOString(),
    project: process.env.PROJECT_ID || process.env.FIREBASE_PROJECT_ID
  });
});

// Dynamically import and export service functions
// Add your service imports here as they become available
// Example structure:
// try {
//   const myService = require('./services/my-service/index.js');
//   Object.assign(exports, myService);
// } catch (error) {
//   console.log('Service my-service not found, skipping...');
// }
EOF

    log_success "Root index.js created"
}

# Deploy to Firebase
execute_deployment() {
    if [ "$DRY_RUN" = true ]; then
        log_info "DRY RUN - Deployment structure created at: $DEPLOYMENT_DIR"
        log_info "To deploy manually, run: cd $DEPLOYMENT_DIR && firebase deploy --only functions --project $PROJECT_ID"
        return 0
    fi

    log_header "Deploying to Firebase"

    cd "$DEPLOYMENT_DIR"

    # Install dependencies if requested
    if [ "$INSTALL_DEPS" = true ]; then
        log_info "Installing dependencies..."
        npm install
    fi

    # Deploy to Firebase
    log_info "Deploying to Firebase project: $PROJECT_ID"
    firebase deploy --only functions --project "$PROJECT_ID"

    log_success "Deployment completed successfully!"
    log_info "Functions deployed to: https://$REGION-$PROJECT_ID.cloudfunctions.net/"

    # Show deployed functions
    log_info "Listing deployed functions..."
    firebase functions:list --project "$PROJECT_ID" || true
}

# Parse command line arguments
parse_arguments() {
    # Check if first argument is a mode
    if [[ "$1" =~ ^(simple|generic|production)$ ]]; then
        MODE="$1"
        shift
    fi

    while [[ $# -gt 0 ]]; do
        case $1 in
            --project-id)
                PROJECT_ID="$2"
                shift 2
                ;;
            --region)
                REGION="$2"
                shift 2
                ;;
            --project-dir)
                PROJECT_DIR="$2"
                shift 2
                ;;
            --services-dir)
                SERVICES_DIR="$2"
                shift 2
                ;;
            --install-deps)
                INSTALL_DEPS=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
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
}

# Main execution
main() {
    log_header "Unified Firebase Deployment Script"

    # Parse arguments
    parse_arguments "$@"

    # Show configuration
    log_info "Deployment Configuration:"
    log_info "  Mode: $MODE"
    log_info "  Project ID: ${PROJECT_ID:-"(to be determined)"}"
    log_info "  Region: $REGION"
    if [ -n "$PROJECT_DIR" ]; then
        log_info "  Project Dir: $PROJECT_DIR"
    fi
    if [ -n "$SERVICES_DIR" ]; then
        log_info "  Services Dir: $SERVICES_DIR"
    fi
    log_info "  Dry Run: $DRY_RUN"
    log_info "  Install Deps: $INSTALL_DEPS"
    echo ""

    # Validate requirements
    validate_requirements

    # Execute deployment based on mode
    case "$MODE" in
        "simple")
            deploy_simple
            ;;
        "generic")
            deploy_generic
            ;;
        "production")
            deploy_production
            ;;
        *)
            log_error "Invalid mode: $MODE"
            show_usage
            exit 1
            ;;
    esac

    # Execute the deployment
    execute_deployment

    log_success "🎉 Unified deployment completed successfully!"
}

# Handle script interruption
trap 'log_warning "Deployment interrupted"; exit 1' INT TERM

# Run main function with all arguments
main "$@"
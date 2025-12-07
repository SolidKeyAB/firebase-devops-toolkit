#!/bin/bash

# =============================================================================
# Project Orchestration Script Template
# =============================================================================
#
# This is a template for your project-specific orchestration script.
# It wraps @solidkey/firebase-devops-toolkit and adds project-specific commands.
#
# USAGE:
#   1. Copy this file to your project: cp orchestrate.sh your-project/scripts/
#   2. Customize the PROJECT_* variables below
#   3. Add your project-specific commands in the case statement
#   4. Run: ./scripts/orchestrate.sh [command]
#
# INSTALLATION METHODS (choose one):
#   npm install @solidkey/firebase-devops-toolkit --save-dev
#   git submodule add https://github.com/SolidKeyAB/firebase-devops-toolkit.git
#   export FIREBASE_DEVOPS_DIR=/path/to/firebase-devops-toolkit
#
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# =============================================================================
# PROJECT CONFIGURATION - Customize these for your project
# =============================================================================

# Project root (typically one level up from scripts/)
export PROJECT_ROOT="${PROJECT_ROOT:-$(dirname "$SCRIPT_DIR")}"

# Services directory (where your Firebase functions live)
export SERVICES_DIR="${SERVICES_DIR:-$PROJECT_ROOT/services}"

# Firebase project ID (can also be set via FIREBASE_PROJECT_ID env var)
export FIREBASE_PROJECT_ID="${FIREBASE_PROJECT_ID:-your-firebase-project-id}"

# GCP region for deployment
export FIREBASE_REGION="${FIREBASE_REGION:-us-central1}"

# Essential services file (optional - list of services to deploy)
export ESSENTIAL_SERVICES_FILE="${ESSENTIAL_SERVICES_FILE:-$SERVICES_DIR/essential-services.txt}"

# =============================================================================
# AUTO-DETECT FIREBASE DEVOPS TOOLKIT LOCATION
# =============================================================================

find_firebase_devops() {
    # Priority order for finding the toolkit:

    # 1. Environment variable (explicit override)
    if [ -n "$FIREBASE_DEVOPS_DIR" ] && [ -f "$FIREBASE_DEVOPS_DIR/manage.sh" ]; then
        echo "$FIREBASE_DEVOPS_DIR"
        return 0
    fi

    # 2. npm package (recommended for most projects)
    local npm_path="$PROJECT_ROOT/node_modules/@solidkey/firebase-devops-toolkit"
    if [ -f "$npm_path/manage.sh" ]; then
        echo "$npm_path"
        return 0
    fi

    # 3. Git submodule (common for monorepos)
    local submodule_path="$PROJECT_ROOT/firebase-devops-toolkit"
    if [ -f "$submodule_path/manage.sh" ]; then
        echo "$submodule_path"
        return 0
    fi

    # 4. Sibling directory (development setup)
    local sibling_path="$(dirname "$PROJECT_ROOT")/firebase-devops-toolkit"
    if [ -f "$sibling_path/manage.sh" ]; then
        echo "$sibling_path"
        return 0
    fi

    # 5. Legacy name: firebase-scripts
    local legacy_npm="$PROJECT_ROOT/node_modules/firebase-scripts"
    if [ -f "$legacy_npm/manage.sh" ]; then
        echo "$legacy_npm"
        return 0
    fi

    local legacy_sibling="$(dirname "$PROJECT_ROOT")/firebase-scripts"
    if [ -f "$legacy_sibling/manage.sh" ]; then
        echo "$legacy_sibling"
        return 0
    fi

    # 6. Global installation
    if [ -f "$HOME/firebase-devops-toolkit/manage.sh" ]; then
        echo "$HOME/firebase-devops-toolkit"
        return 0
    fi

    if [ -f "$HOME/firebase-scripts/manage.sh" ]; then
        echo "$HOME/firebase-scripts"
        return 0
    fi

    return 1
}

FIREBASE_DEVOPS=$(find_firebase_devops)

if [ -z "$FIREBASE_DEVOPS" ]; then
    echo "ERROR: firebase-devops-toolkit not found!"
    echo ""
    echo "Install using one of these methods:"
    echo ""
    echo "  # Option 1: npm (recommended)"
    echo "  npm install @solidkey/firebase-devops-toolkit --save-dev"
    echo ""
    echo "  # Option 2: Git submodule"
    echo "  git submodule add https://github.com/SolidKeyAB/firebase-devops-toolkit.git"
    echo ""
    echo "  # Option 3: Environment variable"
    echo "  export FIREBASE_DEVOPS_DIR=/path/to/firebase-devops-toolkit"
    echo ""
    exit 1
fi

export FIREBASE_DEVOPS_DIR="$FIREBASE_DEVOPS"
MANAGE_SCRIPT="$FIREBASE_DEVOPS/manage.sh"

# =============================================================================
# COLORS AND LOGGING
# =============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_header() { echo -e "${BLUE}========================================${NC}"; echo -e "${BLUE}$1${NC}"; echo -e "${BLUE}========================================${NC}"; }
log_info() { echo -e "${GREEN}ℹ️  $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }

# =============================================================================
# PROJECT-SPECIFIC COMMANDS
# =============================================================================

# Add your project-specific commands here
# These wrap or extend the base toolkit commands

start_dev() {
    log_header "Starting Development Environment"

    # Example: Start Docker services before emulator
    # log_info "Starting Docker services..."
    # docker-compose up -d

    # Start Firebase emulator via toolkit
    "$MANAGE_SCRIPT" start-local "$@"

    log_success "Development environment started!"
    log_info "Emulator UI: http://localhost:4000"
}

stop_dev() {
    log_header "Stopping Development Environment"

    # Stop Firebase emulator
    "$MANAGE_SCRIPT" stop-local

    # Example: Stop Docker services
    # log_info "Stopping Docker services..."
    # docker-compose down

    log_success "Development environment stopped!"
}

deploy_prod() {
    log_header "Deploying to Production"

    # Add pre-deployment checks
    log_info "Running pre-deployment checks..."

    # Example: Run tests before deploying
    # npm test || { log_error "Tests failed!"; exit 1; }

    # Deploy via toolkit
    "$MANAGE_SCRIPT" deploy-production --project "$FIREBASE_PROJECT_ID" "$@"

    log_success "Deployment complete!"
}

show_usage() {
    echo "Project Orchestration Script"
    echo ""
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo ""
    echo "Project Commands:"
    echo "  start-dev         Start local development environment"
    echo "  stop-dev          Stop local development environment"
    echo "  deploy-prod       Deploy to production with pre-checks"
    echo ""
    echo "Toolkit Commands (passed to firebase-devops-toolkit):"
    echo "  start-local       Start Firebase emulator"
    echo "  stop-local        Stop Firebase emulator"
    echo "  deploy-local      Deploy to local emulator"
    echo "  status-local      Check emulator status"
    echo "  clean-local       Clean up local processes"
    echo "  help              Show all toolkit commands"
    echo ""
    echo "Configuration:"
    echo "  PROJECT_ROOT:     $PROJECT_ROOT"
    echo "  SERVICES_DIR:     $SERVICES_DIR"
    echo "  FIREBASE_PROJECT: $FIREBASE_PROJECT_ID"
    echo "  TOOLKIT:          $FIREBASE_DEVOPS"
    echo ""
}

# =============================================================================
# MAIN COMMAND ROUTER
# =============================================================================

main() {
    local command="${1:-help}"
    shift 2>/dev/null || true

    case "$command" in
        # Project-specific commands
        start-dev|dev)
            start_dev "$@"
            ;;
        stop-dev)
            stop_dev "$@"
            ;;
        deploy-prod|production)
            deploy_prod "$@"
            ;;

        # Show usage
        -h|--help|help)
            show_usage
            ;;

        # Pass everything else to the toolkit
        *)
            exec "$MANAGE_SCRIPT" "$command" "$@"
            ;;
    esac
}

main "$@"

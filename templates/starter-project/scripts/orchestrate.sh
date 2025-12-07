#!/bin/bash

# =============================================================================
# Project Orchestration Script
# =============================================================================
# Wrapper for @solidkeyab/firebase-devops-toolkit
# Customize this for your project needs
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
export SERVICES_DIR="$PROJECT_ROOT/services"

# Your Firebase project ID
export FIREBASE_PROJECT_ID="${FIREBASE_PROJECT_ID:-your-project-id}"
export FIREBASE_REGION="${FIREBASE_REGION:-us-central1}"

# =============================================================================
# Find Firebase DevOps Toolkit
# =============================================================================

find_toolkit() {
    # 1. npm package (GitHub Packages)
    local npm_path="$SERVICES_DIR/node_modules/@solidkeyab/firebase-devops-toolkit"
    [ -f "$npm_path/manage.sh" ] && echo "$npm_path" && return 0

    # 2. Environment variable
    [ -n "$FIREBASE_DEVOPS_DIR" ] && [ -f "$FIREBASE_DEVOPS_DIR/manage.sh" ] && echo "$FIREBASE_DEVOPS_DIR" && return 0

    # 3. Sibling directory
    local sibling="$(dirname "$PROJECT_ROOT")/firebase-devops-toolkit"
    [ -f "$sibling/manage.sh" ] && echo "$sibling" && return 0

    return 1
}

TOOLKIT=$(find_toolkit)
if [ -z "$TOOLKIT" ]; then
    echo "ERROR: Firebase DevOps Toolkit not found!"
    echo ""
    echo "Install it via GitHub Packages:"
    echo "  echo '@solidkeyab:registry=https://npm.pkg.github.com' >> .npmrc"
    echo "  cd services && npm install @solidkeyab/firebase-devops-toolkit"
    echo ""
    echo "Or clone directly:"
    echo "  git clone https://github.com/SolidKeyAB/firebase-devops-toolkit.git"
    echo ""
    exit 1
fi

# =============================================================================
# Commands
# =============================================================================

case "${1:-help}" in
    # Development
    dev|start)
        "$TOOLKIT/manage.sh" start-local
        ;;
    stop)
        "$TOOLKIT/manage.sh" stop-local
        ;;
    status)
        "$TOOLKIT/manage.sh" status-local
        ;;
    deploy-local)
        "$TOOLKIT/manage.sh" deploy-local
        ;;

    # Production
    deploy)
        "$TOOLKIT/manage.sh" deploy-production --project "$FIREBASE_PROJECT_ID"
        ;;

    # Help
    help|--help|-h)
        echo "Project Commands:"
        echo "  dev, start    Start local emulator"
        echo "  stop          Stop emulator"
        echo "  status        Check status"
        echo "  deploy-local  Deploy to emulator"
        echo "  deploy        Deploy to production"
        echo ""
        echo "Toolkit Commands:"
        "$TOOLKIT/manage.sh" help
        ;;

    # Pass to toolkit
    *)
        exec "$TOOLKIT/manage.sh" "$@"
        ;;
esac

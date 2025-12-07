#!/bin/bash

# Generic Firebase Data Preservation Script (Local)
# This script helps preserve Firestore data when restarting services

# Source configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }
log_header() { echo -e "\n${BLUE}========================================\n$1\n========================================${NC}"; }

# Function to export Firestore data
export_firestore_data() {
    local export_dir="emulator-data"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local export_name="firebase-export-$timestamp"
    
    log_info "Exporting Firestore data..."
    
    # Create export directory
    mkdir -p "$export_dir"
    
    # Export Firestore data
    firebase firestore:export "$export_dir/$export_name" --project "$FIREBASE_PROJECT_ID"
    
    if [ $? -eq 0 ]; then
        log_success "✅ Firestore data exported to $export_dir/$export_name"
        echo "$export_dir/$export_name"
    else
        log_error "❌ Failed to export Firestore data"
        return 1
    fi
}

# Function to import Firestore data
import_firestore_data() {
    local import_path=$1
    
    if [ -z "$import_path" ]; then
        log_error "❌ Import path is required"
        return 1
    fi
    
    if [ ! -d "$import_path" ]; then
        log_error "❌ Import directory not found: $import_path"
        return 1
    fi
    
    log_info "Importing Firestore data from $import_path..."
    
    # Import Firestore data
    firebase firestore:import "$import_path" --project "$FIREBASE_PROJECT_ID"
    
    if [ $? -eq 0 ]; then
        log_success "✅ Firestore data imported successfully"
    else
        log_error "❌ Failed to import Firestore data"
        return 1
    fi
}

# Function to list available exports
list_exports() {
    local export_dir="emulator-data"
    
    if [ ! -d "$export_dir" ]; then
        log_warning "⚠️  No exports directory found"
        return 1
    fi
    
    log_info "Available Firestore exports:"
    ls -la "$export_dir" | grep "firebase-export-" | while read line; do
        echo "  📁 $line"
    done
}

# Function to backup before restart
backup_before_restart() {
    log_header "Backing up Firestore data before restart"
    
    # Export current data
    local export_path=$(export_firestore_data)
    
    if [ $? -eq 0 ]; then
        log_success "✅ Backup completed: $export_path"
        echo "$export_path"
    else
        log_error "❌ Backup failed"
        return 1
    fi
}

# Function to restore after restart
restore_after_restart() {
    local backup_path=$1
    
    if [ -z "$backup_path" ]; then
        log_warning "⚠️  No backup path provided, skipping restore"
        return 0
    fi
    
    log_header "Restoring Firestore data after restart"
    
    # Wait for emulator to be ready
    log_info "Waiting for Firestore emulator to be ready..."
    sleep 10
    
    # Import data
    import_firestore_data "$backup_path"
    
    if [ $? -eq 0 ]; then
        log_success "✅ Restore completed"
    else
        log_error "❌ Restore failed"
        return 1
    fi
}

# Function to show usage
show_usage() {
    echo "Firebase Data Preservation Script"
    echo ""
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo ""
    echo "Commands:"
    echo "  export              Export current Firestore data"
    echo "  import <path>       Import Firestore data from path"
    echo "  backup              Backup data before restart"
    echo "  restore <path>      Restore data after restart"
    echo "  list                List available exports"
    echo "  help                Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 export"
    echo "  $0 import emulator-data/firebase-export-20250101_120000"
    echo "  $0 backup"
    echo "  $0 restore emulator-data/firebase-export-20250101_120000"
    echo ""
}

# Main function
main() {
    case "${1:-help}" in
        "export")
            export_firestore_data
            ;;
        "import")
            import_firestore_data "$2"
            ;;
        "backup")
            backup_before_restart
            ;;
        "restore")
            restore_after_restart "$2"
            ;;
        "list")
            list_exports
            ;;
        "help"|*)
            show_usage
            ;;
    esac
}

# Run main function
main "$@" 
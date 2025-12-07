#!/bin/bash

# Firestore data export/import helper
# Replaces old local/preserve-data.sh with improved behavior and emulator-awareness

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#!/bin/bash

# Firestore data export/import helper
# Replaces old local/preserve-data.sh with improved behavior and emulator-awareness

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config.sh" 2>/dev/null || true

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }
log_header() { echo -e "\n${BLUE}========================================\n$1\n========================================${NC}"; }

DEFAULT_EXPORT_DIR="emulator-data"

# Detect emulator mode heuristically
is_emulator_mode() {
    if [ -n "$FIRESTORE_EMULATOR_HOST" ] || [ "${USE_FIREBASE_EMULATOR:-}" = "true" ]; then
        return 0
    fi
    return 1
}

export_firestore_data() {
    local export_dir=${EXPORT_DIR:-$DEFAULT_EXPORT_DIR}
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    local export_name="firebase-export-$timestamp"

    log_info "Exporting Firestore data to $export_dir/$export_name..."
    mkdir -p "$export_dir"

    if is_emulator_mode; then
        log_info "Detected emulator mode — using 'firebase emulators:export'"
        firebase emulators:export "$export_dir/$export_name" || {
            log_error "Failed to export emulators data"
            return 1
        }
    else
        # Production export: use gcloud to export to a GCS bucket.
        # Set FIRESTORE_EXPORT_BUCKET to a bucket name (without gs://) or full gs:// path.
        if [ -z "${FIRESTORE_EXPORT_BUCKET:-}" ]; then
            log_error "FIRESTORE_EXPORT_BUCKET not set. To export production Firestore you must provide a GCS bucket."
            log_info "Example: export FIRESTORE_EXPORT_BUCKET=my-bucket && ./manage.sh preserve-data export"
            log_info "Or run 'gcloud firestore export gs://<BUCKET_NAME>/<prefix>' manually."
            return 1
        fi

        # Accept either 'gs://bucket/path' or just 'bucket'
        if echo "$FIRESTORE_EXPORT_BUCKET" | grep -q '^gs://'; then
            gcs_target="${FIRESTORE_EXPORT_BUCKET%/}/${export_name}"
        else
            gcs_target="gs://${FIRESTORE_EXPORT_BUCKET%/}/${export_name}"
        fi

        log_info "Exporting Firestore to GCS: $gcs_target"
        gcloud firestore export "$gcs_target" --project "${FIREBASE_PROJECT_ID:-}" || {
            log_error "Failed to export Firestore data via gcloud firestore export"
            return 1
        }
    fi

    log_success "Exported to $export_dir/$export_name"
    echo "$export_dir/$export_name"
}

import_firestore_data() {
    local import_path="$1"
    local start_emulator_if_needed="$2"

    if [ -z "$import_path" ]; then
        log_error "Import path is required"
        return 1
    fi

    if [ ! -d "$import_path" ]; then
        log_error "Import directory not found: $import_path"
        return 1
    fi

    if is_emulator_mode; then
        log_info "Emulator mode detected. Best practice: start the emulator with --import to load this data."
        if [ "$start_emulator_if_needed" = "--start" ]; then
            log_info "Starting emulator with import (this will run the emulator)."
            firebase emulators:start --import "$import_path" --only firestore || {
                log_error "Failed to start emulator with import"
                return 1
            }
            return 0
        fi

        log_warning "To import into the local emulator, run:"
        log_warning "  firebase emulators:start --import $import_path --only firestore"
        log_warning "Or call this script with the extra flag: preserve-data import <path> --start"
        return 0
    else
        log_info "Importing into Firestore (production)"
        if [ -z "${FIRESTORE_EXPORT_BUCKET:-}" ]; then
            log_error "FIRESTORE_EXPORT_BUCKET not set. To import production Firestore exports you must provide the GCS path or set FIRESTORE_EXPORT_BUCKET."
            log_info "Example: gcloud firestore import gs://<BUCKET_NAME>/<export-prefix> --project ${FIREBASE_PROJECT_ID:-}"
            return 1
        fi

        # If user passed a local path, require they provide a gs:// path for import.
        if echo "$import_path" | grep -q '^gs://'; then
            gcs_path="$import_path"
        else
            # assume user provided only export-name and bucket is in env
            if echo "$FIRESTORE_EXPORT_BUCKET" | grep -q '^gs://'; then
                gcs_path="${FIRESTORE_EXPORT_BUCKET%/}/${import_path}"
            else
                gcs_path="gs://${FIRESTORE_EXPORT_BUCKET%/}/${import_path}"
            fi
        fi

        log_info "Importing from GCS: $gcs_path"
        gcloud firestore import "$gcs_path" --project "${FIREBASE_PROJECT_ID:-}" || {
            log_error "Failed to import Firestore data via gcloud firestore import"
            return 1
        }
        log_success "Firestore import completed"
    fi
}

list_exports() {
    local export_dir=${EXPORT_DIR:-$DEFAULT_EXPORT_DIR}
    if [ ! -d "$export_dir" ]; then
        log_warning "No exports directory found: $export_dir"
        return 1
    fi

    log_info "Available Firestore exports in: $export_dir"
    ls -1d "$export_dir"/firebase-export-* 2>/dev/null || log_info "(none)"
}

backup_before_restart() {
    log_header "Backing up Firestore data before restart"
    local path
    path=$(export_firestore_data) || return 1
    log_success "Backup completed: $path"
    echo "$path"
}

restore_after_restart() {
    local backup_path="$1"
    local start_flag="$2"

    if [ -z "$backup_path" ]; then
        log_warning "No backup path provided, skipping restore"
        return 0
    fi

    log_header "Restoring Firestore data after restart"
    log_info "Waiting briefly for emulator to be ready..."
    sleep 5

    import_firestore_data "$backup_path" "$start_flag"
}

show_usage() {
    cat <<EOF
Usage: $0 [COMMAND] [OPTIONS]

Commands:
  export                 Export current Firestore / emulator data
  import <path> [--start]  Import data; when using emulator, pass --start to start emulator with import
  backup                 Export and print path (use before restart)
  restore <path> [--start] Restore from backup (use --start to have script start emulator with --import)
  list                   List available exports in ${EXPORT_DIR:-$DEFAULT_EXPORT_DIR}
  help                   Show this message

Examples:
  $0 export
  $0 import emulator-data/firebase-export-20250101_120000
  $0 import emulator-data/firebase-export-20250101_120000 --start
  $0 backup
  $0 restore emulator-data/firebase-export-20250101_120000
EOF
}

main() {
    local cmd=${1:-help}
    case "$cmd" in
        export)
            export_firestore_data
            ;;
        import)
            import_firestore_data "$2" "$3"
            ;;
        backup)
            backup_before_restart
            ;;
        restore)
            restore_after_restart "$2" "$3"
            ;;
        list)
            list_exports
            ;;
        help|--help|-h)
            show_usage
            ;;
        *)
            show_usage
            exit 1
            ;;
    esac
}

main "$@"

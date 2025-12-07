#!/bin/bash

# 🔥 Firebase Project Setup Script
# 
# IMPORTANT INSIGHT: This script creates symlinks, but the REAL solution is simpler:
# 
# ✅ WORKING APPROACH (Recommended):
# - Place firebase.json in PROJECT ROOT (not in firebase-scripts/)
# - Set "source": "services" in firebase.json
# - No symlinks needed - Firebase works directly with services/ directory
# 
# ❌ COMPLEX APPROACH (This script creates):
# - Creates firebase-scripts/functions/ with symlinks to services/
# - More complex, more prone to errors
# - Only use if you specifically need the encapsulated structure
#
# The working approach is documented in README.md and QUICK_START.md

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Function to display usage
show_usage() {
    cat << EOF
🚀 Firebase Project Symlink Setup Script

Usage: $0 [OPTIONS]

OPTIONS:
    -p, --project-dir PATH    Path to your project directory (default: current directory)
    -s, --services-dir NAME   Name of your services directory (default: services)
    -f, --firebase-dir NAME   Name of your Firebase directory (default: firebase-scripts)
    -h, --help               Show this help message

EXAMPLES:
    # Setup in current directory
    $0

    # Setup in specific project directory
    $0 -p /path/to/your/project

    # Custom directory names
    $0 -s microservices -f firebase-scripts

DESCRIPTION:
    This script creates the symlink structure needed for Firebase to work with your
    cloud-agnostic services. It will:
    
    1. Create firebase-scripts/functions/ directory
    2. Create symlinks from firebase-scripts/functions/ to your services/
    3. Update firebase.json to point to the correct location
    4. Ensure your project remains cloud-agnostic

ARCHITECTURE:
    your-project/
    ├── services/                    # Your cloud-agnostic business logic
    ├── firebase-scripts/            # Firebase integration layer
    │   ├── functions/              # Symlinks to services/
    │   ├── firebase.json           # Firebase config
    │   └── scripts/                # Firebase management scripts
    └── ...                         # Rest of your project

EOF
}

# Default values
PROJECT_DIR="."
SERVICES_DIR="services"
FIREBASE_DIR="firebase-scripts"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -p|--project-dir)
            PROJECT_DIR="$2"
            shift 2
            ;;
        -s|--services-dir)
            SERVICES_DIR="$2"
            shift 2
            ;;
        -f|--firebase-dir)
            FIREBASE_DIR="$2"
            shift 2
            ;;
        -h|--help)
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

# Validate project directory
if [[ ! -d "$PROJECT_DIR" ]]; then
    log_error "Project directory does not exist: $PROJECT_DIR"
    exit 1
fi

# Change to project directory
cd "$PROJECT_DIR"
PROJECT_DIR=$(pwd)

log_info "Setting up Firebase symlinks for project: $PROJECT_DIR"
log_info "Services directory: $SERVICES_DIR"
log_info "Firebase directory: $FIREBASE_DIR"

# Check if services directory exists
if [[ ! -d "$SERVICES_DIR" ]]; then
    log_error "Services directory not found: $SERVICES_DIR"
    log_error "Please create your services directory first"
    exit 1
fi

# Check if firebase directory exists
if [[ ! -d "$FIREBASE_DIR" ]]; then
    log_warning "Firebase directory not found: $FIREBASE_DIR"
    log_info "Creating Firebase directory structure..."
    mkdir -p "$FIREBASE_DIR"
fi

# Create functions directory
FUNCTIONS_DIR="$FIREBASE_DIR/functions"
if [[ ! -d "$FUNCTIONS_DIR" ]]; then
    log_info "Creating functions directory: $FUNCTIONS_DIR"
    mkdir -p "$FUNCTIONS_DIR"
fi

# Clean up existing symlinks
log_info "Cleaning up existing symlinks..."
rm -f "$FUNCTIONS_DIR"/*

# Create symlinks to services
log_info "Creating symlinks from $FUNCTIONS_DIR to $SERVICES_DIR..."
cd "$FUNCTIONS_DIR"

# Get list of services (directories and files, excluding node_modules and common files)
SERVICES=$(find "../../$SERVICES_DIR" -maxdepth 1 -mindepth 1 \( -type d -o -name "*.js" \) | grep -v "node_modules" | grep -v ".git" | sort)

# Always create package.json for Firebase compatibility
log_info "Creating package.json for Firebase compatibility..."
echo '{"name": "functions", "version": "1.0.0"}' > package.json

if [[ -z "$SERVICES" ]]; then
    log_warning "No services found in $SERVICES_DIR"
    log_info "Created empty functions directory for Firebase compatibility"
else
    # Create symlinks for each service
    for service in $SERVICES; do
        service_name=$(basename "$service")
        log_info "Creating symlink: $service_name -> $service"
        ln -sf "$service" "$service_name"
    done
    
    log_success "Created $(echo "$SERVICES" | wc -l | tr -d ' ') symlinks"
fi

# Go back to project directory
cd "$PROJECT_DIR"

# Check if firebase.json exists and update it
FIREBASE_JSON="$FIREBASE_DIR/firebase.json"
if [[ -f "$FIREBASE_JSON" ]]; then
    log_info "Updating firebase.json to point to symlinked functions..."
    
    # Check if functions source is already correct
    if grep -q '"source": "'"$FIREBASE_DIR"'/functions"' "$FIREBASE_JSON"; then
        log_success "firebase.json already correctly configured"
    else
        # Update the source path
        sed -i.bak 's|"source": "[^"]*"|"source": "'"$FIREBASE_DIR"'/functions"|g' "$FIREBASE_JSON"
        log_success "Updated firebase.json functions source"
    fi
else
    log_warning "firebase.json not found in $FIREBASE_DIR"
    log_info "You may need to run 'firebase init' or create firebase.json manually"
fi

# Create a README explaining the structure
README_FILE="$FIREBASE_DIR/README.md"
if [[ ! -f "$README_FILE" ]]; then
    log_info "Creating README explaining the symlink architecture..."
    cat > "$README_FILE" << 'EOF'
# 🔒 Firebase Integration Layer

## 🎯 **Architecture Philosophy**

This project follows a **cloud-agnostic design** where:
- **`../services/`** contains your **pure business logic** - completely independent of any cloud provider
- **`firebase-scripts/`** contains **all Firebase-specific configuration** and setup
- **Symlinks** bridge the gap without duplicating code

## 🏗️ **Directory Structure**

```
your-project/
├── services/                           # 🚀 Your cloud-agnostic business logic
│   ├── service1/
│   ├── service2/
│   └── ... (all your microservices)
│
├── firebase-scripts/                   # 🔒 Firebase-specific setup only
│   ├── functions/                     # 🔗 Symlinks to services/
│   ├── firebase.json                  # Firebase configuration
│   └── scripts/                       # Firebase management scripts
│
└── ...                                # Rest of your project
```

## 🔗 **How Symlinks Work**

The `firebase-scripts/functions/` directory contains **symbolic links** to your actual services:

```bash
# Example symlinks:
firebase-scripts/functions/service1 -> ../../services/service1
firebase-scripts/functions/service2 -> ../../services/service2
```

**Benefits:**
- ✅ **No code duplication** - your services stay in one place
- ✅ **Firebase compatibility** - Firebase sees a proper `functions/` directory
- ✅ **Easy maintenance** - update services in `services/`, changes reflect everywhere
- ✅ **Cloud agnostic** - your business logic remains independent

## 🔧 **Maintenance**

### **Adding New Services:**
1. Create your service in `services/new-service/`
2. Run this script again to recreate symlinks
3. Firebase automatically picks it up

### **Updating Services:**
- **Edit in `services/`** - changes automatically reflect in Firebase
- **No need to touch `firebase-scripts/functions/`** - symlinks handle everything

## 🚨 **Important Notes**

- ❌ Don't edit files in `firebase-scripts/functions/` - they're symlinks!
- ✅ Always edit services in `services/`
- ✅ Keep Firebase-specific code isolated in `firebase-scripts/`

---

**This architecture keeps your project clean, maintainable, and future-proof! 🎯✨**
EOF
    log_success "Created README.md"
fi

# Final status
log_success "🎉 Firebase symlink setup completed successfully!"
echo
log_info "📋 Next steps:"
log_info "   1. Your services remain in: $SERVICES_DIR/"
log_info "   2. Firebase functions are linked in: $FIREBASE_DIR/functions/"
log_info "   3. You can now run Firebase commands from: $FIREBASE_DIR/"
echo
log_info "🔗 To test your setup:"
log_info "   cd $FIREBASE_DIR"
log_info "   firebase emulators:start --only functions,firestore,ui"
echo
log_info "📚 For more information, see: $FIREBASE_DIR/README.md"

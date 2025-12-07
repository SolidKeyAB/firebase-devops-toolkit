#!/bin/bash

# ESG Pipeline Microservices Cleanup Script
# This script removes old functions and cleans up the deployment

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_ID="${PROJECT_ID:-your-firebase-project-id}"

echo -e "${BLUE}🧹 Starting ESG Pipeline Cleanup${NC}"

# Function to list current functions
list_functions() {
    echo -e "${BLUE}📋 Current deployed functions:${NC}"
    firebase functions:list
}

# Function to delete a function
delete_function() {
    local function_name=$1
    echo -e "${BLUE}🗑️  Deleting function: $function_name${NC}"
    
    if firebase functions:delete "$function_name" --force; then
        echo -e "${GREEN}✅ Successfully deleted $function_name${NC}"
        return 0
    else
        echo -e "${RED}❌ Failed to delete $function_name${NC}"
        return 1
    fi
}

# Function to delete old test functions
delete_old_test_functions() {
    echo -e "${BLUE}🗑️  Deleting old test functions...${NC}"
    
    local old_functions=(
        "helloWorld"
        "healthCheck"
        "standaloneTest"
        "standaloneHealth"
        "simplifiedCategoryExtraction"
        "simplifiedProductExtraction"
        "simplifiedEmbeddingService"
        "simplifiedHealth"
        "workingTest"
        "workingHealth"
    )
    
    local deleted_count=0
    
    for function in "${old_functions[@]}"; do
        if delete_function "$function"; then
            ((deleted_count++))
        fi
    done
    
    echo -e "${GREEN}✅ Deleted $deleted_count old test functions${NC}"
}

# Function to delete all functions (nuclear option)
delete_all_functions() {
    echo -e "${RED}⚠️  WARNING: This will delete ALL functions!${NC}"
    echo -e "${RED}Are you sure you want to continue? (y/N)${NC}"
    read -r response
    
    if [[ "$response" =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}🗑️  Deleting all functions...${NC}"
        
        # Get list of all functions
        functions=$(firebase functions:list --format="value(Function)" 2>/dev/null)
        
        for function in $functions; do
            delete_function "$function"
        done
        
        echo -e "${GREEN}✅ All functions deleted${NC}"
    else
        echo -e "${YELLOW}❌ Cleanup cancelled${NC}"
    fi
}

# Function to clean up temporary files
cleanup_temp_files() {
    echo -e "${BLUE}🧹 Cleaning up temporary files...${NC}"
    
    # Remove temporary files in services directory (only if exists)
    if [ -d "../../services" ]; then
        cd ../../services || return
        rm -f index-simple.js
        rm -f minimal-test.js
        rm -f simple-working.js
        rm -f simplified-index.js
        rm -f health-only.js
        rm -f minimal-working.js
        rm -f test-simple.js
        cd - >/dev/null || true
    fi

    echo -e "${GREEN}✅ Temporary files cleaned up${NC}"
}

# Function to show cleanup summary
show_summary() {
    echo -e "${BLUE}📊 Cleanup Summary${NC}"
    echo -e "${GREEN}✅ Cleanup completed${NC}"
    echo -e "${BLUE}📅 Cleanup completed at: $(date)${NC}"
    echo -e "${BLUE}🔧 Project: $PROJECT_ID${NC}"
}

# Main cleanup process
main() {
    echo -e "${BLUE}🎯 Starting cleanup process...${NC}"
    
    # List current functions
    list_functions
    
    # Ask user what to do
    echo -e "${BLUE}What would you like to do?${NC}"
    echo -e "${BLUE}1. Delete old test functions only${NC}"
    echo -e "${BLUE}2. Delete all functions (nuclear option)${NC}"
    echo -e "${BLUE}3. Clean up temporary files only${NC}"
    echo -e "${BLUE}4. Full cleanup (delete old functions + temp files)${NC}"
    echo -e "${BLUE}5. Exit${NC}"
    
    read -r choice
    
    case $choice in
        1)
            delete_old_test_functions
            ;;
        2)
            delete_all_functions
            ;;
        3)
            cleanup_temp_files
            ;;
        4)
            delete_old_test_functions
            cleanup_temp_files
            ;;
        5)
            echo -e "${YELLOW}❌ Cleanup cancelled${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}❌ Invalid choice${NC}"
            exit 1
            ;;
    esac
    
    # Show summary
    show_summary
    
    echo -e "${GREEN}🎉 Cleanup completed successfully!${NC}"
}

# Run main function
main "$@" 
#!/bin/bash

# Batch delete Firebase functions
# This will delete functions one by one to avoid hanging

PROJECT_ID="${FIREBASE_PROJECT_ID}"

if [ -z "$PROJECT_ID" ]; then
    echo "❌ Error: FIREBASE_PROJECT_ID environment variable is required"
    echo "💡 Set it in your .env file or environment"
    exit 1
fi

echo "🧹 Batch deleting Firebase functions in project: $PROJECT_ID"

# List all functions first
echo "📋 Getting list of deployed functions..."
ALL_FUNCTIONS=$(firebase functions:list --project "$PROJECT_ID" 2>/dev/null | grep "│" | grep -v "Function" | awk '{print $2}' | grep -v "^$" || true)

if [ -z "$ALL_FUNCTIONS" ]; then
    echo "ℹ️  No functions found to delete"
    exit 0
fi

echo "📊 Found functions:"
echo "$ALL_FUNCTIONS"
echo ""

# Convert to array
FUNCTIONS=()
while IFS= read -r func; do
    if [ -n "$func" ]; then
        FUNCTIONS+=("$func")
    fi
done <<< "$ALL_FUNCTIONS"

echo "📊 Total functions to delete: ${#FUNCTIONS[@]}"

for func in "${FUNCTIONS[@]}"; do
    echo "🗑️  Deleting function: $func"
    if firebase functions:delete "$func" --project "$PROJECT_ID" --force; then
        echo "✅ Deleted: $func"
    else
        echo "❌ Failed to delete: $func"
    fi
    # Small delay to avoid overwhelming the API
    sleep 2
done

echo "🎉 Batch deletion completed!"
echo "📊 Check remaining functions with: firebase functions:list --project $PROJECT_ID"

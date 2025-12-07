#!/bin/bash

# Consolidated Function Testing Script
# Tests deployed Firebase functions with multiple authentication methods
# Combines functionality from test-functions.sh and test-correct-urls.js

set -e

PROJECT_ID="${PROJECT_ID:-your-firebase-project-id}"
REGION="${REGION:-us-central1}"

echo "🔍 Testing Firebase Functions (project: $PROJECT_ID)"
echo "===================================================="

# Generic function definitions (configurable via environment)
FUNCTIONS=(
    "categoryExtraction"
    "productExtraction"
    "embeddingService"
    "orchestratorService"
    "productEnrichment"
    "aiLogging"
    "vectorSearch"
    "sustainabilityEnrichment"
    "complianceEnrichment"
    "eprelEnrichment"
    "faoAgricultural"
    "oecdSustainability"
    "productImage"
    "vectorCategoryComparison"
    "yamlCorrection"
)

# Health check functions
HEALTH_FUNCTIONS=(
    "healthCategoryExtraction"
    "healthProductExtraction"
    "healthEmbeddingService"
    "healthOrchestratorService"
    "healthProductEnrichment"
    "healthAiLogging"
    "healthVectorSearch"
    "healthSustainabilityEnrichment"
    "healthComplianceEnrichment"
    "healthEprelEnrichment"
    "healthFaoAgricultural"
    "healthOecdSustainability"
    "healthProductImage"
    "healthVectorCategoryComparison"
    "healthYamlCorrection"
)

# Generate function URL
get_function_url() {
    local function_name=$1
    echo "https://${REGION}-${PROJECT_ID}.cloudfunctions.net/${function_name}"
}

# Test function with different methods
test_function() {
    local name=$1
    local method=${2:-GET}
    local data=${3:-""}
    local auth_type=${4:-"none"}

    local url=$(get_function_url "$name")

    echo "🧪 Testing $name ($method)"
    echo "   URL: $url"
    echo "   Auth: $auth_type"

    local curl_cmd="curl -s -w %{http_code}"
    local auth_header=""

    # Set authentication header
    case "$auth_type" in
        "gcloud")
            local token=$(gcloud auth print-access-token 2>/dev/null || echo "")
            if [ -n "$token" ]; then
                auth_header="-H \"Authorization: Bearer $token\""
            else
                echo "   ❌ Could not get gcloud access token"
                return 1
            fi
            ;;
        "firebase")
            if [ -n "$FIREBASE_TOKEN" ]; then
                auth_header="-H \"Authorization: Bearer $FIREBASE_TOKEN\""
            else
                echo "   ⚠️  No FIREBASE_TOKEN environment variable set"
            fi
            ;;
    esac

    # Build curl command
    if [ "$method" = "POST" ] && [ -n "$data" ]; then
        response=$(eval "$curl_cmd $auth_header -X POST -H \"Content-Type: application/json\" -d '$data' '$url'")
    else
        response=$(eval "$curl_cmd $auth_header '$url'")
    fi

    local http_code="${response: -3}"
    local body="${response%???}"

    echo "   Status: $http_code"
    case "$http_code" in
        "200")
            echo "   ✅ SUCCESS: Function is accessible"
            if [ ${#body} -gt 0 ]; then
                echo "   Response: ${body:0:200}..."
            fi
            ;;
        "403")
            echo "   🔒 FORBIDDEN: Function requires authentication"
            ;;
        "401")
            echo "   🔐 UNAUTHORIZED: Invalid authentication"
            ;;
        "404")
            echo "   ❌ NOT FOUND: Function does not exist"
            ;;
        *)
            echo "   ❓ HTTP $http_code: $body"
            ;;
    esac

    echo ""
    return $http_code
}

# Test all authentication methods for a function
test_all_auth_methods() {
    local function_name=$1
    local method=${2:-GET}
    local data=${3:-""}

    echo "🔍 Testing $function_name with all authentication methods"
    echo "========================================================"

    # Test without authentication
    test_function "$function_name" "$method" "$data" "none"

    # Test with gcloud token
    test_function "$function_name" "$method" "$data" "gcloud"

    # Test with Firebase token (if available)
    if [ -n "$FIREBASE_TOKEN" ]; then
        test_function "$function_name" "$method" "$data" "firebase"
    fi

    echo ""
}

# Run comprehensive tests
run_tests() {
    local test_type=$1
    shift
    local functions_array=("$@")

    echo ""
    echo "📊 Testing $test_type Functions"
    echo "================================"

    local success_count=0
    local total_count=${#functions_array[@]}

    for function_name in "${functions_array[@]}"; do
        echo "Testing: $function_name"

        # Test with simple GET request and gcloud auth
        if test_function "$function_name" "GET" "" "gcloud"; then
            ((success_count++))
        fi
    done

    echo ""
    echo "📈 $test_type Results: $success_count/$total_count functions accessible"

    return 0
}

# Parse command line arguments
VERBOSE=false
TEST_AUTH=false
TEST_POST=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --test-auth)
            TEST_AUTH=true
            shift
            ;;
        --test-post)
            TEST_POST=true
            shift
            ;;
        --function)
            SINGLE_FUNCTION="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --verbose, -v     Show detailed output"
            echo "  --test-auth       Test all authentication methods"
            echo "  --test-post       Test POST requests with sample data"
            echo "  --function NAME   Test only specific function"
            echo "  --help, -h        Show this help message"
            echo ""
            echo "Environment Variables:"
            echo "  PROJECT_ID        Firebase project ID"
            echo "  REGION           Firebase region"
            echo "  FIREBASE_TOKEN   Firebase authentication token"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Main execution
echo "Project: $PROJECT_ID"
echo "Region: $REGION"
echo ""

if [ -n "$SINGLE_FUNCTION" ]; then
    echo "🎯 Testing single function: $SINGLE_FUNCTION"
    if [ "$TEST_AUTH" = true ]; then
        test_all_auth_methods "$SINGLE_FUNCTION"
    else
        test_function "$SINGLE_FUNCTION" "GET" "" "gcloud"
    fi
else
    # Test main functions
    run_tests "Main" "${FUNCTIONS[@]}"

    # Test health check functions
    run_tests "Health Check" "${HEALTH_FUNCTIONS[@]}"
fi

echo ""
echo "💡 Usage Tips:"
echo "   • Functions returning 403/401 require proper authentication"
echo "   • Use --test-auth to test different authentication methods"
echo "   • Set FIREBASE_TOKEN environment variable for Firebase auth"
echo "   • Use --function <name> to test a specific function"
echo ""
echo "🔧 Troubleshooting:"
echo "   • Ensure gcloud is configured: gcloud auth login"
echo "   • Check project permissions: gcloud projects get-iam-policy $PROJECT_ID"
echo "   • Verify function deployment: firebase functions:list --project $PROJECT_ID"
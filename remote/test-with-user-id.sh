#!/bin/bash

# Test ESG Pipeline with Specific User ID
# Uses the provided user ID to test the pipeline

set -e

PROJECT_ID="${PROJECT_ID:-${FIREBASE_PROJECT:-your-firebase-project-id}}"
USER_ID="${USER_ID:-eDi41nJL7gYPyecE6enL52yJSqz1}"

echo "🧪 Testing ESG Pipeline with User ID: $USER_ID"
echo "============================================="
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'
REGION="${REGION:-europe-west1}"
HOST="${HOST:-${REGION}-${PROJECT_ID}.cloudfunctions.net}"
ORCHESTRATOR_URL="https://$HOST/orchestratorService"
CATEGORY_EXTRACTION_URL="https://$HOST/categoryExtraction"
PRODUCT_EXTRACTION_URL="https://$HOST/productExtraction"
EMBEDDING_SERVICE_URL="https://$HOST/embeddingService"

# Step 1: Create custom token for the user
create_custom_token() {
    echo -e "${GREEN}🔐 Step 1: Creating Custom Token for User${NC}"
    echo "==============================================="
    
    # Create a simple Node.js script to generate custom token
    cat > create-token.js << EOF
const admin = require('firebase-admin');

// Initialize Firebase Admin (you'll need to add your service account key)
// admin.initializeApp({
//     credential: admin.credential.cert(require('./service-account-key.json')),
//     projectId: '$PROJECT_ID'
// });

async function createCustomToken() {
    try {
        const customToken = await admin.auth().createCustomToken('$USER_ID', {
            role: 'test_user',
            pipeline_access: true,
            firestore_access: true,
            functions_access: true
        });
        
        console.log('Custom Token:', customToken);
        return customToken;
    } catch (error) {
        console.error('Error creating custom token:', error);
        return null;
    }
}

createCustomToken();
EOF

    echo "   Created token generation script: create-token.js"
    echo "   ⚠️  You'll need to add your Firebase service account key"
    echo "   Run: node create-token.js to generate a token"
    
    echo ""
}

# Step 2: Test function accessibility
test_function_access() {
    echo -e "${GREEN}📊 Step 2: Testing Function Accessibility${NC}"
    echo "============================================="
    
    functions=("categoryExtraction" "productExtraction" "embeddingService" "orchestratorService")
    
    for func in "${functions[@]}"; do
    url="https://$REGION-$PROJECT_ID.cloudfunctions.net/$func"
        echo "   Testing $func..."
        
        response=$(curl -s -w "%{http_code}" "$url")
        http_code="${response: -3}"
        
        if [ "$http_code" = "403" ]; then
            echo -e "   ${GREEN}✅ $func: Deployed and secured${NC}"
        elif [ "$http_code" = "200" ]; then
            echo -e "   ${YELLOW}⚠️  $func: Publicly accessible${NC}"
        else
            echo -e "   ${RED}❌ $func: HTTP $http_code${NC}"
        fi
    done
    
    echo ""
}

# Step 3: Create test data for the user
create_test_data() {
    echo -e "${GREEN}📝 Step 3: Creating Test Data for User${NC}"
    echo "============================================="
    
    # Create test brands data
    cat > test-brands.json << EOF
{
    "user_id": "$USER_ID",
    "brands": [
        {
            "id": "apple-test",
            "name": "Apple Inc.",
            "website": "https://www.apple.com",
            "category": "Electronics",
            "description": "Technology company",
            "status": "active",
            "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
            "user_id": "$USER_ID"
        },
        {
            "id": "tesla-test",
            "name": "Tesla Inc.",
            "website": "https://www.tesla.com",
            "category": "Automotive",
            "description": "Electric vehicle manufacturer",
            "status": "active",
            "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
            "user_id": "$USER_ID"
        },
        {
            "id": "patagonia-test",
            "name": "Patagonia",
            "website": "https://www.patagonia.com",
            "category": "Apparel",
            "description": "Outdoor clothing company",
            "status": "active",
            "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
            "user_id": "$USER_ID"
        }
    ]
}
EOF

    echo -e "   ${GREEN}✅ Created test-brands.json${NC}"
    echo "   This contains test brands for user: $USER_ID"
    
    echo ""
}

# Step 4: Create manual testing instructions
create_manual_instructions() {
    echo -e "${GREEN}📋 Step 4: Manual Testing Instructions${NC}"
    echo "============================================="
    
    cat > manual-test-instructions.md << EOF
# Manual Testing with User ID: $USER_ID

## 🔐 Authentication Steps

1. **Get Custom Token:**
   - Add your Firebase service account key to create-token.js
   - Run: \`node create-token.js\`
   - Copy the generated token

2. **Test Functions with Token:**
   \`\`\`bash
     TOKEN="your_custom_token_here"
   
     # Test category extraction
     curl -H "Authorization: Bearer \$TOKEN" \
         -X POST \
         -H "Content-Type: application/json" \
         -d '{"brand_id": "apple-test", "website": "https://www.apple.com", "max_categories": 5}' \
         "https://${REGION:-us-central1}-${PROJECT_ID:-your-firebase-project-id}.cloudfunctions.net/categoryExtraction"
   
     # Test product extraction
     curl -H "Authorization: Bearer \$TOKEN" \
         -X POST \
         -H "Content-Type: application/json" \
         -d '{"brand_id": "apple-test", "max_products": 3}' \
         "https://${REGION:-us-central1}-${PROJECT_ID:-your-firebase-project-id}.cloudfunctions.net/productExtraction"
   
     # Test orchestrator
     curl -H "Authorization: Bearer \$TOKEN" \
         -X POST \
         -H "Content-Type: application/json" \
         -d '{"workflow_type": "complete_pipeline", "brand_id": "apple-test"}' \
         "https://${REGION:-us-central1}-${PROJECT_ID:-your-firebase-project-id}.cloudfunctions.net/orchestratorService"
   \`\`\`

## 📝 Add Brands to Firestore

1. Go to Firebase Console: https://console.firebase.google.com/project/$PROJECT_ID/firestore
2. Create collection: \`brands\`
3. Add documents using the data from test-brands.json
4. Each document should have \`user_id: "$USER_ID"\`

## 🧪 Test Pipeline

1. **Test Individual Services:**
   - Category extraction for each brand
   - Product extraction for each brand
   - Embedding service with test data

2. **Test Complete Pipeline:**
   - Use orchestrator service with multiple brands
   - Monitor function logs
   - Check Firestore for results

## 📊 Monitor Results

1. **Function Logs:**
   \`\`\`bash
   firebase functions:log --only categoryExtraction
   firebase functions:log --only productExtraction
   firebase functions:log --only orchestratorService
   \`\`\`

2. **Firestore Data:**
   - Check brands collection for processed data
   - Look for extracted categories and products
   - Verify user_id matches: $USER_ID

## 🎯 Expected Results

- ✅ Functions return 200 with proper authentication
- ✅ Brands are processed and stored in Firestore
- ✅ Categories and products are extracted
- ✅ Pipeline completes successfully
- ✅ All data is associated with user: $USER_ID
EOF

    echo -e "   ${GREEN}✅ Created manual-test-instructions.md${NC}"
    echo "   Detailed instructions for testing with your user ID"
    
    echo ""
}

# Step 5: Create quick test script
create_quick_test() {
    echo -e "${GREEN}⚡ Step 5: Creating Quick Test Script${NC}"
    echo "======================================="
    
    cat > quick-test-with-user.sh << 'EOF'
#!/bin/bash

# Quick Test with User ID
# Tests the ESG pipeline with the specific user ID

set -e

PROJECT_ID="$PROJECT_ID"
USER_ID="$USER_ID"

echo "⚡ Quick Test with User ID: $USER_ID"
echo "==================================="

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}🔐 Step 1: Authentication Check${NC}"
echo "====================================="

echo "   User ID: $USER_ID"
echo "   Project: $PROJECT_ID"
echo "   ⚠️  You need to get a custom token for this user"
echo "   Run: node create-token.js"

echo ""
echo -e "${GREEN}📊 Step 2: Function Status Check${NC}"
echo "====================================="

functions=("categoryExtraction" "productExtraction" "embeddingService" "orchestratorService")

for func in "${functions[@]}"; do
    url="https://$REGION-$PROJECT_ID.cloudfunctions.net/$func"
    response=$(curl -s -w "%{http_code}" "$url")
    http_code="${response: -3}"
    
    if [ "$http_code" = "403" ]; then
        echo -e "   ${GREEN}✅ $func: Deployed and secured${NC}"
    elif [ "$http_code" = "200" ]; then
        echo -e "   ${YELLOW}⚠️  $func: Publicly accessible${NC}"
    else
        echo -e "   ${YELLOW}⚠️  $func: HTTP $http_code${NC}"
    fi
done

echo ""
echo -e "${GREEN}📝 Step 3: Test Data Ready${NC}"
echo "==============================="

echo "   ✅ Test brands data: test-brands.json"
echo "   ✅ User ID: $USER_ID"
echo "   ✅ Project: $PROJECT_ID"

echo ""
echo -e "${GREEN}🎯 Ready to Test!${NC}"
echo "====================="
echo ""
echo "💡 Next Steps:"
echo "   1. Get custom token: node create-token.js"
echo "   2. Add brands to Firestore manually"
echo "   3. Test functions with the token"
echo "   4. Monitor results in Firebase Console"
echo ""
echo "📋 See manual-test-instructions.md for detailed steps"
EOF

    chmod +x quick-test-with-user.sh
    echo -e "   ${GREEN}✅ Created quick-test-with-user.sh${NC}"
    
    echo ""
}

# Main function
main() {
    echo -e "${GREEN}🚀 Setting up Test with User ID: $USER_ID${NC}"
    echo "============================================="
    echo ""
    
    # Step 1: Create custom token script
    create_custom_token
    
    # Step 2: Test function access
    test_function_access
    
    # Step 3: Create test data
    create_test_data
    
    # Step 4: Create manual instructions
    create_manual_instructions
    
    # Step 5: Create quick test
    create_quick_test
    
    echo -e "${GREEN}🎉 Test Setup Complete for User ID: $USER_ID${NC}"
    echo "============================================="
    echo ""
    echo -e "${BLUE}📊 Summary:${NC}"
    echo "   ✅ Custom token script created"
    echo "   ✅ Function accessibility tested"
    echo "   ✅ Test brands data created"
    echo "   ✅ Manual instructions created"
    echo "   ✅ Quick test script created"
    echo ""
    echo "💡 User Details:"
    echo "   User ID: $USER_ID"
    echo "   Project: $PROJECT_ID"
    echo "   Test Data: test-brands.json"
    echo ""
    echo "🎯 Next Steps:"
    echo "   1. Run: ./quick-test-with-user.sh"
    echo "   2. Get custom token: node create-token.js"
    echo "   3. Add brands to Firestore manually"
    echo "   4. Test functions with authentication"
    echo "   5. Monitor results in Firebase Console"
    echo ""
    echo -e "${GREEN}🎯 Ready to test with your user ID!${NC}"
}

# Run the script
main "$@" 
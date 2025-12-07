#!/bin/bash

# Setup Local Development Environment
# Google's recommended approach for microservices development

set -e

echo "🚀 Setting up Local Development Environment"
echo "==========================================="
echo ""
echo "This will:"
echo "1. Start Firebase Emulators (Functions, Firestore, Auth)"
echo "2. Deploy functions to local emulator"
echo "3. Set up local testing environment"
echo "4. Create local development scripts"
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# Check if Firebase CLI is installed
if ! command -v firebase &> /dev/null; then
    echo -e "${RED}❌ Firebase CLI not found${NC}"
    echo "Please install Firebase CLI:"
    echo "npm install -g firebase-tools"
    exit 1
fi

# Check if we're in the right directory
if [ ! -f "../../firebase.json" ]; then
    echo -e "${RED}❌ firebase.json not found${NC}"
    echo "Please run this script from the local directory"
    exit 1
fi

echo -e "${BLUE}🔧 Step 1: Starting Firebase Emulators${NC}"
echo "============================================="

# Start Firebase emulators in background
LOCAL_PROJECT="${LOCAL_PROJECT:-local-microservices-project}"
echo "Starting Firebase emulators for project: $LOCAL_PROJECT"
firebase emulators:start --only functions,firestore,auth --project "$LOCAL_PROJECT" &
EMULATOR_PID=$!

# Wait for emulators to start
echo "Waiting for emulators to start..."
sleep 10

echo -e "${GREEN}✅ Firebase emulators started${NC}"
echo ""

echo -e "${BLUE}🔧 Step 2: Deploying Functions to Local Emulator${NC}"
echo "======================================================="

# Deploy functions to local emulator
echo "Deploying functions to local emulator..."
firebase deploy --only functions --project "$LOCAL_PROJECT"

echo -e "${GREEN}✅ Functions deployed to local emulator${NC}"
echo ""

echo -e "${BLUE}🔧 Step 3: Setting up Local Testing Environment${NC}"
echo "====================================================="

# Create local testing scripts
cat > test-local-functions.sh << 'EOF'
#!/bin/bash

# Test Local Functions
# Tests all functions running in Firebase emulator

set -e

echo "🧪 Testing Local Functions"
echo "=========================="

# Local emulator URLs
LOCAL_BASE_URL="http://localhost:5001/${LOCAL_PROJECT}/us-central1"

# Test functions
FUNCTIONS=(
    "categoryExtraction"
    "productExtraction"
    "orchestratorService"
    "embeddingService"
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

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

for func in "${FUNCTIONS[@]}"; do
    echo "Testing: $func"
    response=$(curl -s -w "%{http_code}" "$LOCAL_BASE_URL/$func")
    http_code="${response: -3}"
    body="${response%???}"
    
    if [ "$http_code" = "200" ]; then
        echo -e "   ${GREEN}✅ SUCCESS${NC}"
    else
        echo -e "   ${RED}❌ ERROR: $http_code${NC}"
    fi
    echo ""
done

echo "🎉 Local function testing complete!"
EOF

chmod +x test-local-functions.sh

# Create local development script
cat > start-local-development.sh << 'EOF'
#!/bin/bash

# Start Local Development Environment
# Google's recommended approach

set -e

echo "🚀 Starting Local Development Environment"
echo "========================================"
echo ""
echo "This will:"
echo "1. Start Firebase emulators"
echo "2. Deploy functions locally"
echo "3. Start local testing"
echo "4. Provide development URLs"
echo ""

# Start emulators
echo "Starting Firebase emulators..."
firebase emulators:start --only functions,firestore,auth --project demo-project

echo ""
echo "🎯 Local Development URLs:"
echo "=========================="
echo "Firebase Console: http://localhost:4000"
echo "Functions: http://localhost:5001/demo-project/us-central1"
echo "Firestore: http://localhost:8080"
echo "Auth: http://localhost:9099"
echo ""
echo "💡 Testing Commands:"
echo "===================="
echo "./test-local-functions.sh - Test all functions"
echo "curl http://localhost:5001/demo-project/us-central1/categoryExtraction"
echo ""
echo "🔧 Development Tips:"
echo "==================="
echo "1. Functions auto-reload on code changes"
echo "2. Use Firebase Console for debugging"
echo "3. Check logs in terminal output"
echo "4. Use local Firestore for data persistence"
EOF

chmod +x start-local-development.sh

# Create local data population script
cat > populate-local-data.js << 'EOF'
// Populate Local Firestore Data
// Uses local emulator for development

const admin = require('firebase-admin');

// Initialize Firebase Admin for local emulator
admin.initializeApp({
  projectId: process.env.LOCAL_PROJECT || 'local-microservices-project'
});

// Test user ID
const TEST_USER_ID = "local-test-user-123";

// Brands data
const brands = [
  {
    id: 'apple',
    name: 'Apple Inc.',
    website: 'https://www.apple.com',
    category: 'Electronics',
    description: 'Technology company',
    status: 'active',
    created_by: TEST_USER_ID,
    created_at: new Date().toISOString()
  },
  {
    id: 'tesla',
    name: 'Tesla Inc.',
    website: 'https://www.tesla.com',
    category: 'Automotive',
    description: 'Electric vehicle manufacturer',
    status: 'active',
    created_by: TEST_USER_ID,
    created_at: new Date().toISOString()
  }
];

async function populateLocalData() {
  try {
    console.log('🚀 Populating local Firestore data...');
    
    const db = admin.firestore();
    
    // Add test user
    await db.collection('users').doc(TEST_USER_ID).set({
      id: TEST_USER_ID,
      email: 'local-test@example.com',
      display_name: 'Local Test User',
      role: 'test_user',
      created_at: new Date().toISOString()
    });
    
    // Add brands
    for (const brand of brands) {
      await db.collection('brands').doc(brand.id).set(brand);
      console.log(`✅ Added brand: ${brand.name}`);
    }
    
    console.log('🎉 Local data populated successfully!');
    console.log('💡 Access Firebase Console at: http://localhost:4000');
    
  } catch (error) {
    console.error('❌ Error:', error.message);
  }
}

populateLocalData();
EOF

echo -e "${GREEN}✅ Local development environment setup complete!${NC}"
echo ""

echo -e "${BLUE}🔧 Step 4: Development Commands${NC}"
echo "====================================="
echo ""
echo "Available commands:"
echo "  ./start-local-development.sh  - Start local development"
echo "  ./test-local-functions.sh     - Test local functions"
echo "  node populate-local-data.js   - Populate local data"
echo ""
echo "Local URLs:"
echo "  Firebase Console: http://localhost:4000"
echo "  Functions: http://localhost:5001/demo-project/us-central1"
echo "  Firestore: http://localhost:8080"
echo "  Auth: http://localhost:9099"
echo ""

echo -e "${GREEN}🎉 Local Development Setup Complete!${NC}"
echo ""
echo "💡 Google's Best Practices:"
echo "=========================="
echo "✅ Local development first"
echo "✅ Use emulators for testing"
echo "✅ Secure remote access"
echo "✅ Proper logging and debugging"
echo "✅ Version control and CI/CD"
echo ""
echo "🚀 Ready for local development!" 
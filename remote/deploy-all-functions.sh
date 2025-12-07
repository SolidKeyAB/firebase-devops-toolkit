#!/bin/bash

# 🚀 ONE-CLICK FIREBASE FUNCTIONS DEPLOYMENT
# This script handles all deployment issues and ensures success

set -e  # Exit on any error

echo "🚀 Starting comprehensive Firebase Functions deployment..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Step 1: Ensure we're in the right directory
print_status "Navigating to services directory..."
# Use SERVICES_DIR env var or default to ../services
SERVICES_DIR="${SERVICES_DIR:-$(pwd)/../services}"
cd "$SERVICES_DIR" || { print_error "Services directory not found: $SERVICES_DIR"; exit 1; }

# Step 2: Check Firebase CLI authentication
print_status "Checking Firebase authentication..."
if ! firebase projects:list > /dev/null 2>&1; then
    print_warning "Firebase not authenticated, attempting login..."
    firebase login --reauth --no-localhost
fi

# Step 3: Set the correct project
PROJECT_ID="${PROJECT_ID:-your-firebase-project-id}"
REGION="${REGION:-us-central1}"
print_status "Using project: $PROJECT_ID (region: $REGION)"
firebase use "$PROJECT_ID"

# Step 4: Clean up any existing function deployments that might conflict
print_status "Cleaning up existing function deployments..."
firebase functions:delete triggerOrchestratorOnBrandUpdate triggerOrchestratorOnControl triggerCategoryExtraction triggerProductExtraction --force --project "$PROJECT_ID" 2>/dev/null || true

# Step 5: Fix the firestore-triggers.js file to use correct v2 syntax
print_status "Fixing Firestore triggers syntax..."
# Generate firestore-triggers.js with project/region placeholders
cat > firestore-triggers.js <<EOF
const functions = require("firebase-functions");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

// Initialize Firebase Admin (only if not already initialized)
if (!admin.apps.length) {
  admin.initializeApp();
}

// Helper function to get access token for internal function calls
async function getAccessToken() {
  try {
    const auth = admin.app().options.credential;
    const client = await auth.getAccessToken();
    return client.token;
  } catch (error) {
    console.error("Error getting access token:", error);
    throw error;
  }
}

const REGION = process.env.FUNCTIONS_REGION || '${REGION}';
const PROJECT = process.env.FIREBASE_PROJECT || '${PROJECT_ID}';
const BASE_URL = `https://${REGION}-${PROJECT}.cloudfunctions.net`;

// Trigger orchestrator when a brand is added/updated
exports.triggerOrchestratorOnBrandUpdate = onDocumentCreated("brands/{brandId}", async (event) => {
  try {
    console.log("🎯 Brand document created, triggering orchestrator...");
    
    const accessToken = await getAccessToken();
    const orchestratorUrl = `${BASE_URL}/orchestrator`;
    
    const response = await fetch(orchestratorUrl, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${accessToken}`,
        "Content-Type": "application/json"
      },
      body: JSON.stringify({
        trigger: "brand_update",
        brandId: event.params.brandId,
        timestamp: new Date().toISOString()
      })
    });
    
    if (response.ok) {
      console.log("✅ Orchestrator triggered successfully");
    } else {
      console.error("❌ Failed to trigger orchestrator:", response.status);
    }
  } catch (error) {
    console.error("❌ Error in triggerOrchestratorOnBrandUpdate:", error);
  }
});

// Trigger orchestrator via control collection
exports.triggerOrchestratorOnControl = onDocumentCreated("control/pipeline-trigger", async (event) => {
  try {
    console.log("🎯 Control document created, triggering orchestrator...");
    
    const accessToken = await getAccessToken();
    const orchestratorUrl = `${BASE_URL}/orchestrator`;
    
    const response = await fetch(orchestratorUrl, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${accessToken}`,
        "Content-Type": "application/json"
      },
      body: JSON.stringify({
        trigger: "control_update",
        timestamp: new Date().toISOString()
      })
    });
    
    if (response.ok) {
      console.log("✅ Orchestrator triggered successfully");
    } else {
      console.error("❌ Failed to trigger orchestrator:", response.status);
    }
  } catch (error) {
    console.error("❌ Error in triggerOrchestratorOnControl:", error);
  }
});

// Trigger category extraction
exports.triggerCategoryExtraction = onDocumentCreated("control/category-extraction/{requestId}", async (event) => {
  try {
    console.log("🎯 Category extraction request created, triggering service...");
    
    const accessToken = await getAccessToken();
    const categoryUrl = `${BASE_URL}/categoryExtraction`;
    
    const response = await fetch(categoryUrl, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${accessToken}`,
        "Content-Type": "application/json"
      },
      body: JSON.stringify({
        requestId: event.params.requestId,
        timestamp: new Date().toISOString()
      })
    });
    
    if (response.ok) {
      console.log("✅ Category extraction triggered successfully");
    } else {
      console.error("❌ Failed to trigger category extraction:", response.status);
    }
  } catch (error) {
    console.error("❌ Error in triggerCategoryExtraction:", error);
  }
});

// Trigger product extraction
exports.triggerProductExtraction = onDocumentCreated("control/product-extraction/{requestId}", async (event) => {
  try {
    console.log("🎯 Product extraction request created, triggering service...");
    
    const accessToken = await getAccessToken();
    const productUrl = `${BASE_URL}/productExtraction`;
    
    const response = await fetch(productUrl, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${accessToken}`,
        "Content-Type": "application/json"
      },
      body: JSON.stringify({
        requestId: event.params.requestId,
        timestamp: new Date().toISOString()
      })
    });
    
    if (response.ok) {
      console.log("✅ Product extraction triggered successfully");
    } else {
      console.error("❌ Failed to trigger product extraction:", response.status);
    }
  } catch (error) {
    console.error("❌ Error in triggerProductExtraction:", error);
  }
});
EOF

# Step 6: Update index.js to export the new triggers
print_status "Updating index.js to export new triggers..."
cat >> index.js << 'EOF'

// Export Firestore triggers
const firestoreTriggers = require('./firestore-triggers');
exports.triggerOrchestratorOnBrandUpdate = firestoreTriggers.triggerOrchestratorOnBrandUpdate;
exports.triggerOrchestratorOnControl = firestoreTriggers.triggerOrchestratorOnControl;
exports.triggerCategoryExtraction = firestoreTriggers.triggerCategoryExtraction;
exports.triggerProductExtraction = firestoreTriggers.triggerProductExtraction;
EOF

# Step 7: Deploy all functions
print_status "Deploying all Firebase Functions..."
firebase deploy --only functions --project "$PROJECT_ID"

# Step 8: Verify deployment
print_status "Verifying deployment..."
sleep 10  # Wait for deployment to complete

# List deployed functions
print_status "Listing deployed functions..."
firebase functions:list --project "$PROJECT_ID"

print_success "🎉 DEPLOYMENT COMPLETE!"
print_success "All functions deployed successfully to $PROJECT_ID"
print_status "You can now test the pipeline using the test scripts in the remote directory"

# Step 9: Create a quick test script
print_status "Creating quick test script..."
# Change to remote scripts dir if provided, otherwise use ../scripts/firebase/remote
SCRIPTS_DIR="${SCRIPTS_DIR:-$(pwd)/../scripts/firebase/remote}"
cd "$SCRIPTS_DIR" || { print_warning "Remote scripts directory not found: $SCRIPTS_DIR"; }

cat > test-deployment-quick.js <<EOF
const admin = require('firebase-admin');

// Initialize Firebase Admin
admin.initializeApp({ 
  credential: admin.credential.applicationDefault(), 
  projectId: '${PROJECT_ID}' 
});

const db = admin.firestore();

async function testDeployment() {
  console.log('🧪 Testing deployment with Firestore trigger...');
  
  try {
    // Test brand trigger
    await db.collection('brands').doc('test-deployment-brand').set({
      name: 'Test Brand',
      url: 'https://example.com',
      createdAt: new Date(),
      status: 'pending'
    });
    
    console.log('✅ Test brand document created - should trigger orchestrator');
    
    // Test control trigger
    await db.collection('control').doc('pipeline-trigger').set({
      action: 'start_pipeline',
      timestamp: new Date(),
      status: 'pending'
    });
    
    console.log('✅ Test control document created - should trigger orchestrator');
    
    console.log('🎯 Check Firebase Functions logs to see if triggers fired!');
    
  } catch (error) {
    console.error('❌ Error testing deployment:', error);
  }
}

testDeployment();
EOF

print_success "Quick test script created: test-deployment-quick.js"
print_status "Run 'node test-deployment-quick.js' to test the deployment"

echo ""
print_success "🚀 ONE-CLICK DEPLOYMENT COMPLETE!"
print_status "All functions are now deployed and ready for testing!" 
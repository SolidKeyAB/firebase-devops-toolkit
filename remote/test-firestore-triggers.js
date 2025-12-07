// Test Firestore Triggers
// Official Firebase way to trigger internal functions

const admin = require('firebase-admin');

// Initialize Firebase Admin with ADC
admin.initializeApp({
  credential: admin.credential.applicationDefault(),
  projectId: process.env.FIREBASE_PROJECT_ID || 'your-project-id'
});

const db = admin.firestore();

async function testFirestoreTriggers() {
  console.log('🎯 Testing Firestore Triggers');
  console.log('=============================');
  console.log('');
  
  try {
    // Test 1: Add a brand to trigger orchestrator
    console.log('🧪 Test 1: Adding brand to trigger orchestrator');
    
    const brandData = {
      id: 'test-brand-trigger',
      name: 'Test Brand for Trigger',
      website: 'https://www.testbrand.com',
      category: 'Test Category',
      description: 'Test brand for triggering orchestrator',
      status: 'active',
      created_by: 'test-user-123',
      created_at: new Date().toISOString()
    };
    
    await db.collection('brands').doc('test-brand-trigger').set(brandData);
    console.log('✅ Brand added - orchestrator should be triggered');
    console.log('');
    
    // Wait a moment for trigger to execute
    await new Promise(resolve => setTimeout(resolve, 2000));
    
    // Test 2: Create control document to trigger complete pipeline
    console.log('🧪 Test 2: Creating control document for complete pipeline');
    
    const controlData = {
      user_id: 'test-user-123',
      max_categories: 5,
      max_products: 3,
      comprehensive_extraction: true,
      created_at: new Date().toISOString(),
      status: 'pending'
    };
    
    await db.collection('control').doc('pipeline-trigger').set(controlData);
    console.log('✅ Control document created - complete pipeline should be triggered');
    console.log('');
    
    // Wait a moment for trigger to execute
    await new Promise(resolve => setTimeout(resolve, 2000));
    
    // Test 3: Create category extraction request
    console.log('🧪 Test 3: Creating category extraction request');
    
    const categoryRequest = {
      brand_id: 'apple',
      website: 'https://www.apple.com',
      max_categories: 5,
      user_id: 'test-user-123',
      created_at: new Date().toISOString(),
      status: 'pending'
    };
    
    await db.collection('control').doc('category-extraction').collection('requests').add(categoryRequest);
    console.log('✅ Category extraction request created');
    console.log('');
    
    // Wait a moment for trigger to execute
    await new Promise(resolve => setTimeout(resolve, 2000));
    
    // Test 4: Create product extraction request
    console.log('🧪 Test 4: Creating product extraction request');
    
    const productRequest = {
      brand_id: 'apple',
      max_products: 3,
      comprehensive_extraction: true,
      user_id: 'test-user-123',
      created_at: new Date().toISOString(),
      status: 'pending'
    };
    
    await db.collection('control').doc('product-extraction').collection('requests').add(productRequest);
    console.log('✅ Product extraction request created');
    console.log('');
    
    console.log('🎉 Firestore trigger tests completed!');
    console.log('');
    console.log('📊 Check Firebase Console for:');
    console.log('   - Function logs (trigger execution)');
    console.log('   - Firestore data updates');
    console.log('   - Processing status changes');
    console.log('');
    console.log('💡 This approach:');
    console.log('   ✅ Uses official Firebase triggers');
    console.log('   ✅ Works with secured functions');
    console.log('   ✅ No external authentication needed');
    console.log('   ✅ Internal function calls');
    console.log('   ✅ Proper error handling and logging');
    
  } catch (error) {
    console.error('❌ Error testing Firestore triggers:', error);
  }
}

// Run the test
testFirestoreTriggers(); 
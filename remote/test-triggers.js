const admin = require('firebase-admin');

admin.initializeApp({ 
  credential: admin.credential.applicationDefault(), 
  projectId: process.env.FIREBASE_PROJECT_ID || 'your-project-id' 
});

const db = admin.firestore();

async function testTriggers() {
  console.log('🧪 Testing Firestore triggers...');
  
  try {
    // Test brand trigger
    await db.collection('brands').doc('test-trigger-brand').set({
      name: 'Test Trigger Brand',
      url: 'https://example.com',
      createdAt: new Date(),
      status: 'pending'
    });
    
    console.log('✅ Test brand document created');
    
    // Test control trigger
    await db.collection('control').doc('pipeline-trigger').set({
      action: 'start_pipeline',
      timestamp: new Date(),
      status: 'pending'
    });
    
    console.log('✅ Test control document created');
    console.log('🎯 Check Firebase Functions logs to see triggers!');
    
  } catch (error) {
    console.error('❌ Error:', error);
  }
}

testTriggers();

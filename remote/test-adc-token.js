// Test ADC Token Generation
// Simple test to see what's happening with access tokens

const admin = require('firebase-admin');
const { GoogleAuth } = require('google-auth-library');

async function testADCToken() {
  try {
    console.log('🔐 Testing ADC Token Generation...');
    console.log('');
    
    // Initialize Firebase Admin with ADC
    admin.initializeApp({
      credential: admin.credential.applicationDefault(),
      projectId: process.env.FIREBASE_PROJECT_ID || 'your-project-id'
    });
    
    console.log('✅ Firebase Admin initialized with ADC');
    console.log('');
    
    // Method 1: Try Firebase Admin credential
    try {
      console.log('🔑 Method 1: Firebase Admin credential...');
      const auth = admin.app().options.credential;
      const client = await auth.getAccessToken();
      console.log('✅ Firebase Admin token:', client.token.substring(0, 50) + '...');
    } catch (error) {
      console.log('❌ Firebase Admin token failed:', error.message);
    }
    
    console.log('');
    
    // Method 2: Try Google Auth Library directly
    try {
      console.log('🔑 Method 2: Google Auth Library...');
      const auth = new GoogleAuth({
        scopes: [
          'https://www.googleapis.com/auth/cloud-platform',
          'https://www.googleapis.com/auth/firebase',
          'https://www.googleapis.com/auth/datastore'
        ]
      });
      
      const client = await auth.getClient();
      const token = await client.getAccessToken();
      console.log('✅ Google Auth token:', token.token.substring(0, 50) + '...');
    } catch (error) {
      console.log('❌ Google Auth token failed:', error.message);
    }
    
    console.log('');
    
    // Method 3: Try gcloud command
    try {
      console.log('🔑 Method 3: gcloud auth print-access-token...');
      const { exec } = require('child_process');
      const util = require('util');
      const execAsync = util.promisify(exec);
      
      const { stdout } = await execAsync('gcloud auth print-access-token');
      const token = stdout.trim();
      console.log('✅ gcloud token:', token.substring(0, 50) + '...');
    } catch (error) {
      console.log('❌ gcloud token failed:', error.message);
    }
    
    console.log('');
    console.log('💡 Summary:');
    console.log('   - ADC is working for Firestore (we confirmed this)');
    console.log('   - Cloud Functions might need different authentication');
    console.log('   - Let\'s try the manual approach or check function logs');
    
  } catch (error) {
    console.error('❌ Error testing ADC token:', error.message);
  }
}

// Run the test
testADCToken(); 
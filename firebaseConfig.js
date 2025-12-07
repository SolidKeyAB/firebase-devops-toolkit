/**
 * Shared Firebase Configuration
 * Ensures consistent Firebase setup across all microservices
 */

const admin = require('firebase-admin');

// Environment detection
const isDevelopment = process.env.NODE_ENV !== 'production';
const isEmulator = process.env.FIRESTORE_EMULATOR_HOST || process.env.FUNCTIONS_EMULATOR || process.env.NODE_ENV === 'development';

let firebaseApp = null;

/**
 * Initialize Firebase Admin with proper emulator configuration
 */
function initializeFirebase() {
  if (firebaseApp) {
    return firebaseApp;
  }

  // Check if Firebase is already initialized
  if (admin.apps.length > 0) {
    firebaseApp = admin.apps[0];
    return firebaseApp;
  }

  // Initialize Firebase Admin
  const projectId = process.env.FIREBASE_PROJECT_ID;
  if (!projectId) {
    console.error('❌ FIREBASE_PROJECT_ID environment variable is required');
    console.error('💡 Set it in your .env file or environment');
    process.exit(1);
  }

  firebaseApp = admin.initializeApp({
    projectId: projectId
  });

  // Configure Firestore for emulator if in development
  if (isDevelopment && isEmulator) {
    const db = admin.firestore();
    
    // Set emulator host
    if (process.env.FIRESTORE_EMULATOR_HOST) {
      db.settings({
        host: process.env.FIRESTORE_EMULATOR_HOST,
        ssl: false
      });
    }
    
    console.log('🔧 Firebase configured for emulator mode');
    console.log(`📡 Firestore emulator: ${process.env.FIRESTORE_EMULATOR_HOST || 'localhost:8080'}`);
  } else {
    console.log('🚀 Firebase configured for production mode');
  }

  return firebaseApp;
}

/**
 * Get Firestore instance with proper configuration
 */
function getFirestore() {
  const app = initializeFirebase();
  return app.firestore();
}

/**
 * Get Firebase Admin instance
 */
function getAdmin() {
  return initializeFirebase();
}

module.exports = {
  initializeFirebase,
  getFirestore,
  getAdmin,
  isDevelopment,
  isEmulator
}; 
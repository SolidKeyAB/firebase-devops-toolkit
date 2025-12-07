/**
 * Firebase Admin SDK Singleton
 *
 * Use this to access Firestore, Auth, and other Firebase services.
 * Import in your services: const { getFirestore } = require('../shared/libs/firebase.js');
 */

const admin = require('firebase-admin');

// Initialize Firebase Admin (only once)
if (!admin.apps.length) {
  admin.initializeApp();
}

/**
 * Get Firestore instance
 * @returns {FirebaseFirestore.Firestore}
 */
exports.getFirestore = () => admin.firestore();

/**
 * Get Auth instance
 * @returns {admin.auth.Auth}
 */
exports.getAuth = () => admin.auth();

/**
 * Get Storage instance
 * @returns {admin.storage.Storage}
 */
exports.getStorage = () => admin.storage();

/**
 * Get the admin SDK (for advanced use)
 * @returns {admin.app.App}
 */
exports.getAdmin = () => admin;

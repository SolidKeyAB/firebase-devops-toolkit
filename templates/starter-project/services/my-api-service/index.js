/**
 * My API Service
 *
 * Example HTTP API service with common patterns.
 * Customize this for your needs!
 */

const { onRequest } = require('firebase-functions/v2/https');
const { getFirestore } = require('../shared/libs/firebase.js');

// Configuration - customize these
const REGION = process.env.FIREBASE_REGION || 'us-central1';

// =============================================================================
// Hello World - Simple test endpoint
// =============================================================================
exports.hello = onRequest({
  region: REGION,
  cors: true
}, (req, res) => {
  res.json({
    message: 'Hello from Firebase DevOps Toolkit!',
    timestamp: new Date().toISOString()
  });
});

// =============================================================================
// Health Check - Use this to verify your service is running
// =============================================================================
exports.health = onRequest({
  region: REGION,
  cors: true
}, (req, res) => {
  res.json({
    status: 'healthy',
    service: 'my-api-service',
    timestamp: new Date().toISOString(),
    environment: process.env.NODE_ENV || 'development'
  });
});

// =============================================================================
// Get Items - Example Firestore read
// =============================================================================
exports.getItems = onRequest({
  region: REGION,
  cors: true,
  memory: '256MiB'
}, async (req, res) => {
  try {
    const db = getFirestore();
    const snapshot = await db.collection('items').limit(10).get();

    const items = [];
    snapshot.forEach(doc => {
      items.push({ id: doc.id, ...doc.data() });
    });

    res.json({
      success: true,
      items,
      count: items.length
    });
  } catch (error) {
    console.error('Error getting items:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to get items'
    });
  }
});

// =============================================================================
// Create Item - Example Firestore write
// =============================================================================
exports.createItem = onRequest({
  region: REGION,
  cors: true,
  memory: '256MiB'
}, async (req, res) => {
  // Only allow POST
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  try {
    const { name, description } = req.body;

    if (!name) {
      return res.status(400).json({ error: 'Name is required' });
    }

    const db = getFirestore();
    const docRef = await db.collection('items').add({
      name,
      description: description || '',
      createdAt: new Date().toISOString()
    });

    res.status(201).json({
      success: true,
      id: docRef.id,
      message: 'Item created successfully'
    });
  } catch (error) {
    console.error('Error creating item:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to create item'
    });
  }
});

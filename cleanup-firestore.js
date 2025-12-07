#!/usr/bin/env node

/**
 * Consolidated Firestore Cleanup Utility
 * Combines complete cleanup and duplicate removal functionality
 * Usage:
 *   node cleanup-firestore.js --all                    # Clean all collections
 *   node cleanup-firestore.js --duplicates             # Remove duplicates only
 *   node cleanup-firestore.js --collection products    # Clean specific collection
 */

const admin = require('firebase-admin');

// Optional axios import - only if available
let axios;
try {
  axios = require('axios');
} catch (e) {
  console.log('⚠️  axios not installed - vector database cleanup will be skipped');
}

// Initialize Firebase Admin
if (!admin.apps.length) {
  const projectId = process.env.FIREBASE_PROJECT_ID;
  if (!projectId) {
    console.error('❌ FIREBASE_PROJECT_ID environment variable is required');
    console.error('💡 Set it in your .env file or environment');
    process.exit(1);
  }

  admin.initializeApp({
    projectId: projectId
  });
}

const db = admin.firestore();

// Vector database configuration (optional)
const QDRANT_URL = process.env.QDRANT_URL;
const QDRANT_API_KEY = process.env.QDRANT_API_KEY;

// Default collections that can be cleaned
const DEFAULT_COLLECTIONS = [
  'processing_queue',
  'products',
  'brands',
  'pipeline_progress',
  'system',
  'issues',
  'scores',
  'sustainability_data',
  'legal_compliance_data',
  'product_images',
  'unknown_products',
  'categories',
  'product_categories',
  'extraction_results',
  'enrichment_results'
];

/**
 * Clean all documents from specified collections
 */
async function cleanAllCollections(collections = DEFAULT_COLLECTIONS) {
  console.log('🧹 COMPLETE DATABASE CLEANUP - This will delete ALL data!');
  console.log('⚠️  WARNING: This is a destructive operation!');

  let totalDeleted = 0;

  for (const collectionName of collections) {
    try {
      console.log(`📂 Cleaning collection: ${collectionName}`);

      const collectionRef = db.collection(collectionName);
      const snapshot = await collectionRef.get();

      if (snapshot.empty) {
        console.log(`  ✅ ${collectionName} is already empty`);
        continue;
      }

      // Delete in batches to avoid timeout
      const batchSize = 100;
      let deletedInCollection = 0;

      while (true) {
        const batch = db.batch();
        const docs = await collectionRef.limit(batchSize).get();

        if (docs.empty) break;

        docs.forEach(doc => {
          batch.delete(doc.ref);
        });

        await batch.commit();
        deletedInCollection += docs.size;
        totalDeleted += docs.size;

        console.log(`  🗑️  Deleted ${deletedInCollection} documents from ${collectionName}`);

        if (docs.size < batchSize) break;
      }

    } catch (error) {
      console.error(`❌ Error cleaning ${collectionName}:`, error.message);
    }
  }

  // Clean vector database if configured
  if (QDRANT_URL) {
    await cleanQdrantCollections();
  }

  console.log(`✅ Cleanup complete! Total documents deleted: ${totalDeleted}`);
}

/**
 * Remove duplicate documents from collections
 */
async function removeDuplicates(collections = DEFAULT_COLLECTIONS) {
  console.log('🔍 Finding and removing duplicate documents...');

  let totalDuplicatesRemoved = 0;

  for (const collectionName of collections) {
    try {
      console.log(`📂 Checking for duplicates in: ${collectionName}`);

      const collectionRef = db.collection(collectionName);
      const snapshot = await collectionRef.get();

      if (snapshot.empty) {
        console.log(`  ✅ ${collectionName} is empty`);
        continue;
      }

      // Group documents by content hash or key fields
      const documentGroups = new Map();

      snapshot.forEach(doc => {
        const data = doc.data();

        // Create a hash based on key fields (customize per collection)
        let hashKey;
        if (collectionName === 'products' && data.name && data.brand_id) {
          hashKey = `${data.name}_${data.brand_id}`;
        } else if (collectionName === 'brands' && data.name) {
          hashKey = data.name;
        } else if (data.id) {
          hashKey = data.id;
        } else {
          // Use a hash of the entire document for generic deduplication
          hashKey = JSON.stringify(data);
        }

        if (!documentGroups.has(hashKey)) {
          documentGroups.set(hashKey, []);
        }
        documentGroups.get(hashKey).push({ id: doc.id, data });
      });

      // Remove duplicates (keep the first, delete the rest)
      let duplicatesInCollection = 0;
      const batch = db.batch();
      let batchOps = 0;

      for (const [hashKey, docs] of documentGroups) {
        if (docs.length > 1) {
          // Keep the first document, delete the rest
          for (let i = 1; i < docs.length; i++) {
            batch.delete(collectionRef.doc(docs[i].id));
            batchOps++;
            duplicatesInCollection++;

            // Commit batch if it gets too large
            if (batchOps >= 400) {
              await batch.commit();
              batchOps = 0;
            }
          }
          console.log(`  🔍 Found ${docs.length - 1} duplicates for key: ${hashKey.substring(0, 50)}...`);
        }
      }

      // Commit any remaining operations
      if (batchOps > 0) {
        await batch.commit();
      }

      totalDuplicatesRemoved += duplicatesInCollection;
      console.log(`  ✅ Removed ${duplicatesInCollection} duplicates from ${collectionName}`);

    } catch (error) {
      console.error(`❌ Error removing duplicates from ${collectionName}:`, error.message);
    }
  }

  console.log(`✅ Duplicate removal complete! Total duplicates removed: ${totalDuplicatesRemoved}`);
}

/**
 * Clean specific collection
 */
async function cleanCollection(collectionName) {
  console.log(`🧹 Cleaning specific collection: ${collectionName}`);
  await cleanAllCollections([collectionName]);
}

/**
 * Clean Qdrant vector database collections
 */
async function cleanQdrantCollections() {
  if (!QDRANT_URL) {
    console.log('⚠️  Qdrant URL not configured, skipping vector cleanup');
    return;
  }

  if (!axios) {
    console.log('⚠️  axios not available, skipping vector cleanup');
    return;
  }

  console.log('🧹 Cleaning Qdrant vector database...');

  const collections = ['products', 'categories', 'embeddings'];

  for (const collection of collections) {
    try {
      const headers = {};
      if (QDRANT_API_KEY) {
        headers['api-key'] = QDRANT_API_KEY;
      }

      await axios.delete(`${QDRANT_URL}/collections/${collection}`, { headers });
      console.log(`  ✅ Deleted Qdrant collection: ${collection}`);
    } catch (error) {
      if (error.response?.status === 404) {
        console.log(`  ✅ Qdrant collection ${collection} doesn't exist`);
      } else {
        console.error(`  ❌ Error deleting Qdrant collection ${collection}:`, error.message);
      }
    }
  }
}

/**
 * Show usage information
 */
function showUsage() {
  console.log('🧹 Consolidated Firestore Cleanup Utility');
  console.log('');
  console.log('Usage:');
  console.log('  node cleanup-firestore.js --all                    # Clean all collections');
  console.log('  node cleanup-firestore.js --duplicates             # Remove duplicates only');
  console.log('  node cleanup-firestore.js --collection products    # Clean specific collection');
  console.log('  node cleanup-firestore.js --qdrant                 # Clean vector database only');
  console.log('  node cleanup-firestore.js --help                   # Show this help');
  console.log('');
  console.log('Environment Variables:');
  console.log('  FIREBASE_PROJECT_ID    Required - Firebase project ID');
  console.log('  QDRANT_URL            Optional - Qdrant vector database URL');
  console.log('  QDRANT_API_KEY        Optional - Qdrant API key');
  console.log('');
  console.log('Examples:');
  console.log('  FIREBASE_PROJECT_ID=my-project node cleanup-firestore.js --all');
  console.log('  node cleanup-firestore.js --collection products --collection brands');
}

/**
 * Main execution
 */
async function main() {
  const args = process.argv.slice(2);

  if (args.length === 0 || args.includes('--help') || args.includes('-h')) {
    showUsage();
    return;
  }

  try {
    if (args.includes('--all')) {
      // Get custom collections if specified
      const customCollections = [];
      for (let i = 0; i < args.length; i++) {
        if (args[i] === '--collection' && args[i + 1]) {
          customCollections.push(args[i + 1]);
        }
      }

      await cleanAllCollections(customCollections.length > 0 ? customCollections : DEFAULT_COLLECTIONS);

    } else if (args.includes('--duplicates')) {
      await removeDuplicates();

    } else if (args.includes('--qdrant')) {
      await cleanQdrantCollections();

    } else if (args.includes('--collection')) {
      const collections = [];
      for (let i = 0; i < args.length; i++) {
        if (args[i] === '--collection' && args[i + 1]) {
          collections.push(args[i + 1]);
        }
      }

      if (collections.length === 0) {
        console.error('❌ No collection specified');
        showUsage();
        return;
      }

      for (const collection of collections) {
        await cleanCollection(collection);
      }

    } else {
      console.error('❌ Invalid arguments');
      showUsage();
    }

  } catch (error) {
    console.error('❌ Cleanup failed:', error.message);
    process.exit(1);
  }
}

// Handle graceful shutdown
process.on('SIGINT', () => {
  console.log('\n🛑 Cleanup interrupted by user');
  process.exit(0);
});

process.on('SIGTERM', () => {
  console.log('\n🛑 Cleanup terminated');
  process.exit(0);
});

// Run the script
if (require.main === module) {
  main();
}

module.exports = {
  cleanAllCollections,
  removeDuplicates,
  cleanCollection,
  cleanQdrantCollections
};
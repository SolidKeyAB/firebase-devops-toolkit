#!/usr/bin/env node

/**
 * Cleanup Pub/Sub Topics for Firebase Emulator
 * This script removes Pub/Sub topics and subscriptions (use with caution)
 */

const { PubSub } = require('@google-cloud/pubsub');

// Configuration
const PROJECT_ID = process.env.FIREBASE_PROJECT_ID || 'your-project-id';
const EMULATOR_HOST = 'localhost:8085';

// Set emulator host
process.env.PUBSUB_EMULATOR_HOST = EMULATOR_HOST;

const pubsub = new PubSub({
  projectId: PROJECT_ID,
});

async function cleanupPubSubTopics() {
  console.log('🧹 Cleaning up Pub/Sub Topics for Firebase Emulator');
  console.log('==================================================');
  console.log(`ℹ️  Project ID: ${PROJECT_ID}`);
  console.log(`ℹ️  Emulator Host: ${EMULATOR_HOST}`);
  console.log('');

  try {
    // List existing topics
    console.log('📋 Listing existing topics...');
    const [topics] = await pubsub.getTopics();
    console.log(`Found ${topics.length} topics:`);
    topics.forEach(topic => {
      const topicName = topic.name.split('/').pop();
      console.log(`   - ${topicName}`);
    });
    console.log('');

    // Ask for confirmation
    const readline = require('readline');
    const rl = readline.createInterface({
      input: process.stdin,
      output: process.stdout
    });

    rl.question('⚠️  Are you sure you want to delete ALL topics and subscriptions? (yes/no): ', async (answer) => {
      if (answer.toLowerCase() === 'yes' || answer.toLowerCase() === 'y') {
        console.log('🗑️  Proceeding with cleanup...');
        
        // Delete subscriptions first
        for (const topic of topics) {
          const topicName = topic.name.split('/').pop();
          console.log(`🗑️  Deleting subscriptions for topic: ${topicName}`);
          
          try {
            const [subscriptions] = await topic.getSubscriptions();
            for (const subscription of subscriptions) {
              const subscriptionName = subscription.name.split('/').pop();
              console.log(`   🗑️  Deleting subscription: ${subscriptionName}`);
              await subscription.delete();
            }
          } catch (error) {
            console.log(`   ⚠️  Could not delete subscriptions for ${topicName}: ${error.message}`);
          }
        }

        // Delete topics
        for (const topic of topics) {
          const topicName = topic.name.split('/').pop();
          console.log(`🗑️  Deleting topic: ${topicName}`);
          try {
            await topic.delete();
            console.log(`   ✅ Deleted topic: ${topicName}`);
          } catch (error) {
            console.log(`   ❌ Failed to delete topic ${topicName}: ${error.message}`);
          }
        }

        console.log('');
        console.log('✅ Cleanup completed!');
      } else {
        console.log('❌ Cleanup cancelled.');
      }
      
      rl.close();
      process.exit(0);
    });

  } catch (error) {
    console.error(`❌ Cleanup failed: ${error.message}`);
    process.exit(1);
  }
}

// Run the cleanup
cleanupPubSubTopics();

#!/usr/bin/env node

/**
 * Setup Pub/Sub Topics for Firebase Emulator
 * This script creates the required Pub/Sub topics that the orchestrator service needs
 */

const { PubSub } = require('@google-cloud/pubsub');

// Configuration
const PROJECT_ID = process.env.FIREBASE_PROJECT_ID || 'your-project-id';
const EMULATOR_HOST = 'localhost:8085';

// Required topics and subscriptions based on pubsub-handler.js
const REQUIRED_TOPICS = [
  'category-extraction-topic',
  'product-extraction-topic',
  'product-enrichment-topic',
  'sustainability-enrichment-topic',
  'ai-logging-topic',
  'orchestrator-topic'
];

const REQUIRED_SUBSCRIPTIONS = [
  'category-extraction-subscription',
  'product-extraction-subscription',
  'product-enrichment-subscription',
  'sustainability-enrichment-subscription',
  'ai-logging-subscription',
  'orchestrator-subscription'
];

// Initialize PubSub client for emulator
const pubsub = new PubSub({
  projectId: PROJECT_ID,
  apiEndpoint: EMULATOR_HOST
});

// Logging functions
function logInfo(message) {
  console.log(`ℹ️  ${message}`);
}

function logSuccess(message) {
  console.log(`✅ ${message}`);
}

function logWarning(message) {
  console.log(`⚠️  ${message}`);
}

function logError(message) {
  console.error(`❌ ${message}`);
}

function logHeader(message) {
  console.log('');
  console.log(`🔧 ${message}`);
  console.log('==================================');
}

// Check if emulator is accessible
async function checkEmulator() {
  try {
    logInfo('Checking if Pub/Sub emulator is accessible...');
    
    // Try to list topics to check connectivity
    const [topics] = await pubsub.getTopics();
    logSuccess(`Pub/Sub emulator is accessible. Found ${topics.length} existing topics.`);
    return true;
  } catch (error) {
    logError(`Pub/Sub emulator is not accessible: ${error.message}`);
    logInfo('Please ensure the Firebase emulator is running with Pub/Sub enabled:');
    logInfo('  ./firebase-scripts/local/start-emulator.sh');
    return false;
  }
}

// Create a topic
async function createTopic(topicName) {
  try {
    logInfo(`Creating topic: ${topicName}`);
    
    const [topic] = await pubsub.createTopic(topicName);
    logSuccess(`Created topic: ${topicName}`);
    return true;
  } catch (error) {
    if (error.code === 6) { // ALREADY_EXISTS
      logWarning(`Topic ${topicName} already exists`);
      return true;
    } else {
      logError(`Failed to create topic ${topicName}: ${error.message}`);
      return false;
    }
  }
}

// Create a subscription
async function createSubscription(topicName, subscriptionName) {
  try {
    logInfo(`Creating subscription: ${subscriptionName} for topic: ${topicName}`);
    
    const [subscription] = await pubsub.topic(topicName).createSubscription(subscriptionName, {
      ackDeadlineSeconds: 10
    });
    
    logSuccess(`Created subscription: ${subscriptionName}`);
    return true;
  } catch (error) {
    if (error.code === 6) { // ALREADY_EXISTS
      logWarning(`Subscription ${subscriptionName} already exists`);
      return true;
    } else {
      logError(`Failed to create subscription ${subscriptionName}: ${error.message}`);
      return false;
    }
  }
}

// List existing topics
async function listTopics() {
  try {
    logInfo('Listing existing topics...');
    const [topics] = await pubsub.getTopics();
    
    if (topics.length === 0) {
      logInfo('No topics found');
    } else {
      topics.forEach(topic => {
        const topicName = topic.name.split('/').pop();
        logInfo(`  - ${topicName}`);
      });
    }
  } catch (error) {
    logError(`Failed to list topics: ${error.message}`);
  }
}

// List existing subscriptions
async function listSubscriptions() {
  try {
    logInfo('Listing existing subscriptions...');
    const [subscriptions] = await pubsub.getSubscriptions();
    
    if (subscriptions.length === 0) {
      logInfo('No subscriptions found');
    } else {
      subscriptions.forEach(subscription => {
        const subscriptionName = subscription.name.split('/').pop();
        const topicName = subscription.topic.split('/').pop();
        logInfo(`  - ${subscriptionName} (topic: ${topicName})`);
      });
    }
  } catch (error) {
    logError(`Failed to list subscriptions: ${error.message}`);
  }
}

// Main setup function
async function setupPubSub() {
  logHeader('Setting up Pub/Sub Topics for Firebase Emulator');
  
  // Check emulator accessibility
  if (!(await checkEmulator())) {
    process.exit(1);
  }
  
  logInfo(`Using project ID: ${PROJECT_ID}`);
  
  // List existing topics
  await listTopics();
  
  // Create topics
  logHeader('Creating Required Topics');
  let topicsCreated = 0;
  let topicsFailed = 0;
  
  for (const topic of REQUIRED_TOPICS) {
    if (await createTopic(topic)) {
      topicsCreated++;
    } else {
      topicsFailed++;
    }
  }
  
  // Create subscriptions
  logHeader('Creating Required Subscriptions');
  let subscriptionsCreated = 0;
  let subscriptionsFailed = 0;
  
  for (let i = 0; i < REQUIRED_TOPICS.length; i++) {
    const topic = REQUIRED_TOPICS[i];
    const subscription = REQUIRED_SUBSCRIPTIONS[i];
    
    if (await createSubscription(topic, subscription)) {
      subscriptionsCreated++;
    } else {
      subscriptionsFailed++;
    }
  }
  
  // Summary
  logHeader('Setup Summary');
  logInfo(`Topics created: ${topicsCreated}/${REQUIRED_TOPICS.length}`);
  logInfo(`Subscriptions created: ${subscriptionsCreated}/${REQUIRED_SUBSCRIPTIONS.length}`);
  
  if (topicsFailed === 0 && subscriptionsFailed === 0) {
    logSuccess('All Pub/Sub resources created successfully!');
  } else {
    logWarning('Some resources failed to create. Check the logs above.');
  }
  
  // List final state
  logHeader('Final State');
  await listTopics();
  await listSubscriptions();
  
  logInfo('');
  logInfo('Pub/Sub setup complete! The orchestrator service should now work properly.');
  logInfo('You can restart the orchestrator service to test the connection.');
}

// Handle errors
process.on('unhandledRejection', (reason, promise) => {
  logError(`Unhandled Rejection at: ${promise}, reason: ${reason}`);
  process.exit(1);
});

// Run setup
setupPubSub().catch(error => {
  logError(`Setup failed: ${error.message}`);
  process.exit(1);
});

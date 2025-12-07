#!/usr/bin/env node

/**
 * Verify Emulator Configuration for All Services
 * This script checks that all services are properly configured to use the Pub/Sub emulator
 */

const fs = require('fs');
const path = require('path');

// Configuration
const SERVICES_DIR = path.join(__dirname, '../../services');
const EMULATOR_HOST = 'localhost:8085';

// Files to check for PubSub configuration
const FILES_TO_CHECK = [
  'orchestrator-service/pubsub-handler.js',
  'orchestrator-service/index.js',
  'category-extraction-service/index.js',
  'product-extraction-service/index.js',
  'libs/shared/interfaces/cloudProvider.js'
];

// Patterns to look for
const PATTERNS = {
  PUBSUB_EMULATOR_HOST: /PUBSUB_EMULATOR_HOST.*localhost:8085/,
  EMULATOR_DETECTION: /isEmulator.*FUNCTIONS_EMULATOR.*true/,
  EMULATOR_CONFIG: /localhost:8085/
};

function checkFile(filePath) {
  const fullPath = path.join(SERVICES_DIR, filePath);
  
  if (!fs.existsSync(fullPath)) {
    return { exists: false, path: filePath };
  }
  
  const content = fs.readFileSync(fullPath, 'utf8');
  
  const results = {
    exists: true,
    path: filePath,
    hasEmulatorHost: PATTERNS.PUBSUB_EMULATOR_HOST.test(content),
    hasEmulatorDetection: PATTERNS.EMULATOR_DETECTION.test(content),
    hasEmulatorConfig: PATTERNS.EMULATOR_CONFIG.test(content),
    issues: []
  };
  
  // Check for issues
  if (!results.hasEmulatorHost && !results.hasEmulatorDetection) {
    results.issues.push('No emulator configuration found');
  }
  
  if (content.includes('new PubSub()') && !results.hasEmulatorDetection) {
    results.issues.push('Direct PubSub initialization without emulator detection');
  }
  
  return results;
}

function main() {
  console.log('🔍 Verifying Emulator Configuration for All Services');
  console.log('==================================================');
  console.log(`ℹ️  Services directory: ${SERVICES_DIR}`);
  console.log(`ℹ️  Expected emulator host: ${EMULATOR_HOST}`);
  console.log('');

  let totalFiles = 0;
  let configuredFiles = 0;
  let issuesFound = 0;

  for (const filePath of FILES_TO_CHECK) {
    const result = checkFile(filePath);
    totalFiles++;
    
    console.log(`📁 ${filePath}:`);
    
    if (!result.exists) {
      console.log(`   ❌ File not found`);
      issuesFound++;
      continue;
    }
    
    if (result.issues.length === 0) {
      console.log(`   ✅ Properly configured for emulator`);
      configuredFiles++;
    } else {
      console.log(`   ⚠️  Issues found:`);
      result.issues.forEach(issue => {
        console.log(`      - ${issue}`);
      });
      issuesFound++;
    }
    
    console.log(`   📊 Emulator Host: ${result.hasEmulatorHost ? '✅' : '❌'}`);
    console.log(`   📊 Emulator Detection: ${result.hasEmulatorDetection ? '✅' : '❌'}`);
    console.log(`   📊 Emulator Config: ${result.hasEmulatorConfig ? '✅' : '❌'}`);
    console.log('');
  }

  console.log('📊 Summary:');
  console.log(`   Total files checked: ${totalFiles}`);
  console.log(`   Properly configured: ${configuredFiles}`);
  console.log(`   Issues found: ${issuesFound}`);
  console.log('');

  if (issuesFound === 0) {
    console.log('✅ All services are properly configured for the Pub/Sub emulator!');
    console.log('🚀 You can now restart your services and they should work with the emulator.');
  } else {
    console.log('⚠️  Some services need configuration updates.');
    console.log('🔧 Please fix the issues above before restarting your services.');
  }
}

// Run the verification
main();

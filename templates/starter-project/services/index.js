/**
 * Firebase Functions Entry Point
 *
 * This file exports all functions from all services.
 * Each export becomes a Cloud Function when deployed.
 *
 * IMPORTANT: You must export every function you want to deploy!
 */

// =============================================================================
// API Service - HTTP endpoints
// =============================================================================
const myApiService = require('./my-api-service/index.js');

// Public endpoints
exports.hello = myApiService.hello;
exports.health = myApiService.health;
exports.getItems = myApiService.getItems;
exports.createItem = myApiService.createItem;

// =============================================================================
// Add more services here as you create them
// =============================================================================

// Example: Auth Service
// const authService = require('./auth-service/index.js');
// exports.login = authService.login;
// exports.logout = authService.logout;

// Example: Background Jobs (Pub/Sub)
// const jobsService = require('./jobs-service/index.js');
// exports.processJob = jobsService.processJob;

// Example: Scheduled Tasks
// const scheduledService = require('./scheduled-service/index.js');
// exports.dailyReport = scheduledService.dailyReport;

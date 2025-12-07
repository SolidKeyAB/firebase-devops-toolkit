# Pub/Sub Management for Firebase Emulator

This directory contains scripts to manage Pub/Sub topics and subscriptions in the Firebase emulator environment.

## Overview

The Firebase emulator includes a Pub/Sub emulator that runs on port 8085. These scripts help you set up, test, and manage the required Pub/Sub resources for the orchestrator service and other microservices.

## Scripts

### 1. `setup-pubsub-topics.sh` (Shell Script)
- **Purpose**: Creates all required Pub/Sub topics and subscriptions
- **Usage**: `./setup-pubsub-topics.sh`
- **What it does**:
  - Creates topics: `orchestrator-topic`, `category-extraction-topic`, `product-extraction-topic`, etc.
  - Creates corresponding subscriptions for each topic
  - Verifies the setup was successful

### 2. `setup-pubsub-topics.js` (Node.js Script)
- **Purpose**: Same as the shell script, but more reliable and cross-platform
- **Usage**: `node setup-pubsub-topics.js`
- **What it does**:
  - Creates all required topics and subscriptions
  - Provides detailed logging and error handling
  - Lists existing resources after setup

### 3. `test-pubsub-connection.js` (Node.js Script)
- **Purpose**: Tests that the Pub/Sub setup is working correctly
- **Usage**: `node test-pubsub-connection.js`
- **What it does**:
  - Lists all available topics
  - Tests publishing a message to `orchestrator-topic`
  - Tests subscribing to receive the message
  - Verifies end-to-end functionality

### 4. `cleanup-pubsub-topics.js` (Node.js Script)
- **Purpose**: Removes all Pub/Sub topics and subscriptions (use with caution)
- **Usage**: `node cleanup-pubsub-topics.js`
- **What it does**:
  - Lists existing resources
  - Asks for confirmation before deletion
  - Deletes subscriptions first, then topics
  - Provides detailed logging of the cleanup process

## Required Topics

The following topics are created by the setup scripts:

| Topic Name | Purpose |
|------------|---------|
| `orchestrator-topic` | Main orchestrator service communication |
| `category-extraction-topic` | Category extraction service |
| `product-extraction-topic` | Product extraction service |
| `product-enrichment-topic` | Product enrichment service |
| `sustainability-enrichment-topic` | Sustainability enrichment service |
| `ai-logging-topic` | AI logging service |

Each topic has a corresponding subscription with the same name plus `-subscription` suffix.

## Environment Variables

The scripts automatically set the following environment variable:
- `PUBSUB_EMULATOR_HOST=localhost:8085`

This ensures the scripts connect to the Firebase emulator instead of production Pub/Sub.

## Prerequisites

1. **Firebase Emulator Running**: Make sure the Firebase emulator is started with Pub/Sub support:
   ```bash
   firebase emulators:start --only functions,firestore,pubsub,ui
   ```

2. **Node.js Dependencies**: The Node.js scripts require the `@google-cloud/pubsub` package:
   ```bash
   npm install @google-cloud/pubsub
   ```

3. **Project Configuration**: The scripts use the project ID from `FIREBASE_PROJECT_ID` environment variable or default to `your-project-id`.

## Common Issues and Solutions

### Topic Not Found Error
If you see `Error: 5 NOT_FOUND: Topic not found`, run the setup script:
```bash
node setup-pubsub-topics.js
```

### Connection Refused
If you see connection errors, ensure the Firebase emulator is running:
```bash
firebase emulators:start --only functions,firestore,pubsub,ui
```

### Permission Denied
Make sure the shell scripts are executable:
```bash
chmod +x *.sh
```

## Workflow

1. **Start Firebase Emulator**: Start the emulator with Pub/Sub support
2. **Setup Topics**: Run `node setup-pubsub-topics.js` to create required resources
3. **Test Connection**: Run `node test-pubsub-connection.js` to verify setup
4. **Use Services**: Your microservices should now work with Pub/Sub
5. **Cleanup (Optional)**: Use `node cleanup-pubsub-topics.js` if you need to reset

## Integration with Orchestrator Service

The orchestrator service expects these topics to exist. After running the setup script, the service should be able to:

- Publish messages to `orchestrator-topic`
- Subscribe to various service topics
- Handle the pipeline workflow through Pub/Sub messaging

## Troubleshooting

- **Check Emulator Status**: Visit `http://localhost:4000` to see the Firebase emulator UI
- **Check Logs**: Look for Pub/Sub emulator logs in the terminal where you started the emulator
- **Verify Ports**: Ensure port 8085 is not blocked or used by another service
- **Restart Emulator**: Sometimes restarting the emulator helps resolve connection issues

## Notes

- These scripts are designed for local development with the Firebase emulator
- For production, you would need to create these topics in Google Cloud Pub/Sub
- The emulator data is ephemeral and will be lost when the emulator is stopped
- Always test your setup with the test script before running your services

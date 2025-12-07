# Required Project Structure

This document describes the project structure required for Firebase DevOps Toolkit to work correctly.

## Overview

The toolkit expects a **microservices architecture** where:
- Each service is a separate directory
- A root `index.js` exports all functions from all services
- Firebase Functions are exported using the standard pattern

---

## Directory Structure

```
your-project/
├── services/                          # Main services directory
│   ├── index.js                       # ROOT EXPORTS (critical!)
│   ├── package.json                   # Dependencies
│   ├── firebase.json                  # Firebase configuration
│   ├── essential-services.txt         # Services to deploy (optional)
│   │
│   ├── shared/                        # Shared utilities (optional)
│   │   └── libs/
│   │       ├── firebaseAdmin.js
│   │       └── ...
│   │
│   ├── public-api-service/            # Example service
│   │   └── index.js                   # Service exports
│   │
│   ├── auth-service/                  # Another service
│   │   └── index.js
│   │
│   └── {service-name}/                # Pattern: service directories
│       └── index.js
│
├── scripts/                           # Project scripts (optional)
│   └── orchestrate.sh                 # Your project wrapper
│
└── docs/                              # Documentation (optional)
```

---

## Critical Files

### 1. Root `index.js` (Required)

This file **must export all functions** from all services. Firebase Functions discovers what to deploy by reading this file.

```javascript
// services/index.js

/**
 * Root Firebase Functions Entry Point
 * Exports all service functions for deployment
 */

// Import and re-export from each service
const publicApiService = require('./public-api-service/index.js');
exports.getProducts = publicApiService.getProducts;
exports.getProduct = publicApiService.getProduct;
exports.health = publicApiService.health;

const authService = require('./auth-service/index.js');
exports.login = authService.login;
exports.logout = authService.logout;

const orderService = require('./order-service/index.js');
exports.createOrder = orderService.createOrder;
exports.processOrder = orderService.processOrder;  // Pub/Sub function
```

**Why this pattern?**
- Firebase Functions scans `exports.*` to discover functions
- The toolkit parses this file to build deployment lists
- Each function name becomes the Cloud Function name

---

### 2. Service `index.js` (Required per service)

Each service directory must have an `index.js` that exports its functions:

```javascript
// services/public-api-service/index.js

const { onRequest } = require('firebase-functions/v2/https');

// HTTP endpoint
exports.getProducts = onRequest({
  region: 'europe-west1',
  cors: true
}, async (req, res) => {
  // Implementation
  res.json({ products: [] });
});

// Another HTTP endpoint
exports.health = onRequest({
  region: 'europe-west1'
}, (req, res) => {
  res.json({ status: 'healthy' });
});
```

**For Pub/Sub functions:**

```javascript
// services/order-service/index.js

const { onMessagePublished } = require('firebase-functions/v2/pubsub');

exports.processOrder = onMessagePublished({
  topic: 'order-topic',
  region: 'europe-west1'
}, async (event) => {
  const data = JSON.parse(Buffer.from(event.data.message.data, 'base64').toString());
  // Process order
});
```

---

### 3. `package.json` (Required)

Must include Firebase dependencies:

```json
{
  "name": "your-project-services",
  "main": "index.js",
  "engines": {
    "node": "18"
  },
  "dependencies": {
    "firebase-functions": "^4.0.0",
    "firebase-admin": "^11.0.0"
  }
}
```

---

### 4. `firebase.json` (Required)

Configure Firebase Functions:

```json
{
  "functions": {
    "source": ".",
    "runtime": "nodejs18",
    "codebase": "default"
  }
}
```

---

### 5. `essential-services.txt` (Optional)

List services to deploy (one per line). Used by selective deployment:

```
# Core services
public-api-service
auth-service

# Processing services
order-service
notification-service

# Admin
admin-service
```

---

## Export Patterns

### HTTP Endpoints (v2)

```javascript
const { onRequest } = require('firebase-functions/v2/https');

exports.myEndpoint = onRequest({
  region: 'europe-west1',
  cors: true,
  memory: '256MiB',
  timeoutSeconds: 60
}, async (req, res) => {
  res.json({ success: true });
});
```

### Pub/Sub Functions (v2)

```javascript
const { onMessagePublished } = require('firebase-functions/v2/pubsub');

exports.processMessage = onMessagePublished({
  topic: 'my-topic',
  region: 'europe-west1'
}, async (event) => {
  const data = JSON.parse(Buffer.from(event.data.message.data, 'base64').toString());
  console.log('Received:', data);
});
```

### Firestore Triggers (v2)

```javascript
const { onDocumentCreated } = require('firebase-functions/v2/firestore');

exports.onUserCreated = onDocumentCreated({
  document: 'users/{userId}',
  region: 'europe-west1'
}, async (event) => {
  const userData = event.data.data();
  console.log('New user:', userData);
});
```

### Scheduled Functions (v2)

```javascript
const { onSchedule } = require('firebase-functions/v2/scheduler');

exports.dailyCleanup = onSchedule({
  schedule: '0 0 * * *',
  region: 'europe-west1',
  timeZone: 'Europe/Stockholm'
}, async (event) => {
  console.log('Running daily cleanup');
});
```

---

## Shared Libraries

For code shared across services, create a `shared/` directory:

```
services/
├── shared/
│   └── libs/
│       ├── firebaseAdmin.js     # Firebase Admin SDK singleton
│       ├── logger.js            # Logging utilities
│       └── validation.js        # Input validation
│
└── my-service/
    └── index.js                 # Uses: require('../shared/libs/logger')
```

Example shared module:

```javascript
// services/shared/libs/firebaseAdmin.js
const admin = require('firebase-admin');

if (!admin.apps.length) {
  admin.initializeApp();
}

exports.getFirestore = () => admin.firestore();
exports.getAuth = () => admin.auth();
```

---

## Function Naming Convention

The toolkit uses function names from exports:

| Export Name | Cloud Function Name | URL Path |
|-------------|---------------------|----------|
| `exports.getProducts` | `getProducts` | `/getProducts` |
| `exports.health` | `health` | `/health` |
| `exports.processOrder` | `processOrder` | (Pub/Sub, no URL) |

**Best practices:**
- Use camelCase for function names
- Use descriptive names: `getUserById` not `get`
- Prefix by domain: `orderCreate`, `orderProcess`, `orderCancel`

---

## Toolkit Detection

The toolkit automatically detects your project structure by looking for:

1. `services/index.js` - Root exports
2. `services/package.json` - Node.js project
3. `services/firebase.json` - Firebase configuration

If these exist, deployment commands will work:

```bash
./manage.sh deploy-local           # Deploy to emulator
./manage.sh deploy-production      # Deploy to Firebase
./manage.sh deploy-function --function getProducts  # Single function
```

---

## Example Project

See the template in `templates/orchestrate.sh` for a complete working example.

For a full reference implementation, check out the project structure documentation.

---

## Common Issues

### "No functions found"

**Cause:** Root `index.js` doesn't export any functions.

**Fix:** Ensure all functions are exported:
```javascript
// services/index.js
const myService = require('./my-service/index.js');
exports.myFunction = myService.myFunction;  // Must export!
```

### "Function not in source"

**Cause:** Function exists in Firebase but not in your exports.

**Fix:** Either add the export or delete the function:
```bash
firebase functions:delete oldFunction --project PROJECT_ID
```

### "Cannot find module './my-service'"

**Cause:** Service directory or index.js missing.

**Fix:** Ensure structure:
```
services/
├── my-service/
│   └── index.js    # Must exist!
└── index.js        # Must require('./my-service/index.js')
```

---

*Documentation by [SolidKey AB](https://solidkey.se)*

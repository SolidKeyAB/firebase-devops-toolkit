# Firestore Triggers Guide

## Overview

This guide covers implementing Firestore triggers in Firebase to create event-driven workflows without exposing public endpoints.

---

## Architecture Overview

### How It Works:
```
External Request → Firestore Update → Trigger Function → Internal Service Call
```

### Trigger Types:
1. **Document Creation Trigger** - Automatically processes new documents
2. **Control Document Trigger** - Manually triggers workflows
3. **Individual Service Triggers** - Triggers specific services

---

## Implementation Examples

### 1. Basic Document Trigger
```javascript
// Firebase Function triggered on document creation
exports.onDocumentCreate = functions.firestore
  .document('collection/{docId}')
  .onCreate(async (snap, context) => {
    const data = snap.data();

    // Process the document
    console.log('Processing new document:', data);

    // Call other internal functions
    await processDocument(data);
  });
```

### 2. Control Collection Pattern
```javascript
// Add to Firestore to trigger workflow
await db.collection('control').doc('workflow-trigger').set({
  user_id: 'user-123',
  parameters: {
    max_items: 5,
    process_type: 'comprehensive'
  },
  created_at: new Date().toISOString(),
  status: 'pending'
});
```

### 3. Individual Service Trigger
```javascript
// Trigger specific service
await db.collection('tasks').add({
  service: 'dataProcessing',
  input: {
    item_id: 'item-123',
    user_id: 'user-123'
  },
  created_at: new Date().toISOString(),
  status: 'pending'
});
```

---

## Security Benefits

### Why This Approach is Secure:
- ✅ **No public HTTP endpoints** - Functions triggered internally
- ✅ **Firestore security rules** - Control access to trigger documents
- ✅ **Internal authentication** - Uses Firebase Admin SDK
- ✅ **Audit trail** - All triggers logged in Firestore
- ✅ **Proper error handling** - Failed triggers don't break the system

### Firestore Security Rules:
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Only authenticated users can create control documents
    match /control/{document} {
      allow create: if request.auth != null;
      allow read: if request.auth != null;
    }

    // Tasks can be created by authenticated users
    match /tasks/{taskId} {
      allow create: if request.auth != null;
      allow read: if request.auth != null;
    }
  }
}
```

---

## Monitoring and Debugging

### Check Trigger Execution:
1. **Firebase Console** → Functions → Logs
2. **Firestore Console** → Data → Check document updates
3. **Function Logs** → Real-time execution logs

### Debug Triggers:
```bash
# View function logs
firebase functions:log --only onDocumentCreate

# Check Firestore data
firebase firestore:get /control/workflow-trigger
```

---

## Best Practices

### 1. Control Document Structure:
```javascript
{
  user_id: 'user-123',
  parameters: {
    max_items: 5,
    process_type: 'standard'
  },
  created_at: '2025-01-27T10:00:00Z',
  status: 'pending', // pending → processing → completed
  started_at: null,
  completed_at: null,
  error: null
}
```

### 2. Error Handling:
```javascript
// In trigger function
try {
  // Process request
  await processRequest(data);

  // Update status
  await snap.ref.update({
    status: 'completed',
    completed_at: admin.firestore.FieldValue.serverTimestamp()
  });
} catch (error) {
  // Log error and update status
  await snap.ref.update({
    status: 'error',
    error: error.message,
    error_at: admin.firestore.FieldValue.serverTimestamp()
  });
}
```

### 3. Rate Limiting:
```javascript
// Add rate limiting to prevent abuse
const rateLimit = require('express-rate-limit');

const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100 // limit each IP to 100 requests per windowMs
});
```

---

## Deployment

### Deploy Triggers:
```bash
# Deploy all functions including triggers
firebase deploy --only functions --project PROJECT_ID

# Deploy specific trigger
firebase deploy --only functions:onDocumentCreate
```

### Test Triggers:
```bash
# Test Firestore triggers
./remote/test-firestore-triggers.js

# Check deployment status
./remote/test-deployment-status.sh
```

---

## Advantages of This Approach

### Security:
- ✅ **No public endpoints** - All functions triggered internally
- ✅ **Firestore security** - Leverages Firestore security rules
- ✅ **Audit trail** - All actions logged in Firestore
- ✅ **Rate limiting** - Can implement at Firestore level

### Reliability:
- ✅ **Automatic retries** - Firebase handles retry logic
- ✅ **Error handling** - Proper error states in documents
- ✅ **Monitoring** - Built-in Firebase monitoring
- ✅ **Scalability** - Auto-scaling with Firebase

### Development:
- ✅ **Easy testing** - Just update Firestore documents
- ✅ **Local development** - Works with Firebase emulators
- ✅ **Debugging** - Clear logs and status updates
- ✅ **Version control** - All triggers in code

---

## Summary

Firestore triggers provide a secure, scalable way to implement event-driven workflows:

1. **✅ Firestore triggers deployed** - Official Firebase mechanism
2. **✅ Internal function calls** - No external authentication needed
3. **✅ Proper security** - Functions remain secured
4. **✅ Easy testing** - Just update Firestore documents
5. **✅ Production ready** - Scalable and reliable

This approach follows **Google's best practices** and provides a secure, scalable way to trigger internal functions!
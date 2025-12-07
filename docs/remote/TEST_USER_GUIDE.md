# Firebase Test User Guide

## Quick Start with Test User

This guide helps you create and use a test user for Firebase authentication and testing.

### Test User Details:
- **Email:** `test-user@your-domain.com`
- **Password:** `TestPassword123!`
- **Display Name:** `Firebase Test User`
- **Role:** `test_user`
- **Permissions:** Project access for testing

---

## Step-by-Step Testing

### **Step 1: Create Test User**
```bash
# Create test user via Firebase CLI
firebase auth:create-user \
  --email "test-user@your-domain.com" \
  --password "TestPassword123!" \
  --display-name "Firebase Test User"
```

### **Step 2: Manual Authentication (Firebase Console)**
1. **Go to Firebase Console:**
   ```
   https://console.firebase.google.com/project/PROJECT_ID/authentication/users
   ```

2. **Sign in with test user:**
   - Email: `test-user@your-domain.com`
   - Password: `TestPassword123!`

3. **Verify user has proper permissions**

### **Step 3: Add Test Data**
1. **Go to Firestore:**
   ```
   https://console.firebase.google.com/project/PROJECT_ID/firestore
   ```

2. **Add test collection:**
   - Collection ID: `test_data`
   - Add sample documents

#### **Sample Document 1: Test Item**
```
Document ID: item_1
Fields:
- name: "Test Item 1"
- category: "Testing"
- description: "Sample test item"
- status: "active"
```

#### **Sample Document 2: Another Test Item**
```
Document ID: item_2
Fields:
- name: "Test Item 2"
- category: "Testing"
- description: "Another sample item"
- status: "active"
```

### **Step 4: Test Functions with Test User**
```bash
# Run the test script
./remote/test-functions-consolidated.sh
```

---

## Manual Testing Steps

### **1. Test Function Status (No Auth Required)**
```bash
# Check if functions are deployed
firebase functions:list

# Test function accessibility
curl -s -w "Status: %{http_code}\n" "https://REGION-PROJECT_ID.cloudfunctions.net/FUNCTION_NAME"
```

### **2. Test with Authentication**
```bash
# Get access token (if you have gcloud auth)
TOKEN=$(gcloud auth print-access-token)

# Test function with authentication
curl -H "Authorization: Bearer $TOKEN" \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{"param1": "value1", "param2": "value2"}' \
  "https://REGION-PROJECT_ID.cloudfunctions.net/FUNCTION_NAME"
```

### **3. Monitor in Firebase Console**
- **Function Logs:** Check execution logs
- **Firestore:** Monitor processed data
- **Authentication:** Verify user permissions

---

## What the Test User Can Do

### ✅ Permissions:
- **Read Firestore** - Access test data
- **Write Firestore** - Add/update documents
- **Execute Functions** - Call deployed functions
- **Access Services** - Use Firebase services

### ✅ Operations:
- **Add data** to Firestore
- **Trigger functions**
- **Monitor execution**
- **Test workflows**

---

## Troubleshooting

### **If Test User Creation Fails:**
```bash
# Create user manually in Firebase Console
# Go to: Authentication > Users > Add User
# Email: test-user@your-domain.com
# Password: TestPassword123!
```

### **If Authentication Fails:**
```bash
# Check user exists
firebase auth:list --project PROJECT_ID

# Reset password if needed
firebase auth:update-user test-user@your-domain.com --password "TestPassword123!" --project PROJECT_ID
```

### **If Functions Return 403:**
- Functions are secured (this is correct)
- Use proper authentication token
- Check user permissions in Firebase Console

---

## Expected Results

### ✅ Success Indicators:
- **Test user created** in Firebase Auth
- **Test data added** to Firestore
- **Functions return 403** (secured)
- **Functions work** with proper auth
- **System processes** data successfully

### 📊 Monitoring:
- **Function logs** show execution
- **Firestore** contains processed data
- **Authentication** works properly
- **Workflow** completes successfully

---

## Quick Commands

### **Check Status:**
```bash
# Check functions
firebase functions:list

# Check authentication
firebase auth:list --project PROJECT_ID

# Test function access
curl -s -w "Status: %{http_code}\n" "https://REGION-PROJECT_ID.cloudfunctions.net/FUNCTION_NAME"
```

### **Run Tests:**
```bash
# Create test user
firebase auth:create-user --email "test-user@your-domain.com" --password "TestPassword123!"

# Run tests
./remote/test-functions-consolidated.sh

# Run health check
./remote/health-check.sh
```

---

## Production Considerations

### **For Production Use:**
1. **Service Account** - Use service account instead of test user
2. **Proper IAM** - Grant minimal required permissions
3. **Security Rules** - Implement Firestore security rules
4. **Monitoring** - Set up proper logging and alerts
5. **Backup** - Regular data backups

### **Security Best Practices:**
- Use service accounts for automated operations
- Grant minimal required permissions
- Implement proper authentication
- Monitor access logs
- Use Firebase Security Rules

---

## Ready to Test!

With the test user, you can:

1. ✅ **Authenticate** with Firebase
2. ✅ **Add data** to Firestore
3. ✅ **Call functions** securely
4. ✅ **Monitor results** in real-time
5. ✅ **Scale up** for production use

**Your Firebase project is ready for comprehensive testing with the test user!**
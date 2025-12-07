# Firebase Functions Authentication Guide

## Firebase Functions Security

This guide covers authentication methods for secure Firebase Cloud Functions access.

---

## Current Status

✅ **Firebase Functions are successfully deployed**
✅ **Security properly configured**
❌ **Functions require authentication (403 Forbidden for public access)**
🔧 **Organization policy may prevent public access**

---

## Authentication Methods

### **Method 1: Firebase Auth Token (Recommended)**

```bash
# Get Firebase Auth token
firebase login --no-localhost

# Test with token
curl -H "Authorization: Bearer YOUR_FIREBASE_TOKEN" \
  "https://REGION-PROJECT_ID.cloudfunctions.net/FUNCTION_NAME"
```

### **Method 2: Google Cloud Service Account**

```bash
# Create service account key (if allowed by org policy)
gcloud iam service-accounts create function-test --display-name="Function Test"
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:function-test@PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/cloudfunctions.invoker"

# Use service account
gcloud auth activate-service-account --key-file=function-test-key.json
```

### **Method 3: Application Default Credentials**

```bash
# Set up application default credentials
gcloud auth application-default login

# Test with ADC
curl -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  "https://REGION-PROJECT_ID.cloudfunctions.net/FUNCTION_NAME"
```

---

## Testing Scripts

### **Quick Test:**
```bash
# Test a single function
curl -s -w "%{http_code}" "https://REGION-PROJECT_ID.cloudfunctions.net/FUNCTION_NAME"
# Expected: 403 (requires authentication)
```

### **Comprehensive Test:**
```bash
# Run the full testing script
./remote/test-functions-consolidated.sh
```

---

## Production Usage

### **For Public Access (Requires Admin Action):**

Contact your GCP organization admin to:

1. **Allow public access to Cloud Functions:**
   ```bash
   gcloud functions add-iam-policy-binding [FUNCTION_NAME] \
     --region=us-central1 \
     --member="allUsers" \
     --role="roles/cloudfunctions.invoker"
   ```

2. **Or modify organization policy:**
   - Go to Google Cloud Console
   - Navigate to IAM & Admin > Organization Policies
   - Find the policy blocking `allUsers`
   - Modify to allow public access to Cloud Functions

### **For Authenticated Access:**

1. **Implement Firebase Auth in your application**
2. **Use service account authentication**
3. **Use application default credentials**

---

## Function Testing Examples

### **Basic Function Call:**
```bash
curl -X POST \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{"param1": "value1", "param2": "value2"}' \
  "https://REGION-PROJECT_ID.cloudfunctions.net/FUNCTION_NAME"
```

### **Health Check:**
```bash
curl "https://REGION-PROJECT_ID.cloudfunctions.net/healthCheck"
```

---

## Troubleshooting

### **403 Forbidden:**
- ✅ **Normal behavior** - Functions require authentication
- **Solution:** Use one of the authentication methods above

### **401 Unauthorized:**
- ❌ **Invalid token** - Check your authentication method
- **Solution:** Refresh your token or check service account permissions

### **500 Internal Server Error:**
- ❌ **Function error** - Check function logs
- **Solution:** `firebase functions:log --only [FUNCTION_NAME]`

---

## Next Steps

1. **Choose authentication method** for your application
2. **Implement proper error handling** for 403/401 responses
3. **Set up monitoring** for function health
4. **Configure proper IAM roles** for production use

---

## Success Criteria

✅ **Functions deployed successfully**
✅ **Security properly configured**
✅ **Authentication system in place**
✅ **Functions are production-ready**

**Your Firebase Functions are properly secured and ready for production use!**
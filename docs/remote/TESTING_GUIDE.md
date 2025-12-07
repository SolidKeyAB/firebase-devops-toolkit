# Firebase Functions Testing Guide

## Testing Your Firebase Functions

This guide covers different methods to test your Firebase Cloud Functions after deployment.

---

## Quick Status Check

```bash
# Check if functions are deployed
firebase functions:list --project YOUR_PROJECT_ID
```

**Expected Output:**
```
│ functionName        │ version │ trigger │ region      │ memory │ runtime  │
│ yourFunction1       │ v1      │ https   │ us-central1 │ 256MB  │ nodejs18 │
│ yourFunction2       │ v1      │ https   │ us-central1 │ 256MB  │ nodejs18 │
```

---

## Test Security (Functions are Secured)

```bash
# Test that functions require authentication (should return 403)
curl -s -w "Status: %{http_code}\n" "https://REGION-PROJECT_ID.cloudfunctions.net/FUNCTION_NAME"
```

**Expected Output:**
```
Status: 403
```

**This confirms the function is deployed and properly secured!**

---

## Test Health Checks

```bash
# Test your health check endpoint
curl "https://REGION-PROJECT_ID.cloudfunctions.net/healthCheck"
```

**Expected Output:**
```
{"status":"healthy","timestamp":"2025-01-27T...","project":"PROJECT_ID"}
```

---

## Individual Function Tests

### Test a Function:
```bash
curl -s -w "Status: %{http_code}\n" "https://REGION-PROJECT_ID.cloudfunctions.net/FUNCTION_NAME"
```

### Test Multiple Functions:
```bash
# Test multiple functions at once
for func in function1 function2 function3; do
    echo "Testing $func..."
    curl -s -w "Status: %{http_code}\n" "https://REGION-PROJECT_ID.cloudfunctions.net/$func"
done
```

---

## Test with Authentication

### Using Firebase Auth:
```bash
# Get Firebase token
firebase login --no-localhost

# Test with authentication
curl -H "Authorization: Bearer YOUR_FIREBASE_TOKEN" \
  "https://REGION-PROJECT_ID.cloudfunctions.net/FUNCTION_NAME"
```

### Using Google Cloud Token:
```bash
# Get Google Cloud token
TOKEN=$(gcloud auth print-access-token)

# Test with token
curl -H "Authorization: Bearer $TOKEN" \
  "https://REGION-PROJECT_ID.cloudfunctions.net/FUNCTION_NAME"
```

---

## Run Test Scripts

### Quick Test:
```bash
./remote/quick-test.sh
```

### Comprehensive Testing:
```bash
./remote/test-functions-consolidated.sh
```

### Health Check:
```bash
./remote/health-check.sh
```

---

## Understanding Test Results

### ✅ 403 Forbidden = SUCCESS
- Function is deployed and working
- Security is properly configured
- Authentication is required (as expected)

### ✅ 200 OK = SUCCESS
- Function is deployed and publicly accessible
- No authentication required

### ❌ 404 Not Found = ERROR
- Function is not deployed
- Check deployment status

### ❌ 000 Connection Error = ERROR
- Network connectivity issue
- Check internet connection

---

## Test Checklist

- [ ] **Firebase Functions List** - All functions deployed
- [ ] **Security Test** - Functions return appropriate status codes
- [ ] **Health Check** - Health endpoints working
- [ ] **Individual Tests** - Each function responds correctly
- [ ] **Authentication Test** - Functions work with proper auth

---

## Production Readiness Confirmation

### ✅ Deployment Status:
- All functions deployed successfully
- All health checks working
- No deployment errors

### ✅ Security Status:
- Functions properly secured
- Authentication configured correctly
- No unauthorized access

### ✅ System Status:
- Complete workflow available
- All components operational
- Ready for production use

---

## Next Steps After Testing

1. **Choose authentication method** for your application
2. **Implement proper error handling** for 403/401 responses
3. **Set up monitoring** for function health
4. **Configure IAM roles** for production use
5. **Set up alerts** for function failures

---

## Success Criteria

✅ **All functions deployed**
✅ **Security working correctly**
✅ **Health checks operational**
✅ **System ready for production**
✅ **Testing tools available**

**Your Firebase Functions are ready for production use!**
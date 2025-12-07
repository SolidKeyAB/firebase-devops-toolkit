# Deployment Quick Reference

## 🚀 One-Command Deployment

```bash
# Prepare and get deployment directory (using absolute paths)
/full/path/to/firebase-scripts/manage.sh prepare-deploy \
  --project-dir /full/path/to/esg_microservices_platform \
  --services-dir services \
  --project your-project-id \
  --public-api-only

# Deploy (use the directory path from above)
/full/path/to/firebase-scripts/manage.sh deploy-from \
  --dir /tmp/firebase-deployment-XXXXXX \
  --project your-project-id
```

## 📋 Quick Commands

### Prepare Clean Deployment
```bash
/full/path/to/firebase-scripts/manage.sh prepare-deploy --project-dir /full/path/to/esg_microservices_platform --services-dir services --project your-project-id --public-api-only
```

### Deploy from Directory  
```bash
/full/path/to/firebase-scripts/manage.sh deploy-from --dir /tmp/firebase-deployment-XXXXXX --project your-project-id
```

### Check Deployment Size
```bash
du -sh /tmp/firebase-deployment-XXXXXX  # Should be ~1.2MB
```

### List Functions
```bash
firebase functions:list --project your-project-id
```

### Test Health
```bash
curl https://europe-west1-your-project-id.cloudfunctions.net/publicApiHealth
```

### Delete Function (for redeployment)
```bash
firebase functions:delete FUNCTION_NAME --project your-project-id --force
```

## ⚠️ Manual Steps Required (Organization Policy)

**Deployment will show IAM errors - this is expected!** 

Organization policies prevent automated permission setting. You must manually set permissions in [Google Cloud Console](https://console.cloud.google.com/):

1. **Cloud Run** → **your-project-id** 
2. Click each function: `queryproductscores`, `querybrandscores`, `searchscores`, `publicapihealth`
3. **Security** → **Add Principal** → `allUsers` → **Cloud Run Invoker**

**Test after setting permissions**:
```bash
curl https://europe-west1-your-project-id.cloudfunctions.net/publicApiHealth
```

## ✅ Success Indicators

- ✅ Deployment size ~1.2MB (not 150MB+)
- ✅ Only 4 functions deployed
- ✅ Health endpoint returns 200 OK
- ✅ No `node_modules` in deployment directory
- ✅ Firebase Admin logs show "your-project-id project"

## 🔧 Troubleshooting

| Issue | Solution |
|-------|----------|
| Large deployment (150MB+) | Use `--public-api-only` flag |
| 403 Forbidden | Set function permissions in Cloud Console |
| No changes detected | Delete function first, then redeploy |
| Auth errors | Check Firebase project ID consistency |

---

*For detailed workflow, see `/docs/DEPLOYMENT_WORKFLOW.md`*

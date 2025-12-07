# 🧪 Testing Guide for Emulator Sharing

Complete testing instructions for all security levels, including mobile access.

## 📱 **Mobile Access - YES!**

All sharing methods work perfectly on mobile devices:
- ✅ **iPhone/Android browsers** - Full compatibility
- ✅ **Mobile Safari/Chrome** - Native support
- ✅ **Tablet devices** - Works great for demos
- ✅ **Cross-platform** - Any device with internet

## 🚀 **Quick Test Setup**

### **1. Install and Setup (One-time)**
```bash
# Install prerequisites
brew install ngrok jq

# Setup global aliases
cd /path/to/firebase-devops-toolkit
./install-global-alias.sh
source ~/.zshrc  # or ~/.bashrc

# Verify installation
ai-share-emulators --help
```

### **2. Start Your Emulators**
```bash
# Make sure your Firebase emulators are running
firebase emulators:start --only functions,firestore,auth,ui

# Or in your case (already running):
# Frontend: http://localhost:9002
# Emulator UI: http://localhost:4002
```

## 🧪 **Test Scenarios**

### **Test 1: Basic Sharing (No Protection)**
```bash
# Start basic sharing
share-emulators start

# Expected output:
📱 Public URLs:
🎛️  Emulator UI: https://abc123.ngrok.io
🌐 Frontend: https://def456.ngrok.io

# Test on mobile:
# 1. Copy URL to your phone
# 2. Should work immediately - no password
# 3. Try rapid clicking - no rate limiting
```

### **Test 2: Secure Sharing (Password Protected)**
```bash
# Start secure sharing with 30min timeout
secure-share-emulators start --timeout 1800

# Expected output:
🔒 Security Settings:
🔑 Auth credentials: demo:a1b2c3d4e5f6...

📱 Secure Public URLs:
🎛️  Emulator UI: https://xyz789.ngrok.io

# Test on mobile:
# 1. Open URL on phone
# 2. Browser will prompt for username/password
# 3. Enter: demo / a1b2c3d4e5f6... (the generated token)
# 4. Should access normally after auth
```

### **Test 3: AI-Protected Sharing (Full Defense)**
```bash
# Start AI protection with strict limits
ai-share-emulators start --rate-limit 5 --max-requests 25

# Expected output:
🤖 AI Protection Settings:
⏱️  Rate limit: 1 request per 5 seconds
📊 Max requests: 25 per session
🛡️  Protections: Bot detection, User-agent filtering, Rate limiting

# Test on mobile:
# 1. Normal access should work fine
# 2. Try rapid navigation - should be rate limited
# 3. Should see "Access temporarily restricted" if too fast
```

## 📱 **Mobile Testing Steps**

### **Step 1: Start Sharing**
```bash
# From your current studio project directory
ai-share-emulators start --timeout 3600
```

### **Step 2: Get URLs**
```bash
# Check status and get URLs
ai-share-emulators status

# Copy the URLs that look like:
# 🎛️  Emulator UI: https://abc123.ngrok.io (AI Protected)
# 🌐 Frontend: https://def456.ngrok.io (AI Protected)
```

### **Step 3: Test on Mobile**
1. **Open browser** on your phone
2. **Paste the URL** (e.g., https://abc123.ngrok.io)
3. **Enter credentials** if prompted (demo:token)
4. **Navigate normally** - should work fine
5. **Try rapid clicks** - should see rate limiting in action

### **Step 4: Test AI Protection**
```bash
# Test with automation (should be blocked)
curl https://your-ngrok-url.ngrok.io

# Expected response:
# HTTP 429 - Too Many Requests
# "Access temporarily restricted: Suspicious user agent detected"
```

## 🔍 **What to Look For**

### **✅ Working Correctly:**
- Mobile browser loads the page normally
- Authentication prompts work on mobile
- Rate limiting shows "Please wait" messages
- Bot requests get 429 errors

### **❌ Issues to Check:**
- URLs not accessible → Check if emulators are running
- Authentication fails → Verify you're using the exact token shown
- Rate limiting too strict → Adjust `--rate-limit` value
- Mobile doesn't load → Check mobile network/firewall

## 📊 **Testing Different Security Levels**

| Test | Command | Mobile Access | Rate Limit | Auth Required |
|------|---------|---------------|------------|---------------|
| **Basic** | `share-emulators start` | ✅ Instant | ❌ None | ❌ No |
| **Secure** | `secure-share-emulators start` | ✅ With password | ❌ None | ✅ Yes |
| **AI Protected** | `ai-share-emulators start` | ✅ With rate limits | ✅ 1/10sec | ✅ Optional |

## 🤖 **Testing AI Protection Features**

### **Test Bot Detection:**
```bash
# These should be blocked:
curl -H "User-Agent: bot/1.0" https://your-url.ngrok.io
curl -H "User-Agent: selenium" https://your-url.ngrok.io
wget https://your-url.ngrok.io

# Should return 429 with protection message
```

### **Test Rate Limiting:**
```bash
# Rapid requests (should be blocked after first)
for i in {1..5}; do
  curl https://your-url.ngrok.io &
done

# Only first request should succeed
```

### **Test Normal Browser (should work):**
```bash
# Open in regular browser - should work fine
open https://your-url.ngrok.io
```

## 📱 **Mobile Demo Workflow**

Perfect for client presentations:

```bash
# 1. Start protected sharing
ai-share-emulators start --timeout 1800 --services ui,frontend

# 2. Share URL with client via text/email
# Example: "Demo available at: https://abc123.ngrok.io"
# "Use demo:a1b2c3d4 to login"

# 3. Client opens on their phone/tablet
# 4. They can navigate your app naturally
# 5. AI protection prevents abuse/scraping

# 6. Stop when done
ai-share-emulators stop
```

## 🛠 **Troubleshooting**

### **Mobile Can't Access:**
- Check if URL is HTTPS (ngrok provides this automatically)
- Verify mobile is on internet (not just local WiFi)
- Try different mobile browser

### **Rate Limiting Too Strict:**
```bash
# Increase rate limit for smoother mobile experience
ai-share-emulators start --rate-limit 15  # 1 request per 15 seconds
```

### **Authentication Issues:**
- Make sure you're copying the exact token (including case)
- Username is always "demo"
- Try typing instead of copy/paste on mobile

### **Check Status Anytime:**
```bash
ai-share-emulators status
# Shows current security settings and URLs
```

## 🎯 **Recommended Settings for Different Use Cases**

### **Client Demo on Mobile:**
```bash
ai-share-emulators start --timeout 1800 --rate-limit 8 --services ui,frontend
```

### **Team Testing:**
```bash
ai-share-emulators start --no-auth --rate-limit 12 --max-requests 200
```

### **Public Demo (High Security):**
```bash
ai-share-emulators start --rate-limit 5 --max-requests 30 --timeout 900
```

Your mobile phone will work perfectly for testing and demos! The AI protection ensures security while maintaining a smooth user experience.
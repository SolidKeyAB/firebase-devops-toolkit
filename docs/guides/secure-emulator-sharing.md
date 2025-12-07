# 🔒 Secure Firebase Emulator Sharing

Enhanced security features for safely sharing Firebase emulators with team members and clients.

## 🛡️ Security Features

- ✅ **Session Timeouts** - Auto-expire sharing sessions (default: 1 hour)
- ✅ **HTTP Basic Auth** - Password protection for sensitive UIs
- ✅ **Service Filtering** - Only share approved services
- ✅ **Secure Tokens** - Generated authentication credentials
- ✅ **Region Control** - Specify ngrok regions
- ✅ **Session Management** - Proper cleanup and monitoring
- ✅ **Security Warnings** - Clear alerts about exposure risks

## 📋 Quick Setup

```bash
# 1. Install prerequisites
brew install ngrok jq

# 2. Install both basic and secure aliases
cd /path/to/firebase-devops-toolkit
./install-global-alias.sh
source ~/.zshrc
```

## 🚀 Usage Examples

### **Secure Demo (Recommended)**
```bash
# Start with password protection and 30min timeout
secure-share-emulators start --timeout 1800

# Output:
🔒 Security Settings:
🕐 Session expires: 2024-01-15T15:30:00Z
🔐 Auth required: true
🔑 Auth credentials: demo:a1b2c3d4e5f6...

📱 Secure Public URLs:
🎛️  Emulator UI: https://abc123.ngrok.io (password protected)
🌐 Frontend: https://def456.ngrok.io (password protected)
```

### **Client Presentation**
```bash
# Limited services, longer timeout, with auth
secure-share-emulators start --timeout 7200 --services ui,frontend
```

### **Internal Team Testing**
```bash
# No auth for trusted team, short timeout
secure-share-emulators start --no-auth --timeout 900 --services ui,functions,frontend
```

### **Quick Demo (No Security)**
```bash
# Basic sharing (not recommended for production data)
share-emulators start
```

## 🔧 Command Reference

### **Secure Commands**
```bash
secure-share-emulators start [options]     # Start secure sharing
secure-share-emulators stop                # Stop sharing
secure-share-emulators status              # Check status + security info
secure-share-emulators urls                # Show URLs + credentials
secure-share-emulators restart [options]   # Restart with new settings
```

### **Security Options**
- `--timeout SECONDS` - Session timeout (default: 3600 = 1 hour)
- `--no-auth` - Disable password protection
- `--services LIST` - Comma-separated services (ui,functions,frontend,firestore,auth,hosting)

### **Example Configurations**

| Use Case | Command | Security Level |
|----------|---------|----------------|
| **Client Demo** | `--timeout 1800 --services ui,frontend` | High |
| **Team Testing** | `--timeout 3600 --services ui,functions,frontend` | Medium |
| **Internal Dev** | `--no-auth --timeout 900` | Low |
| **Quick Test** | `--timeout 300 --services ui` | High |

## 🛡️ Security Best Practices

### **DO:**
- ✅ Use password protection for client demos
- ✅ Set short timeouts (15-30 minutes)
- ✅ Limit services to only what's needed
- ✅ Stop sharing immediately after demos
- ✅ Monitor active sessions with `status`
- ✅ Use secure networks when sharing

### **DON'T:**
- ❌ Share URLs in public channels
- ❌ Leave sessions running overnight
- ❌ Use `--no-auth` with production data
- ❌ Share all services unless necessary
- ❌ Forget to check session expiry

## 🔍 Security Monitoring

### **Check Active Sessions**
```bash
secure-share-emulators status
```

### **Session Information**
```
✅ Secure emulator sharing is active (2 tunnels)

🔒 Security Settings:
🕐 Session expires: 2024-01-15T15:30:00Z
🔐 Auth required: true
📋 Allowed services: ui,frontend
🔑 Auth credentials: demo:a1b2c3d4e5f6...

📱 Secure Public URLs:
🎛️  Emulator UI: https://abc123.ngrok.io
🌐 Frontend: https://def456.ngrok.io

⚠️  SECURITY WARNING:
• These URLs expose your local emulators publicly
• Only share with trusted developers
• Stop sharing when demo/testing is complete
• Sessions auto-expire for security
```

## 🚨 Security Warnings

The system provides multiple security warnings:

1. **Session Expiry**: Automatic timeout enforcement
2. **Public Exposure**: Clear warnings about internet accessibility
3. **Service Filtering**: Only approved services are exposed
4. **Auth Requirements**: Password protection for sensitive UIs

## 🔒 Authentication Details

When auth is enabled:
- **Username**: `demo`
- **Password**: Auto-generated secure token
- **Browser Prompt**: Standard HTTP Basic Auth dialog
- **Credential Display**: Shown in terminal for easy sharing

## 📁 Generated Files

```
firebase-devops-toolkit/
├── .emulator-sharing/
│   ├── security_config.json   # Session settings
│   ├── auth_tokens.txt        # Current auth token
│   ├── ngrok_pids.txt         # Process IDs
│   ├── ngrok_urls.txt         # Extracted URLs
│   └── ngrok_*.log            # Individual service logs
```

## 🔄 Session Management

- **Auto-Expiry**: Sessions automatically stop when timeout reached
- **Manual Stop**: Use `stop` command anytime
- **Restart**: Use `restart` to change settings
- **Status Check**: Monitor active sessions and remaining time

## 🌍 Network Security

- **ngrok Regions**: Uses 'us' region by default
- **HTTPS Only**: All tunnels use encrypted connections
- **Temporary URLs**: ngrok URLs are temporary and rotate
- **No Persistence**: No permanent exposure of local services

This secure sharing system balances accessibility with safety, perfect for client demos and team collaboration!
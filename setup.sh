#!/bin/bash

# Firebase Scripts - One-Click Setup
# This script sets up everything needed to run the secure emulator sharing

set -e  # Exit on any error

echo "🚀 Firebase Scripts - One-Click Setup"
echo "===================================="
echo ""

# Check if we're in the right directory
if [ ! -f "package.json" ]; then
    echo "❌ Error: Please run this script from the firebase-scripts directory"
    exit 1
fi

# Step 1: Install dependencies
echo "📦 Installing dependencies..."
if command -v npm &> /dev/null; then
    npm install
    echo "✅ Dependencies installed"
else
    echo "❌ Error: npm not found. Please install Node.js first"
    exit 1
fi

# Step 2: Generate SSL certificates
echo ""
echo "🔐 Generating SSL certificates..."
if [ ! -d ".certs" ] || [ ! -f ".certs/cert.pem" ]; then
    ./create-self-signed-cert.sh
    echo "✅ SSL certificates generated"
else
    echo "⏭️  SSL certificates already exist"
fi

# Step 3: Create basic .env if it doesn't exist
echo ""
echo "⚙️  Setting up configuration..."
if [ ! -f ".env" ]; then
    echo "📝 Creating basic .env file..."
    cat > .env << EOF
# Firebase Scripts Configuration
# Minimal configuration - most values will auto-detect

# Your Firebase project ID (optional - for reference)
# FIREBASE_PROJECT_ID=your-project-id

# Network configuration (auto-detected if not set)
# LOCAL_NETWORK_IP=192.168.1.100

# Customize if needed (defaults shown)
# COMPANY_NAME=YourCompany
# APP_NAME=Firebase Development Tools
# FRONTEND_NAME=Console

# Ports (defaults usually work fine)
# HTTPS_PORT=8443
# HTTP_PORT=8080
EOF
    echo "✅ Created .env with sensible defaults"
else
    echo "⏭️  .env file already exists"
fi

# Step 4: Check network setup
echo ""
echo "🌐 Checking network setup..."

# Try to detect local IP
LOCAL_IP=""
if command -v ip &> /dev/null; then
    LOCAL_IP=$(ip route get 1.1.1.1 | grep -oP 'src \K\S+' 2>/dev/null || echo "")
elif command -v ipconfig &> /dev/null; then
    LOCAL_IP=$(ipconfig getifaddr en0 2>/dev/null || echo "")
fi

if [ -n "$LOCAL_IP" ]; then
    echo "✅ Detected local IP: $LOCAL_IP"
else
    echo "⚠️  Could not auto-detect local IP (will use 127.0.0.1)"
    LOCAL_IP="127.0.0.1"
fi

# Step 5: Ready to go!
echo ""
echo "🎉 Setup Complete!"
echo "=================="
echo ""
echo "🚀 To start the secure emulator sharing:"
echo "   node https-wrapper-proxy.js"
echo ""
echo "📱 Then access from mobile device:"
echo "   https://$LOCAL_IP:8443"
echo ""
echo "🔑 The auth token will be shown in the console"
echo ""
echo "💡 Tips:"
echo "   • Make sure your Firebase emulators are running first"
echo "   • Accept the SSL certificate warning in your browser"
echo "   • Ensure your mobile device is on the same WiFi network"
echo ""
echo "📚 For more details, see README.md"
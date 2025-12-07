# Quick Start Guide

Get your Firebase project running in under 5 minutes!

## Installation

### **Option 1: Clone the Repository**
```bash
git clone https://github.com/your-username/firebase-scripts.git
cd firebase-scripts
chmod +x *.sh local/*.sh remote/*.sh
```

### **Option 2: Download and Extract**
```bash
# Download the latest release
wget https://github.com/your-username/firebase-scripts/archive/main.zip
unzip main.zip
cd firebase-scripts-main
chmod +x *.sh local/*.sh remote/*.sh
```

## Quick Setup (3 Steps)

### **Step 1: Create Your Project Config**
```bash
# Copy the example that matches your project type
cp examples/simple-project-config.sh project-config.sh

# Edit with your project details
nano project-config.sh
```

### **Step 2: Set Your Project Values**
```bash
# Edit project-config.sh
export FIREBASE_PROJECT_ID="your-project-id"
export FIREBASE_REGION="us-central1"
export FUNCTION_NAME_PREFIX="your-prefix-"
```

### **Step 3: Start Your Environment**
```bash
# Full setup (emulator + deploy services)
./setup.sh

# Or step by step:
./manage.sh start-local
./manage.sh deploy-local
```

## Common Use Cases

### **Start Development Environment**
```bash
./manage.sh start-local
```

### **Check Status**
```bash
./manage.sh status-local
```

### **Deploy to Production**
```bash
./unified-deploy.sh simple --project-id YOUR_PROJECT_ID
```

### **Restart Everything**
```bash
./manage.sh restart-local
```

### **Clean Up**
```bash
./manage.sh clean-local
```

## Advanced Features

### **Smart Resource Management**
```bash
# Start with controlled resources (prevents overload)
./manage.sh start-local --concurrency=2 --max-instances=3

# Load only specific services for faster startup
./manage.sh start-local --services=service1,service2

# Minimal mode for development (faster, lighter)
./manage.sh start-local-min
```

### **Production Deployment Options**
```bash
# Simple deployment (essential services, faster)
./unified-deploy.sh simple --project-id PROJECT_ID

# Production deployment (full features)
./unified-deploy.sh production --project-id PROJECT_ID

# Deploy specific function only
./manage.sh deploy-function --function FUNCTION_NAME
```

### **Resource Monitoring**
```bash
# Start monitoring to prevent system overload
./manage.sh monitor-resources

# Check current resource usage
./manage.sh check-resources

# Clean up excess processes
./manage.sh cleanup-resources
```

## Configuration Examples

### **Simple Project (No Prefix)**
```bash
export FIREBASE_PROJECT_ID="my-app"
export FIREBASE_REGION="us-central1"
export FUNCTION_NAME_TRANSFORM="default"
```

### **API Project (api- Prefix)**
```bash
export FIREBASE_PROJECT_ID="api-project"
export FIREBASE_REGION="europe-west1"
export FUNCTION_NAME_TRANSFORM="kebab"
export FUNCTION_NAME_PREFIX="api-"
```

### **Enterprise Project (enterprise- Prefix)**
```bash
export FIREBASE_PROJECT_ID="enterprise-api"
export FIREBASE_REGION="asia-southeast1"
export FUNCTION_NAME_TRANSFORM="custom"
export FUNCTION_NAME_PREFIX="enterprise-"
export FUNCTION_NAME_SUFFIX="-v1"
```

## Troubleshooting

### **Port Conflicts**
```bash
./manage.sh clean-local
./manage.sh start-local
```

### **Resource Issues**
```bash
# Force clean everything
./manage.sh force-clean

# Fresh start
./manage.sh fresh-deploy
```

### **Configuration Issues**
```bash
# Validate your config
source project-config.sh
validate_project_config
```

### **Service Not Responding**
```bash
# Check health
./manage.sh status-local

# Check logs
firebase emulators:start --only functions,firestore
```

## Testing Your Setup

### **Test Functions**
```bash
./remote/test-functions-consolidated.sh
```

### **Test Health Checks**
```bash
./remote/health-check.sh
```

### **Quick Test**
```bash
./remote/quick-test.sh
```

## Next Steps

- 📖 Read the [full documentation](README.md)
- 🔧 Check [configuration options](README.md#configuration-options)
- 💡 See [examples](../examples/) for different project types
- 🚀 Try [advanced features](README.md#advanced-options)
- 📊 Explore [resource monitoring](README.md#resource-management)

## Need Help?

- 📖 **Documentation**: [README.md](README.md)
- 🐛 **Issues**: Check troubleshooting guides
- ⭐ **Star the repo** if it helped you!

**Your Firebase project is ready to go!**
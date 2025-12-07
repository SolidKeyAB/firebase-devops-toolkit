# 🚀 Firebase Scripts Integration Guide

> **Get this Firebase DevOps toolkit running in your project in under 5 minutes!**

## 📦 Installation Methods

### **Method 1: Git Submodule (Recommended)**
Keep the toolkit updated while maintaining your project structure:

```bash
# Add as submodule in your Firebase project
cd your-firebase-project/
git submodule add https://github.com/SolidKeyAB/firebase-scripts.git scripts
cd scripts/
./setup.sh

# Create symlinks to your project root (optional)
ln -s scripts/manage.sh ./manage.sh
ln -s scripts/unified-deploy.sh ./deploy.sh
```

### **Method 2: Direct Clone**
Simple integration for standalone use:

```bash
# Clone into your project
cd your-firebase-project/
git clone https://github.com/SolidKeyAB/firebase-scripts.git scripts
cd scripts/
./setup.sh
```

### **Method 3: Download & Extract**
For one-time use or testing:

```bash
curl -L https://github.com/SolidKeyAB/firebase-scripts/archive/main.zip -o firebase-scripts.zip
unzip firebase-scripts.zip
mv firebase-scripts-main scripts/
cd scripts/
./setup.sh
```

---

## ⚡ Quick Start (30 seconds)

### **1. Set Your Project ID**
```bash
# Option A: Environment variable
export FIREBASE_PROJECT_ID="your-project-id"

# Option B: Create .env file
echo "FIREBASE_PROJECT_ID=your-project-id" > .env
echo "FIREBASE_REGION=us-central1" >> .env
```

### **2. Start Development**
```bash
cd scripts/
./manage.sh start-local    # Start Firebase emulators
```

### **3. Deploy to Production**
```bash
./unified-deploy.sh simple --project-id your-project-id
```

**That's it!** 🎉 You're now using enterprise-grade Firebase DevOps tools.

---

## 🔧 Project Integration Patterns

### **Pattern 1: Submodule Integration**
```
your-firebase-project/
├── functions/
├── firestore.rules
├── firebase.json
├── scripts/                 # ← Firebase scripts submodule
│   ├── manage.sh
│   ├── unified-deploy.sh
│   └── ...
├── manage.sh               # ← Symlink to scripts/manage.sh
└── deploy.sh               # ← Symlink to scripts/unified-deploy.sh
```

**Setup commands:**
```bash
git submodule add https://github.com/SolidKeyAB/firebase-scripts.git scripts
ln -s scripts/manage.sh ./manage.sh
ln -s scripts/unified-deploy.sh ./deploy.sh
```

### **Pattern 2: Scripts Directory**
```
your-firebase-project/
├── functions/
├── firestore.rules
├── firebase.json
├── package.json
└── scripts/                 # ← Cloned firebase-scripts
    ├── manage.sh
    ├── unified-deploy.sh
    └── ...
```

**Usage:**
```bash
scripts/manage.sh start-local
scripts/unified-deploy.sh simple --project-id your-project
```

### **Pattern 3: NPM Scripts Integration**
Add to your `package.json`:

```json
{
  "scripts": {
    "dev": "scripts/manage.sh start-local",
    "deploy": "scripts/unified-deploy.sh simple --project-id $FIREBASE_PROJECT_ID",
    "test": "scripts/remote/test-functions-consolidated.sh",
    "clean": "node scripts/cleanup-firestore.js --all",
    "share": "node scripts/https-wrapper-proxy.js"
  }
}
```

**Usage:**
```bash
npm run dev      # Start development
npm run deploy   # Deploy to production
npm run test     # Test functions
npm run clean    # Clean database
npm run share    # Share emulators securely
```

---

## ⚙️ Configuration

### **Essential Environment Variables**
Create `.env` file in your project root:

```bash
# Required
FIREBASE_PROJECT_ID=your-project-id
FIREBASE_REGION=us-central1

# Optional - AI Services
GEMINI_API_KEY=your-gemini-api-key
GOOGLE_SEARCH_API_KEY=your-search-api-key
GOOGLE_CSE_ID=your-custom-search-engine-id

# Optional - Vector Database
QDRANT_URL=your-qdrant-url
QDRANT_API_KEY=your-qdrant-api-key

# Optional - Emulator Ports
FIREBASE_UI_PORT=4000
FIREBASE_HUB_PORT=4400
```

### **Project-Specific Configuration**
Create `project-config.sh` to override defaults:

```bash
#!/bin/bash
# Your project-specific configuration

# Override default settings
export FIREBASE_PROJECT_ID="your-project-id"
export FIREBASE_REGION="europe-west1"

# Custom service configuration
export FIREBASE_SERVICES=(
    "your-service-1:5001"
    "your-service-2:5002"
    "your-service-3:5003"
)

# Custom function naming
export FUNCTION_NAME_TRANSFORM="camel"  # camel, snake, kebab

# Source the main config
source scripts/config.sh
```

---

## 🎯 Common Usage Patterns

### **Development Workflow**
```bash
# 1. Start development environment
./scripts/manage.sh start-local

# 2. Open Firebase UI in browser
open http://localhost:4000

# 3. Share with team (optional)
node scripts/https-wrapper-proxy.js

# 4. Test your functions
./scripts/remote/test-functions-consolidated.sh --function myFunction

# 5. Clean up when done
./scripts/manage.sh clean-local
```

### **Deployment Workflow**
```bash
# 1. Deploy to staging
./scripts/unified-deploy.sh generic \
  --project-dir . \
  --services-dir functions \
  --project-id staging-project \
  --dry-run

# 2. Deploy to production
./scripts/unified-deploy.sh production \
  --project-id production-project \
  --region europe-west1 \
  --install-deps
```

### **Testing Workflow**
```bash
# Test all functions
./scripts/remote/test-functions-consolidated.sh

# Test specific function
./scripts/remote/test-functions-consolidated.sh --function myFunction --test-auth

# Health check
./scripts/remote/health-check.sh

# Monitor deployment
./scripts/remote/monitor-deployment.sh
```

### **Database Management**
```bash
# Clean all data
node scripts/cleanup-firestore.js --all

# Remove duplicates only
node scripts/cleanup-firestore.js --duplicates

# Clean specific collections
node scripts/cleanup-firestore.js --collection users --collection products

# Backup before cleanup
./scripts/local/preserve-data.sh
```

---

## 🔄 Update & Maintenance

### **Updating the Toolkit**
```bash
# If using submodule
git submodule update --remote scripts

# If using direct clone
cd scripts/
git pull origin main
```

### **Custom Modifications**
```bash
# Fork the repository for custom changes
git remote add upstream https://github.com/SolidKeyAB/firebase-scripts.git

# Keep your fork updated
git fetch upstream
git merge upstream/main
```

---

## 🚨 Troubleshooting

### **Common Issues & Solutions**

#### **Firebase CLI Issues**
```bash
# Install/update Firebase CLI
npm install -g firebase-tools

# Login to Firebase
firebase login

# Verify project access
firebase projects:list
```

#### **Permission Errors**
```bash
# Make scripts executable
chmod +x scripts/*.sh scripts/*/*.sh

# Fix ownership
sudo chown -R $USER scripts/
```

#### **Port Conflicts**
```bash
# Check ports in use
lsof -i :4000,4400,5001,8080

# Kill conflicting processes
scripts/manage.sh clean-local

# Use custom ports
export FIREBASE_UI_PORT=4001
export FIREBASE_HUB_PORT=4401
```

#### **Environment Variables Not Working**
```bash
# Verify .env file exists
cat .env

# Source environment
source .env

# Check if variables are set
echo $FIREBASE_PROJECT_ID
```

#### **Functions Not Deploying**
```bash
# Check Firebase project
firebase use --add

# Verify function syntax
cd functions/ && npm run lint

# Deploy specific function
firebase deploy --only functions:myFunction
```

---

## 🎯 Advanced Integration

### **CI/CD Integration**
GitHub Actions example:

```yaml
name: Firebase Deploy
on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
        with:
          submodules: true  # If using submodule

      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '18'

      - name: Install dependencies
        run: npm install

      - name: Deploy to Firebase
        env:
          FIREBASE_TOKEN: ${{ secrets.FIREBASE_TOKEN }}
          FIREBASE_PROJECT_ID: ${{ secrets.FIREBASE_PROJECT_ID }}
        run: |
          scripts/unified-deploy.sh production \
            --project-id $FIREBASE_PROJECT_ID
```

### **Docker Integration**
```dockerfile
FROM node:18-alpine

WORKDIR /app
COPY . .
COPY scripts/ ./scripts/

RUN npm install -g firebase-tools
RUN chmod +x scripts/*.sh scripts/*/*.sh

EXPOSE 4000 4400 5001 8080

CMD ["scripts/manage.sh", "start-local"]
```

### **VS Code Integration**
Add to `.vscode/tasks.json`:

```json
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "Start Firebase Emulators",
      "type": "shell",
      "command": "scripts/manage.sh start-local",
      "group": "build",
      "presentation": {
        "echo": true,
        "reveal": "always",
        "panel": "new"
      }
    },
    {
      "label": "Deploy to Firebase",
      "type": "shell",
      "command": "scripts/unified-deploy.sh simple --project-id ${env:FIREBASE_PROJECT_ID}",
      "group": "build"
    }
  ]
}
```

---

## 📞 Support & Contributing

- **Issues**: [Report bugs](https://github.com/SolidKeyAB/firebase-scripts/issues)
- **Discussions**: [Ask questions](https://github.com/SolidKeyAB/firebase-scripts/discussions)
- **Contributing**: See [CONTRIBUTING.md](CONTRIBUTING.md)
- **Documentation**: See [docs/](docs/) directory

---

## 🏆 Success Stories

> *"Reduced our Firebase setup time from 2 days to 30 minutes!"*
> — Development Team Lead

> *"The emulator sharing feature is a game-changer for remote teams."*
> — Mobile Developer

> *"Finally, a professional Firebase DevOps toolkit that just works."*
> — Senior DevOps Engineer

---

**🚀 Ready to supercharge your Firebase development?**
**[⭐ Star the repo](https://github.com/SolidKeyAB/firebase-scripts) and get started in 30 seconds!**
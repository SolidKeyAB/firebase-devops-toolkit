# Firebase DevOps Toolkit

> **Enterprise-grade Firebase DevOps - Local to Production in Minutes**

[![GitHub Package](https://img.shields.io/badge/npm-GitHub%20Packages-blue)](https://github.com/SolidKeyAB/firebase-devops-toolkit/packages)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)

A complete Firebase development ecosystem with **80+ production-ready scripts** for local development, team collaboration, and deployment automation.

**By [SolidKey AB](https://solidkey.se)** | [Documentation](docs/) | [Contributing](CONTRIBUTING.md)

---

## Why This Toolkit?

Firebase is powerful, but managing a growing Firebase project becomes complex. This toolkit solves real problems we faced:

### 🏗️ **Enforce Clean Project Structure**
Without structure, Firebase projects become messy. We enforce a **microservices architecture** with clear separation:
```
services/
├── index.js              # Single entry point - all exports here
├── user-service/         # Each service isolated
├── order-service/
└── shared/               # Shared utilities
```

### 🎯 **Single Entry Point with `orchestrate.sh`**
Stop remembering dozens of commands. One script to rule them all:
```bash
./orchestrate.sh dev          # Start local development
./orchestrate.sh deploy       # Deploy to production
./orchestrate.sh status       # Check what's running
./orchestrate.sh help         # See all commands
```

### 💰 **Reduce Deployment Costs**
Deploy only what changed, not everything:
```bash
# Deploy specific services (not all 50 functions!)
./manage.sh deploy-production-selective --services user-service,order-service

# Deploy single function
./manage.sh deploy-function --function createUser
```

### 🧪 **Use Emulators Effectively**
Local development should be fast and reliable:
- **Auto-detect** emulator ports from `firebase.json`
- **Manage Pub/Sub topics** automatically
- **Preserve data** between restarts
- **Monitor resources** in real-time

### 🤝 **Share Emulators with Your Team**
This is a game-changer - share your running emulators with teammates:
```bash
./share-emulators.sh start    # Teammates can now access your emulators!
```
Three security levels: Basic → Secure (password) → Enterprise (HTTPS + auth)

### 📱 **Mobile Development Made Easy**
Test mobile apps against emulators running on your machine - securely.

### ⚡ **Quick Onboarding**
New team member? Get them productive in 5 minutes with our starter template.

---

## Quick Start

### Option A: Start from Starter Template (Recommended for New Projects)

```bash
# Clone the toolkit
git clone https://github.com/SolidKeyAB/firebase-devops-toolkit.git

# Copy the starter template
cp -r firebase-devops-toolkit/templates/starter-project my-project
cd my-project

# Install dependencies
cd services && npm install

# Configure your Firebase project
cp .firebaserc.template .firebaserc
# Edit .firebaserc with your project ID

# Start development!
cd .. && ./scripts/orchestrate.sh dev
```

The starter template includes:
- Working project structure
- Sample API service with CRUD endpoints
- Shared Firebase utilities
- Pre-configured orchestrate.sh
- Ready-to-use emulator config

### Option B: Add to Existing Project (via GitHub Packages)

```bash
# Configure npm to use GitHub Packages for @solidkeyab scope
echo "@solidkeyab:registry=https://npm.pkg.github.com" >> .npmrc

# Install the toolkit
cd your-project/services
npm install @solidkeyab/firebase-devops-toolkit --save-dev

# Copy the orchestration script
cp node_modules/@solidkeyab/firebase-devops-toolkit/templates/orchestrate.sh ../scripts/

# Set your project ID and start
export FIREBASE_PROJECT_ID="your-project-id"
./scripts/orchestrate.sh dev
```

> **Note:** GitHub Packages requires authentication. Create a [Personal Access Token](https://github.com/settings/tokens) with `read:packages` scope and run:
> ```bash
> npm login --registry=https://npm.pkg.github.com
> ```

### Option C: Standalone Installation

```bash
# Clone for global use
git clone https://github.com/SolidKeyAB/firebase-devops-toolkit.git ~/firebase-devops-toolkit
cd ~/firebase-devops-toolkit && ./setup.sh

# Use directly
export FIREBASE_PROJECT_ID="your-project-id"
./manage.sh start-local
```

---

## Required Project Structure

**Important:** Your project must follow a specific structure for the toolkit to work.

```
your-project/
├── services/                    # Firebase Functions directory
│   ├── index.js                 # ROOT EXPORTS - must export all functions!
│   ├── package.json             # Dependencies
│   ├── firebase.json            # Firebase config
│   ├── my-service/              # Each service in its own directory
│   │   └── index.js             # Service exports
│   └── shared/                  # Shared utilities (optional)
└── scripts/
    └── orchestrate.sh           # Project wrapper (from template)
```

**Key requirement:** The root `index.js` must export all functions:

```javascript
// services/index.js
const myService = require('./my-service/index.js');
exports.myFunction = myService.myFunction;  // This becomes a Cloud Function!
```

**[Read the full Project Structure Guide](docs/PROJECT_STRUCTURE.md)** for detailed requirements, patterns, and examples.

---

## Feature Overview

| Category | Features |
|----------|----------|
| **Local Development** | Emulator management, hot reload, Pub/Sub topics, resource monitoring |
| **Deployment** | Multi-environment, selective deploy, rollback, function versioning |
| **Team Collaboration** | Secure emulator sharing (3 security levels), HTTPS proxy, mobile access |
| **Database** | Firestore cleanup, schema inference, data backup/restore |
| **Testing** | Function testing, health checks, auth method validation |
| **Configuration** | Multi-project support, environment templates, zero-config defaults |

---

## Core Commands

### Local Development

```bash
# Start/stop emulator
./manage.sh start-local
./manage.sh stop-local
./manage.sh restart-local

# Deploy to emulator
./manage.sh deploy-local

# Monitor & status
./manage.sh status-local
./manage.sh monitor-resources
```

### Production Deployment

```bash
# Full deployment
./manage.sh deploy-production --project my-project

# Selective deployment
./manage.sh deploy-production-selective --services api-service,auth-service

# Single function
./manage.sh deploy-function --function myFunction
```

### Database Operations

```bash
# Cleanup
node cleanup-firestore.js --all
node cleanup-firestore.js --duplicates

# Schema
node local/infer-firestore-schema.js
```

### Secure Team Sharing

```bash
# Level 1: Basic (dev only)
./share-emulators.sh

# Level 2: Password protected
./secure-share-emulators.sh

# Level 3: Enterprise (HTTPS + auth + rate limiting)
node https-wrapper-proxy.js
```

---

## Project Integration

### Recommended Project Structure

```
your-project/
├── services/                    # Your Firebase functions
│   ├── api-service/
│   ├── auth-service/
│   └── shared/
├── scripts/
│   └── orchestrate.sh          # Your project wrapper (from template)
├── firebase.json
└── package.json
```

### Using the Orchestration Template

The `templates/orchestrate.sh` provides a project wrapper that:
- Auto-detects toolkit location (npm, submodule, or global)
- Adds project-specific commands
- Handles environment configuration
- Passes standard commands to the toolkit

```bash
# Copy and customize
cp node_modules/@solidkeyab/firebase-devops-toolkit/templates/orchestrate.sh ./scripts/

# Your custom commands
./scripts/orchestrate.sh start-dev    # Your project-specific
./scripts/orchestrate.sh start-local  # Passed to toolkit
```

---

## Configuration

### Zero Configuration

Works out of the box with smart defaults!

### Environment Variables

```bash
# Required
FIREBASE_PROJECT_ID=your-project-id

# Optional - auto-detected
PROJECT_ROOT=/path/to/project
SERVICES_DIR=/path/to/services
FIREBASE_REGION=us-central1

# Security (for team sharing)
HTTPS_PORT=8443
RATE_LIMIT_MAX=20
```

### .env File

```bash
# Create .env in your project root
FIREBASE_PROJECT_ID=my-project
FIREBASE_REGION=europe-west1
LOCAL_NETWORK_IP=192.168.1.100
```

---

## Mobile Development

Securely access Firebase emulators from mobile devices:

```bash
# Start HTTPS proxy
node https-wrapper-proxy.js

# Console output:
# 🔐 Auth Token: abc123xyz
# 🌐 Access URL: https://192.168.1.100:8443
```

1. Connect mobile to same WiFi
2. Open the URL
3. Accept SSL certificate
4. Enter auth token
5. Access all emulators!

---

## Documentation

| Guide | Description |
|-------|-------------|
| [Quick Start](docs/core/QUICK_START.md) | 5-minute setup guide |
| [Integration Guide](INTEGRATION_GUIDE.md) | Project integration methods |
| [Authentication](docs/remote/AUTHENTICATION_GUIDE.md) | Security & auth setup |
| [Testing](docs/remote/TESTING_GUIDE.md) | Testing framework |
| [Best Practices](docs/local/GOOGLE_BEST_PRACTICES.md) | Google recommended practices |

---

## Known Limitations & TODOs

### Firebase Emulator Limitations

| Limitation | Impact | Workaround |
|------------|--------|------------|
| **No parallel processing** | Emulator handles requests sequentially; can't test true concurrency | Test parallel logic in production with low traffic first |
| **Pub/Sub ordering** | Message ordering differs from production | Design for idempotency |
| **Cold starts not simulated** | Functions start instantly in emulator | Monitor cold starts in production |
| **Firestore indexes** | Index errors only appear in production | Deploy indexes before functions |

### Deployment Considerations

| Issue | Details |
|-------|---------|
| **IAM after re-deploy** | Cloud Function IAM settings (invoker permissions) may need manual re-configuration after re-deploying functions. Check IAM if you get 403 errors. |
| **Environment variables** | Secrets and env vars configured in Cloud Console don't sync automatically. Use `.env` files or Secret Manager. |

### Potential Improvements

- [ ] Automated IAM invoker permission restoration after deployment
- [ ] Script to detect and warn about missing Firestore indexes before deploy

> Have a suggestion? [Open an issue](https://github.com/SolidKeyAB/firebase-devops-toolkit/issues)!

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Port conflicts | `./manage.sh force-clean` |
| SSL errors | `./create-self-signed-cert.sh` |
| Permission errors | Check Firebase auth: `firebase login` |
| Function deploy fails | `./cleanup-http-functions.sh` |
| Mobile can't connect | Same WiFi + accept certificate |

---

## Contributing

We welcome contributions! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

```bash
# Fork, clone, and create a branch
git checkout -b feature/my-feature

# Make changes and test
./manage.sh start-local

# Submit PR
git push origin feature/my-feature
```

### Good First Issues

Look for issues labeled `good first issue` - perfect for newcomers!

---

## Support

- **Issues**: [GitHub Issues](https://github.com/SolidKeyAB/firebase-devops-toolkit/issues)
- **Discussions**: [GitHub Discussions](https://github.com/SolidKeyAB/firebase-devops-toolkit/discussions)
- **Email**: dev@solidkey.se

---

## License

MIT License - see [LICENSE](LICENSE) for details.

---

## About SolidKey

**[SolidKey AB](https://solidkey.se)** builds developer tools and sustainable technology solutions. We believe in open source and giving back to the developer community.

---

**Made with care in Sweden**

# Firebase Starter Project

A ready-to-use Firebase Functions project powered by [Firebase DevOps Toolkit](https://github.com/SolidKeyAB/firebase-devops-toolkit).

## Quick Start

### 1. Setup

```bash
# Copy this template to your project
cp -r templates/starter-project my-project
cd my-project

# Install dependencies
cd services
npm install

# Configure your project
cp .firebaserc.template .firebaserc
# Edit .firebaserc and set your Firebase project ID
```

### 2. Start Development

```bash
# From project root
./scripts/orchestrate.sh dev

# Or from services directory
npx firebase-devops start-local
```

### 3. Test Your Endpoints

Open http://localhost:4000 for the Emulator UI, then test:

```bash
# Hello endpoint
curl http://localhost:5001/YOUR_PROJECT_ID/us-central1/hello

# Health check
curl http://localhost:5001/YOUR_PROJECT_ID/us-central1/health
```

### 4. Deploy to Production

```bash
# Set your project ID
export FIREBASE_PROJECT_ID=your-project-id

# Deploy
./scripts/orchestrate.sh deploy
```

## Project Structure

```
my-project/
├── scripts/
│   └── orchestrate.sh          # Project commands
│
└── services/                    # Firebase Functions
    ├── index.js                 # Root exports (IMPORTANT!)
    ├── package.json
    ├── firebase.json
    │
    ├── my-api-service/          # Your first service
    │   └── index.js
    │
    └── shared/                  # Shared code
        └── libs/
            └── firebase.js      # Firebase Admin singleton
```

## Adding a New Service

1. Create the service directory:
   ```bash
   mkdir services/my-new-service
   ```

2. Create the service file:
   ```javascript
   // services/my-new-service/index.js
   const { onRequest } = require('firebase-functions/v2/https');

   exports.myEndpoint = onRequest({ region: 'us-central1' }, (req, res) => {
     res.json({ message: 'Hello!' });
   });
   ```

3. Export from root index.js:
   ```javascript
   // services/index.js
   const myNewService = require('./my-new-service/index.js');
   exports.myEndpoint = myNewService.myEndpoint;  // Add this line!
   ```

4. Restart the emulator:
   ```bash
   ./scripts/orchestrate.sh stop
   ./scripts/orchestrate.sh dev
   ```

## Commands

| Command | Description |
|---------|-------------|
| `./scripts/orchestrate.sh dev` | Start local emulator |
| `./scripts/orchestrate.sh stop` | Stop emulator |
| `./scripts/orchestrate.sh status` | Check status |
| `./scripts/orchestrate.sh deploy` | Deploy to production |
| `./scripts/orchestrate.sh help` | Show all commands |

## Learn More

- [Project Structure Guide](https://github.com/SolidKeyAB/firebase-devops-toolkit/blob/main/docs/PROJECT_STRUCTURE.md)
- [Firebase DevOps Toolkit](https://github.com/SolidKeyAB/firebase-devops-toolkit)
- [Firebase Functions Docs](https://firebase.google.com/docs/functions)

---

**Built with [Firebase DevOps Toolkit](https://github.com/SolidKeyAB/firebase-devops-toolkit) by [SolidKey AB](https://solidkey.se)**

# Firebase Emulator Sharing System

Dynamic emulator sharing that works from any Firebase project directory using ngrok tunnels.

## Quick Setup

1. **Install ngrok (if not already installed):**
   ```bash
   brew install ngrok
   ```

2. **Install global alias:**
   ```bash
   cd /path/to/firebase-devops-toolkit
   ./install-global-alias.sh
   source ~/.zshrc  # or ~/.bashrc
   ```

## Usage

From **any** Firebase project directory:

```bash
# Start sharing your running emulators
share-emulators start

# Check status and view URLs
share-emulators status

# Show only URLs
share-emulators urls

# Stop sharing
share-emulators stop

# Restart sharing
share-emulators restart
```

## How It Works

1. **Auto-detects** emulator ports from `firebase.json`
2. **Checks** which services are actually running
3. **Creates** ngrok tunnels for active services
4. **Extracts** public URLs from ngrok API
5. **Displays** shareable URLs with service labels

## Supported Services

- 🎛️ **Emulator UI** - Firebase console interface
- ⚡ **Functions** - Firebase Functions
- 🌐 **Frontend** - Next.js/React dev server
- 🔥 **Firestore** - Database emulator
- 🔐 **Auth** - Authentication emulator
- 📦 **Hosting** - Static hosting

## Example Output

```
🚀 Starting emulator sharing...
Found firebase.json: /path/to/project/firebase.json
Detected ports:
  UI: 4002
  Functions: 5002
  Frontend: 9002

✅ Emulator sharing started!

📱 Public URLs:
════════════════════════════════════════
  🎛️  Emulator UI: https://abc123.ngrok.io
  ⚡ Functions: https://def456.ngrok.io
  🌐 Frontend: https://ghi789.ngrok.io
════════════════════════════════════════
💡 Share these URLs with other developers!
```

## Features

- ✅ **Universal** - Works from any Firebase project
- ✅ **Smart Detection** - Auto-finds ports and services
- ✅ **Clean URLs** - Labeled output for easy sharing
- ✅ **Process Management** - Proper cleanup and restart
- ✅ **Status Tracking** - Know what's running
- ✅ **Cross-Platform** - Works on macOS/Linux

## Directory Structure

```
firebase-devops-toolkit/
├── share-emulators.sh          # Main script
├── install-global-alias.sh     # Setup script
├── .emulator-sharing/          # Runtime data (auto-created)
│   ├── ngrok_pids.txt         # Process IDs
│   ├── ngrok_urls.txt         # Extracted URLs
│   └── ngrok_*.log            # Individual logs
└── README-EMULATOR-SHARING.md  # This file
```

## Troubleshooting

**No URLs found:**
- Make sure your emulators are running
- Check that ports in firebase.json match running services

**ngrok not found:**
- Install with: `brew install ngrok`
- Make sure it's in your PATH

**Permission denied:**
- Make scripts executable: `chmod +x *.sh`

**Tunnels not starting:**
- Check ngrok logs in `.emulator-sharing/`
- Verify ports aren't already in use by other ngrok instances

## Demo Workflow

1. Start your Firebase emulators: `firebase emulators:start`
2. Start sharing: `share-emulators start`
3. Share URLs with team members
4. They can access your local emulators remotely
5. Stop sharing when done: `share-emulators stop`

Perfect for demos, testing, and collaborative development!
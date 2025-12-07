# Contributing to Firebase DevOps Toolkit

First off, thank you for considering contributing to Firebase DevOps Toolkit! It's people like you that make this tool better for everyone.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [How Can I Contribute?](#how-can-i-contribute)
- [Development Setup](#development-setup)
- [Pull Request Process](#pull-request-process)
- [Style Guidelines](#style-guidelines)
- [Community](#community)

## Code of Conduct

This project and everyone participating in it is governed by our commitment to providing a welcoming and inclusive environment. Please be respectful and constructive in all interactions.

## Getting Started

### Prerequisites

- Node.js 18+
- Firebase CLI (`npm install -g firebase-tools`)
- Git
- Bash shell (macOS, Linux, or WSL on Windows)

### Quick Start

```bash
# Clone the repository
git clone https://github.com/SolidKeyAB/firebase-devops-toolkit.git
cd firebase-devops-toolkit

# Install dependencies
npm install

# Run setup
./setup.sh
```

## How Can I Contribute?

### Reporting Bugs

Before creating bug reports, please check existing issues to avoid duplicates.

**Great Bug Reports** include:
- A clear, descriptive title
- Steps to reproduce the issue
- Expected vs actual behavior
- Your environment (OS, Node version, Firebase CLI version)
- Relevant logs or error messages

### Suggesting Features

We love feature suggestions! Please:
- Check if the feature already exists or is planned
- Describe the use case and why it would be valuable
- Explain how it should work

### Your First Contribution

Look for issues labeled:
- `good first issue` - Great for newcomers
- `help wanted` - We'd love your help on these
- `documentation` - Help improve our docs

### Pull Requests

1. Fork the repo and create your branch from `main`
2. Make your changes
3. Test your changes thoroughly
4. Update documentation if needed
5. Submit a pull request

## Development Setup

### Project Structure

```
firebase-devops-toolkit/
├── manage.sh              # Main CLI entry point
├── local/                 # Local development scripts
│   ├── deploy-services.sh
│   ├── setup-pubsub-topics.sh
│   └── ...
├── remote/                # Production/remote scripts
│   ├── deploy-complete.sh
│   ├── test-functions-consolidated.sh
│   └── ...
├── templates/             # Project templates
│   └── orchestrate.sh     # Project wrapper template
├── docs/                  # Documentation
├── examples/              # Example configurations
└── lib/                   # Shared utilities
```

### Testing Your Changes

```bash
# Test locally with a Firebase project
export FIREBASE_PROJECT_ID=your-test-project
./manage.sh start-local

# Run the emulator and verify your changes
./manage.sh status-local

# Clean up
./manage.sh stop-local
```

### Writing Scripts

When adding new scripts:

1. **Add to appropriate directory**: `local/` for development, `remote/` for production
2. **Follow naming conventions**: `verb-noun.sh` (e.g., `deploy-services.sh`)
3. **Include header comments**: Purpose, usage, examples
4. **Use shared utilities**: Source `lib/common.sh` for logging functions
5. **Handle errors gracefully**: Use `set -e` and proper error messages
6. **Make it executable**: `chmod +x your-script.sh`

## Pull Request Process

1. **Branch naming**: `feature/description`, `fix/description`, `docs/description`

2. **Commit messages**: Use clear, descriptive messages
   ```
   feat: Add support for Cloud Run deployment
   fix: Handle spaces in project paths
   docs: Update installation guide
   ```

3. **PR description**: Include:
   - What changes were made
   - Why the changes were needed
   - How to test the changes
   - Screenshots (if UI-related)

4. **Review process**:
   - At least one maintainer review required
   - All CI checks must pass
   - Documentation must be updated

5. **After merge**: Delete your feature branch

## Style Guidelines

### Bash Scripts

```bash
#!/bin/bash

# Script description
# Usage: ./script.sh [options]

set -e  # Exit on error

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh" 2>/dev/null || true

# Use meaningful variable names
PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"

# Functions should be documented
# @param $1 - Description of first parameter
# @returns 0 on success, 1 on failure
my_function() {
    local param1="$1"
    # Implementation
}

# Always quote variables that might contain spaces
echo "Processing: $file_path"

# Use log functions for output
log_info "Starting process..."
log_success "Process completed!"
log_error "Something went wrong"
```

### JavaScript/Node.js

```javascript
// Use ES6+ features
const { readFile } = require('fs').promises;

// Document public functions
/**
 * Description of function
 * @param {string} path - Path to file
 * @returns {Promise<object>} Parsed content
 */
async function loadConfig(path) {
    // Implementation
}

// Handle errors appropriately
try {
    await riskyOperation();
} catch (error) {
    console.error('Operation failed:', error.message);
    process.exit(1);
}
```

### Documentation

- Use Markdown for all documentation
- Include code examples
- Keep language clear and concise
- Update the README if adding new features

## Community

- **GitHub Issues**: Bug reports and feature requests
- **GitHub Discussions**: Questions and community chat
- **Pull Requests**: Code contributions

### Getting Help

If you need help:
1. Check the [documentation](docs/)
2. Search existing [issues](https://github.com/SolidKeyAB/firebase-devops-toolkit/issues)
3. Ask in [GitHub Discussions](https://github.com/SolidKeyAB/firebase-devops-toolkit/discussions)

---

## Recognition

Contributors are recognized in:
- The [README.md](README.md) contributors section
- Release notes when their contribution is included

Thank you for contributing!

---

*Maintained by [SolidKey AB](https://solidkey.se)*

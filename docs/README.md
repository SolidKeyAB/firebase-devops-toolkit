# Firebase DevOps Toolkit Documentation

Welcome to the documentation for Firebase DevOps Toolkit by SolidKey AB.

## Quick Links

- **[Project Structure](PROJECT_STRUCTURE.md)** - Required project structure (READ FIRST!)
- [Quick Start Guide](core/QUICK_START.md) - Get up and running in 5 minutes
- [Integration Guide](guides/integration.md) - Integrate with your project
- [Main README](../README.md) - Back to main documentation

---

## Documentation Index

### Getting Started

| Guide | Description |
|-------|-------------|
| **[Project Structure](PROJECT_STRUCTURE.md)** | **Required project structure - READ FIRST!** |
| [Quick Start](core/QUICK_START.md) | 5-minute setup guide |
| [Integration Guide](guides/integration.md) | Multiple integration methods |
| [Core Documentation](core/README.md) | Complete feature overview |

### Guides

| Guide | Description |
|-------|-------------|
| [Deployment Quick Reference](guides/deployment-quick-reference.md) | Common deployment commands |
| [Testing Guide](guides/testing.md) | Testing framework and validation |
| [Emulator Sharing](guides/emulator-sharing.md) | Share emulators with team (basic) |
| [Secure Emulator Sharing](guides/secure-emulator-sharing.md) | Password-protected sharing |

### Local Development

| Guide | Description |
|-------|-------------|
| [Pub/Sub Management](local/PUBSUB_MANAGEMENT.md) | Topic and subscription management |
| [Pub/Sub Issues Resolved](local/PUBSUB_ISSUES_RESOLVED.md) | Common issue solutions |
| [Google Best Practices](local/GOOGLE_BEST_PRACTICES.md) | Recommended practices |

### Remote / Production

| Guide | Description |
|-------|-------------|
| [Authentication Guide](remote/AUTHENTICATION_GUIDE.md) | Security and auth setup |
| [Authentication Requirements](remote/AUTHENTICATION_REQUIREMENTS.md) | Setup requirements |
| [Firestore Triggers](remote/FIRESTORE_TRIGGER_GUIDE.md) | Event-driven workflows |
| [Firestore Pipeline](remote/FIRESTORE_PIPELINE_GUIDE.md) | Pipeline configuration |
| [Testing Guide](remote/TESTING_GUIDE.md) | Remote testing |
| [Test User Guide](remote/TEST_USER_GUIDE.md) | Test user management |

---

## Common Tasks

### Local Development
```bash
./manage.sh start-local        # Start emulator
./manage.sh deploy-local       # Deploy services
./manage.sh status-local       # Check status
./manage.sh stop-local         # Stop emulator
```

### Production Deployment
```bash
./manage.sh deploy-production --project PROJECT_ID
./manage.sh deploy-function --function FUNCTION_NAME
./unified-deploy.sh simple --project-id PROJECT_ID
```

### Testing
```bash
./remote/test-functions-consolidated.sh    # Test functions
./remote/health-check.sh                   # Health check
./remote/quick-test.sh                     # Quick test
```

---

## Need Help?

- **Issues**: [GitHub Issues](https://github.com/SolidKeyAB/firebase-devops-toolkit/issues)
- **Discussions**: [GitHub Discussions](https://github.com/SolidKeyAB/firebase-devops-toolkit/discussions)

---

*Documentation maintained by [SolidKey AB](https://solidkey.se)*

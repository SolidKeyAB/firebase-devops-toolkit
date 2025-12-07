# Firebase Management Scripts

These scripts provide a unified, reusable interface for managing Firebase emulators and services across different projects.

## Design Philosophy

- **Generic**: No hardcoded project values
- **Configurable**: All settings via environment variables
- **Reusable**: Can be copied to any Firebase project
- **Extensible**: Easy to add project-specific customizations

## Quick Start

### 1. **Copy Scripts to Your Project**
```bash
cp -r firebase-scripts/ your-new-project/scripts/
```

### 2. **Create Project Configuration**
```bash
cp examples/simple-project-config.sh project-config.sh
# Edit project-config.sh with your project values
```

### 3. **Set Environment Variables**
```bash
export FIREBASE_PROJECT_ID="your-project-id"
export FIREBASE_REGION="us-central1"
export FUNCTION_NAME_PREFIX="your-prefix-"
```

### 4. **Use the Scripts**
```bash
./manage.sh setup-local
./manage.sh start-local
```

## Configuration Options

### **Project Configuration**
```bash
export FIREBASE_PROJECT_ID="your-project-id"
export FIREBASE_REGION="us-central1"
```

### **Function Naming Conventions**
```bash
export FUNCTION_NAME_TRANSFORM="default"  # Options: default, kebab, snake, camel
export FUNCTION_NAME_PREFIX="your-prefix-"
export FUNCTION_NAME_SUFFIX="-suffix"
```

### **Service Configuration**
```bash
# Format: "service-name:port"
export FIREBASE_SERVICES=(
    "your-service:5001"
    "another-service:5002"
)
```

## Customization Examples

### **Example 1: Simple Project**
```bash
# project-config.sh
export FIREBASE_PROJECT_ID="my-app"
export FIREBASE_REGION="us-central1"
export FUNCTION_NAME_TRANSFORM="default"
```

### **Example 2: Enterprise Project**
```bash
# project-config.sh
export FIREBASE_PROJECT_ID="enterprise-project"
export FIREBASE_REGION="europe-west1"
export FUNCTION_NAME_TRANSFORM="kebab"
export FUNCTION_NAME_PREFIX="api-"
```

## File Structure

```
firebase-scripts/
├── config.sh              # Generic configuration (base)
├── project-config.sh      # Project-specific overrides
├── manage.sh              # Main management script
├── local/                 # Local development scripts
│   ├── start-emulator.sh
│   ├── deploy-services.sh
│   ├── check-status.sh
│   └── monitor-resources.sh
├── remote/                # Production deployment scripts
│   ├── deploy-services.sh
│   ├── deploy-all-functions.sh
│   └── health-check.sh
└── examples/              # Configuration examples
    ├── simple-project-config.sh
    └── enterprise-project-config.sh
```

## Available Commands

### **Local Development**
```bash
./manage.sh start-local                     # Start emulators
./manage.sh stop-local                      # Stop emulator
./manage.sh status-local                    # Check status
./manage.sh deploy-local                    # Deploy to local
./manage.sh restart-local                   # Restart emulator
./manage.sh clean-local                     # Clean up processes
./manage.sh setup-local                     # Full local setup
```

### **Production Deployment**
```bash
./unified-deploy.sh simple --project-id PROJECT_ID        # Simple deployment
./unified-deploy.sh production --project-id PROJECT_ID    # Production deployment
./remote/deploy-complete.sh                               # Complete deployment
```

### **Resource Management**
```bash
./manage.sh monitor-resources               # Start resource monitoring
./manage.sh check-resources                 # Check current resource usage
./manage.sh cleanup-resources               # Clean up excess processes
```

### **Testing**
```bash
./remote/test-functions-consolidated.sh     # Test functions
./remote/health-check.sh                    # Health check
./remote/quick-test.sh                      # Quick test
```

## Health Check Endpoints

The scripts automatically generate health check endpoints based on your configuration:

- **Local**: `http://localhost:PORT/FUNCTION_NAME/REGION/health`
- **Production**: `https://REGION-PROJECT_ID.cloudfunctions.net/FUNCTION_NAME`

## Troubleshooting

### **Port Conflicts**
```bash
./manage.sh clean-local
./manage.sh start-local
```

### **Configuration Issues**
```bash
# Check if project config is loaded
./manage.sh status-local

# Validate configuration
source project-config.sh
```

### **Service Not Responding**
```bash
# Check service health
curl http://localhost:5001/FUNCTION_NAME/REGION/health

# Check logs
firebase emulators:start --only functions,firestore
```

### **Resource Issues**
```bash
# Check resource usage
./manage.sh check-resources

# Clean up excess processes
./manage.sh cleanup-resources

# Force clean everything
./manage.sh force-clean
```

## Migration Checklist

When copying these scripts to a new project:

- [ ] Copy scripts directory
- [ ] Create `project-config.sh` with your values
- [ ] Set `FIREBASE_PROJECT_ID` and `FIREBASE_REGION`
- [ ] Configure function naming options
- [ ] Update service configuration if needed
- [ ] Test with `./manage.sh setup-local`
- [ ] Verify health checks work

## Updating Scripts

To update the scripts:

1. **Backup your project-config.sh**
2. **Update the generic scripts**
3. **Test with your project configuration**
4. **Deploy to other projects**

## Best Practices

1. **Always use project-config.sh** for project-specific values
2. **Never hardcode values** in the generic scripts
3. **Use environment variables** for sensitive data
4. **Test locally** before deploying to production
5. **Keep generic scripts generic** - extend, don't modify
6. **Monitor resources** to prevent system overload

## Contributing

When contributing to these scripts:

- Keep them generic and reusable
- Add new features as configurable options
- Maintain backward compatibility
- Document all new configuration options
- Test with multiple project configurations
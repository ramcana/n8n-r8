# N8N-R8 Documentation Index

This directory contains organized documentation for the N8N-R8 project.

## 📁 **Directory Structure**

### **📖 Main Documentation**
- [`QUICK-REFERENCE.md`](QUICK-REFERENCE.md) - Quick reference guide for common tasks
- [`GETTING-STARTED.md`](GETTING-STARTED.md) - Getting started guide for new users
- [`README.md`](README.md) - Main documentation overview

### **🛠️ Development**
- [`development/`](development/) - Development-related documentation
  - [`CI-FIX-SUMMARY.md`](development/CI-FIX-SUMMARY.md) - CI/CD fixes and improvements
  - [`shell-script-standards.md`](development/shell-script-standards.md) - Shell scripting standards
  - [`shellcheck-validation.md`](development/shellcheck-validation.md) - ShellCheck validation guide
  - [`HTTPS-TUNNELING-IMPLEMENTATION-PLAN.md`](development/HTTPS-TUNNELING-IMPLEMENTATION-PLAN.md) - Tunneling implementation details
  - [`verify-comfyui-nodes.md`](development/verify-comfyui-nodes.md) - ComfyUI nodes verification

### **🚀 Deployment**
- [`deployment/`](deployment/) - Deployment guides and configurations
  - [`VOLUME_MOUNT_SETUP.md`](deployment/VOLUME_MOUNT_SETUP.md) - Volume mount configuration
  - [`autoupdate.md`](autoupdate.md) - Auto-update configuration

### **🔧 Troubleshooting**
- [`troubleshooting/`](troubleshooting/) - Troubleshooting guides
  - [`NGINX-DEPLOYMENT-DEBUG.md`](troubleshooting/NGINX-DEPLOYMENT-DEBUG.md) - NGINX deployment debugging
  - [`PORT-CONFLICT-RESOLUTION.md`](troubleshooting/PORT-CONFLICT-RESOLUTION.md) - Port conflict resolution
  - [`shellcheck-issues.md`](troubleshooting/shellcheck-issues.md) - ShellCheck issue resolution
  - [`flowcharts.md`](troubleshooting/flowcharts.md) - Troubleshooting flowcharts

### **🏗️ Architecture**
- [`architecture/`](architecture/) - System architecture documentation
  - [`overview.md`](architecture/overview.md) - System overview

### **📊 Performance**
- [`performance/`](performance/) - Performance optimization guides
  - [`baseline-recommendations.md`](performance/baseline-recommendations.md) - Performance baselines

### **📚 Archive**
- [`archive/`](archive/) - Archived documentation and historical records
  - [`FINAL-SUMMARY.md`](archive/FINAL-SUMMARY.md) - Final implementation summary
  - [`IMPROVEMENTS-IMPLEMENTED.md`](archive/IMPROVEMENTS-IMPLEMENTED.md) - Historical improvements
  - [`IMPROVEMENTS-SUMMARY.md`](archive/IMPROVEMENTS-SUMMARY.md) - Summary of improvements

## 🔍 **Quick Links**

### **For New Users:**
1. Start with [`../README.md`](../README.md) - Main project README
2. Read [`GETTING-STARTED.md`](GETTING-STARTED.md) - Setup guide
3. Check [`QUICK-REFERENCE.md`](QUICK-REFERENCE.md) - Common commands

### **For Developers:**
1. Review [`development/shell-script-standards.md`](development/shell-script-standards.md)
2. Check [`development/CI-FIX-SUMMARY.md`](development/CI-FIX-SUMMARY.md) for recent changes
3. Follow [`development/shellcheck-validation.md`](development/shellcheck-validation.md) for code quality

### **For Troubleshooting:**
1. Check [`troubleshooting/`](troubleshooting/) for specific issues
2. Review [`architecture/overview.md`](architecture/overview.md) for system understanding
3. Use [`performance/baseline-recommendations.md`](performance/baseline-recommendations.md) for optimization

## 📝 **Contributing to Documentation**

When adding new documentation:
- Place development notes in `development/`
- Put deployment guides in `deployment/`
- Add troubleshooting guides in `troubleshooting/`
- Use clear, descriptive filenames
- Update this index when adding new files

## 🚫 **Ignored Documentation Patterns**

The following patterns are automatically ignored (see `.gitignore`):
- `*-IMPLEMENTATION-PLAN.md`
- `*-DEBUG.md`
- `*-SETUP.md`
- `verify-*.md`
- `temp-*.md`
- `personal-*.md`
- And many more development/temporary patterns

This keeps the repository clean while allowing local development documentation.

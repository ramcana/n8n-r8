# ShellCheck Issues Troubleshooting Guide

This guide provides solutions for common ShellCheck validation errors encountered in the N8N-R8 project.

## Quick Diagnosis

### Check ShellCheck Status

```bash
# Run comprehensive validation
./tests/run_tests.sh

# Check specific script
shellcheck scripts/start-nginx.sh

# Validate all shell scripts
find . -name "*.sh" -type f -not -path "*/node_modules/*" | xargs shellcheck
```

### Common Error Patterns

```bash
# Check for specific error types
shellcheck scripts/*.sh | grep "SC1090"  # Source path issues
shellcheck scripts/*.sh | grep "SC2034"  # Unused variables
shellcheck scripts/*.sh | grep "SC2148"  # Missing shebang
```

## Error Code Reference

### SC1090: Can't follow non-constant source

**Error Message**: `Can't follow non-constant source. Use a directive to specify location.`

**Cause**: ShellCheck cannot determine the path of sourced files when using variables.

**Example Problem**:

```bash
source "$SCRIPT_DIR/helpers.sh"
```

**Solution**: Add explicit source directive

```bash
# shellcheck source=helpers/test_helpers.sh
source "$SCRIPT_DIR/helpers.sh"
```

**Project-Specific Fix**:

```bash
# For test scripts sourcing helpers
# shellcheck source=../helpers/test_helpers.sh
source "$SCRIPT_DIR/../helpers/test_helpers.sh"

# For scripts sourcing config
# shellcheck source=../test_config.sh
source "$SCRIPT_DIR/../test_config.sh"
```

### SC1091: Not following sourced file

**Error Message**: `Not following: [file] was not specified as input`

**Cause**: ShellCheck cannot find the sourced file at the specified path.

**Example Problem**:

```bash
source "missing-file.sh"
```

**Solution**: Verify file exists and path is correct

```bash
# Check if file exists
ls -la tests/helpers/test_helpers.sh

# Use correct relative path
# shellcheck source=tests/helpers/test_helpers.sh
source "$SCRIPT_DIR/tests/helpers/test_helpers.sh"
```

**Project-Specific Fix**:

```bash
# Ensure source paths are relative to script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../helpers/test_helpers.sh
source "$SCRIPT_DIR/../helpers/test_helpers.sh"
```

### SC2034: Variable appears unused

**Error Message**: `[variable] appears to be unused. Verify use (or export if used externally).`

**Cause**: Variables defined but not used in the current script scope.

**Example Problem**:

```bash
COLOR_RED='\033[0;31m'  # Used by other scripts but not here
```

**Solution**: Export for external use or document usage

```bash
# Export for use by other scripts
export COLOR_RED='\033[0;31m'

# Or document with disable directive
# shellcheck disable=SC2034
COLOR_RED='\033[0;31m'  # Used by sourcing scripts
```

**Project-Specific Fix**:

```bash
# In tests/helpers/test_helpers.sh
# Color variables for output formatting - exported for use by test scripts
export GREEN='\033[0;32m'
export RED='\033[0;31m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export NC='\033[0m'
```

### SC2148: Tips depend on target shell

**Error Message**: `Tips depend on target shell and yours is unknown. Add a shebang or a 'shell' directive.`

**Cause**: Script missing shebang line or ShellCheck cannot determine shell type.

**Example Problem**:

```bash
echo "Hello World"  # No shebang
```

**Solution**: Add appropriate shebang

```bash
#!/bin/bash
echo "Hello World"
```

**Project-Specific Fix**:

```bash
# For Bash scripts (most common in project)
#!/bin/bash

# For POSIX-compliant scripts
#!/bin/sh
```

### SC1036: '(' is invalid here

**Error Message**: `'(' is invalid here. Did you forget to escape it?`

**Cause**: Syntax error in conditional statements or function definitions.

**Example Problem**:

```bash
if [ $var = "value" {  # Missing closing bracket and wrong opening brace
    echo "matched"
```

**Solution**: Fix syntax

```bash
if [[ "$var" = "value" ]]; then
    echo "matched"
fi
```

### SC1088: Parsing stopped here

**Error Message**: `Parsing stopped here. Invalid syntax?`

**Cause**: Severe syntax error preventing parsing.

**Example Problem**:

```bash
function test_function {
    echo "missing closing brace"
# Missing }
```

**Solution**: Fix syntax errors

```bash
function test_function() {
    echo "proper syntax"
}
```

## Validation Workflow Issues

### Pre-commit Hook Failures

**Problem**: Commits rejected due to ShellCheck errors

**Diagnosis**:

```bash
# Check which files are causing issues
git status
git diff --cached --name-only | grep '\.sh$' | xargs shellcheck
```

**Solution**:

```bash
# Fix issues in staged files
shellcheck scripts/problematic-script.sh
# Edit and fix issues
git add scripts/problematic-script.sh
git commit -m "Fix ShellCheck issues"
```

### CI Pipeline Failures

**Problem**: GitHub Actions failing on ShellCheck validation

**Diagnosis**:

```bash
# Run the same command as CI locally
find . -name "*.sh" -type f -not -path "*/node_modules/*" | \
xargs shellcheck --source-path=tests/helpers --source-path=tests
```

**Solution**:

```bash
# Fix all reported issues
./scripts/validate_syntax.sh
# Commit fixes
git add .
git commit -m "Fix ShellCheck validation issues"
```

### Source Path Resolution Issues

**Problem**: ShellCheck cannot resolve source paths in CI

**Diagnosis**:

```bash
# Check if source paths are correct
shellcheck --source-path=tests/helpers --source-path=tests scripts/test-script.sh
```

**Solution**:

```bash
# Update source directives with correct paths
# shellcheck source=../helpers/test_helpers.sh
source "$SCRIPT_DIR/../helpers/test_helpers.sh"
```

## Environment-Specific Issues

### Windows/WSL Issues

**Problem**: ShellCheck not available or behaving differently

**Solution**:

```bash
# Install ShellCheck in WSL
sudo apt-get update
sudo apt-get install shellcheck

# Verify installation
shellcheck --version
```

### macOS Issues

**Problem**: Different ShellCheck version or behavior

**Solution**:

```bash
# Install/update ShellCheck via Homebrew
brew install shellcheck
brew upgrade shellcheck

# Verify version compatibility
shellcheck --version
```

### Docker Environment Issues

**Problem**: ShellCheck validation in Docker containers

**Solution**:

```bash
# Run validation in Docker
docker run --rm -v "$PWD:/mnt" koalaman/shellcheck:stable /mnt/scripts/*.sh

# Or use project's validation script
./scripts/validate_syntax.sh
```

## Performance Issues

### Slow Validation

**Problem**: ShellCheck taking too long on large projects

**Diagnosis**:

```bash
# Time the validation
time shellcheck scripts/*.sh
```

**Solution**:

```bash
# Use parallel processing
find . -name "*.sh" -type f -not -path "*/node_modules/*" | \
xargs -P 4 -I {} shellcheck {}

# Or validate specific directories
shellcheck scripts/*.sh tests/**/*.sh
```

### Memory Issues

**Problem**: ShellCheck consuming too much memory

**Solution**:

```bash
# Process files in smaller batches
find . -name "*.sh" -type f | head -10 | xargs shellcheck
find . -name "*.sh" -type f | tail -n +11 | head -10 | xargs shellcheck
```

## Configuration Issues

### .shellcheckrc Not Working

**Problem**: Configuration file not being read

**Diagnosis**:

```bash
# Check if .shellcheckrc exists and is readable
ls -la .shellcheckrc
cat .shellcheckrc
```

**Solution**:

```bash
# Ensure .shellcheckrc is in project root
# Verify syntax of configuration file
# Check file permissions
chmod 644 .shellcheckrc
```

### Source Path Configuration

**Problem**: Source paths not resolving correctly

**Diagnosis**:

```bash
# Test with explicit source paths
shellcheck --source-path=tests/helpers --source-path=tests scripts/test.sh
```

**Solution**:

```bash
# Update .shellcheckrc with correct paths
echo "source-path=tests/helpers" >> .shellcheckrc
echo "source-path=tests" >> .shellcheckrc
```

## Recovery Procedures

### Reset ShellCheck Configuration

```bash
# Backup current configuration
cp .shellcheckrc .shellcheckrc.backup

# Reset to project defaults
git checkout .shellcheckrc

# Or recreate from template
cat > .shellcheckrc << 'EOF'
# ShellCheck configuration for n8n-r8 project
external-sources=true
source-path=tests/helpers
source-path=tests
shell=bash
EOF
```

### Fix All Issues Automatically

```bash
# Run comprehensive fix script
./scripts/validate_syntax.sh --fix

# Or fix specific types of issues
# Fix source directives
find . -name "*.sh" -exec sed -i '1i#!/bin/bash' {} \;

# Export color variables
sed -i 's/^COLOR_/export COLOR_/' tests/helpers/test_helpers.sh
```

### Emergency Bypass (Use Sparingly)

```bash
# Temporarily disable ShellCheck for specific files
# shellcheck disable=SC1090,SC2034
source "$DYNAMIC_PATH"

# Skip validation for emergency commits
git commit --no-verify -m "Emergency fix - bypass validation"
```

## Prevention Strategies

### Development Best Practices

```bash
# Always validate before committing
git add scripts/new-script.sh
shellcheck scripts/new-script.sh
git commit -m "Add new script"

# Use editor integration
# VS Code: Install ShellCheck extension
# Vim: Add syntastic configuration
```

### Automated Validation

```bash
# Set up git hooks
cp scripts/pre-commit-shellcheck .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit

# Use make targets for validation
make validate-scripts
make test-shellcheck
```

### Continuous Monitoring

```bash
# Regular validation runs
crontab -e
# Add: 0 2 * * * cd /path/to/n8n-r8 && ./scripts/validate_syntax.sh

# Monitor CI pipeline
# Check GitHub Actions regularly
# Fix issues promptly
```

## Getting Help

### Diagnostic Information

When reporting ShellCheck issues, include:

```bash
# ShellCheck version
shellcheck --version

# Operating system
uname -a

# Project structure
find . -name "*.sh" -type f | head -20

# Specific error output
shellcheck problematic-script.sh 2>&1
```

### Resources

- **ShellCheck Wiki**: https://github.com/koalaman/shellcheck/wiki
- **Error Code Reference**: https://github.com/koalaman/shellcheck/wiki/Checks
- **Project Issues**: Open an issue with diagnostic information
- **Community Support**: N8N Community forums for workflow-related questions

### Quick Reference Commands

```bash
# Validate all scripts
./tests/run_tests.sh

# Fix common issues
./scripts/validate_syntax.sh --fix

# Check specific error type
shellcheck scripts/*.sh | grep "SC2034"

# Bypass validation (emergency only)
git commit --no-verify

# Reset configuration
git checkout .shellcheckrc
```

---

**Remember**: ShellCheck validation ensures script reliability and maintainability. Fix issues promptly to maintain project quality! 🔧

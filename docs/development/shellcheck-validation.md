# ShellCheck Validation Guide

This guide covers shell script quality standards, ShellCheck validation processes, and best practices for maintaining high-quality shell scripts in the N8N-R8 project.

## Overview

All shell scripts in this project must pass ShellCheck validation with zero errors. This ensures:

- **Syntax correctness** across different shell environments
- **Proper variable usage** and scope management
- **Source file resolution** for script dependencies
- **Best practice compliance** for maintainable code

## Quick Validation

### Run All Validations

```bash
# Comprehensive validation (recommended)
./tests/run_tests.sh

# Syntax validation only
./scripts/validate_syntax.sh

# ShellCheck validation for specific script
shellcheck scripts/start-nginx.sh
```

### Pre-commit Validation

ShellCheck validation runs automatically before commits:

```bash
# Manual pre-commit check
git add scripts/my-script.sh
git commit -m "Add new script"
# ShellCheck validation runs automatically
```

## ShellCheck Configuration

### Project Configuration

The project uses `.shellcheckrc` for consistent validation:

```bash
# .shellcheckrc
# Disable specific checks that don't apply to our use case
disable=SC2034  # Unused variables (handled by exports)
disable=SC1091  # Source file resolution (handled by directives)

# Enable external source following
external-sources=true

# Set shell dialect
shell=bash
```

### Source Path Configuration

ShellCheck is configured with proper source paths for validation:

```bash
# CI configuration uses source-path option
shellcheck --source-path=tests/helpers --source-path=tests scripts/*.sh
```

## Shell Script Best Practices

### 1. Shebang Lines

All shell scripts must start with proper shebang:

```bash
#!/bin/bash
# Preferred for Bash-specific features

#!/bin/sh
# Use for POSIX-compliant scripts
```

### 2. Source Directives

Use explicit ShellCheck source directives for external files:

```bash
# shellcheck source=../helpers/test_helpers.sh
source "$SCRIPT_DIR/../helpers/test_helpers.sh"

# shellcheck source=../test_config.sh
source "$SCRIPT_DIR/../test_config.sh"
```

### 3. Variable Management

#### Export Variables for External Use

```bash
# In helper scripts - export variables used by other scripts
export GREEN='\033[0;32m'
export RED='\033[0;31m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export NC='\033[0m'
```

#### Document Variable Usage

```bash
# Color variables for output formatting
# These are exported for use by test scripts that source this file
export GREEN='\033[0;32m'  # Success messages
export RED='\033[0;31m'    # Error messages
export YELLOW='\033[1;33m' # Warning messages
```

#### Handle Unused Variables

```bash
# For intentionally unused variables
# shellcheck disable=SC2034
DEBUG_MODE=false  # Used by sourcing scripts

# Or use underscore prefix for internal variables
_internal_var="value"
```

### 4. Error Handling

#### Robust Source Loading

```bash
# shellcheck source=../helpers/test_helpers.sh
if ! source "$SCRIPT_DIR/../helpers/test_helpers.sh" 2>/dev/null; then
    echo "Warning: Could not source test helpers"
    # Provide fallback functions
    log_info() { echo "[INFO] $*"; }
    log_error() { echo "[ERROR] $*"; }
fi
```

#### Exit on Errors

```bash
#!/bin/bash
set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Or for specific sections
set -e
critical_operation
set +e  # Disable for non-critical operations
```

### 5. Function Definitions

```bash
# Proper function syntax
function_name() {
    local param1="$1"
    local param2="${2:-default_value}"

    # Function body
    echo "Processing: $param1"
    return 0
}
```

### 6. Conditional Statements

```bash
# Proper conditional syntax
if [[ -f "$file" ]]; then
    echo "File exists"
elif [[ -d "$file" ]]; then
    echo "Directory exists"
else
    echo "Path does not exist"
fi
```

## Common ShellCheck Issues and Solutions

### SC1090/SC1091: Source Path Issues

**Problem**: ShellCheck cannot follow non-constant source paths

```bash
# Problematic
source "$SCRIPT_DIR/helpers.sh"
```

**Solution**: Add explicit source directive

```bash
# shellcheck source=helpers/test_helpers.sh
source "$SCRIPT_DIR/helpers.sh"
```

### SC2034: Unused Variables

**Problem**: Variables defined but not used in current scope

```bash
# Problematic
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

### SC2148: Missing Shebang

**Problem**: Script missing shebang line

```bash
# Problematic - no shebang
echo "Hello World"
```

**Solution**: Add appropriate shebang

```bash
#!/bin/bash
echo "Hello World"
```

### SC1036/SC1088: Syntax Errors

**Problem**: Malformed syntax (missing braces, quotes, etc.)

```bash
# Problematic
if [ $var = "value" {
    echo "matched"
```

**Solution**: Fix syntax

```bash
if [[ "$var" = "value" ]]; then
    echo "matched"
fi
```

## Validation Workflow

### 1. Development Phase

```bash
# Before committing changes
./scripts/validate_syntax.sh

# Fix any issues reported
shellcheck scripts/my-script.sh

# Test script execution
bash -n scripts/my-script.sh  # Syntax check
./scripts/my-script.sh        # Execution test
```

### 2. Pre-commit Validation

The pre-commit hook automatically runs ShellCheck on modified scripts:

```bash
# Hook location: .git/hooks/pre-commit
# Validates all staged .sh files
# Prevents commit if validation fails
```

### 3. CI/CD Validation

GitHub Actions runs comprehensive validation:

```yaml
# .github/workflows/ci.yml
- name: Lint shell scripts
  run: |
    find . -name "*.sh" -type f -not -path "*/node_modules/*" | \
    xargs shellcheck --source-path=tests/helpers --source-path=tests
```

### 4. Regression Testing

Automated tests prevent reintroduction of issues:

```bash
# Run regression tests
./tests/unit/test_shellcheck_regression.sh

# Validates all previously fixed issues remain resolved
```

## Troubleshooting

### ShellCheck Installation

```bash
# Ubuntu/Debian
sudo apt-get install shellcheck

# macOS
brew install shellcheck

# Windows (WSL)
sudo apt-get install shellcheck
```

### Common Validation Failures

#### Source Path Not Found

```bash
# Error: shellcheck: can't find source file
# Solution: Check source directive path
# shellcheck source=correct/path/to/file.sh
```

#### Variable Scope Issues

```bash
# Error: variable used but not defined
# Solution: Check variable exports and source order
export REQUIRED_VAR="value"
```

#### Syntax Parsing Errors

```bash
# Error: syntax error in script
# Solution: Run bash syntax check first
bash -n problematic-script.sh
```

### Debugging ShellCheck Issues

```bash
# Verbose ShellCheck output
shellcheck -f gcc scripts/my-script.sh

# Check specific error codes
shellcheck -e SC2034 scripts/my-script.sh

# Ignore specific checks (use sparingly)
# shellcheck disable=SC2034
```

## Integration with Development Tools

### VS Code Integration

Install the ShellCheck extension:

```json
// .vscode/settings.json
{
  "shellcheck.enable": true,
  "shellcheck.executablePath": "shellcheck",
  "shellcheck.run": "onType"
}
```

### Vim Integration

Add to `.vimrc`:

```vim
" ShellCheck integration
let g:syntastic_sh_checkers = ['shellcheck']
let g:syntastic_sh_shellcheck_args = '--source-path=tests/helpers'
```

### Pre-commit Hook Setup

```bash
# Install pre-commit hook
cp scripts/pre-commit-shellcheck .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
```

## Best Practices Summary

### ✅ Do

- **Always use proper shebang lines** (`#!/bin/bash`)
- **Add shellcheck source directives** for external files
- **Export variables** used by other scripts
- **Use proper error handling** (`set -euo pipefail`)
- **Test scripts locally** before committing
- **Document variable usage** with comments
- **Use consistent formatting** and indentation

### ❌ Don't

- **Commit scripts with ShellCheck errors**
- **Use non-constant source paths** without directives
- **Define unused variables** without documentation
- **Skip syntax validation** during development
- **Ignore ShellCheck warnings** without good reason
- **Use complex regex** without proper escaping
- **Mix shell dialects** (bash vs sh) inconsistently

## Resources

- [ShellCheck Official Documentation](https://github.com/koalaman/shellcheck)
- [ShellCheck Error Codes](https://github.com/koalaman/shellcheck/wiki)
- [Bash Best Practices](https://mywiki.wooledge.org/BashGuide/Practices)
- [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html)

## Support

For questions about shell script validation:

1. **Check this guide** for common issues and solutions
2. **Run validation tools** to identify specific problems
3. **Review ShellCheck output** for detailed error explanations
4. **Open an issue** if you encounter project-specific validation problems

---

**Remember**: High-quality shell scripts make the entire project more reliable and maintainable! 🚀

# Shell Script Standards and Configuration

This document outlines the shell script standards, ShellCheck configuration, and validation processes used in the N8N-R8 project.

## Overview

The N8N-R8 project maintains high shell script quality through:

- **ShellCheck validation** with zero-error policy
- **Standardized configuration** via `.shellcheckrc`
- **Automated validation** in CI/CD pipeline
- **Pre-commit hooks** for early error detection
- **Comprehensive testing** for script reliability

## ShellCheck Configuration

### Project Configuration File

The project uses `.shellcheckrc` for consistent validation across all environments:

```bash
# .shellcheckrc - ShellCheck configuration for n8n-r8 project

# Exclude directories that don't contain shell scripts we want to validate
exclude-dir=node_modules
exclude-dir=data
exclude-dir=.git
exclude-dir=logs/watchtower

# Enable external source following to resolve source directives
external-sources=true

# Set source path for resolving relative includes
source-path=SCRIPTDIR
source-path=tests
source-path=tests/helpers
source-path=scripts

# Disable specific checks that are not relevant for this project
# SC1008: This shebang was unrecognized (we use various shells)
# SC2312: Consider invoking this command separately (acceptable for simple cases)
disable=SC1008,SC2312

# Set shell dialect (bash is primary shell used in project)
shell=bash

# Enable all severity levels for comprehensive checking
severity=style
```

### Configuration Explanation

#### Source Path Resolution

```bash
source-path=SCRIPTDIR  # Resolve paths relative to script location
source-path=tests      # Allow resolution of test-related includes
source-path=tests/helpers  # Specific path for helper functions
source-path=scripts    # Allow cross-script sourcing
```

This configuration enables ShellCheck to:

- Follow source statements with relative paths
- Validate cross-script dependencies
- Resolve helper function includes
- Check test script sourcing

#### External Sources

```bash
external-sources=true
```

Enables ShellCheck to:

- Follow source directives in comments
- Validate sourced file contents
- Check function and variable usage across files
- Detect undefined functions and variables

#### Disabled Checks

```bash
disable=SC1008,SC2312
```

- **SC1008**: Allows various shebang formats (bash, sh, etc.)
- **SC2312**: Permits simple command chaining for readability

## Validation Process

### 1. Local Development Validation

#### Manual Validation

```bash
# Validate all shell scripts
./scripts/validate_syntax.sh

# Validate specific script
shellcheck scripts/start-nginx.sh

# Comprehensive test suite (includes ShellCheck)
./tests/run_tests.sh
```

#### Editor Integration

**VS Code Configuration**:

```json
{
  "shellcheck.enable": true,
  "shellcheck.executablePath": "shellcheck",
  "shellcheck.run": "onType",
  "shellcheck.useWorkspaceRootAsCwd": true
}
```

**Vim Configuration**:

```vim
let g:syntastic_sh_checkers = ['shellcheck']
let g:syntastic_sh_shellcheck_args = '--source-path=tests/helpers --source-path=tests'
```

### 2. Pre-commit Validation

The project includes pre-commit hooks that automatically validate shell scripts:

```bash
#!/bin/bash
# .git/hooks/pre-commit

# Get list of staged shell scripts
staged_files=$(git diff --cached --name-only --diff-filter=ACM | grep '\.sh$')

if [[ -n "$staged_files" ]]; then
    echo "Running ShellCheck validation on staged files..."

    # Run ShellCheck on staged files
    if ! echo "$staged_files" | xargs shellcheck; then
        echo "❌ ShellCheck validation failed!"
        echo "Please fix the issues above before committing."
        exit 1
    fi

    echo "✅ ShellCheck validation passed!"
fi
```

### 3. CI/CD Pipeline Validation

GitHub Actions workflow includes comprehensive shell script validation:

```yaml
# .github/workflows/ci.yml
name: Shell Script Validation

jobs:
  shellcheck:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install ShellCheck
        run: |
          sudo apt-get update
          sudo apt-get install -y shellcheck

      - name: Validate shell scripts
        run: |
          find . -name "*.sh" -type f -not -path "*/node_modules/*" | \
          xargs shellcheck --source-path=tests/helpers --source-path=tests

      - name: Run syntax validation script
        run: ./scripts/validate_syntax.sh

      - name: Run comprehensive test suite
        run: ./tests/run_tests.sh
```

### 4. Regression Testing

Automated tests ensure previously fixed issues don't reoccur:

```bash
# tests/unit/test_shellcheck_regression.sh
test_shellcheck_compliance() {
    local script_count=0
    local error_count=0

    while IFS= read -r -d '' script; do
        ((script_count++))
        if ! shellcheck "$script" >/dev/null 2>&1; then
            ((error_count++))
            echo "❌ ShellCheck failed: $script"
        fi
    done < <(find . -name "*.sh" -type f -not -path "*/node_modules/*" -print0)

    echo "Validated $script_count scripts, $error_count errors"
    return $error_count
}
```

## Script Standards

### 1. File Structure

#### Shebang Requirements

```bash
#!/bin/bash
# Use for Bash-specific features (arrays, [[ ]], etc.)

#!/bin/sh
# Use for POSIX-compliant scripts
```

#### Header Template

```bash
#!/bin/bash
#
# Script Name: start-nginx.sh
# Description: Start N8N with Nginx proxy configuration
# Author: N8N-R8 Project
# Version: 1.0
# Usage: ./scripts/start-nginx.sh [options]
#

set -euo pipefail  # Exit on error, undefined vars, pipe failures
```

### 2. Source Management

#### Source Directives

```bash
# Always include shellcheck source directive before sourcing
# shellcheck source=../helpers/test_helpers.sh
source "$SCRIPT_DIR/../helpers/test_helpers.sh"

# For conditional sourcing
# shellcheck source=../test_config.sh
if [[ -f "$SCRIPT_DIR/../test_config.sh" ]]; then
    source "$SCRIPT_DIR/../test_config.sh"
fi
```

#### Error Handling for Sources

```bash
# Robust source loading with fallback
# shellcheck source=../helpers/test_helpers.sh
if ! source "$SCRIPT_DIR/../helpers/test_helpers.sh" 2>/dev/null; then
    echo "Warning: Could not source test helpers, using fallback functions"

    # Provide minimal fallback functions
    log_info() { echo "[INFO] $*"; }
    log_error() { echo "[ERROR] $*" >&2; }
    log_success() { echo "[SUCCESS] $*"; }
fi
```

### 3. Variable Management

#### Export Strategy

```bash
# In helper scripts - export variables for external use
# Color variables for output formatting
export GREEN='\033[0;32m'   # Success messages
export RED='\033[0;31m'     # Error messages
export YELLOW='\033[1;33m'  # Warning messages
export BLUE='\033[0;34m'    # Info messages
export NC='\033[0m'         # No color (reset)
```

#### Local Variables

```bash
function process_data() {
    local input_file="$1"
    local output_dir="${2:-./output}"
    local temp_file

    temp_file=$(mktemp)
    # Process data...
    rm "$temp_file"
}
```

#### Unused Variables

```bash
# For intentionally unused variables, document the reason
# shellcheck disable=SC2034
DEBUG_MODE=false  # Used by sourcing scripts for conditional logging

# Or use underscore prefix for internal variables
_internal_counter=0
```

### 4. Function Standards

#### Function Definition

```bash
# Preferred function syntax
function_name() {
    local param1="$1"
    local param2="${2:-default_value}"

    # Validate parameters
    if [[ -z "$param1" ]]; then
        echo "Error: param1 is required" >&2
        return 1
    fi

    # Function logic
    echo "Processing: $param1"
    return 0
}
```

#### Error Handling

```bash
safe_operation() {
    local file="$1"

    # Check prerequisites
    if [[ ! -f "$file" ]]; then
        log_error "File not found: $file"
        return 1
    fi

    # Perform operation with error handling
    if ! cp "$file" "$file.backup"; then
        log_error "Failed to create backup of $file"
        return 1
    fi

    log_success "Successfully backed up $file"
    return 0
}
```

### 5. Conditional Logic

#### Test Constructs

```bash
# Use [[ ]] for Bash scripts (more features, safer)
if [[ -f "$file" && -r "$file" ]]; then
    echo "File exists and is readable"
fi

# Use [ ] for POSIX compliance
if [ -f "$file" ] && [ -r "$file" ]; then
    echo "File exists and is readable"
fi
```

#### String Comparisons

```bash
# Always quote variables in comparisons
if [[ "$var" = "expected_value" ]]; then
    echo "Match found"
fi

# Pattern matching
if [[ "$filename" == *.sh ]]; then
    echo "Shell script detected"
fi
```

## Validation Tools

### 1. Syntax Validation Script

The project includes `scripts/validate_syntax.sh` for comprehensive validation:

```bash
#!/bin/bash
# scripts/validate_syntax.sh

validate_all_scripts() {
    local script_count=0
    local error_count=0

    echo "🔍 Validating shell scripts..."

    while IFS= read -r -d '' script; do
        ((script_count++))
        echo -n "Checking $script... "

        # Run ShellCheck
        if shellcheck "$script" >/dev/null 2>&1; then
            echo "✅"
        else
            echo "❌"
            ((error_count++))
            echo "ShellCheck errors in $script:"
            shellcheck "$script"
            echo
        fi

        # Run syntax check
        if ! bash -n "$script" 2>/dev/null; then
            echo "❌ Syntax error in $script"
            ((error_count++))
        fi

    done < <(find . -name "*.sh" -type f -not -path "*/node_modules/*" -print0)

    echo
    echo "📊 Validation Summary:"
    echo "   Scripts checked: $script_count"
    echo "   Errors found: $error_count"

    if [[ $error_count -eq 0 ]]; then
        echo "✅ All scripts passed validation!"
        return 0
    else
        echo "❌ $error_count scripts failed validation"
        return 1
    fi
}

# Run validation
validate_all_scripts
```

### 2. Test Integration

ShellCheck validation is integrated into the test suite:

```bash
# tests/validation/test_shellcheck_compliance.sh

test_shellcheck_all_scripts() {
    echo "Testing ShellCheck compliance for all shell scripts..."

    local failed_scripts=()

    while IFS= read -r -d '' script; do
        if ! shellcheck "$script" >/dev/null 2>&1; then
            failed_scripts+=("$script")
        fi
    done < <(find . -name "*.sh" -type f -not -path "*/node_modules/*" -print0)

    if [[ ${#failed_scripts[@]} -eq 0 ]]; then
        log_success "All scripts pass ShellCheck validation"
        return 0
    else
        log_error "ShellCheck validation failed for:"
        printf '  - %s\n' "${failed_scripts[@]}"
        return 1
    fi
}
```

## Performance Considerations

### 1. Validation Speed

```bash
# Parallel validation for large projects
find . -name "*.sh" -type f -not -path "*/node_modules/*" | \
xargs -P 4 -I {} shellcheck {}

# Incremental validation (only changed files)
git diff --name-only HEAD~1 | grep '\.sh$' | xargs shellcheck
```

### 2. CI Optimization

```bash
# Cache ShellCheck installation in CI
- name: Cache ShellCheck
  uses: actions/cache@v3
  with:
    path: ~/.local/bin/shellcheck
    key: shellcheck-${{ runner.os }}-v0.8.0

# Use specific ShellCheck version for consistency
- name: Install ShellCheck
  run: |
    wget -qO- "https://github.com/koalaman/shellcheck/releases/download/v0.8.0/shellcheck-v0.8.0.linux.x86_64.tar.xz" | tar -xJv
    sudo cp "shellcheck-v0.8.0/shellcheck" /usr/local/bin/
```

## Maintenance

### 1. Regular Updates

```bash
# Update ShellCheck configuration
# Review and update .shellcheckrc quarterly
# Check for new ShellCheck versions
# Update CI configuration as needed
```

### 2. Monitoring

```bash
# Monitor validation performance
time ./scripts/validate_syntax.sh

# Track error trends
git log --oneline --grep="shellcheck" --since="1 month ago"

# Review disabled checks periodically
grep "disable=" .shellcheckrc
```

### 3. Documentation Updates

- Update this document when standards change
- Maintain troubleshooting guide with new issues
- Document any project-specific exceptions
- Keep examples current with actual code

## Resources

- **ShellCheck Documentation**: https://github.com/koalaman/shellcheck
- **Bash Best Practices**: https://mywiki.wooledge.org/BashGuide/Practices
- **Google Shell Style Guide**: https://google.github.io/styleguide/shellguide.html
- **Project Validation Guide**: [docs/development/shellcheck-validation.md](shellcheck-validation.md)
- **Troubleshooting Guide**: [docs/troubleshooting/shellcheck-issues.md](../troubleshooting/shellcheck-issues.md)

---

**Maintaining high shell script standards ensures reliable, maintainable, and portable code across all environments! 🚀**

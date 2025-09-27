#!/bin/bash

# N8N-R8 Syntax Validation Script
# Comprehensive validation for all shell scripts in the project
# Provides local development validation with shellcheck integration

set -euo pipefail

# Script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SHELLCHECK_SEVERITY="error"
SHELLCHECK_FORMAT="gcc"
AUTO_FIX=false
QUIET_MODE=false
VERBOSE_MODE=false
EXIT_ON_FIRST_ERROR=false

# Statistics
TOTAL_FILES=0
PASSED_FILES=0
FAILED_FILES=0
FIXED_FILES=0

# Logging functions
log_info() {
    [[ "$QUIET_MODE" == "true" ]] && return
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    [[ "$QUIET_MODE" == "true" ]] && return
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

log_debug() {
    [[ "$VERBOSE_MODE" == "true" ]] || return
    echo -e "${BLUE}[DEBUG]${NC} $*"
}

# Show usage information
usage() {
    cat << EOF
Usage: $0 [OPTIONS] [PATH...]

N8N-R8 Syntax Validation Script
Validates shell scripts for syntax errors and shellcheck compliance.

OPTIONS:
    -h, --help              Show this help message
    -q, --quiet             Quiet mode (minimal output)
    -v, --verbose           Verbose mode (detailed output)
    -f, --fix               Automatically fix common issues
    -s, --severity LEVEL    Set shellcheck severity (error|warning|info|style)
    -e, --exit-on-error     Exit on first error encountered
    --format FORMAT         Set shellcheck output format (gcc|json|tty)
    --exclude CODES         Comma-separated list of shellcheck codes to exclude

PATHS:
    If no paths specified, validates all shell scripts in the project.
    Paths can be files or directories.

EXAMPLES:
    $0                      # Validate all shell scripts
    $0 -f                   # Validate and auto-fix issues
    $0 -q scripts/          # Quietly validate scripts directory
    $0 -v --severity warning tests/  # Verbose validation with warnings
    $0 --exclude SC2034,SC1091 file.sh  # Exclude specific checks

EXIT CODES:
    0   All validations passed
    1   Validation errors found
    2   Script execution error
    3   Missing dependencies
EOF
}

# Check if required tools are available
check_dependencies() {
    local missing_deps=()
    
    if ! command -v shellcheck >/dev/null 2>&1; then
        missing_deps+=("shellcheck")
    fi
    
    if ! command -v bash >/dev/null 2>&1; then
        missing_deps+=("bash")
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Missing required dependencies: ${missing_deps[*]}"
        log_error "Please install missing tools and try again"
        return 3
    fi
    
    log_debug "All dependencies available"
    return 0
}

# Find all shell scripts in the project
find_shell_scripts() {
    local search_paths=("$@")
    
    # Default to project root if no paths specified
    if [[ ${#search_paths[@]} -eq 0 ]]; then
        search_paths=("$PROJECT_ROOT")
    fi
    
    local scripts=()
    
    for path in "${search_paths[@]}"; do
        if [[ -f "$path" ]]; then
            # Single file
            if is_shell_script "$path"; then
                scripts+=("$path")
            fi
        elif [[ -d "$path" ]]; then
            # Directory - find all shell scripts
            while IFS= read -r script; do
                [[ -n "$script" ]] && scripts+=("$script")
            done < <(find "$path" -type f \( -name "*.sh" -o -name "*.bash" \) \
                     -not -path "*/node_modules/*" \
                     -not -path "*/data/*" \
                     -not -path "*/.git/*")
        else
            log_warning "Path not found: $path"
        fi
    done
    
    printf '%s\n' "${scripts[@]}"
}

# Check if a file is a shell script
is_shell_script() {
    local file="$1"
    
    # Check file extension
    if [[ "$file" =~ \.(sh|bash)$ ]]; then
        return 0
    fi
    
    # Check shebang
    if [[ -f "$file" && -r "$file" ]]; then
        local first_line
        first_line=$(head -n1 "$file" 2>/dev/null || echo "")
        if [[ "$first_line" =~ ^#!.*/(bash|sh)$ ]]; then
            return 0
        fi
    fi
    
    return 1
}

# Validate syntax of a single shell script
validate_script_syntax() {
    local script="$1"
    
    log_debug "Validating syntax: $script"
    
    # Check if file exists and is readable
    if [[ ! -f "$script" ]]; then
        log_error "File not found: $script"
        return 1
    fi
    
    if [[ ! -r "$script" ]]; then
        log_error "File not readable: $script"
        return 1
    fi
    
    # Check bash syntax
    local syntax_output
    if syntax_output=$(bash -n "$script" 2>&1); then
        log_debug "Syntax check passed for: $script"
        return 0
    else
        log_error "Syntax error in: $script"
        if [[ "$VERBOSE_MODE" == "true" && -n "$syntax_output" ]]; then
            echo "$syntax_output"
        fi
        return 1
    fi
}

# Run shellcheck on a script
validate_script_shellcheck() {
    local script="$1"
    local shellcheck_args=()
    
    log_debug "Running shellcheck: $script"
    
    # Build shellcheck arguments
    shellcheck_args+=("--severity=$SHELLCHECK_SEVERITY")
    shellcheck_args+=("--format=$SHELLCHECK_FORMAT")
    shellcheck_args+=("--source-path=$PROJECT_ROOT")
    shellcheck_args+=("-x")  # Follow external sources
    
    # Add exclude codes if specified
    if [[ -n "${SHELLCHECK_EXCLUDE:-}" ]]; then
        shellcheck_args+=("--exclude=$SHELLCHECK_EXCLUDE")
    fi
    
    # Run shellcheck and capture output
    local shellcheck_output
    if shellcheck_output=$(shellcheck "${shellcheck_args[@]}" "$script" 2>&1); then
        log_debug "Shellcheck passed for: $script"
        return 0
    else
        log_debug "Shellcheck failed for: $script"
        if [[ "$VERBOSE_MODE" == "true" && -n "$shellcheck_output" ]]; then
            echo "$shellcheck_output"
        fi
        return 1
    fi
}

# Attempt to automatically fix common issues
auto_fix_script() {
    local script="$1"
    local fixed=false
    
    log_debug "Attempting auto-fix: $script"
    
    # Create backup
    local backup
    backup="${script}.backup.$(date +%s)"
    cp "$script" "$backup"
    
    # Fix missing shebang
    if ! head -n1 "$script" | grep -q "^#!"; then
        log_debug "Adding missing shebang to: $script"
        # Create temporary file with shebang and original content
        local temp_file="${script}.tmp"
        {
            echo "#!/bin/bash"
            echo ""
            cat "$script"
        } > "$temp_file"
        if [[ -f "$temp_file" ]]; then
            mv "$temp_file" "$script"
            fixed=true
        fi
    fi
    
    # Fix common shellcheck issues
    # SC2034: Variable appears unused - add export to uppercase variables
    if grep -q "^[[:space:]]*[A-Z_][A-Z0-9_]*=" "$script"; then
        log_debug "Adding export to variables in: $script"
        # Use a temporary file for sed operations
        sed 's/^[[:space:]]*\([A-Z_][A-Z0-9_]*=\)/export \1/' "$script" > "${script}.tmp"
        if [[ -f "${script}.tmp" ]]; then
            mv "${script}.tmp" "$script"
            fixed=true
        fi
    fi
    
    if [[ "$fixed" == "true" ]]; then
        log_info "Applied automatic fixes to: $script"
        log_info "Backup created: $backup"
        FIXED_FILES=$((FIXED_FILES + 1))
        return 0
    else
        # Remove backup if no changes made
        rm "$backup"
        return 1
    fi
}

# Validate a single script
validate_single_script() {
    local script="$1"
    local script_errors=0
    
    TOTAL_FILES=$((TOTAL_FILES + 1))
    
    if [[ "$VERBOSE_MODE" == "true" ]]; then
        log_info "Validating: $script"
    fi
    
    # Syntax validation
    log_debug "Running syntax check on: $script"
    if validate_script_syntax "$script"; then
        log_debug "Syntax validation passed for: $script"
    else
        script_errors=$((script_errors + 1))
        log_debug "Syntax validation failed for: $script"
    fi
    
    # Shellcheck validation
    log_debug "Running shellcheck on: $script"
    if validate_script_shellcheck "$script"; then
        log_debug "Shellcheck validation passed for: $script"
    else
        script_errors=$((script_errors + 1))
        log_debug "Shellcheck validation failed for: $script"
        
        # Attempt auto-fix if enabled
        if [[ "$AUTO_FIX" == "true" ]]; then
            if auto_fix_script "$script"; then
                log_info "Auto-fixed issues in: $script"
                # Re-validate after fixes
                if validate_script_shellcheck "$script"; then
                    script_errors=$((script_errors - 1))
                fi
            fi
        fi
    fi
    
    if [[ $script_errors -eq 0 ]]; then
        PASSED_FILES=$((PASSED_FILES + 1))
        [[ "$VERBOSE_MODE" == "true" ]] && log_success "✓ $script"
        return 0
    else
        FAILED_FILES=$((FAILED_FILES + 1))
        log_error "✗ $script ($script_errors errors)"
        
        if [[ "$EXIT_ON_FIRST_ERROR" == "true" ]]; then
            log_error "Exiting on first error as requested"
            exit 1
        fi
        
        return 1
    fi
}

# Print validation summary
print_summary() {
    echo
    echo "=================================="
    echo "Syntax Validation Summary"
    echo "=================================="
    echo "Total files:    $TOTAL_FILES"
    echo "Passed:         $PASSED_FILES"
    echo "Failed:         $FAILED_FILES"
    
    if [[ "$AUTO_FIX" == "true" ]]; then
        echo "Auto-fixed:     $FIXED_FILES"
    fi
    
    echo
    
    if [[ $FAILED_FILES -eq 0 ]]; then
        log_success "All shell scripts passed validation!"
        return 0
    else
        log_error "$FAILED_FILES shell script(s) failed validation"
        return 1
    fi
}

# Main validation function
main() {
    local paths=()
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                exit 0
                ;;
            -q|--quiet)
                QUIET_MODE=true
                shift
                ;;
            -v|--verbose)
                VERBOSE_MODE=true
                shift
                ;;
            -f|--fix)
                AUTO_FIX=true
                shift
                ;;
            -s|--severity)
                SHELLCHECK_SEVERITY="$2"
                shift 2
                ;;
            -e|--exit-on-error)
                EXIT_ON_FIRST_ERROR=true
                shift
                ;;
            --format)
                SHELLCHECK_FORMAT="$2"
                shift 2
                ;;
            --exclude)
                SHELLCHECK_EXCLUDE="$2"
                shift 2
                ;;
            -*)
                log_error "Unknown option: $1"
                usage
                exit 2
                ;;
            *)
                paths+=("$1")
                shift
                ;;
        esac
    done
    
    # Check dependencies
    if ! check_dependencies; then
        exit 3
    fi
    
    log_info "Starting shell script validation..."
    [[ "$AUTO_FIX" == "true" ]] && log_info "Auto-fix mode enabled"
    
    # Find scripts to validate
    local scripts
    mapfile -t scripts < <(find_shell_scripts "${paths[@]}")
    
    if [[ ${#scripts[@]} -eq 0 ]]; then
        log_warning "No shell scripts found to validate"
        exit 0
    fi
    
    log_info "Found ${#scripts[@]} shell script(s) to validate"
    
    # Validate each script
    for script in "${scripts[@]}"; do
        log_debug "About to validate script: $script"
        validate_single_script "$script"
        log_debug "Finished validating script: $script"
    done
    
    # Print summary and exit with appropriate code
    if print_summary; then
        exit 0
    else
        exit 1
    fi
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
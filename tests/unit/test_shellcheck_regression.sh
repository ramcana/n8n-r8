#!/bin/bash

# ShellCheck Regression Test Suite for N8N-R8
# Prevents future syntax errors by validating each fixed shellcheck issue remains resolved
# Focuses on regression testing for SC1090, SC1091, SC2034, and other critical errors

set -euo pipefail

# Get script directory and source helpers with error handling
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source test helpers with comprehensive error handling
# shellcheck source=../helpers/test_helpers.sh
if ! source "$SCRIPT_DIR/../helpers/test_helpers.sh" 2>/dev/null; then
    echo "CRITICAL ERROR: Cannot load test helpers from $SCRIPT_DIR/../helpers/test_helpers.sh"
    echo "This file is required for regression test execution. Please check:"
    echo "  1. File exists and is readable: $SCRIPT_DIR/../helpers/test_helpers.sh"
    echo "  2. File permissions allow execution"
    echo "  3. File syntax is correct"
    echo ""
    echo "Providing minimal fallback functions for basic operation..."
    
    # Essential fallback functions for regression tests
    log_info() { echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') $*"; }
    log_error() { echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') $*" >&2; }
    log_warning() { echo "[WARNING] $(date '+%Y-%m-%d %H:%M:%S') $*"; }
    log_success() { echo "[SUCCESS] $(date '+%Y-%m-%d %H:%M:%S') $*"; }
    
    # Basic assertion functions
    assert_command_success() {
        local command="$1"
        local message="${2:-Command should succeed}"
        if eval "$command" >/dev/null 2>&1; then
            log_info "✓ $message"
            return 0
        else
            log_error "✗ $message: $command"
            return 1
        fi
    }
    
    assert_equals() {
        local expected="$1"
        local actual="$2"
        local message="${3:-Values should be equal}"
        if [[ "$expected" == "$actual" ]]; then
            log_info "✓ $message"
            return 0
        else
            log_error "✗ $message: expected '$expected', got '$actual'"
            return 1
        fi
    }
    
    log_warning "Using fallback functions. Some advanced test features may not be available."
fi

# Source test configuration with error handling
# shellcheck source=../test_config.sh
if ! source "$SCRIPT_DIR/../test_config.sh" 2>/dev/null; then
    log_warning "Cannot load test configuration from $SCRIPT_DIR/../test_config.sh"
    log_info "Using default configuration for regression tests"
    
    # Set essential defaults for regression tests
    TEST_TIMEOUT=${TEST_TIMEOUT:-60}
    PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
    
    log_info "Using defaults: TEST_TIMEOUT=$TEST_TIMEOUT, PROJECT_ROOT=$PROJECT_ROOT"
fi

# Project root directory
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

# Test configuration
SHELLCHECK_TIMEOUT=30
REGRESSION_TEST_SCRIPTS=(
    "tests/integration/test_deployment.sh"
    "tests/unit/test_backup.sh"
    "tests/validation/validate_environment.sh"
    "tests/run_tests.sh"
    "tests/helpers/test_helpers.sh"
    "tests/validation/test_shellcheck_compliance.sh"
)

# Validate regression test environment
validate_regression_test_environment() {
    local validation_errors=()
    
    # Check if shellcheck is available
    if ! command -v shellcheck >/dev/null 2>&1; then
        validation_errors+=("ShellCheck is not installed - required for regression tests")
    fi
    
    # Check PROJECT_ROOT
    if [[ -z "${PROJECT_ROOT:-}" ]]; then
        validation_errors+=("PROJECT_ROOT variable is not set")
    elif [[ ! -d "$PROJECT_ROOT" ]]; then
        validation_errors+=("PROJECT_ROOT directory does not exist: $PROJECT_ROOT")
    fi
    
    # Check .shellcheckrc exists
    if [[ ! -f "$PROJECT_ROOT/.shellcheckrc" ]]; then
        validation_errors+=("ShellCheck configuration file missing: $PROJECT_ROOT/.shellcheckrc")
    fi
    
    # Check test scripts exist
    for script in "${REGRESSION_TEST_SCRIPTS[@]}"; do
        if [[ ! -f "$PROJECT_ROOT/$script" ]]; then
            validation_errors+=("Regression test script missing: $PROJECT_ROOT/$script")
        fi
    done
    
    # Report validation results
    if [[ ${#validation_errors[@]} -gt 0 ]]; then
        log_error "Regression test environment validation failed:"
        for error in "${validation_errors[@]}"; do
            log_error "  - $error"
        done
        return 1
    fi
    
    log_info "Regression test environment validation passed"
    return 0
}

# Test that SC1090 errors are resolved (source path following)
test_sc1090_regression() {
    log_info "Testing SC1090 regression - source path following errors should not exist"
    
    local sc1090_errors
    sc1090_errors=$(find "$PROJECT_ROOT" -name "*.sh" -type f \
        -not -path "*/node_modules/*" \
        -not -path "*/data/*" \
        -not -path "*/.git/*" \
        -exec timeout "$SHELLCHECK_TIMEOUT" shellcheck \
            --external-sources \
            --source-path="$PROJECT_ROOT/tests/helpers:$PROJECT_ROOT/tests:$PROJECT_ROOT/scripts" \
            --format=gcc {} \; 2>&1 | grep "SC1090" || true)
    
    if [[ -z "$sc1090_errors" ]]; then
        log_success "✓ No SC1090 errors found - source path following regression test passed"
        return 0
    else
        log_error "✗ SC1090 errors detected - regression test failed"
        echo "$sc1090_errors" | while IFS= read -r line; do
            log_error "  $line"
        done
        return 1
    fi
}

# Test that SC1091 errors are resolved (source file not found)
test_sc1091_regression() {
    log_info "Testing SC1091 regression - source file not found errors should not exist"
    
    local sc1091_errors
    sc1091_errors=$(find "$PROJECT_ROOT" -name "*.sh" -type f \
        -not -path "*/node_modules/*" \
        -not -path "*/data/*" \
        -not -path "*/.git/*" \
        -exec timeout "$SHELLCHECK_TIMEOUT" shellcheck \
            --external-sources \
            --source-path="$PROJECT_ROOT/tests/helpers:$PROJECT_ROOT/tests:$PROJECT_ROOT/scripts" \
            --format=gcc {} \; 2>&1 | grep "SC1091" || true)
    
    if [[ -z "$sc1091_errors" ]]; then
        log_success "✓ No SC1091 errors found - source file resolution regression test passed"
        return 0
    else
        log_error "✗ SC1091 errors detected - regression test failed"
        echo "$sc1091_errors" | while IFS= read -r line; do
            log_error "  $line"
        done
        return 1
    fi
}

# Test that SC2034 errors are resolved (unused variables)
test_sc2034_regression() {
    log_info "Testing SC2034 regression - unused variable errors should not exist"
    
    local sc2034_errors
    sc2034_errors=$(find "$PROJECT_ROOT" -name "*.sh" -type f \
        -not -path "*/node_modules/*" \
        -not -path "*/data/*" \
        -not -path "*/.git/*" \
        -exec timeout "$SHELLCHECK_TIMEOUT" shellcheck \
            --external-sources \
            --source-path="$PROJECT_ROOT/tests/helpers:$PROJECT_ROOT/tests:$PROJECT_ROOT/scripts" \
            --format=gcc {} \; 2>&1 | grep "SC2034" || true)
    
    if [[ -z "$sc2034_errors" ]]; then
        log_success "✓ No SC2034 errors found - unused variable regression test passed"
        return 0
    else
        log_error "✗ SC2034 errors detected - regression test failed"
        echo "$sc2034_errors" | while IFS= read -r line; do
            log_error "  $line"
        done
        return 1
    fi
}

# Test source directive resolution for specific scripts
test_source_directive_resolution_regression() {
    log_info "Testing source directive resolution regression"
    
    local failed_scripts=()
    
    for script in "${REGRESSION_TEST_SCRIPTS[@]}"; do
        local script_path="$PROJECT_ROOT/$script"
        local script_name
        script_name=$(basename "$script")
        
        if [[ ! -f "$script_path" ]]; then
            log_warning "Script not found, skipping: $script"
            continue
        fi
        
        log_info "Checking source directives in: $script_name"
        
        # Check if script has source statements
        if ! grep -q "^[[:space:]]*source\|^[[:space:]]*\." "$script_path"; then
            log_info "No source statements in $script_name - skipping"
            continue
        fi
        
        # Run shellcheck specifically for source resolution
        local shellcheck_output
        if shellcheck_output=$(timeout "$SHELLCHECK_TIMEOUT" shellcheck \
            --external-sources \
            --source-path="$PROJECT_ROOT/tests/helpers:$PROJECT_ROOT/tests:$PROJECT_ROOT/scripts" \
            --format=gcc \
            "$script_path" 2>&1); then
            log_success "✓ Source directive resolution passed: $script_name"
        else
            # Check if the failure is related to source resolution
            if echo "$shellcheck_output" | grep -q -E "(SC1090|SC1091)"; then
                log_error "✗ Source directive resolution failed: $script_name"
                echo "$shellcheck_output" | grep -E "(SC1090|SC1091)" | while IFS= read -r line; do
                    log_error "  $line"
                done
                failed_scripts+=("$script_name")
            else
                log_info "✓ Source directive resolution passed (other issues exist): $script_name"
            fi
        fi
    done
    
    if [[ ${#failed_scripts[@]} -eq 0 ]]; then
        log_success "✓ Source directive resolution regression test passed for all scripts"
        return 0
    else
        log_error "✗ Source directive resolution regression test failed for: ${failed_scripts[*]}"
        return 1
    fi
}

# Test variable usage compliance for color variables
test_variable_usage_compliance_regression() {
    log_info "Testing variable usage compliance regression - color variables should be properly exported"
    
    local test_helpers_path="$PROJECT_ROOT/tests/helpers/test_helpers.sh"
    
    if [[ ! -f "$test_helpers_path" ]]; then
        log_error "Test helpers file not found: $test_helpers_path"
        return 1
    fi
    
    # Check that color variables are exported
    local color_variables=("GREEN" "RED" "YELLOW" "BLUE" "NC")
    local missing_exports=()
    
    for var in "${color_variables[@]}"; do
        if grep -q "^export $var=" "$test_helpers_path"; then
            log_info "✓ Color variable $var is properly exported"
        else
            log_error "✗ Color variable $var is not exported"
            missing_exports+=("$var")
        fi
    done
    
    # Run shellcheck on test_helpers.sh to ensure no SC2034 errors
    local sc2034_in_helpers
    sc2034_in_helpers=$(timeout "$SHELLCHECK_TIMEOUT" shellcheck \
        --external-sources \
        --source-path="$PROJECT_ROOT/tests/helpers:$PROJECT_ROOT/tests" \
        --format=gcc \
        "$test_helpers_path" 2>&1 | grep "SC2034" || true)
    
    if [[ ${#missing_exports[@]} -eq 0 && -z "$sc2034_in_helpers" ]]; then
        log_success "✓ Variable usage compliance regression test passed"
        return 0
    else
        log_error "✗ Variable usage compliance regression test failed"
        if [[ ${#missing_exports[@]} -gt 0 ]]; then
            log_error "  Missing exports: ${missing_exports[*]}"
        fi
        if [[ -n "$sc2034_in_helpers" ]]; then
            log_error "  SC2034 errors in test_helpers.sh:"
            echo "$sc2034_in_helpers" | while IFS= read -r line; do
                log_error "    $line"
            done
        fi
        return 1
    fi
}

# Test that all critical shell scripts pass shellcheck
test_critical_scripts_shellcheck_regression() {
    log_info "Testing critical scripts shellcheck regression"
    
    local failed_scripts=()
    
    for script in "${REGRESSION_TEST_SCRIPTS[@]}"; do
        local script_path="$PROJECT_ROOT/$script"
        local script_name
        script_name=$(basename "$script")
        
        if [[ ! -f "$script_path" ]]; then
            log_warning "Script not found, skipping: $script"
            continue
        fi
        
        log_info "Running shellcheck on critical script: $script_name"
        
        if timeout "$SHELLCHECK_TIMEOUT" shellcheck \
            --external-sources \
            --source-path="$PROJECT_ROOT/tests/helpers:$PROJECT_ROOT/tests:$PROJECT_ROOT/scripts" \
            "$script_path" >/dev/null 2>&1; then
            log_success "✓ ShellCheck passed: $script_name"
        else
            log_error "✗ ShellCheck failed: $script_name"
            failed_scripts+=("$script_name")
        fi
    done
    
    if [[ ${#failed_scripts[@]} -eq 0 ]]; then
        log_success "✓ Critical scripts shellcheck regression test passed"
        return 0
    else
        log_error "✗ Critical scripts shellcheck regression test failed for: ${failed_scripts[*]}"
        return 1
    fi
}

# Test shellcheck configuration compliance
test_shellcheck_config_compliance_regression() {
    log_info "Testing shellcheck configuration compliance regression"
    
    local shellcheckrc_path="$PROJECT_ROOT/.shellcheckrc"
    
    if [[ ! -f "$shellcheckrc_path" ]]; then
        log_error "ShellCheck configuration file missing: $shellcheckrc_path"
        return 1
    fi
    
    # Check required configuration settings
    local required_settings=(
        "external-sources=true"
        "source-path=tests"
        "source-path=tests/helpers"
        "shell=bash"
    )
    
    local missing_settings=()
    
    for setting in "${required_settings[@]}"; do
        if grep -q "$setting" "$shellcheckrc_path"; then
            log_info "✓ Required setting found: $setting"
        else
            log_error "✗ Required setting missing: $setting"
            missing_settings+=("$setting")
        fi
    done
    
    if [[ ${#missing_settings[@]} -eq 0 ]]; then
        log_success "✓ ShellCheck configuration compliance regression test passed"
        return 0
    else
        log_error "✗ ShellCheck configuration compliance regression test failed"
        log_error "  Missing settings: ${missing_settings[*]}"
        return 1
    fi
}

# Test that no new critical shellcheck errors are introduced
test_no_new_critical_errors_regression() {
    log_info "Testing no new critical shellcheck errors regression"
    
    # Define critical error codes that should never appear
    local critical_error_codes=("SC1090" "SC1091" "SC2034" "SC1036" "SC1088" "SC2148")
    local found_critical_errors=()
    
    for error_code in "${critical_error_codes[@]}"; do
        log_info "Checking for critical error code: $error_code"
        
        local errors
        errors=$(find "$PROJECT_ROOT" -name "*.sh" -type f \
            -not -path "*/node_modules/*" \
            -not -path "*/data/*" \
            -not -path "*/.git/*" \
            -exec timeout "$SHELLCHECK_TIMEOUT" shellcheck \
                --external-sources \
                --source-path="$PROJECT_ROOT/tests/helpers:$PROJECT_ROOT/tests:$PROJECT_ROOT/scripts" \
                --format=gcc {} \; 2>&1 | grep "$error_code" || true)
        
        if [[ -n "$errors" ]]; then
            log_error "✗ Critical error $error_code found:"
            echo "$errors" | head -5 | while IFS= read -r line; do
                log_error "  $line"
            done
            found_critical_errors+=("$error_code")
        else
            log_success "✓ No $error_code errors found"
        fi
    done
    
    if [[ ${#found_critical_errors[@]} -eq 0 ]]; then
        log_success "✓ No new critical errors regression test passed"
        return 0
    else
        log_error "✗ Critical errors found: ${found_critical_errors[*]}"
        return 1
    fi
}

# Run all regression tests
run_regression_test_suite() {
    log_info "Running ShellCheck regression test suite"
    
    # Validate environment first
    if ! validate_regression_test_environment; then
        log_error "Regression test environment validation failed"
        return 1
    fi
    
    local tests_passed=0
    local tests_total=7
    
    # Test 1: SC1090 regression
    if test_sc1090_regression; then
        tests_passed=$((tests_passed + 1))
    fi
    
    # Test 2: SC1091 regression
    if test_sc1091_regression; then
        tests_passed=$((tests_passed + 1))
    fi
    
    # Test 3: SC2034 regression
    if test_sc2034_regression; then
        tests_passed=$((tests_passed + 1))
    fi
    
    # Test 4: Source directive resolution
    if test_source_directive_resolution_regression; then
        tests_passed=$((tests_passed + 1))
    fi
    
    # Test 5: Variable usage compliance
    if test_variable_usage_compliance_regression; then
        tests_passed=$((tests_passed + 1))
    fi
    
    # Test 6: Critical scripts shellcheck
    if test_critical_scripts_shellcheck_regression; then
        tests_passed=$((tests_passed + 1))
    fi
    
    # Test 7: ShellCheck configuration compliance
    if test_shellcheck_config_compliance_regression; then
        tests_passed=$((tests_passed + 1))
    fi
    
    # Test 8: No new critical errors
    if test_no_new_critical_errors_regression; then
        tests_passed=$((tests_passed + 1))
        tests_total=$((tests_total + 1))
    fi
    
    # Generate summary
    echo
    log_info "=== ShellCheck Regression Test Summary ==="
    echo "Tests Passed: $tests_passed/$tests_total"
    
    local success_rate=0
    if [[ $tests_total -gt 0 ]]; then
        success_rate=$((tests_passed * 100 / tests_total))
    fi
    echo "Success Rate: ${success_rate}%"
    
    if [[ $tests_passed -eq $tests_total ]]; then
        log_success "🎉 All ShellCheck regression tests passed!"
        return 0
    else
        log_error "❌ $((tests_total - tests_passed)) ShellCheck regression tests failed"
        return 1
    fi
}

# Execute main function only if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_regression_test_suite "$@"
fi
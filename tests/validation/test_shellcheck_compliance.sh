#!/bin/bash

# ShellCheck Compliance Validation Tests for N8N-R8
# Validates all shell scripts pass ShellCheck linting without errors
# Focuses on SC1090, SC1091, and SC2034 error resolution

set -euo pipefail

# Get script directory and source helpers
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../helpers/test_helpers.sh
source "$SCRIPT_DIR/../helpers/test_helpers.sh"
# shellcheck source=../test_config.sh
source "$SCRIPT_DIR/../test_config.sh"

# Initialize test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Project root directory
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

# Test shellcheck availability
test_shellcheck_available() {
    log_info "Testing ShellCheck availability"
    
    if command -v shellcheck >/dev/null 2>&1; then
        local shellcheck_version
        shellcheck_version=$(shellcheck --version | grep "version:" | awk '{print $2}')
        log_success "ShellCheck is available (version: $shellcheck_version)"
        return 0
    else
        log_error "ShellCheck is not installed"
        log_error "Install with: apt-get install shellcheck (Ubuntu/Debian) or brew install shellcheck (macOS)"
        return 1
    fi
}

# Get all shell scripts in the project
get_shell_scripts() {
    find "$PROJECT_ROOT" -name "*.sh" -type f \
        -not -path "*/node_modules/*" \
        -not -path "*/nodes/node_modules/*" \
        -not -path "*/data/*" \
        -not -path "*/.git/*" \
        -not -path "*/logs/*" 2>/dev/null | sort
}

# Test individual script with shellcheck
test_script_shellcheck() {
    local script_path="$1"
    local script_name
    script_name=$(basename "$script_path")
    
    log_info "Running ShellCheck on: $script_name"
    
    # Run shellcheck with specific configuration
    local shellcheck_output
    local shellcheck_exit_code
    
    # Capture both output and exit code with timeout
    shellcheck_output=$(timeout 30 shellcheck \
        --external-sources \
        --source-path="$PROJECT_ROOT/tests/helpers:$PROJECT_ROOT/tests" \
        --format=gcc \
        "$script_path" 2>&1) || shellcheck_exit_code=$?
    
    if [[ ${shellcheck_exit_code:-0} -eq 0 ]]; then
        log_success "✓ ShellCheck passed: $script_name"
        return 0
    else
        log_error "✗ ShellCheck failed: $script_name"
        if [[ -n "$shellcheck_output" ]]; then
            echo "$shellcheck_output" | while IFS= read -r line; do
                log_error "  $line"
            done
        fi
        return 1
    fi
}

# Test for specific ShellCheck error codes that should not exist
test_no_critical_shellcheck_errors() {
    local script_path="$1"
    local script_name
    script_name=$(basename "$script_path")
    
    log_info "Testing for critical ShellCheck errors in: $script_name"
    
    # Check for SC1090, SC1091, SC2034 specifically
    local critical_errors
    critical_errors=$(timeout 30 shellcheck \
        --external-sources \
        --source-path="$PROJECT_ROOT/tests/helpers:$PROJECT_ROOT/tests" \
        --format=gcc \
        "$script_path" 2>&1 | grep -E "(SC1090|SC1091|SC2034)" || true)
    
    if [[ -z "$critical_errors" ]]; then
        log_success "✓ No critical errors (SC1090, SC1091, SC2034): $script_name"
        return 0
    else
        log_error "✗ Critical ShellCheck errors found in: $script_name"
        echo "$critical_errors" | while IFS= read -r line; do
            log_error "  $line"
        done
        return 1
    fi
}

# Test source directive resolution
test_source_directive_resolution() {
    local script_path="$1"
    local script_name
    script_name=$(basename "$script_path")
    
    log_info "Testing source directive resolution in: $script_name"
    
    # Check if script has source statements
    if ! grep -q "^[[:space:]]*source\|^[[:space:]]*\." "$script_path"; then
        log_info "No source statements found in: $script_name (skipping)"
        return 0
    fi
    
    # Check for proper shellcheck source directives
    local has_source_directives=false
    local source_lines
    source_lines=$(grep -n "^[[:space:]]*source\|^[[:space:]]*\." "$script_path" || true)
    
    if [[ -n "$source_lines" ]]; then
        # Check if there are corresponding shellcheck source directives
        while IFS= read -r source_line; do
            local line_num
            line_num=$(echo "$source_line" | cut -d: -f1)
            local prev_line_num=$((line_num - 1))
            
            if [[ $prev_line_num -gt 0 ]]; then
                local prev_line
                prev_line=$(sed -n "${prev_line_num}p" "$script_path")
                if [[ "$prev_line" =~ ^[[:space:]]*#[[:space:]]*shellcheck[[:space:]]+source= ]]; then
                    has_source_directives=true
                    break
                fi
            fi
        done <<< "$source_lines"
    fi
    
    if [[ "$has_source_directives" == "true" ]]; then
        log_success "✓ Source directives found: $script_name"
        return 0
    else
        log_warning "⚠ No shellcheck source directives found: $script_name"
        return 0  # Warning, not failure
    fi
}

# Test script syntax validation
test_script_syntax() {
    local script_path="$1"
    local script_name
    script_name=$(basename "$script_path")
    
    log_info "Testing syntax validation for: $script_name"
    
    if bash -n "$script_path" 2>/dev/null; then
        log_success "✓ Syntax validation passed: $script_name"
        return 0
    else
        log_error "✗ Syntax validation failed: $script_name"
        bash -n "$script_path" 2>&1 | while IFS= read -r line; do
            log_error "  $line"
        done
        return 1
    fi
}

# Test shebang line presence
test_shebang_presence() {
    local script_path="$1"
    local script_name
    script_name=$(basename "$script_path")
    
    log_info "Testing shebang presence in: $script_name"
    
    local first_line
    first_line=$(head -n1 "$script_path")
    
    if [[ "$first_line" =~ ^#!/ ]]; then
        log_success "✓ Shebang found: $script_name ($first_line)"
        return 0
    else
        log_error "✗ Missing or invalid shebang: $script_name"
        log_error "  First line: $first_line"
        return 1
    fi
}

# Run comprehensive shellcheck validation on a single script
run_script_validation() {
    local script_path="$1"
    local script_name
    script_name=$(basename "$script_path")
    local script_tests_passed=0
    local script_tests_total=5
    
    log_info "=== Validating script: $script_name ==="
    
    # Test 1: ShellCheck compliance
    if test_script_shellcheck "$script_path"; then
        script_tests_passed=$((script_tests_passed + 1))
    fi
    
    # Test 2: No critical errors
    if test_no_critical_shellcheck_errors "$script_path"; then
        script_tests_passed=$((script_tests_passed + 1))
    fi
    
    # Test 3: Source directive resolution
    if test_source_directive_resolution "$script_path"; then
        script_tests_passed=$((script_tests_passed + 1))
    fi
    
    # Test 4: Syntax validation
    if test_script_syntax "$script_path"; then
        script_tests_passed=$((script_tests_passed + 1))
    fi
    
    # Test 5: Shebang presence
    if test_shebang_presence "$script_path"; then
        script_tests_passed=$((script_tests_passed + 1))
    fi
    
    TESTS_RUN=$((TESTS_RUN + script_tests_total))
    TESTS_PASSED=$((TESTS_PASSED + script_tests_passed))
    TESTS_FAILED=$((TESTS_FAILED + (script_tests_total - script_tests_passed)))
    
    if [[ $script_tests_passed -eq $script_tests_total ]]; then
        log_success "✓ All tests passed for: $script_name ($script_tests_passed/$script_tests_total)"
    else
        log_error "✗ Some tests failed for: $script_name ($script_tests_passed/$script_tests_total)"
    fi
    
    echo
}

# Run shellcheck validation on all scripts
test_all_scripts_shellcheck_compliance() {
    log_info "Running ShellCheck compliance validation on all shell scripts"
    
    # First check if shellcheck is available
    if ! test_shellcheck_available; then
        log_error "Cannot run ShellCheck tests - ShellCheck not available"
        return 1
    fi
    
    local scripts
    scripts=$(get_shell_scripts)
    
    if [[ -z "$scripts" ]]; then
        log_warning "No shell scripts found to validate"
        return 0
    fi
    
    local script_count
    script_count=$(echo "$scripts" | wc -l)
    
    log_info "Found $script_count shell scripts to validate"
    
    # Debug: Show first few scripts
    log_debug "Scripts found:"
    echo "$scripts" | head -5 | while IFS= read -r script; do
        log_debug "  $script"
    done
    echo
    
    # Validate each script
    local processed=0
    while IFS= read -r script_path; do
        if [[ -n "$script_path" ]]; then
            processed=$((processed + 1))
            log_info "Processing script $processed/$script_count: $(basename "$script_path")"
            run_script_validation "$script_path"
        fi
    done <<< "$scripts"
}

# Generate summary report
generate_summary_report() {
    log_info "=== ShellCheck Compliance Summary ==="
    echo
    echo "Total Tests Run:    $TESTS_RUN"
    echo "Tests Passed:       $TESTS_PASSED"
    echo "Tests Failed:       $TESTS_FAILED"
    echo "Tests Skipped:      $TESTS_SKIPPED"
    echo
    
    local success_rate=0
    if [[ $TESTS_RUN -gt 0 ]]; then
        success_rate=$((TESTS_PASSED * 100 / TESTS_RUN))
    fi
    
    echo "Success Rate:       ${success_rate}%"
    echo
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        log_success "🎉 All ShellCheck compliance tests passed!"
        return 0
    else
        log_error "❌ $TESTS_FAILED ShellCheck compliance tests failed"
        return 1
    fi
}

# Main test execution
main() {
    log_info "Starting ShellCheck Compliance Validation"
    echo
    
    # Run all shellcheck compliance tests
    if test_all_scripts_shellcheck_compliance; then
        log_info "ShellCheck validation completed successfully"
    else
        log_error "ShellCheck validation encountered errors"
    fi
    
    # Generate summary report
    generate_summary_report
}

# Execute main function only if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
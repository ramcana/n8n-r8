#!/bin/bash

# N8N-R8 Test Runner
# Comprehensive test execution script for all test categories
# shellcheck disable=SC2317
set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source test helpers with error handling
# shellcheck source=helpers/test_helpers.sh
if ! source "$SCRIPT_DIR/helpers/test_helpers.sh" 2>/dev/null; then
    echo "ERROR: Failed to load test helpers from $SCRIPT_DIR/helpers/test_helpers.sh"
    echo "This is a critical dependency required for test execution."
    echo "Please ensure the file exists and is readable."
    echo "Attempting to provide minimal fallback functions..."
    
    # Provide minimal fallback logging functions
    log_info() { echo "[INFO] $*"; }
    log_error() { echo "[ERROR] $*" >&2; }
    log_warning() { echo "[WARNING] $*"; }
    log_success() { echo "[SUCCESS] $*"; }
    log_debug() { [[ "${TEST_DEBUG:-false}" == "true" ]] && echo "[DEBUG] $*"; }
    
    echo "WARNING: Using fallback functions. Some test features may not work correctly."
fi

# Source test configuration with error handling
# shellcheck source=test_config.sh
if ! source "$SCRIPT_DIR/test_config.sh" 2>/dev/null; then
    log_warning "Failed to load test configuration from $SCRIPT_DIR/test_config.sh"
    log_info "Using default configuration values"
    
    # Provide default configuration values
    RUN_UNIT=${RUN_UNIT:-true}
    RUN_INTEGRATION=${RUN_INTEGRATION:-true}
    RUN_VALIDATION=${RUN_VALIDATION:-true}
    TEST_PARALLEL=${TEST_PARALLEL:-false}
    TEST_CLEANUP=${TEST_CLEANUP:-true}
    TEST_TIMEOUT=${TEST_TIMEOUT:-300}
    REPORTS_DIR="$SCRIPT_DIR/reports"
fi

# Validate required functions are available
validate_required_functions() {
    local required_functions=("log_info" "log_error" "log_warning" "log_success")
    local missing_functions=()
    
    for func in "${required_functions[@]}"; do
        if ! declare -f "$func" >/dev/null 2>&1; then
            missing_functions+=("$func")
        fi
    done
    
    if [[ ${#missing_functions[@]} -gt 0 ]]; then
        echo "ERROR: Missing required functions: ${missing_functions[*]}"
        echo "Test execution cannot continue without these critical functions."
        return 1
    fi
    
    log_debug "All required functions are available"
    return 0
}

# Validate required variables are set
validate_required_variables() {
    local required_vars=("SCRIPT_DIR" "REPORTS_DIR")
    local missing_vars=()
    
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            missing_vars+=("$var")
        fi
    done
    
    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        log_error "Missing required variables: ${missing_vars[*]}"
        log_error "These variables are essential for test execution."
        return 1
    fi
    
    log_debug "All required variables are set"
    return 0
}

# Perform initial validation
if ! validate_required_functions; then
    exit 1
fi

if ! validate_required_variables; then
    exit 1
fi

# Default settings
RUN_UNIT=${RUN_UNIT:-true}
RUN_INTEGRATION=${RUN_INTEGRATION:-true}
RUN_VALIDATION=${RUN_VALIDATION:-true}
TEST_PARALLEL=${TEST_PARALLEL:-false}
TEST_CLEANUP=${TEST_CLEANUP:-true}
COVERAGE_ENABLED=${COVERAGE_ENABLED:-false}
REPORT_FORMAT=${REPORT_FORMAT:-"console"}

# Test directories
UNIT_TEST_DIR="$SCRIPT_DIR/unit"
INTEGRATION_TEST_DIR="$SCRIPT_DIR/integration"
VALIDATION_TEST_DIR="$SCRIPT_DIR/validation"
REPORTS_DIR="$SCRIPT_DIR/reports"

# Usage function
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  --unit          Run only unit tests"
    echo "  --integration   Run only integration tests"
    echo "  --validation    Run only validation tests"
    echo "  --all           Run all test categories (default)"
    echo "  --parallel      Run tests in parallel"
    echo "  --coverage      Enable coverage reporting"
    echo "  --verbose       Enable verbose output"
    echo "  --debug         Enable debug mode"
    echo "  --cleanup       Clean up after tests (default)"
    echo "  --no-cleanup    Skip cleanup after tests"
    echo "  --report FORMAT Report format (console, junit, html)"
    echo "  --help          Show this help message"
    exit 1
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --unit)
                RUN_UNIT=true
                RUN_INTEGRATION=false
                RUN_VALIDATION=false
                shift
                ;;
            --integration)
                RUN_UNIT=false
                RUN_INTEGRATION=true
                RUN_VALIDATION=false
                shift
                ;;
            --validation)
                RUN_UNIT=false
                RUN_INTEGRATION=false
                RUN_VALIDATION=true
                shift
                ;;
            --all)
                RUN_UNIT=true
                RUN_INTEGRATION=true
                RUN_VALIDATION=true
                shift
                ;;
            --parallel)
                TEST_PARALLEL=true
                shift
                ;;
            --coverage)
                COVERAGE_ENABLED=true
                shift
                ;;
            --verbose)
                TEST_VERBOSE=true
                export TEST_VERBOSE=true
                shift
                ;;
            --debug)
                TEST_DEBUG=true
                export TEST_DEBUG=true
                shift
                ;;
            --cleanup)
                TEST_CLEANUP=true
                shift
                ;;
            --no-cleanup)
                TEST_CLEANUP=false
                shift
                ;;
            --report)
                REPORT_FORMAT="$2"
                shift 2
                ;;
            --help)
                usage
                ;;
            *)
                echo "Unknown option: $1"
                usage
                ;;
        esac
    done
}

# Setup test environment
setup_test_environment() {
    log_info "Setting up test environment"
    mkdir -p "$REPORTS_DIR"
}

# Cleanup test environment
cleanup_test_environment() {
    if [[ "$TEST_CLEANUP" == "true" ]]; then
        log_info "Cleaning up test environment"
    fi
}

# Run test category
run_test_category() {
    local category="$1"
    local test_dir="$2"
    
    if [[ ! -d "$test_dir" ]]; then
        log_warning "Test directory not found: $test_dir"
        log_info "Expected directory: $test_dir"
        log_info "Skipping $category tests"
        return 0
    fi
    
    log_info "Running $category tests from directory: $test_dir"
    
    local test_files=()
    while IFS= read -r -d '' file; do
        test_files+=("$file")
    done < <(find "$test_dir" -name "test_*.sh" -type f -print0 2>/dev/null)
    
    if [[ ${#test_files[@]} -eq 0 ]]; then
        log_warning "No test files found in $test_dir"
        log_info "Looking for files matching pattern: test_*.sh"
        log_info "Available files in directory:"
        if ls -la "$test_dir" 2>/dev/null; then
            :  # ls output already shown
        else
            log_error "Cannot list directory contents"
        fi
        return 0
    fi
    
    log_info "Found ${#test_files[@]} test file(s) in $category category"
    
    local success=true
    local failed_tests=()
    
    for test_file in "${test_files[@]}"; do
        log_info "Executing test file: $(basename "$test_file")"
        
        # Validate test file before execution
        if [[ ! -r "$test_file" ]]; then
            log_error "Test file is not readable: $test_file"
            failed_tests+=("$(basename "$test_file"): not readable")
            success=false
            continue
        fi
        
        # Check if test file has proper shebang
        if ! head -n1 "$test_file" | grep -q "^#!/bin/bash"; then
            log_warning "Test file missing proper shebang: $test_file"
        fi
        
        # Execute test with timeout and error handling
        local test_start_time
        test_start_time=$(date +%s)
        
        # shellcheck source=/dev/null
        if timeout "${TEST_TIMEOUT:-300}" bash "$test_file" 2>&1; then
            local test_end_time
            test_end_time=$(date +%s)
            local test_duration=$((test_end_time - test_start_time))
            log_success "✓ $(basename "$test_file") completed in ${test_duration}s"
        else
            local exit_code=$?
            local test_end_time
            test_end_time=$(date +%s)
            local test_duration=$((test_end_time - test_start_time))
            
            case $exit_code in
                124)
                    log_error "✗ $(basename "$test_file") timed out after ${TEST_TIMEOUT:-300}s"
                    failed_tests+=("$(basename "$test_file"): timeout")
                    ;;
                *)
                    log_error "✗ $(basename "$test_file") failed with exit code $exit_code after ${test_duration}s"
                    failed_tests+=("$(basename "$test_file"): exit code $exit_code")
                    ;;
            esac
            success=false
        fi
    done
    
    if [[ "$success" == "true" ]]; then
        log_success "$category tests completed successfully (${#test_files[@]} tests passed)"
        return 0
    else
        log_error "$category tests failed (${#failed_tests[@]} of ${#test_files[@]} tests failed)"
        log_error "Failed tests:"
        for failed_test in "${failed_tests[@]}"; do
            log_error "  - $failed_test"
        done
        return 1
    fi
}

# Generate reports
generate_reports() {
    log_info "Generating test reports"
    case "$REPORT_FORMAT" in
        junit)
            generate_junit_report
            ;;
        html)
            generate_html_report
            ;;
        console)
            generate_console_report
            ;;
        *)
            log_warning "Unknown report format: $REPORT_FORMAT"
            ;;
    esac
}

# Generate console report
generate_console_report() {
    echo "=========================================="
    echo "N8N-R8 Test Suite Results"
    echo "=========================================="
    echo "Test execution completed"
}

# Generate JUnit report
generate_junit_report() {
    local junit_file="$REPORTS_DIR/test_results.xml"
    cat > "$junit_file" << 'JUNIT_EOF'
<?xml version="1.0" encoding="UTF-8"?>
<testsuite name="N8N-R8 Test Suite">
</testsuite>
JUNIT_EOF
    log_info "JUnit report generated: $junit_file"
}

# Generate HTML report
generate_html_report() {
    local html_file="$REPORTS_DIR/test_results.html"
    cat > "$html_file" << 'HTML_EOF'
<!DOCTYPE html>
<html>
<head>
    <title>N8N-R8 Test Results</title>
</head>
<body>
    <h1>N8N-R8 Test Results</h1>
    <p>Test execution completed</p>
</body>
</html>
HTML_EOF
    log_info "HTML report generated: $html_file"
}

# Main function
main() {
    log_info "Starting N8N-R8 test suite"
    
    # Parse command line arguments
    parse_arguments "$@"
    
    # Setup test environment
    setup_test_environment
    
    # Trap to ensure cleanup on exit
    trap cleanup_test_environment EXIT
    
    local overall_exit_code=0
    
    # Run test categories
    if [[ "$RUN_VALIDATION" == "true" ]]; then
        if ! run_test_category "validation" "$VALIDATION_TEST_DIR"; then
            overall_exit_code=1
        fi
    fi
    
    if [[ "$RUN_UNIT" == "true" ]]; then
        if ! run_test_category "unit" "$UNIT_TEST_DIR"; then
            overall_exit_code=1
        fi
    fi
    
    if [[ "$RUN_INTEGRATION" == "true" ]]; then
        if ! run_test_category "integration" "$INTEGRATION_TEST_DIR"; then
            overall_exit_code=1
        fi
    fi
    
    # Generate reports
    generate_reports
    
    # Final summary
    if [[ $overall_exit_code -eq 0 ]]; then
        log_success "All test categories completed successfully"
    else
        log_error "Some test categories failed"
    fi
    
    exit $overall_exit_code
}

# Run main function with all arguments
main "$@"

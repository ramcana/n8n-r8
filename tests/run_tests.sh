#!/bin/bash

# N8N-R8 Test Runner
# Comprehensive test execution script for all test categories
# shellcheck disable=SC2317
set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source test helpers
# shellcheck source=/dev/null
source "$SCRIPT_DIR/helpers/test_helpers.sh"

# shellcheck source=/dev/null
source "$SCRIPT_DIR/test_config.sh" 2>/dev/null || true

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
        return 0
    fi
    
    log_info "Running $category tests"
    
    local test_files=()
    while IFS= read -r -d '' file; do
        test_files+=("$file")
    done < <(find "$test_dir" -name "test_*.sh" -type f -print0)
    
    if [[ ${#test_files[@]} -eq 0 ]]; then
        log_warning "No test files found in $test_dir"
        return 0
    fi
    
    local success=true
    for test_file in "${test_files[@]}"; do
        if ! source "$test_file"; then
            success=false
        fi
    done
    
    if [[ "$success" == "true" ]]; then
        log_success "$category tests completed successfully"
        return 0
    else
        log_error "$category tests failed"
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

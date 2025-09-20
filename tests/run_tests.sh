#!/bin/bash

# N8N-R8 Test Runner
# Comprehensive test execution script for all test categories

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Source test helpers
# shellcheck source=/dev/null
source "$SCRIPT_DIR/helpers/test_helpers.sh"

# Test configuration
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

# Global test counters
TOTAL_TESTS_RUN=0
TOTAL_TESTS_PASSED=0
TOTAL_TESTS_FAILED=0
TOTAL_TESTS_SKIPPED=0

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Run N8N-R8 test suite with various options.

OPTIONS:
    --unit              Run only unit tests
    --integration       Run only integration tests
    --validation        Run only validation tests
    --all               Run all tests (default)
    --parallel          Run tests in parallel
    --coverage          Enable coverage reporting
    --verbose           Enable verbose output
    --debug             Enable debug output
    --cleanup           Clean up test artifacts after run
    --no-cleanup        Skip cleanup after tests
    --report FORMAT     Report format: console, junit, html (default: console)
    --timeout SECONDS   Test timeout in seconds (default: 300)
    --help              Show this help message

EXAMPLES:
    $0                          # Run all tests
    $0 --unit --verbose         # Run unit tests with verbose output
    $0 --integration --parallel # Run integration tests in parallel
    $0 --coverage --report html # Run with coverage and HTML report

EOF
}

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
            --timeout)
                TEST_TIMEOUT="$2"
                export TEST_TIMEOUT="$2"
                shift 2
                ;;
            --help)
                usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
}

setup_test_environment() {
    log_info "Setting up test environment"
    
    # Create reports directory
    mkdir -p "$REPORTS_DIR"
    
    # Initialize coverage if enabled
    if [[ "$COVERAGE_ENABLED" == "true" ]]; then
        log_info "Initializing coverage tracking"
        # Coverage setup would go here
    fi
    
    # Set up test Docker network if needed
    if ! docker network ls | grep -q "n8n-test"; then
        docker network create n8n-test || true
    fi
    
    # Backup current configurations
    backup_config "$PROJECT_ROOT/.env"
    backup_config "$PROJECT_ROOT/docker-compose.yml"
}

cleanup_test_environment() {
    if [[ "$TEST_CLEANUP" == "true" ]]; then
        log_info "Cleaning up test environment"
        
        # Restore configurations
        restore_config "$PROJECT_ROOT/.env"
        restore_config "$PROJECT_ROOT/docker-compose.yml"
        
        # Clean up Docker resources
        docker_cleanup "test_"
        
        # Remove test network
        docker network rm n8n-test 2>/dev/null || true
        
        # Clean up temporary files
        find /tmp -name "n8n_test_*" -type d -exec rm -rf {} + 2>/dev/null || true
    fi
}

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
    
    
    if [[ "$TEST_PARALLEL" == "true" && ${#test_files[@]} -gt 1 ]]; then
        log_info "Running tests in parallel"
        run_tests_parallel "${test_files[@]}"
    else
        log_info "Running tests sequentially"
        for test_file in "${test_files[@]}"; do
            run_single_test_file "$test_file"
        done
    fi
    
    log_info "Completed $category tests"
}

run_single_test_file() {
    local test_file="$1"
    local test_name
    test_name=$(basename "$test_file")
    
    log_info "Executing test file: $test_name"
    
    # Make test file executable
    chmod +x "$test_file"
    
    # Run test file and capture results
    local temp_output
    temp_output=$(mktemp)
    local exit_code=0
    
    if timeout "$TEST_TIMEOUT" "$test_file" > "$temp_output" 2>&1; then
        log_success "✓ $test_name completed successfully"
        if [[ "$TEST_VERBOSE" == "true" ]]; then
            cat "$temp_output"
        fi
    else
        exit_code=$?
        log_error "✗ $test_name failed (exit code: $exit_code)"
        cat "$temp_output"
    fi
    
    # Parse test results from output
    local tests_run
    local tests_passed
    local tests_failed
    local tests_skipped
    tests_run=$(grep -o "Tests Run: *[0-9]*" "$temp_output" | grep -o "[0-9]*" || echo "0")
    tests_passed=$(grep -o "Passed: *[0-9]*" "$temp_output" | grep -o "[0-9]*" || echo "0")
    tests_failed=$(grep -o "Failed: *[0-9]*" "$temp_output" | grep -o "[0-9]*" || echo "0")
    tests_skipped=$(grep -o "Skipped: *[0-9]*" "$temp_output" | grep -o "[0-9]*" || echo "0")
    
    # Update global counters
    TOTAL_TESTS_RUN=$((TOTAL_TESTS_RUN + tests_run))
    TOTAL_TESTS_PASSED=$((TOTAL_TESTS_PASSED + tests_passed))
    TOTAL_TESTS_FAILED=$((TOTAL_TESTS_FAILED + tests_failed))
    TOTAL_TESTS_SKIPPED=$((TOTAL_TESTS_SKIPPED + tests_skipped))
    
    rm -f "$temp_output"
    return $exit_code
}

run_tests_parallel() {
    local test_files=("$@")
    local pids=()
    local results=()
    
    # Start all tests in background
    for test_file in "${test_files[@]}"; do
        run_single_test_file "$test_file" &
        pids+=($!)
    done
    
    # Wait for all tests to complete
    for pid in "${pids[@]}"; do
        wait "$pid"
        results+=($?)
    done
    
    # Check if any tests failed
    local failed=false
    for result in "${results[@]}"; do
        if [[ $result -ne 0 ]]; then
            failed=true
            break
        fi
    done
    
    if [[ "$failed" == "true" ]]; then
        return 1
    fi
    
    return 0
}

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
            generate_console_report
            ;;
    esac
    
    if [[ "$COVERAGE_ENABLED" == "true" ]]; then
        generate_coverage_report
    fi
}

generate_console_report() {
    echo
    echo "=========================================="
    echo "N8N-R8 Test Suite Results"
    echo "=========================================="
    echo "Total Tests Run:    $TOTAL_TESTS_RUN"
    echo "Passed:             $TOTAL_TESTS_PASSED"
    echo "Failed:             $TOTAL_TESTS_FAILED"
    echo "Skipped:            $TOTAL_TESTS_SKIPPED"
    echo "Success Rate:       $(( TOTAL_TESTS_RUN > 0 ? (TOTAL_TESTS_PASSED * 100) / TOTAL_TESTS_RUN : 0 ))%"
    echo "=========================================="
    
    if [[ $TOTAL_TESTS_FAILED -gt 0 ]]; then
        echo "❌ Some tests failed!"
        echo "Check the output above for details."
    else
        echo "✅ All tests passed!"
    fi
    echo
}

generate_junit_report() {
    local junit_file="$REPORTS_DIR/test_results.xml"
    
    cat > "$junit_file" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<testsuite name="N8N-R8 Test Suite" 
           tests="$TOTAL_TESTS_RUN" 
           failures="$TOTAL_TESTS_FAILED" 
           skipped="$TOTAL_TESTS_SKIPPED" 
           time="$(date '+%Y-%m-%dT%H:%M:%S')">
EOF
    
    # Add individual test cases (would need to be collected during test runs)
    echo "</testsuite>" >> "$junit_file"
    
    log_info "JUnit report generated: $junit_file"
}

generate_html_report() {
    local html_file="$REPORTS_DIR/test_results.html"
    
    cat > "$html_file" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>N8N-R8 Test Results</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .summary { background: #f5f5f5; padding: 20px; border-radius: 5px; }
        .passed { color: green; }
        .failed { color: red; }
        .skipped { color: orange; }
    </style>
</head>
<body>
    <h1>N8N-R8 Test Results</h1>
    <div class="summary">
        <h2>Summary</h2>
        <p>Total Tests: $TOTAL_TESTS_RUN</p>
        <p class="passed">Passed: $TOTAL_TESTS_PASSED</p>
        <p class="failed">Failed: $TOTAL_TESTS_FAILED</p>
        <p class="skipped">Skipped: $TOTAL_TESTS_SKIPPED</p>
        <p>Success Rate: $(( TOTAL_TESTS_RUN > 0 ? (TOTAL_TESTS_PASSED * 100) / TOTAL_TESTS_RUN : 0 ))%</p>
    </div>
    <p>Generated on: $(date)</p>
</body>
</html>
EOF
    
    log_info "HTML report generated: $html_file"
}

generate_coverage_report() {
    local coverage_file="$REPORTS_DIR/coverage.html"
    log_info "Coverage report would be generated: $coverage_file"
    # Coverage report generation would be implemented here
}

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

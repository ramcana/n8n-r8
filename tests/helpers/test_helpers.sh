#!/bin/bash

# Test Helper Functions for N8N-R8 Testing Framework
# Provides common testing utilities and assertion functions
# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}
}

run_tests() {
    # Setup
    if declare -f setup > /dev/null; then
        log_debug "Running setup"
        setup
    fi
}

    # Run all test functions
    for func in $(declare -F | grep "test_" | awk '{print $3}'); do
        run_single_test "$func"
    done

    # Teardown
    if declare -f teardown > /dev/null; then
        log_debug "Running teardown"
        teardown
    fi

    # Report results
    print_test_summary
}
run_single_test() {
    local test_name="$1"
    TESTS_RUN=$((TESTS_RUN + 1))
    log_info "Running test: $test_name"
    # Run test with timeout
    if timeout "$TEST_TIMEOUT" bash -c "$test_name"; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        log_success "✓ $test_name"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        log_error "✗ $test_name"
    fi
}
}

skip_test() {
    local reason="$1"
    TESTS_SKIPPED=$((TESTS_SKIPPED + 1))
    log_warning "⊘ Skipped: $reason"
}
print_test_summary() {
    echo
    echo "=================================="
    echo "Test Summary"
    echo "Tests Run:    $TESTS_RUN"
    echo "Passed:       $TESTS_PASSED"
    echo "Failed:       $TESTS_FAILED"
    echo "Skipped:      $TESTS_SKIPPED"
    if [[ $TESTS_FAILED -gt 0 ]]; then
        exit 1
    fi
}
}

# Assertion functions
assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Values should be equal}"
    if [[ "$expected" == "$actual" ]]; then
        log_debug "✓ Assertion passed: $message"
        return 0
    else
        log_error "✗ Assertion failed: $message"
        log_error "  Expected: '$expected'"
        log_error "  Actual:   '$actual'"
        return 1
    fi
}
assert_not_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Values should not be equal}"
    if [[ "$expected" != "$actual" ]]; then
        log_debug "✓ Assertion passed: $message"
        return 0
    else
        log_error "✗ Assertion failed: $message"
        log_error "  Expected: NOT '$expected'"
        log_error "  Actual:   '$actual'"
        return 1
    fi
}
assert_contains() {
    local haystack="$1"
    local needle="$2"
    local message="${3:-String should contain substring}"
    if [[ "$haystack" == *"$needle"* ]]; then
        log_debug "✓ Assertion passed: $message"
        return 0
    else
        log_error "✗ Assertion failed: $message"
        log_error "  String:    '$haystack'"
        log_error "  Should contain: '$needle'"
        return 1
    fi
}
assert_file_exists() {
    local file="$1"
    local message="${2:-File should exist}"
    if [[ -f "$file" ]]; then
        log_debug "✓ Assertion passed: $message"
        return 0
    else
        log_error "✗ Assertion failed: $message"
        log_error "  File: '$file'"
        return 1
    fi
}
assert_directory_exists() {
    local dir="$1"
    local message="${2:-Directory should exist}"
    if [[ -d "$dir" ]]; then
        log_debug "✓ Assertion passed: $message"
        return 0
    else
        log_error "✗ Assertion failed: $message"
        log_error "  Directory: '$dir'"
        return 1
    fi
}
assert_command_success() {
    local command="$1"
    local message="${2:-Command should succeed}"
    if eval "$command" > /dev/null 2>&1; then
        log_debug "✓ Assertion passed: $message"
        return 0
    else
        log_error "✗ Assertion failed: $message"
        log_error "  Command: '$command'"
        return 1
    fi
}
assert_command_fails() {
    local command="$1"
    local message="${2:-Command should fail}"
    if ! eval "$command" > /dev/null 2>&1; then
        log_debug "✓ Assertion passed: $message"
        return 0
    else
        log_error "✗ Assertion failed: $message"
        log_error "  Command: '$command'"
        return 1
    fi
}
assert_service_running() {
    local service="$1"
    local message="${2:-Service should be running}"
    if docker compose ps --services --filter "status=running" | grep -q "^$service$"; then
        log_debug "✓ Assertion passed: $message"
        return 0
    else
        log_error "✗ Assertion failed: $message"
        log_error "  Service: '$service'"
        return 1
    fi
}
assert_url_accessible() {
    local url="$1"
    local expected_status="${2:-200}"
    local message="${3:-URL should be accessible}"
    local status
    status=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null || echo "000")
    if [[ "$status" == "$expected_status" ]]; then
        log_debug "✓ Assertion passed: $message"
        return 0
    else
        log_error "✗ Assertion failed: $message"
        log_error "  URL: '$url'"
        log_error "  Expected status: '$expected_status'"
        log_error "  Actual status: '$status'"
        return 1
    fi
}
# Docker helper functions
docker_cleanup() {
    local prefix="${1:-test_}"
    log_debug "Cleaning up Docker containers with prefix: $prefix"
    # Stop and remove containers
    docker ps -a --filter "name=$prefix" --format "{{.Names}}" | xargs -r docker rm -f
    # Remove networks
    docker network ls --filter "name=$prefix" --format "{{.Name}}" | xargs -r docker network rm
    # Remove volumes
    docker volume ls --filter "name=$prefix" --format "{{.Name}}" | xargs -r docker volume rm
wait_for_service() {
    local timeout="${2:-60}"
    local interval="${3:-2}"
    log_debug "Waiting for service '$service' to be ready (timeout: ${timeout}s)"
    local elapsed=0
    while [[ $elapsed -lt $timeout ]]; do
        if docker compose ps --services --filter "status=running" | grep -q "^$service$"; then
            log_debug "Service '$service' is ready"
            return 0
        fi
}
        
        sleep "$interval"
        elapsed=$((elapsed + interval))
    log_error "Service '$service' failed to start within ${timeout}s"
    return 1
wait_for_url() {
    log_debug "Waiting for URL '$url' to be accessible (timeout: ${timeout}s)"
        if curl -s -f "$url" > /dev/null 2>&1; then
            log_debug "URL '$url' is accessible"
    log_error "URL '$url' not accessible within ${timeout}s"
# File and directory helpers
create_temp_dir() {
    local prefix="${1:-n8n_test_}"
    local temp_dir
    temp_dir=$(mktemp -d -t "${prefix}XXXXXX")
    echo "$temp_dir"
cleanup_temp_dir() {
    local temp_dir="$1"
    if [[ -n "$temp_dir" && -d "$temp_dir" ]]; then
        rm -rf "$temp_dir"
        log_debug "Cleaned up temporary directory: $temp_dir"
# Configuration helpers
backup_config() {
    local config_file="$1"
    local backup_suffix="${2:-.test_backup}"
    if [[ -f "$config_file" ]]; then
        cp "$config_file" "${config_file}${backup_suffix}"
        log_debug "Backed up config: $config_file"
restore_config() {
    local backup_file="${config_file}${backup_suffix}"
    if [[ -f "$backup_file" ]]; then
        mv "$backup_file" "$config_file"
        log_debug "Restored config: $config_file"
# Performance testing helpers
measure_execution_time() {
    local start_time
    start_time=$(date +%s.%N)
    eval "$command"
    local exit_code=$?
    local end_time
    end_time=$(date +%s.%N)
    local duration
    duration=$(echo "$end_time - $start_time" | bc)
    echo "$duration"
    return $exit_code
assert_execution_time_under() {
    local command="$1"
    local max_time="$2"
    local message="${3:-Command should execute within time limit}"
    local duration
    duration=$(measure_execution_time "$command")
    local exit_code=$?
    if [[ $exit_code -eq 0 ]] && (( $(echo "$duration <= $max_time" | bc -l) )); then
        log_debug "✓ Assertion passed: $message (${duration}s <= ${max_time}s)"
        return 0
    fi
    log_error "✗ Assertion failed: $message"
    log_error "  Duration: ${duration}s"
    log_error "  Max allowed: ${max_time}s"
    log_error "  Exit code: $exit_code"
    return 1
}
# Export functions for use in test scripts
export -f log_info log_success log_warning log_error log_debug
export -f run_test_suite run_single_test skip_test print_test_summary
export -f assert_equals assert_not_equals assert_contains
export -f assert_file_exists assert_directory_exists
export -f assert_command_success assert_command_fails
export -f assert_service_running assert_url_accessible
export -f docker_cleanup wait_for_service wait_for_url
export -f create_temp_dir cleanup_temp_dir
export -f backup_config restore_config
export -f measure_execution_time assert_execution_time_under
}

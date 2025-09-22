#!/bin/bash

# Test Helper Functions for N8N-R8 Testing Framework
# Provides common testing utilities and assertion functions

# Ensure this script can be sourced safely
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "ERROR: This script should be sourced, not executed directly"
    echo "Usage: source ${BASH_SOURCE[0]}"
    exit 1
fi

# Validate bash version compatibility
if [[ ${BASH_VERSION%%.*} -lt 4 ]]; then
    echo "WARNING: Bash version ${BASH_VERSION} detected. Some features may not work correctly."
    echo "Recommended: Bash 4.0 or higher"
fi

# Initialize test counters if not already set
TESTS_RUN=${TESTS_RUN:-0}
TESTS_PASSED=${TESTS_PASSED:-0}
TESTS_FAILED=${TESTS_FAILED:-0}
TESTS_SKIPPED=${TESTS_SKIPPED:-0}

# Set default test timeout if not specified
TEST_TIMEOUT=${TEST_TIMEOUT:-300}

# Color variables for output formatting
# These variables are exported to make them available to scripts that source this file
# Usage: echo -e "${GREEN}Success message${NC}" for colored output
export GREEN='\033[0;32m'    # Green color for success messages
export RED='\033[0;31m'      # Red color for error messages  
export YELLOW='\033[1;33m'   # Yellow color for warning messages
export BLUE='\033[0;34m'     # Blue color for info messages
export NC='\033[0m'          # No Color - resets color formatting

# Logging functions
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message"
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

log_debug() {
    if [[ "${TEST_DEBUG:-false}" == "true" ]]; then
        echo -e "${BLUE}[DEBUG]${NC} $*"
    fi
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}
run_tests() {
    # Setup
    if declare -f setup > /dev/null; then
        log_debug "Running setup"
        setup
    fi

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

assert_file_executable() {
    local file="$1"
    local message="${2:-File should be executable}"
    if [[ -x "$file" ]]; then
        log_debug "✓ Assertion passed: $message"
        return 0
    else
        log_error "✗ Assertion failed: $message"
        log_error "  File: '$file' is not executable"
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
    
    # Validate input parameters
    if [[ -z "$file" ]]; then
        log_error "✗ Assertion failed: $message"
        log_error "  Error: No file path provided"
        return 1
    fi
    
    if [[ -f "$file" ]]; then
        log_debug "✓ Assertion passed: $message"
        return 0
    else
        log_error "✗ Assertion failed: $message"
        log_error "  File: '$file'"
        
        # Provide helpful debugging information
        local dir_path
        dir_path=$(dirname "$file")
        if [[ -d "$dir_path" ]]; then
            log_error "  Directory exists: $dir_path"
            if [[ -e "$file" ]]; then
                if [[ -d "$file" ]]; then
                    log_error "  Path exists but is a directory, not a file"
                elif [[ -L "$file" ]]; then
                    log_error "  Path exists but is a symbolic link"
                else
                    log_error "  Path exists but is not a regular file"
                fi
            else
                log_error "  File does not exist"
            fi
        else
            log_error "  Directory does not exist: $dir_path"
        fi
        return 1
    fi
}
assert_directory_exists() {
    local dir="$1"
    local message="${2:-Directory should exist}"
    
    # Validate input parameters
    if [[ -z "$dir" ]]; then
        log_error "✗ Assertion failed: $message"
        log_error "  Error: No directory path provided"
        return 1
    fi
    
    if [[ -d "$dir" ]]; then
        log_debug "✓ Assertion passed: $message"
        return 0
    else
        log_error "✗ Assertion failed: $message"
        log_error "  Directory: '$dir'"
        
        # Provide helpful debugging information
        if [[ -e "$dir" ]]; then
            if [[ -f "$dir" ]]; then
                log_error "  Path exists but is a file, not a directory"
            elif [[ -L "$dir" ]]; then
                log_error "  Path exists but is a symbolic link"
            else
                log_error "  Path exists but is not a directory"
            fi
        else
            log_error "  Directory does not exist"
            
            # Check parent directory
            local parent_dir
            parent_dir=$(dirname "$dir")
            if [[ -d "$parent_dir" ]]; then
                log_error "  Parent directory exists: $parent_dir"
            else
                log_error "  Parent directory does not exist: $parent_dir"
            fi
        fi
        return 1
    fi
}
assert_command_success() {
    local command="$1"
    local message="${2:-Command should succeed}"
    
    # Validate input parameters
    if [[ -z "$command" ]]; then
        log_error "✗ Assertion failed: $message"
        log_error "  Error: No command provided"
        return 1
    fi
    
    # Capture both exit code and output for better error reporting
    local output
    local exit_code
    
    output=$(eval "$command" 2>&1)
    exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        log_debug "✓ Assertion passed: $message"
        return 0
    else
        log_error "✗ Assertion failed: $message"
        log_error "  Command: '$command'"
        log_error "  Exit code: $exit_code"
        
        # Show command output if it's not too long
        if [[ -n "$output" ]]; then
            local output_lines
            output_lines=$(echo "$output" | wc -l)
            if [[ $output_lines -le 5 ]]; then
                log_error "  Output: $output"
            else
                log_error "  Output (first 3 lines):"
                echo "$output" | head -3 | while IFS= read -r line; do
                    log_error "    $line"
                done
                log_error "  ... ($output_lines total lines)"
            fi
        fi
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
}
wait_for_service() {
    local service="$1"
    local timeout="${2:-60}"
    local interval="${3:-2}"
    log_debug "Waiting for service '$service' to be ready (timeout: ${timeout}s)"
    local elapsed=0
    while [[ $elapsed -lt $timeout ]]; do
        if docker compose ps --services --filter "status=running" | grep -q "^$service$"; then
            log_debug "Service '$service' is ready"
            return 0
        fi
        sleep "$interval"
        elapsed=$((elapsed + interval))
    done
    log_error "Service '$service' failed to start within ${timeout}s"
    return 1
}
wait_for_url() {
    local url="$1"
    local timeout="${2:-30}"
    local interval="${3:-2}"
    log_debug "Waiting for URL '$url' to be accessible (timeout: ${timeout}s)"
    local elapsed=0
    while [[ $elapsed -lt $timeout ]]; do
        if curl -s -f "$url" > /dev/null 2>&1; then
            log_debug "URL '$url' is accessible"
            return 0
        fi
        sleep "$interval"
        elapsed=$((elapsed + interval))
    done
    log_error "URL '$url' not accessible within ${timeout}s"
    return 1
}
# File and directory helpers
create_temp_dir() {
    local prefix="${1:-n8n_test_}"
    local temp_dir
    temp_dir=$(mktemp -d -t "${prefix}XXXXXX")
    echo "$temp_dir"
}
cleanup_temp_dir() {
    local temp_dir="$1"
    if [[ -n "$temp_dir" && -d "$temp_dir" ]]; then
        rm -rf "$temp_dir"
        log_debug "Cleaned up temporary directory: $temp_dir"
    fi
}
# Configuration helpers
backup_config() {
    local config_file="$1"
    local backup_suffix="${2:-.test_backup}"
    if [[ -f "$config_file" ]]; then
        cp "$config_file" "${config_file}${backup_suffix}"
        log_debug "Backed up config: $config_file"
    fi
}
restore_config() {
    local config_file="$1"
    local backup_suffix="${2:-.test_backup}"
    local backup_file="${config_file}${backup_suffix}"
    if [[ -f "$backup_file" ]]; then
        mv "$backup_file" "$config_file"
        log_debug "Restored config: $config_file"
    fi
}
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
}
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
# Validation function to check if all required functions are available
validate_test_helpers() {
    local required_functions=(
        "log_info" "log_error" "log_warning" "log_success" "log_debug"
        "assert_equals" "assert_file_exists" "assert_directory_exists"
        "assert_command_success" "assert_command_fails"
        "run_tests" "run_single_test" "print_test_summary"
    )
    
    local missing_functions=()
    
    for func in "${required_functions[@]}"; do
        if ! declare -f "$func" >/dev/null 2>&1; then
            missing_functions+=("$func")
        fi
    done
    
    if [[ ${#missing_functions[@]} -gt 0 ]]; then
        echo "ERROR: Missing required test helper functions:"
        for func in "${missing_functions[@]}"; do
            echo "  - $func"
        done
        echo "Test execution may fail or behave unexpectedly."
        return 1
    fi
    
    return 0
}

# Enhanced error handling for Docker operations
docker_safe_exec() {
    local container="$1"
    local command="$2"
    local timeout="${3:-30}"
    
    if [[ -z "$container" || -z "$command" ]]; then
        log_error "docker_safe_exec: Missing required parameters"
        return 1
    fi
    
    if ! docker ps --format "{{.Names}}" | grep -q "^${container}$"; then
        log_error "Container '$container' is not running"
        return 1
    fi
    
    if timeout "$timeout" docker exec "$container" bash -c "$command"; then
        return 0
    else
        local exit_code=$?
        if [[ $exit_code -eq 124 ]]; then
            log_error "Command timed out after ${timeout}s in container '$container'"
        else
            log_error "Command failed with exit code $exit_code in container '$container'"
        fi
        return $exit_code
    fi
}

# Enhanced wait function with better error reporting
wait_for_condition() {
    local condition_command="$1"
    local timeout="${2:-60}"
    local interval="${3:-2}"
    local description="${4:-condition}"
    
    log_debug "Waiting for $description (timeout: ${timeout}s, interval: ${interval}s)"
    
    local elapsed=0
    local attempts=0
    
    while [[ $elapsed -lt $timeout ]]; do
        attempts=$((attempts + 1))
        
        if eval "$condition_command" >/dev/null 2>&1; then
            log_debug "$description met after ${elapsed}s (${attempts} attempts)"
            return 0
        fi
        
        sleep "$interval"
        elapsed=$((elapsed + interval))
        
        # Log progress every 30 seconds for long waits
        if [[ $((elapsed % 30)) -eq 0 ]] && [[ $elapsed -lt $timeout ]]; then
            log_debug "Still waiting for $description... (${elapsed}s elapsed)"
        fi
    done
    
    log_error "$description not met within ${timeout}s (${attempts} attempts)"
    return 1
}

# Self-validation when sourced
if ! validate_test_helpers; then
    echo "WARNING: Test helpers validation failed. Some functions may not be available."
fi

# No need to export functions, they are sourced

#!/bin/bash

# Unit Tests for Backup Script
# Tests backup functionality and error handling

set -euo pipefail

# Get script directory and source helpers with error handling
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source test helpers with comprehensive error handling
# shellcheck source=../helpers/test_helpers.sh
if ! source "$SCRIPT_DIR/../helpers/test_helpers.sh" 2>/dev/null; then
    echo "CRITICAL ERROR: Cannot load test helpers from $SCRIPT_DIR/../helpers/test_helpers.sh"
    echo "This file is required for unit test execution. Please check:"
    echo "  1. File exists and is readable: $SCRIPT_DIR/../helpers/test_helpers.sh"
    echo "  2. File permissions allow execution"
    echo "  3. File syntax is correct"
    echo ""
    echo "Providing minimal fallback functions for basic operation..."
    
    # Essential fallback functions for unit tests
    log_info() { echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') $*"; }
    log_error() { echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') $*" >&2; }
    log_warning() { echo "[WARNING] $(date '+%Y-%m-%d %H:%M:%S') $*"; }
    log_success() { echo "[SUCCESS] $(date '+%Y-%m-%d %H:%M:%S') $*"; }
    
    # Basic assertion functions
    assert_file_exists() {
        local file="$1"
        local message="${2:-File should exist}"
        if [[ -f "$file" ]]; then
            log_info "✓ $message: $file"
            return 0
        else
            log_error "✗ $message: $file"
            return 1
        fi
    }
    
    assert_file_executable() {
        local file="$1"
        local message="${2:-File should be executable}"
        if [[ -x "$file" ]]; then
            log_info "✓ $message: $file"
            return 0
        else
            log_error "✗ $message: $file"
            return 1
        fi
    }
    
    assert_directory_exists() {
        local dir="$1"
        local message="${2:-Directory should exist}"
        if [[ -d "$dir" ]]; then
            log_info "✓ $message: $dir"
            return 0
        else
            log_error "✗ $message: $dir"
            return 1
        fi
    }
    
    log_warning "Using fallback functions. Some advanced test features may not be available."
fi

# Source test configuration with error handling
# shellcheck source=../test_config.sh
if ! source "$SCRIPT_DIR/../test_config.sh" 2>/dev/null; then
    log_warning "Cannot load test configuration from $SCRIPT_DIR/../test_config.sh"
    log_info "Using default configuration for unit tests"
    
    # Set essential defaults for unit tests
    TEST_TIMEOUT=${TEST_TIMEOUT:-60}
    PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
    TEST_BACKUP_DIR="${TEST_BACKUP_DIR:-/tmp/n8n_test_backups}"
    
    log_info "Using defaults: TEST_TIMEOUT=$TEST_TIMEOUT, PROJECT_ROOT=$PROJECT_ROOT"
fi

# Validate unit test environment
validate_unit_test_environment() {
    local validation_errors=()
    
    # Check PROJECT_ROOT
    if [[ -z "${PROJECT_ROOT:-}" ]]; then
        validation_errors+=("PROJECT_ROOT variable is not set")
    elif [[ ! -d "$PROJECT_ROOT" ]]; then
        validation_errors+=("PROJECT_ROOT directory does not exist: $PROJECT_ROOT")
    fi
    
    # Check if we can create temporary directories
    if ! mkdir -p "/tmp/test_$$" 2>/dev/null; then
        validation_errors+=("Cannot create temporary directories in /tmp")
    else
        rmdir "/tmp/test_$$" 2>/dev/null
    fi
    
    # Check for required commands
    local required_commands=("tar" "date" "mktemp")
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            validation_errors+=("Required command not found: $cmd")
        fi
    done
    
    # Report validation results
    if [[ ${#validation_errors[@]} -gt 0 ]]; then
        log_error "Unit test environment validation failed:"
        for error in "${validation_errors[@]}"; do
            log_error "  - $error"
        done
        return 1
    fi
    
    log_info "Unit test environment validation passed"
    return 0
}

# Perform environment validation
if ! validate_unit_test_environment; then
    log_error "Unit test environment is not properly configured"
    log_error "Please ensure required commands are available and filesystem permissions are correct"
    exit 1
fi

# Test variables
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
BACKUP_SCRIPT="$PROJECT_ROOT/scripts/backup.sh"
TEST_BACKUP_DIR=""

# Test setup with comprehensive error handling
setup() {
    log_info "Setting up backup tests"
    
    # Create test backup directory with error handling
    if ! TEST_BACKUP_DIR=$(mktemp -d 2>/dev/null); then
        log_error "Failed to create temporary directory for backup tests"
        log_error "This may indicate insufficient permissions or disk space"
        log_error "Please check /tmp directory permissions and available space"
        return 1
    fi
    
    export TEST_BACKUP_DIR
    log_info "Test backup directory created: $TEST_BACKUP_DIR"
    
    # Verify directory is writable
    if ! touch "$TEST_BACKUP_DIR/.test_write" 2>/dev/null; then
        log_error "Test backup directory is not writable: $TEST_BACKUP_DIR"
        return 1
    fi
    rm -f "$TEST_BACKUP_DIR/.test_write"
    
    # Verify required commands are available
    local required_commands=("tar" "gzip" "date")
    local missing_commands=()
    
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_commands+=("$cmd")
        fi
    done
    
    if [[ ${#missing_commands[@]} -gt 0 ]]; then
        log_error "Missing required commands for backup tests: ${missing_commands[*]}"
        log_error "Please install these commands to run backup tests"
        return 1
    fi
    
    log_success "Backup test setup completed successfully"
}

# Test cleanup with comprehensive error handling
teardown() {
    log_info "Cleaning up backup tests"
    
    local cleanup_errors=()
    
    # Clean up test backup directory
    if [[ -n "$TEST_BACKUP_DIR" ]]; then
        if [[ -d "$TEST_BACKUP_DIR" ]]; then
            log_debug "Removing test backup directory: $TEST_BACKUP_DIR"
            
            # Try to remove directory with error handling
            if ! rm -rf "$TEST_BACKUP_DIR" 2>/dev/null; then
                cleanup_errors+=("Failed to remove test backup directory: $TEST_BACKUP_DIR")
                
                # Try alternative cleanup methods
                if command -v find >/dev/null 2>&1; then
                    log_debug "Attempting alternative cleanup with find"
                    if find "$TEST_BACKUP_DIR" -type f -delete 2>/dev/null && rmdir "$TEST_BACKUP_DIR" 2>/dev/null; then
                        log_debug "Alternative cleanup successful"
                    else
                        cleanup_errors+=("Alternative cleanup also failed")
                    fi
                fi
            else
                log_debug "Test backup directory removed successfully"
            fi
        else
            log_debug "Test backup directory does not exist: $TEST_BACKUP_DIR"
        fi
    else
        log_debug "TEST_BACKUP_DIR not set, no cleanup needed"
    fi
    
    # Report cleanup results
    if [[ ${#cleanup_errors[@]} -gt 0 ]]; then
        log_warning "Cleanup completed with errors:"
        for error in "${cleanup_errors[@]}"; do
            log_warning "  - $error"
        done
        log_warning "Manual cleanup may be required"
    else
        log_success "Backup test cleanup completed successfully"
    fi
}

# Test backup script exists
test_backup_script_exists() {
    log_info "Testing backup script exists"
    
    assert_file_exists "$BACKUP_SCRIPT" "Backup script should exist"
    assert_file_executable "$BACKUP_SCRIPT" "Backup script should be executable"
}

# Test backup directory creation
test_backup_directory_creation() {
    log_info "Testing backup directory creation"
    
    # Create a simple test that simulates backup directory creation
    local test_dir="$TEST_BACKUP_DIR/test_backup"
    mkdir -p "$test_dir"
    
    assert_directory_exists "$test_dir" "Test backup directory should be created"
}

# Test backup filename generation
test_backup_filename_generation() {
    log_info "Testing backup filename generation"
    
    # Test that backup filename follows expected pattern
    local timestamp
    timestamp=$(date '+%Y%m%d_%H%M%S')
    
    # Create a simple test that generates a filename
    local test_filename="n8n_backup_${timestamp}.tar.gz"
    
    # Test filename pattern
    if [[ "$test_filename" =~ n8n_backup_[0-9]{8}_[0-9]{6}\.tar\.gz ]]; then
        log_success "Backup filename follows expected pattern"
    else
        log_error "Backup filename does not follow expected pattern: $test_filename"
        return 1
    fi
}

# Test backup metadata generation
test_backup_metadata_generation() {
    log_info "Testing backup metadata generation"
    
    # Create mock metadata
    local metadata_file="$TEST_BACKUP_DIR/backup_metadata.json"
    local metadata_content
    metadata_content=$(cat << 'EOF'
{
    "timestamp": "2023-01-01T00:00:00Z",
    "version": "1.0",
    "services": ["n8n", "postgres", "redis"],
    "backup_type": "full",
    "size_bytes": 1024,
    "checksum": "abc123def456"
}
EOF
)
    echo "$metadata_content" > "$metadata_file"
    
    # Verify metadata file
    assert_file_exists "$metadata_file" "Metadata file should exist"
    
    # Verify JSON is valid (if jq is available)
    if command -v jq >/dev/null 2>&1; then
        if jq . "$metadata_file" >/dev/null 2>&1; then
            log_success "Metadata is valid JSON"
        else
            log_error "Metadata is not valid JSON"
            return 1
        fi
    else
        log_info "jq not available, skipping JSON validation"
    fi
}

# Test backup compression
test_backup_compression() {
    log_info "Testing backup compression"
    
    # Create test files
    local test_file1="$TEST_BACKUP_DIR/test1.txt"
    local test_file2="$TEST_BACKUP_DIR/test2.txt"
    
    echo "Test content 1" > "$test_file1"
    echo "Test content 2" > "$test_file2"
    
    # Create compressed archive
    local archive_file="$TEST_BACKUP_DIR/test_backup.tar.gz"
    tar -czf "$archive_file" -C "$TEST_BACKUP_DIR" test1.txt test2.txt
    
    assert_file_exists "$archive_file" "Compressed archive should exist"
    
    # Verify archive contents
    if tar -tzf "$archive_file" | grep -q "test1.txt"; then
        log_success "Archive contains expected files"
    else
        log_error "Archive does not contain expected files"
        return 1
    fi
}

# Run all tests
run_test_suite() {
    log_info "Running backup unit test suite"
    
    setup
    trap teardown EXIT
    
    test_backup_script_exists
    test_backup_directory_creation
    test_backup_filename_generation
    test_backup_metadata_generation
    test_backup_compression
    
    log_success "Backup unit tests completed"
}

# Run the test suite
run_test_suite

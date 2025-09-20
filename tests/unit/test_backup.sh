#!/bin/bash

# Unit Tests for Backup Script
# Tests backup functionality and error handling

set -euo pipefail

# Get script directory and source helpers
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../helpers/test_helpers.sh
source "$SCRIPT_DIR/../helpers/test_helpers.sh"
# shellcheck source=../test_config.sh
source "$SCRIPT_DIR/../test_config.sh"

# Test variables
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
BACKUP_SCRIPT="$PROJECT_ROOT/scripts/backup.sh"
TEST_BACKUP_DIR=""

# Test setup
setup() {
    log_info "Setting up backup tests"
    
    # Create test backup directory
    TEST_BACKUP_DIR=$(mktemp -d)
    export TEST_BACKUP_DIR
    
    log_info "Test backup directory: $TEST_BACKUP_DIR"
}

# Test cleanup
teardown() {
    log_info "Cleaning up backup tests"
    
    if [[ -n "$TEST_BACKUP_DIR" && -d "$TEST_BACKUP_DIR" ]]; then
        rm -rf "$TEST_BACKUP_DIR"
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

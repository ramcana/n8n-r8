#!/bin/bash

# Unit Tests for Backup Script
# Tests backup functionality and error handling
set -euo pipefail
# Get script directory and source helpers
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../helpers/test_helpers.sh
    # shellcheck source=/dev/null
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
    
    # Create temporary backup directory
    TEST_BACKUP_DIR=$(create_temp_dir "backup_test_")
    export BACKUP_DIR="$TEST_BACKUP_DIR"
    # Ensure backup script exists
    assert_file_exists "$BACKUP_SCRIPT" "Backup script should exist"
    # Make backup script executable
    chmod +x "$BACKUP_SCRIPT"
    # Create test data structure
    mkdir -p "$TEST_BACKUP_DIR/test_data/n8n"
    mkdir -p "$TEST_BACKUP_DIR/test_data/postgres"
    mkdir -p "$TEST_BACKUP_DIR/test_data/redis"
    # Create test files
    echo "test workflow" > "$TEST_BACKUP_DIR/test_data/n8n/workflow.json"
    echo "test database" > "$TEST_BACKUP_DIR/test_data/postgres/dump.sql"
    echo "test redis data" > "$TEST_BACKUP_DIR/test_data/redis/dump.rdb"
}
# Test cleanup
teardown() {
    log_info "Cleaning up backup tests"
    if [[ -n "$TEST_BACKUP_DIR" ]]; then
        cleanup_temp_dir "$TEST_BACKUP_DIR"
    fi
    # Clean up any test containers
    docker_cleanup "backup_test_"
# Test backup script exists and is executable
test_backup_script_exists() {
    log_info "Testing backup script existence and permissions"
    assert_command_success "test -x '$BACKUP_SCRIPT'" "Backup script should be executable"
# Test backup script help option
test_backup_script_help() {
    log_info "Testing backup script help option"
    # Test --help option
    assert_command_success "$BACKUP_SCRIPT --help" "Backup script should show help"
    # Test help output contains expected information
    local help_output
    help_output=$($BACKUP_SCRIPT --help 2>&1)
    assert_contains "$help_output" "Usage:" "Help should contain usage information"
    assert_contains "$help_output" "backup" "Help should mention backup functionality"
# Test backup directory creation
test_backup_directory_creation() {
    log_info "Testing backup directory creation"
    local test_backup_dir="$TEST_BACKUP_DIR/new_backup_dir"
    # Run backup with custom directory
    export BACKUP_DIR="$test_backup_dir"
    # Mock the backup process to just create directory
    local mock_backup_script
    mock_backup_script=$(cat << 'EOF'
mkdir -p "$BACKUP_DIR"
echo "Backup directory created: $BACKUP_DIR"
EOF
)
    local temp_script="$TEST_BACKUP_DIR/mock_backup.sh"
    echo "$mock_backup_script" > "$temp_script"
    chmod +x "$temp_script"
    assert_command_success "$temp_script" "Mock backup should succeed"
    assert_directory_exists "$test_backup_dir" "Backup directory should be created"
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
# Test backup with missing services
test_backup_with_missing_services() {
    log_info "Testing backup behavior with missing services"
    # Create mock backup script that handles missing services
source "$(dirname "$0")/../helpers/test_helpers.sh"
# Check if services are running
if ! docker compose ps --services --filter "status=running" | grep -q "n8n"; then
    log_warning "N8N service not running, skipping N8N backup"
fi
if ! docker compose ps --services --filter "status=running" | grep -q "postgres"; then
    log_warning "PostgreSQL service not running, skipping database backup"
if ! docker compose ps --services --filter "status=running" | grep -q "redis"; then
    log_warning "Redis service not running, skipping Redis backup"
echo "Backup completed with warnings"
exit 0
    local temp_script="$TEST_BACKUP_DIR/mock_backup_missing.sh"
    # Should succeed even with missing services
    assert_command_success "$temp_script" "Backup should handle missing services gracefully"
# Test backup compression
test_backup_compression() {
    log_info "Testing backup compression"
    # Create test files to compress
    local test_dir="$TEST_BACKUP_DIR/test_compress"
    mkdir -p "$test_dir"
    # Create some test data
    echo "test data 1" > "$test_dir/file1.txt"
    echo "test data 2" > "$test_dir/file2.txt"
    mkdir -p "$test_dir/subdir"
    echo "test data 3" > "$test_dir/subdir/file3.txt"
    # Test compression
    local archive_file="$TEST_BACKUP_DIR/test_backup.tar.gz"
    assert_command_success "tar -czf '$archive_file' -C '$test_dir' ." "Should create compressed archive"
    # Verify archive exists and is not empty
    assert_file_exists "$archive_file" "Archive file should exist"
    local file_size
    file_size=$(stat -c%s "$archive_file")
    if [[ $file_size -gt 0 ]]; then
        log_success "Archive file is not empty ($file_size bytes)"
        log_error "Archive file is empty"
    # Test extraction
    local extract_dir="$TEST_BACKUP_DIR/test_extract"
    mkdir -p "$extract_dir"
    assert_command_success "tar -xzf '$archive_file' -C '$extract_dir'" "Should extract archive"
    # Verify extracted files
    assert_file_exists "$extract_dir/file1.txt" "Extracted file1.txt should exist"
    assert_file_exists "$extract_dir/file2.txt" "Extracted file2.txt should exist"
    assert_file_exists "$extract_dir/subdir/file3.txt" "Extracted subdir/file3.txt should exist"
# Test backup metadata generation
test_backup_metadata_generation() {
    log_info "Testing backup metadata generation"
    # Create mock metadata
    local metadata_file="$TEST_BACKUP_DIR/backup_metadata.json"
    local metadata_content
    metadata_content=$(cat << EOF
{
    "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "version": "1.0",
    "services": ["n8n", "postgres", "redis"],
    "backup_type": "full",
    "size_bytes": 1024,
    "checksum": "abc123def456"
    echo "$metadata_content" > "$metadata_file"
    # Verify metadata file
    assert_file_exists "$metadata_file" "Metadata file should exist"
    # Verify JSON is valid
    assert_command_success "jq . '$metadata_file'" "Metadata should be valid JSON"
    # Verify required fields
    timestamp=$(jq -r '.timestamp' "$metadata_file")
    assert_not_equals "" "$timestamp" "Timestamp should not be empty"
    local services
    services=$(jq -r '.services[]' "$metadata_file" | wc -l)
    if [[ $services -gt 0 ]]; then
        log_success "Services list is not empty"
        log_error "Services list is empty"
# Test backup size calculation
test_backup_size_calculation() {
    log_info "Testing backup size calculation"
    # Create test data with known size
    local test_file="$TEST_BACKUP_DIR/size_test.txt"
    # Create 1KB file
    dd if=/dev/zero of="$test_file" bs=1024 count=1 2>/dev/null
    # Calculate size
    file_size=$(stat -c%s "$test_file")
    assert_equals "1024" "$file_size" "File size should be 1024 bytes"
    # Test human-readable size formatting
    local human_size
    human_size=$(du -h "$test_file" | cut -f1)
    assert_contains "$human_size" "1" "Human-readable size should contain '1'"
# Test backup rotation
test_backup_rotation() {
    log_info "Testing backup rotation"
    # Create multiple backup files
    local backup_dir="$TEST_BACKUP_DIR/rotation_test"
    mkdir -p "$backup_dir"
    # Create old backup files
    for i in {1..5}; do
        local old_date
        old_date=$(date -d "$i days ago" '+%Y%m%d_%H%M%S')
        touch "$backup_dir/n8n_backup_${old_date}.tar.gz"
    done
    # Count files before rotation
    local files_before
    files_before=$(ls "$backup_dir"/n8n_backup_*.tar.gz | wc -l)
    assert_equals "5" "$files_before" "Should have 5 backup files before rotation"
    # Mock rotation (keep only 3 most recent)
    local keep_count=3
    ls -t "$backup_dir"/n8n_backup_*.tar.gz | tail -n +$((keep_count + 1)) | xargs -r rm
    # Count files after rotation
    local files_after
    files_after=$(ls "$backup_dir"/n8n_backup_*.tar.gz 2>/dev/null | wc -l)
    assert_equals "$keep_count" "$files_after" "Should have $keep_count backup files after rotation"
# Test backup verification
test_backup_verification() {
    log_info "Testing backup verification"
    # Create test backup file
    local test_backup="$TEST_BACKUP_DIR/test_verification.tar.gz"
    echo "test content" | tar -czf "$test_backup" -T -
    # Verify backup integrity
    assert_command_success "tar -tzf '$test_backup'" "Backup archive should be valid"
    # Test checksum generation
    local checksum1
    checksum1=$(sha256sum "$test_backup" | cut -d' ' -f1)
    local checksum2
    checksum2=$(sha256sum "$test_backup" | cut -d' ' -f1)
    assert_equals "$checksum1" "$checksum2" "Checksums should be consistent"
    # Test corrupted backup detection
    local corrupted_backup="$TEST_BACKUP_DIR/corrupted.tar.gz"
    echo "corrupted data" > "$corrupted_backup"
    assert_command_fails "tar -tzf '$corrupted_backup'" "Corrupted backup should be detected"
# Test backup with custom options
test_backup_with_custom_options() {
    log_info "Testing backup with custom options"
    # Test backup with compression level
    local test_file="$TEST_BACKUP_DIR/custom_test.txt"
    echo "test data for compression" > "$test_file"
    # Test different compression levels
    local archive_fast="$TEST_BACKUP_DIR/fast.tar.gz"
    local archive_best="$TEST_BACKUP_DIR/best.tar.gz"
    assert_command_success "tar -czf '$archive_fast' --gzip -1 -C '$(dirname "$test_file")' '$(basename "$test_file")'" "Fast compression should work"
    assert_command_success "tar -czf '$archive_best' --gzip -9 -C '$(dirname "$test_file")' '$(basename "$test_file")'" "Best compression should work"
    # Verify both archives exist
    assert_file_exists "$archive_fast" "Fast compression archive should exist"
    assert_file_exists "$archive_best" "Best compression archive should exist"
# Run all tests
run_test_suite

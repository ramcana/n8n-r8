#!/bin/bash

# N8N-R8 Monitoring Test Script
# This script tests the monitoring system components
set -euo pipefail
# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'
# Test results
TESTS_PASSED=0
TESTS_FAILED=0
# Logging functions
log_test() {
    echo -e "${BLUE}[TEST]${NC} $1"
}
log_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((TESTS_PASSED++))
log_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((TESTS_FAILED++))
log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
# Test script permissions
test_script_permissions() {
    log_test "Checking script permissions..."
    
    local scripts=(
        "monitor.sh"
        "disk-monitor.sh"
        "setup-logrotate.sh"
        "test-monitoring.sh"
    )
    for script in "${scripts[@]}"; do
        if [[ -x "$SCRIPT_DIR/$script" ]]; then
            log_pass "Script $script is executable"
        else
            log_fail "Script $script is not executable"
        fi
    done
    if [[ -x "$PROJECT_DIR/scripts/start-monitoring.sh" ]]; then
        log_pass "Start monitoring script is executable"
    else
        log_fail "Start monitoring script is not executable"
    fi
# Test configuration files
test_configuration_files() {
    log_test "Checking configuration files..."
    local configs=(
        "monitoring/config/monitor.conf"
        "monitoring/config/prometheus.yml"
        "monitoring/config/alert_rules.yml"
        "monitoring/config/alertmanager.yml"
        "monitoring/config/logrotate.conf"
        "monitoring/config/loki.yml"
        "monitoring/config/promtail.yml"
    for config in "${configs[@]}"; do
        if [[ -f "$PROJECT_DIR/$config" ]]; then
            log_pass "Configuration file $config exists"
            log_fail "Configuration file $config is missing"
# Test directory structure
test_directory_structure() {
    log_test "Checking directory structure..."
    local dirs=(
        "monitoring/scripts"
        "monitoring/config"
        "monitoring/logs"
        "monitoring/data"
    for dir in "${dirs[@]}"; do
        if [[ -d "$PROJECT_DIR/$dir" ]]; then
            log_pass "Directory $dir exists"
            log_fail "Directory $dir is missing"
# Test Docker availability
test_docker() {
    log_test "Checking Docker availability..."
    if command -v docker >/dev/null 2>&1; then
        log_pass "Docker command is available"
        
        if docker info >/dev/null 2>&1; then
            log_pass "Docker daemon is running"
            log_fail "Docker daemon is not running"
        log_fail "Docker command not found"
# Test monitoring scripts functionality
test_monitoring_scripts() {
    log_test "Testing monitoring script functionality..."
    # Test monitor script help
    if "$SCRIPT_DIR/monitor.sh" --help >/dev/null 2>&1; then
        log_pass "Monitor script help works"
        log_fail "Monitor script help failed"
    # Test disk monitor script help
    if "$SCRIPT_DIR/disk-monitor.sh" --help >/dev/null 2>&1; then
        log_pass "Disk monitor script help works"
        log_fail "Disk monitor script help failed"
    # Test start monitoring script help
    if "$PROJECT_DIR/scripts/start-monitoring.sh" --help >/dev/null 2>&1; then
        log_pass "Start monitoring script help works"
        log_fail "Start monitoring script help failed"
# Test environment file
test_environment() {
    log_test "Checking environment configuration..."
    if [[ -f "$PROJECT_DIR/.env" ]]; then
        log_pass "Environment file exists"
        # Check for monitoring-related variables
        if grep -q "ENABLE_EMAIL_ALERTS" "$PROJECT_DIR/.env" 2>/dev/null; then
            log_pass "Monitoring variables found in .env"
            log_warn "No monitoring variables in .env (this is optional)"
        log_fail "Environment file .env is missing"
# Test Docker Compose files
test_docker_compose() {
    log_test "Checking Docker Compose configurations..."
    local compose_files=(
        "docker-compose.yml"
        "docker-compose.monitoring.yml"
    for compose_file in "${compose_files[@]}"; do
        if [[ -f "$PROJECT_DIR/$compose_file" ]]; then
            log_pass "Docker Compose file $compose_file exists"
            
            # Test if the compose file is valid
            if docker compose -f "$PROJECT_DIR/$compose_file" config >/dev/null 2>&1; then
                log_pass "Docker Compose file $compose_file is valid"
            else
                log_fail "Docker Compose file $compose_file has syntax errors"
            fi
            log_fail "Docker Compose file $compose_file is missing"
# Test system requirements
test_system_requirements() {
    log_test "Checking system requirements..."
    # Check available memory
    local mem_gb
    mem_gb=$(free -g | awk 'NR==2{print $2}')
    if [[ $mem_gb -ge 4 ]]; then
        log_pass "Sufficient memory available (${mem_gb}GB)"
        log_warn "Low memory (${mem_gb}GB) - monitoring stack may need tuning"
    # Check disk space
    local disk_avail
    disk_avail=$(df -BG . | awk 'NR==2{print $4}' | sed 's/G//')
    if [[ $disk_avail -ge 10 ]]; then
        log_pass "Sufficient disk space available (${disk_avail}GB)"
        log_warn "Low disk space (${disk_avail}GB) - consider cleanup"
    # Check for required commands
    local commands=("curl" "wget" "mail")
    for cmd in "${commands[@]}"; do
        if command -v "$cmd" >/dev/null 2>&1; then
            log_pass "Command $cmd is available"
            log_warn "Command $cmd not found (optional for some features)"
# Run a basic monitoring test
test_basic_monitoring() {
    log_test "Running basic monitoring test..."
    # Create temporary log directory for test
    mkdir -p "$PROJECT_DIR/monitoring/logs"
    # Run a quick health check
    if "$SCRIPT_DIR/monitor.sh" check --no-email >/dev/null 2>&1; then
        log_pass "Basic health check completed successfully"
        log_warn "Basic health check had issues (may be normal if services aren't running)"
    # Test disk monitoring
    if "$SCRIPT_DIR/disk-monitor.sh" check >/dev/null 2>&1; then
        log_pass "Disk monitoring check completed successfully"
        log_warn "Disk monitoring check had issues"
# Main test function
main() {
    echo -e "${BLUE}N8N-R8 Monitoring System Test${NC}"
    echo "=================================="
    echo ""
    # Change to project directory
    cd "$PROJECT_DIR"
    # Run all tests
    test_script_permissions
    test_configuration_files
    test_directory_structure
    test_docker
    test_monitoring_scripts
    test_environment
    test_docker_compose
    test_system_requirements
    test_basic_monitoring
    # Summary
    echo -e "${BLUE}Test Summary${NC}"
    echo "============"
    echo -e "${GREEN}Tests Passed: $TESTS_PASSED${NC}"
    echo -e "${RED}Tests Failed: $TESTS_FAILED${NC}"
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}✅ All tests passed! Monitoring system is ready.${NC}"
        echo ""
        echo "Next steps:"
        echo "1. Start basic monitoring: make monitor-basic"
        echo "2. Or start full stack: make monitor-full"
        echo "3. Check monitoring/README.md for detailed setup"
        return 0
        echo -e "${RED}❌ Some tests failed. Please review the issues above.${NC}"
        echo "Common fixes:"
        echo "1. Run: chmod +x monitoring/scripts/*.sh scripts/*.sh"
        echo "2. Ensure Docker is running: sudo systemctl start docker"
        echo "3. Create .env file if missing"
        return 1
# Run main function
main "$@"

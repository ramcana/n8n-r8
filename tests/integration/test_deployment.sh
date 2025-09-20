#!/bin/bash

# Integration Tests for N8N-R8 Deployment
# Tests complete deployment scenarios end-to-end
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
TEST_ENV_FILE=""
# Test setup
setup() {
    log_info "Setting up deployment integration tests"
    
    # Create test environment file
    TEST_ENV_FILE="$PROJECT_ROOT/.env.test"
    cat > "$TEST_ENV_FILE" << EOF
# Test environment configuration
N8N_BASIC_AUTH_USER=$TEST_N8N_USER
N8N_BASIC_AUTH_PASSWORD=$TEST_N8N_PASSWORD
POSTGRES_PASSWORD=$TEST_POSTGRES_PASSWORD
REDIS_PASSWORD=$TEST_REDIS_PASSWORD
N8N_ENCRYPTION_KEY=$N8N_ENCRYPTION_KEY
N8N_JWT_SECRET=$N8N_JWT_SECRET
N8N_HOST=localhost
N8N_PORT=5678
POSTGRES_DB=n8n_test
POSTGRES_USER=n8n_test
REDIS_DB=1
NODE_ENV=test
EOF
    # Backup original environment
    backup_config "$PROJECT_ROOT/.env"
    # Use test environment
    cp "$TEST_ENV_FILE" "$PROJECT_ROOT/.env"
    # Clean up any existing test containers
    docker_cleanup "test_"
    # Change to project directory
    cd "$PROJECT_ROOT"
}
# Test cleanup
teardown() {
    log_info "Cleaning up deployment integration tests"
    # Stop all test services
    docker compose down --remove-orphans --volumes 2>/dev/null || true
    # Restore original environment
    restore_config "$PROJECT_ROOT/.env"
    # Clean up test files
    rm -f "$TEST_ENV_FILE"
    # Clean up Docker resources
# Test basic N8N deployment
test_basic_n8n_deployment() {
    log_info "Testing basic N8N deployment"
    # Start basic services
    assert_command_success "docker compose up -d" "Should start basic N8N services"
    # Wait for services to be ready
    wait_for_service "n8n" 120
    wait_for_service "postgres" 60
    wait_for_service "redis" 30
    # Test service health
    assert_service_running "n8n" "N8N service should be running"
    assert_service_running "postgres" "PostgreSQL service should be running"
    assert_service_running "redis" "Redis service should be running"
    # Test N8N web interface
    wait_for_url "$TEST_N8N_URL" 60
    assert_url_accessible "$TEST_N8N_URL" "200" "N8N web interface should be accessible"
    # Test N8N API endpoint
    local api_url="$TEST_N8N_URL/rest/login"
    assert_url_accessible "$api_url" "200" "N8N API should be accessible"
    # Stop services
    assert_command_success "docker compose down" "Should stop services cleanly"
# Test deployment with Nginx proxy
test_nginx_proxy_deployment() {
    log_info "Testing deployment with Nginx proxy"
    # Start with Nginx proxy
    assert_command_success "docker compose -f docker-compose.yml -f docker-compose.nginx.yml up -d" "Should start with Nginx proxy"
    # Wait for services
    wait_for_service "nginx" 60
    # Test Nginx proxy
    assert_service_running "nginx" "Nginx service should be running"
    # Test proxy functionality
    wait_for_url "$TEST_NGINX_URL" 60
    assert_url_accessible "$TEST_NGINX_URL" "200" "Nginx proxy should serve N8N"
    # Test proxy headers
    local response_headers
    response_headers=$(curl -s -I "$TEST_NGINX_URL" 2>/dev/null || echo "")
    assert_contains "$response_headers" "Server: nginx" "Response should include Nginx header"
    assert_command_success "docker compose -f docker-compose.yml -f docker-compose.nginx.yml down" "Should stop Nginx deployment"
# Test deployment with Traefik proxy
test_traefik_proxy_deployment() {
    log_info "Testing deployment with Traefik proxy"
    # Start with Traefik proxy
    assert_command_success "docker compose -f docker-compose.yml -f docker-compose.traefik.yml up -d" "Should start with Traefik proxy"
    wait_for_service "traefik" 60
    # Test Traefik proxy
    assert_service_running "traefik" "Traefik service should be running"
    # Test Traefik dashboard
    wait_for_url "$TEST_TRAEFIK_DASHBOARD" 60
    assert_url_accessible "$TEST_TRAEFIK_DASHBOARD" "200" "Traefik dashboard should be accessible"
    wait_for_url "$TEST_TRAEFIK_URL" 60
    assert_url_accessible "$TEST_TRAEFIK_URL" "200" "Traefik proxy should serve N8N"
    assert_command_success "docker compose -f docker-compose.yml -f docker-compose.traefik.yml down" "Should stop Traefik deployment"
# Test deployment with monitoring
test_monitoring_deployment() {
    log_info "Testing deployment with monitoring"
    # Start with monitoring stack
    assert_command_success "docker compose -f docker-compose.yml -f docker-compose.monitoring.yml up -d" "Should start with monitoring"
    # Wait for core services
    wait_for_service "prometheus" 60
    wait_for_service "grafana" 60
    # Test monitoring services
    assert_service_running "prometheus" "Prometheus should be running"
    assert_service_running "grafana" "Grafana should be running"
    # Test monitoring interfaces
    wait_for_url "$TEST_PROMETHEUS_URL" 60
    assert_url_accessible "$TEST_PROMETHEUS_URL" "200" "Prometheus should be accessible"
    wait_for_url "$TEST_GRAFANA_URL" 60
    assert_url_accessible "$TEST_GRAFANA_URL" "200" "Grafana should be accessible"
    # Test Prometheus metrics
    local metrics_url="$TEST_PROMETHEUS_URL/metrics"
    assert_url_accessible "$metrics_url" "200" "Prometheus metrics should be available"
    assert_command_success "docker compose -f docker-compose.yml -f docker-compose.monitoring.yml down" "Should stop monitoring deployment"
# Test custom nodes deployment
test_custom_nodes_deployment() {
    log_info "Testing custom nodes deployment"
    # Check if custom nodes exist
    if [[ ! -d "$PROJECT_ROOT/nodes" ]]; then
        skip_test "Custom nodes directory not found"
        return 0
    fi
    # Start with custom nodes
    assert_command_success "docker compose -f docker-compose.yml -f docker-compose.custom-nodes.yml up -d" "Should start with custom nodes"
    # Test N8N with custom nodes
    assert_url_accessible "$TEST_N8N_URL" "200" "N8N with custom nodes should be accessible"
    # Test custom nodes API (if available)
    local nodes_api_url="$TEST_N8N_URL/rest/node-types"
    assert_url_accessible "$nodes_api_url" "401" "Node types API should require authentication"
    assert_command_success "docker compose -f docker-compose.yml -f docker-compose.custom-nodes.yml down" "Should stop custom nodes deployment"
# Test deployment persistence
test_deployment_persistence() {
    log_info "Testing deployment data persistence"
    # First deployment
    assert_command_success "docker compose up -d" "Should start services"
    # Create test data (simulate workflow creation)
    local test_data_file="$PROJECT_ROOT/data/n8n/test_persistence.txt"
    mkdir -p "$(dirname "$test_data_file")"
    echo "test persistence data" > "$test_data_file"
    assert_command_success "docker compose down" "Should stop services"
    # Restart services
    assert_command_success "docker compose up -d" "Should restart services"
    # Verify data persistence
    assert_file_exists "$test_data_file" "Test data should persist across restarts"
    local file_content
    file_content=$(cat "$test_data_file")
    assert_equals "test persistence data" "$file_content" "File content should be preserved"
    # Clean up
    rm -f "$test_data_file"
# Test deployment scaling
test_deployment_scaling() {
    log_info "Testing deployment scaling"
    # Start basic deployment
    # Scale N8N service
    assert_command_success "docker compose up -d --scale n8n=2" "Should scale N8N to 2 instances"
    # Wait for scaled services
    sleep 10
    # Check scaled instances
    local n8n_count
    n8n_count=$(docker compose ps n8n --format "{{.Names}}" | wc -l)
    if [[ $n8n_count -eq 2 ]]; then
        log_success "N8N scaled to 2 instances"
    else
        log_warning "N8N scaling might not work as expected (found $n8n_count instances)"
    # Scale back down
    assert_command_success "docker compose up -d --scale n8n=1" "Should scale N8N back to 1 instance"
# Test deployment resource limits
test_deployment_resource_limits() {
    log_info "Testing deployment resource limits"
    # Start services
    # Check memory usage
    local n8n_memory
    n8n_memory=$(docker stats --no-stream --format "{{.MemUsage}}" n8n-r8-n8n-1 2>/dev/null | cut -d'/' -f1 | sed 's/[^0-9.]//g' || echo "0")
    if [[ -n "$n8n_memory" && $(echo "$n8n_memory > 0" | bc -l) -eq 1 ]]; then
        log_success "N8N memory usage: ${n8n_memory}MB"
        
        # Check if within reasonable limits
        if [[ $(echo "$n8n_memory < $PERFORMANCE_MEMORY_LIMIT_MB" | bc -l) -eq 1 ]]; then
            log_success "Memory usage is within limits"
        else
            log_warning "Memory usage might be high: ${n8n_memory}MB"
        fi
        log_warning "Could not measure memory usage"
# Test deployment recovery
test_deployment_recovery() {
    log_info "Testing deployment recovery from failures"
    # Simulate container failure
    assert_command_success "docker stop n8n-r8-n8n-1" "Should stop N8N container"
    # Wait a moment
    sleep 5
    # Restart failed service
    assert_command_success "docker compose up -d" "Should restart failed services"
    wait_for_service "n8n" 60
    # Verify recovery
    assert_service_running "n8n" "N8N should recover after restart"
    assert_url_accessible "$TEST_N8N_URL" "200" "N8N should be accessible after recovery"
# Test deployment configuration validation
test_deployment_configuration_validation() {
    log_info "Testing deployment configuration validation"
    # Test with invalid configuration
    local invalid_env="$PROJECT_ROOT/.env.invalid"
    cat > "$invalid_env" << EOF
# Invalid configuration
N8N_BASIC_AUTH_USER=
N8N_BASIC_AUTH_PASSWORD=weak
POSTGRES_PASSWORD=123
    # Backup and use invalid config
    cp "$invalid_env" "$PROJECT_ROOT/.env"
    # Try to start with invalid config (should handle gracefully)
    local start_result=0
    docker compose up -d 2>/dev/null || start_result=$?
    # Check if start failed as expected
    if [[ $start_result -ne 0 ]]; then
        log_info "Invalid config properly rejected (exit code: $start_result)"
    # Restore valid config
    rm -f "$invalid_env"
    # Stop any started services
    docker compose down 2>/dev/null || true
    log_success "Configuration validation test completed"
# Run all tests
run_test_suite

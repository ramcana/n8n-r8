#!/bin/bash

# Integration Tests for N8N-R8 Deployment
# Tests complete deployment scenarios end-to-end

set -euo pipefail

# Get script directory and source helpers
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../helpers/test_helpers.sh
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
    cat > "$TEST_ENV_FILE" << 'EOF'
# Test environment configuration
N8N_BASIC_AUTH_USER=admin
N8N_BASIC_AUTH_PASSWORD=test_password_123!
POSTGRES_PASSWORD=test_secure_password!
REDIS_PASSWORD=test_redis_password!
EOF
}

# Test cleanup
teardown() {
    log_info "Cleaning up deployment integration tests"
    
    # Stop any running services
    cd "$PROJECT_ROOT"
    docker-compose down 2>/dev/null || true
    
    # Remove test files
    if [[ -n "$TEST_ENV_FILE" && -f "$TEST_ENV_FILE" ]]; then
        rm -f "$TEST_ENV_FILE"
    fi
}

# Test basic deployment
test_basic_deployment() {
    log_info "Testing basic deployment"
    
    cd "$PROJECT_ROOT"
    
    # Copy test environment
    cp "$TEST_ENV_FILE" .env
    
    # Test docker-compose validation
    if docker-compose config >/dev/null 2>&1; then
        log_success "Docker Compose configuration is valid"
    else
        log_error "Docker Compose configuration is invalid"
        return 1
    fi
    
    # Test service startup (dry run)
    log_info "Testing service startup (validation only)"
    if docker-compose config --services >/dev/null 2>&1; then
        log_success "Services configuration is valid"
    else
        log_error "Services configuration is invalid"
        return 1
    fi
}

# Test nginx deployment
test_nginx_deployment() {
    log_info "Testing nginx deployment"
    
    cd "$PROJECT_ROOT"
    
    # Test nginx compose file
    if [[ -f "docker-compose.nginx.yml" ]]; then
        if docker-compose -f docker-compose.yml -f docker-compose.nginx.yml config >/dev/null 2>&1; then
            log_success "Nginx deployment configuration is valid"
        else
            log_error "Nginx deployment configuration is invalid"
            return 1
        fi
    else
        log_warning "Nginx compose file not found"
    fi
}

# Test traefik deployment
test_traefik_deployment() {
    log_info "Testing traefik deployment"
    
    cd "$PROJECT_ROOT"
    
    # Test traefik compose file
    if [[ -f "docker-compose.traefik.yml" ]]; then
        if docker-compose -f docker-compose.yml -f docker-compose.traefik.yml config >/dev/null 2>&1; then
            log_success "Traefik deployment configuration is valid"
        else
            log_error "Traefik deployment configuration is invalid"
            return 1
        fi
    else
        log_warning "Traefik compose file not found"
    fi
}

# Test monitoring deployment
test_monitoring_deployment() {
    log_info "Testing monitoring deployment"
    
    cd "$PROJECT_ROOT"
    
    # Test monitoring compose file
    if [[ -f "docker-compose.monitoring.yml" ]]; then
        if docker-compose -f docker-compose.yml -f docker-compose.monitoring.yml config >/dev/null 2>&1; then
            log_success "Monitoring deployment configuration is valid"
        else
            log_error "Monitoring deployment configuration is invalid"
            return 1
        fi
    else
        log_warning "Monitoring compose file not found"
    fi
}

# Test environment configuration
test_environment_configuration() {
    log_info "Testing environment configuration"
    
    # Test with valid configuration
    if [[ -f "$TEST_ENV_FILE" ]]; then
        log_success "Test environment file exists"
        
        # Check required variables
        if grep -q "N8N_BASIC_AUTH_PASSWORD" "$TEST_ENV_FILE"; then
            log_success "N8N authentication is configured"
        else
            log_error "N8N authentication is missing"
            return 1
        fi
    else
        log_error "Test environment file not found"
        return 1
    fi
}

# Run all tests
run_test_suite() {
    log_info "Running deployment integration test suite"
    
    setup
    trap teardown EXIT
    
    test_basic_deployment
    test_nginx_deployment
    test_traefik_deployment
    test_monitoring_deployment
    test_environment_configuration
    
    log_success "Deployment integration tests completed"
}

# Run the test suite
run_test_suite

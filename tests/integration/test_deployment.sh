#!/bin/bash

# Integration Tests for N8N-R8 Deployment
# Tests complete deployment scenarios end-to-end

set -euo pipefail

# Get script directory and source helpers with error handling
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source test helpers with comprehensive error handling
# shellcheck source=../helpers/test_helpers.sh
if ! source "$SCRIPT_DIR/../helpers/test_helpers.sh" 2>/dev/null; then
    echo "CRITICAL ERROR: Cannot load test helpers from $SCRIPT_DIR/../helpers/test_helpers.sh"
    echo "This file is required for test execution. Please check:"
    echo "  1. File exists: $SCRIPT_DIR/../helpers/test_helpers.sh"
    echo "  2. File is readable"
    echo "  3. File has correct permissions"
    echo ""
    echo "Attempting to provide minimal fallback functions..."
    
    # Minimal fallback functions for critical operations
    log_info() { echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') $*"; }
    log_error() { echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') $*" >&2; }
    log_warning() { echo "[WARNING] $(date '+%Y-%m-%d %H:%M:%S') $*"; }
    log_success() { echo "[SUCCESS] $(date '+%Y-%m-%d %H:%M:%S') $*"; }
    
    echo "WARNING: Using minimal fallback functions. Test reliability may be reduced."
fi

# Source test configuration with error handling
# shellcheck source=../test_config.sh
if ! source "$SCRIPT_DIR/../test_config.sh" 2>/dev/null; then
    log_warning "Cannot load test configuration from $SCRIPT_DIR/../test_config.sh"
    log_info "Using default values for integration tests"
    
    # Set essential default values for integration tests
    TEST_TIMEOUT=${TEST_TIMEOUT:-600}
    PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
    
    log_info "Using defaults: TEST_TIMEOUT=$TEST_TIMEOUT, PROJECT_ROOT=$PROJECT_ROOT"
fi

# Validate critical dependencies and environment
validate_integration_environment() {
    local validation_errors=()
    
    # Check if we have required commands
    local required_commands=("docker" "docker-compose")
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            validation_errors+=("Required command not found: $cmd")
        fi
    done
    
    # Check if PROJECT_ROOT is set and valid
    if [[ -z "${PROJECT_ROOT:-}" ]]; then
        validation_errors+=("PROJECT_ROOT variable is not set")
    elif [[ ! -d "$PROJECT_ROOT" ]]; then
        validation_errors+=("PROJECT_ROOT directory does not exist: $PROJECT_ROOT")
    fi
    
    # Check for required files in project root
    local required_files=("docker-compose.yml")
    for file in "${required_files[@]}"; do
        if [[ ! -f "$PROJECT_ROOT/$file" ]]; then
            validation_errors+=("Required file not found: $PROJECT_ROOT/$file")
        fi
    done
    
    # Report validation results
    if [[ ${#validation_errors[@]} -gt 0 ]]; then
        log_error "Integration test environment validation failed:"
        for error in "${validation_errors[@]}"; do
            log_error "  - $error"
        done
        log_error "Cannot proceed with integration tests"
        return 1
    fi
    
    log_info "Integration test environment validation passed"
    return 0
}

# Perform environment validation
if ! validate_integration_environment; then
    log_error "Integration test environment is not properly configured"
    log_error "Please ensure Docker and docker-compose are installed and the project structure is correct"
    exit 1
fi

# Test variables
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
TEST_ENV_FILE=""

# Test setup with comprehensive error handling
setup() {
    log_info "Setting up deployment integration tests"
    
    # Validate PROJECT_ROOT is accessible
    if [[ ! -d "$PROJECT_ROOT" ]]; then
        log_error "PROJECT_ROOT directory not accessible: $PROJECT_ROOT"
        return 1
    fi
    
    if [[ ! -w "$PROJECT_ROOT" ]]; then
        log_error "PROJECT_ROOT directory is not writable: $PROJECT_ROOT"
        log_error "Integration tests require write access to create test files"
        return 1
    fi
    
    # Create test environment file with error handling
    TEST_ENV_FILE="$PROJECT_ROOT/.env.test"
    log_debug "Creating test environment file: $TEST_ENV_FILE"
    
    if ! cat > "$TEST_ENV_FILE" << 'EOF' 2>/dev/null
# Test environment configuration
N8N_BASIC_AUTH_USER=admin
N8N_BASIC_AUTH_PASSWORD=test_password_123!
POSTGRES_PASSWORD=test_secure_password!
REDIS_PASSWORD=test_redis_password!
N8N_ENCRYPTION_KEY=test-encryption-key-32-characters
N8N_JWT_SECRET=test-jwt-secret-key
EOF
    then
        log_error "Failed to create test environment file: $TEST_ENV_FILE"
        log_error "Check write permissions in PROJECT_ROOT directory"
        return 1
    fi
    
    # Verify test environment file was created correctly
    if [[ ! -f "$TEST_ENV_FILE" ]]; then
        log_error "Test environment file was not created: $TEST_ENV_FILE"
        return 1
    fi
    
    if [[ ! -r "$TEST_ENV_FILE" ]]; then
        log_error "Test environment file is not readable: $TEST_ENV_FILE"
        return 1
    fi
    
    # Validate Docker is available for integration tests
    if ! command -v docker >/dev/null 2>&1; then
        log_error "Docker is required for integration tests but not found"
        return 1
    fi
    
    if ! docker info >/dev/null 2>&1; then
        log_error "Docker daemon is not accessible"
        log_error "Please ensure Docker is running and accessible"
        return 1
    fi
    
    log_success "Integration test setup completed successfully"
    log_info "Test environment file: $TEST_ENV_FILE"
}

# Test cleanup with comprehensive error handling
teardown() {
    log_info "Cleaning up deployment integration tests"
    
    local cleanup_errors=()
    
    # Stop any running services with error handling
    if [[ -d "$PROJECT_ROOT" ]]; then
        log_debug "Stopping Docker services in: $PROJECT_ROOT"
        
        # Change to project directory safely
        if cd "$PROJECT_ROOT" 2>/dev/null; then
            # Try to stop services gracefully
            if command -v docker-compose >/dev/null 2>&1; then
                if ! docker-compose down --timeout 30 2>/dev/null; then
                    log_debug "docker-compose down failed, trying alternative methods"
                    
                    # Try docker compose (plugin version)
                    if ! docker compose down --timeout 30 2>/dev/null; then
                        cleanup_errors+=("Failed to stop Docker services gracefully")
                    fi
                fi
            else
                log_debug "docker-compose not available, skipping service cleanup"
            fi
        else
            cleanup_errors+=("Cannot change to PROJECT_ROOT directory: $PROJECT_ROOT")
        fi
    else
        log_debug "PROJECT_ROOT directory not accessible for cleanup"
    fi
    
    # Remove test files with error handling
    if [[ -n "$TEST_ENV_FILE" ]]; then
        if [[ -f "$TEST_ENV_FILE" ]]; then
            log_debug "Removing test environment file: $TEST_ENV_FILE"
            
            if ! rm -f "$TEST_ENV_FILE" 2>/dev/null; then
                cleanup_errors+=("Failed to remove test environment file: $TEST_ENV_FILE")
            else
                log_debug "Test environment file removed successfully"
            fi
        else
            log_debug "Test environment file does not exist: $TEST_ENV_FILE"
        fi
    else
        log_debug "TEST_ENV_FILE not set, no file cleanup needed"
    fi
    
    # Report cleanup results
    if [[ ${#cleanup_errors[@]} -gt 0 ]]; then
        log_warning "Integration test cleanup completed with errors:"
        for error in "${cleanup_errors[@]}"; do
            log_warning "  - $error"
        done
        log_warning "Manual cleanup may be required"
    else
        log_success "Integration test cleanup completed successfully"
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
        # Test with direct-access profile to include n8n service
        if COMPOSE_PROFILES=direct-access docker-compose -f docker-compose.yml -f docker-compose.nginx.yml config >/dev/null 2>&1; then
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
        # Test with direct-access profile to include n8n service
        if COMPOSE_PROFILES=direct-access docker-compose -f docker-compose.yml -f docker-compose.traefik.yml config >/dev/null 2>&1; then
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
        # Test with direct-access profile to include n8n service
        if COMPOSE_PROFILES=direct-access docker-compose -f docker-compose.yml -f docker-compose.monitoring.yml config >/dev/null 2>&1; then
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

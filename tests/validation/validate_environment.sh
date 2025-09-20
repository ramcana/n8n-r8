#!/bin/bash

# Environment Validation Tests for N8N-R8
# Validates system requirements and environment setup

set -euo pipefail

# Get script directory and source helpers
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../helpers/test_helpers.sh
source "$SCRIPT_DIR/../helpers/test_helpers.sh"
# shellcheck source=../test_config.sh
source "$SCRIPT_DIR/../test_config.sh"

# Test system requirements
test_system_requirements() {
    log_info "Testing system requirements"
    
    # Check OS
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        log_success "Operating system: Linux"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        log_success "Operating system: macOS"
    else
        log_warning "Operating system: $OSTYPE (may not be fully supported)"
    fi
}

# Test Docker availability
test_docker_availability() {
    log_info "Testing Docker availability"
    
    if command -v docker >/dev/null 2>&1; then
        log_success "Docker is installed"
        local docker_version
        docker_version=$(docker --version)
        log_info "Docker version: $docker_version"
    else
        log_error "Docker is not installed"
        return 1
    fi
}

# Test Docker Compose availability
test_docker_compose_availability() {
    log_info "Testing Docker Compose availability"
    
    if command -v docker-compose >/dev/null 2>&1; then
        log_success "Docker Compose is installed"
        local compose_version
        compose_version=$(docker-compose --version)
        log_info "Docker Compose version: $compose_version"
    elif docker compose version >/dev/null 2>&1; then
        log_success "Docker Compose (plugin) is available"
        local compose_version
        compose_version=$(docker compose version)
        log_info "Docker Compose version: $compose_version"
    else
        log_error "Docker Compose is not available"
        return 1
    fi
}

# Test network connectivity
test_network_connectivity() {
    log_info "Testing network connectivity"
    
    if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        log_success "Network connectivity is available"
    else
        log_warning "Network connectivity test failed"
    fi
}

# Test disk space
test_disk_space() {
    log_info "Testing disk space"
    
    local available_space
    available_space=$(df -BG . | awk 'NR==2{print $4}' | sed 's/G//')
    
    if [[ $available_space -ge 10 ]]; then
        log_success "Sufficient disk space available (${available_space}GB)"
    else
        log_warning "Low disk space (${available_space}GB) - consider cleanup"
    fi
}

# Test memory availability
test_memory_availability() {
    log_info "Testing memory availability"
    
    local mem_gb
    mem_gb=$(free -g | awk 'NR==2{print $2}')
    
    if [[ $mem_gb -ge 4 ]]; then
        log_success "Sufficient memory available (${mem_gb}GB)"
    else
        log_warning "Low memory (${mem_gb}GB) - N8N may need tuning"
    fi
}

# Test CPU architecture
test_cpu_architecture() {
    log_info "Testing CPU architecture"
    
    local arch
    arch=$(uname -m)
    
    case "$arch" in
        x86_64|amd64)
            log_success "CPU architecture ($arch) is supported"
            ;;
        arm64|aarch64)
            log_success "ARM architecture ($arch) is supported"
            ;;
        *)
            log_warning "CPU architecture ($arch) might not be fully supported"
            ;;
    esac
}

# Test environment configuration
test_environment_configuration() {
    log_info "Testing environment configuration"
    
    local env_file="$(dirname "$SCRIPT_DIR")/.env"
    if [[ -f "$env_file" ]]; then
        log_success "Environment file exists: $env_file"
        
        # Check for critical variables
        if grep -q "N8N_BASIC_AUTH_PASSWORD" "$env_file"; then
            log_success "N8N authentication is configured"
        else
            log_warning "N8N authentication might not be configured"
        fi
        
        if grep -q "POSTGRES_PASSWORD" "$env_file"; then
            log_success "PostgreSQL password is configured"
        else
            log_warning "PostgreSQL password might not be configured"
        fi
    else
        log_warning "Environment file not found: $env_file"
    fi
}

# Run all validation tests
run_test_suite() {
    log_info "Running environment validation test suite"
    
    test_system_requirements
    test_docker_availability
    test_docker_compose_availability
    test_network_connectivity
    test_disk_space
    test_memory_availability
    test_cpu_architecture
    test_environment_configuration
    
    log_success "Environment validation completed"
}

# Run the test suite
run_test_suite

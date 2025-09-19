#!/bin/bash

# Environment Validation Tests for N8N-R8
# Validates system requirements and environment setup

set -euo pipefail

# Get script directory and source helpers
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../helpers/test_helpers.sh"
source "$SCRIPT_DIR/../test_config.sh"

# Test setup
setup() {
    log_info "Setting up environment validation tests"
}

# Test cleanup
teardown() {
    log_info "Environment validation tests completed"
}

# Test Docker installation and version
test_docker_installation() {
    log_info "Testing Docker installation"
    
    # Check if Docker is installed
    assert_command_success "which docker" "Docker should be installed"
    
    # Check Docker daemon is running
    assert_command_success "docker info" "Docker daemon should be running"
    
    # Check Docker version
    local docker_version=$(docker --version | grep -oE '[0-9]+\.[0-9]+' | head -1)
    local min_version="$MIN_DOCKER_VERSION"
    
    if [[ $(echo "$docker_version >= $min_version" | bc -l) -eq 1 ]]; then
        log_success "Docker version $docker_version meets minimum requirement ($min_version)"
    else
        log_error "Docker version $docker_version is below minimum requirement ($min_version)"
        return 1
    fi
}

# Test Docker Compose installation and version
test_docker_compose_installation() {
    log_info "Testing Docker Compose installation"
    
    # Check if Docker Compose is installed
    assert_command_success "docker compose version" "Docker Compose should be installed"
    
    # Check Docker Compose version
    local compose_version=$(docker compose version --short | grep -oE '[0-9]+\.[0-9]+' | head -1)
    local min_version="$MIN_DOCKER_COMPOSE_VERSION"
    
    if [[ $(echo "$compose_version >= $min_version" | bc -l) -eq 1 ]]; then
        log_success "Docker Compose version $compose_version meets minimum requirement ($min_version)"
    else
        log_error "Docker Compose version $compose_version is below minimum requirement ($min_version)"
        return 1
    fi
}

# Test system memory requirements
test_memory_requirements() {
    log_info "Testing system memory requirements"
    
    # Get total memory in GB
    local total_memory_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local total_memory_gb=$((total_memory_kb / 1024 / 1024))
    
    if [[ $total_memory_gb -ge $MIN_MEMORY_GB ]]; then
        log_success "System memory ${total_memory_gb}GB meets minimum requirement (${MIN_MEMORY_GB}GB)"
    else
        log_error "System memory ${total_memory_gb}GB is below minimum requirement (${MIN_MEMORY_GB}GB)"
        return 1
    fi
    
    # Check available memory
    local available_memory_kb=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
    local available_memory_gb=$((available_memory_kb / 1024 / 1024))
    
    if [[ $available_memory_gb -ge 2 ]]; then
        log_success "Available memory ${available_memory_gb}GB is sufficient"
    else
        log_warning "Available memory ${available_memory_gb}GB might be insufficient for optimal performance"
    fi
}

# Test disk space requirements
test_disk_space_requirements() {
    log_info "Testing disk space requirements"
    
    local project_root="$(dirname "$SCRIPT_DIR")"
    local available_space_gb=$(df "$project_root" | tail -1 | awk '{print int($4/1024/1024)}')
    
    if [[ $available_space_gb -ge $MIN_DISK_GB ]]; then
        log_success "Available disk space ${available_space_gb}GB meets minimum requirement (${MIN_DISK_GB}GB)"
    else
        log_error "Available disk space ${available_space_gb}GB is below minimum requirement (${MIN_DISK_GB}GB)"
        return 1
    fi
}

# Test required system tools
test_required_tools() {
    log_info "Testing required system tools"
    
    local required_tools=("curl" "jq" "bc" "grep" "awk" "sed" "tar" "gzip")
    
    for tool in "${required_tools[@]}"; do
        assert_command_success "which $tool" "$tool should be installed"
    done
}

# Test network connectivity
test_network_connectivity() {
    if [[ "$VALIDATION_NETWORK_TESTS" != "true" ]]; then
        skip_test "Network tests disabled"
        return 0
    fi
    
    log_info "Testing network connectivity"
    
    # Test DNS resolution
    assert_command_success "nslookup google.com" "DNS resolution should work"
    
    # Test internet connectivity
    assert_command_success "curl -s --connect-timeout 10 https://google.com" "Internet connectivity should work"
    
    # Test Docker Hub connectivity
    assert_command_success "curl -s --connect-timeout 10 https://hub.docker.com" "Docker Hub should be accessible"
}

# Test port availability
test_port_availability() {
    log_info "Testing port availability"
    
    local required_ports=(5678 80 443 8080 9090 3000 9093 3001)
    
    for port in "${required_ports[@]}"; do
        if ! netstat -tuln | grep -q ":$port "; then
            log_success "Port $port is available"
        else
            log_warning "Port $port is already in use"
        fi
    done
}

# Test file permissions
test_file_permissions() {
    log_info "Testing file permissions"
    
    local project_root="$(dirname "$SCRIPT_DIR")"
    
    # Test if we can write to project directory
    local test_file="$project_root/.test_write_permission"
    if echo "test" > "$test_file" 2>/dev/null; then
        rm -f "$test_file"
        log_success "Write permissions are correct"
    else
        log_error "Cannot write to project directory"
        return 1
    fi
    
    # Test script executability
    local scripts_dir="$project_root/scripts"
    if [[ -d "$scripts_dir" ]]; then
        for script in "$scripts_dir"/*.sh; do
            if [[ -f "$script" ]]; then
                if [[ -x "$script" ]]; then
                    log_debug "Script $script is executable"
                else
                    log_warning "Script $script is not executable"
                fi
            fi
        done
    fi
}

# Test Docker permissions
test_docker_permissions() {
    log_info "Testing Docker permissions"
    
    # Test if current user can run Docker commands
    if docker ps > /dev/null 2>&1; then
        log_success "User can run Docker commands"
    else
        log_error "User cannot run Docker commands. May need to add user to docker group."
        return 1
    fi
    
    # Test Docker socket permissions
    if [[ -w /var/run/docker.sock ]]; then
        log_success "Docker socket is writable"
    else
        log_warning "Docker socket may not be writable"
    fi
}

# Test system limits
test_system_limits() {
    log_info "Testing system limits"
    
    # Test file descriptor limits
    local max_files=$(ulimit -n)
    if [[ $max_files -ge 1024 ]]; then
        log_success "File descriptor limit ($max_files) is sufficient"
    else
        log_warning "File descriptor limit ($max_files) might be too low"
    fi
    
    # Test process limits
    local max_processes=$(ulimit -u)
    if [[ $max_processes -ge 1024 ]]; then
        log_success "Process limit ($max_processes) is sufficient"
    else
        log_warning "Process limit ($max_processes) might be too low"
    fi
}

# Test timezone configuration
test_timezone_configuration() {
    log_info "Testing timezone configuration"
    
    # Check if timezone is set
    if [[ -f /etc/timezone ]] || [[ -L /etc/localtime ]]; then
        local timezone=$(timedatectl show --property=Timezone --value 2>/dev/null || cat /etc/timezone 2>/dev/null || echo "Unknown")
        log_success "Timezone is configured: $timezone"
    else
        log_warning "Timezone might not be properly configured"
    fi
}

# Test locale configuration
test_locale_configuration() {
    log_info "Testing locale configuration"
    
    # Check if locale is set
    if locale | grep -q "LANG="; then
        local lang=$(locale | grep "LANG=" | cut -d= -f2)
        log_success "Locale is configured: $lang"
    else
        log_warning "Locale might not be properly configured"
    fi
}

# Test CPU architecture
test_cpu_architecture() {
    log_info "Testing CPU architecture"
    
    local arch=$(uname -m)
    case "$arch" in
        x86_64|amd64)
            log_success "CPU architecture ($arch) is supported"
            ;;
        arm64|aarch64)
            log_success "CPU architecture ($arch) is supported"
            ;;
        *)
            log_warning "CPU architecture ($arch) might not be fully supported"
            ;;
    esac
}

# Test kernel version
test_kernel_version() {
    log_info "Testing kernel version"
    
    local kernel_version=$(uname -r)
    local kernel_major=$(echo "$kernel_version" | cut -d. -f1)
    local kernel_minor=$(echo "$kernel_version" | cut -d. -f2)
    
    # Docker requires kernel 3.10+
    if [[ $kernel_major -gt 3 ]] || [[ $kernel_major -eq 3 && $kernel_minor -ge 10 ]]; then
        log_success "Kernel version ($kernel_version) is supported"
    else
        log_error "Kernel version ($kernel_version) is too old for Docker"
        return 1
    fi
}

# Test environment variables
test_environment_variables() {
    log_info "Testing environment variables"
    
    # Check if required environment variables are set
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
run_test_suite

#!/bin/bash

# Environment Validation Tests for N8N-R8
# Validates system requirements and environment setup

set -euo pipefail

# Get script directory and source helpers with error handling
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source test helpers with comprehensive error handling
# shellcheck source=../helpers/test_helpers.sh
if ! source "$SCRIPT_DIR/../helpers/test_helpers.sh" 2>/dev/null; then
    echo "WARNING: Cannot load test helpers from $SCRIPT_DIR/../helpers/test_helpers.sh"
    echo "Validation tests will continue with basic logging functions."
    echo "Some advanced features may not be available."
    echo ""
    
    # Provide essential logging functions for validation
    log_info() { echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') $*"; }
    log_error() { echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') $*" >&2; }
    log_warning() { echo "[WARNING] $(date '+%Y-%m-%d %H:%M:%S') $*"; }
    log_success() { echo "[SUCCESS] $(date '+%Y-%m-%d %H:%M:%S') $*"; }
    
    echo "Continuing with basic logging functions..."
fi

# Source test configuration with error handling
# shellcheck source=../test_config.sh
if ! source "$SCRIPT_DIR/../test_config.sh" 2>/dev/null; then
    log_warning "Cannot load test configuration from $SCRIPT_DIR/../test_config.sh"
    log_info "Validation will proceed with minimal configuration"
    
    # Set minimal defaults for validation tests
    PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
    VALIDATION_SKIP_SLOW=${VALIDATION_SKIP_SLOW:-false}
    VALIDATION_NETWORK_TESTS=${VALIDATION_NETWORK_TESTS:-true}
    MIN_MEMORY_GB=${MIN_MEMORY_GB:-4}
    MIN_DISK_GB=${MIN_DISK_GB:-10}
    
    log_info "Using minimal configuration for validation tests"
fi

# Validate validation test environment
validate_validation_environment() {
    local validation_errors=()
    local validation_warnings=()
    
    # Check basic system commands
    local required_commands=("uname" "df" "free" "date")
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            validation_errors+=("Required system command not found: $cmd")
        fi
    done
    
    # Check optional but useful commands
    local optional_commands=("docker" "docker-compose" "ping" "curl" "jq")
    for cmd in "${optional_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            validation_warnings+=("Optional command not found: $cmd (some tests may be skipped)")
        fi
    done
    
    # Check PROJECT_ROOT if set
    if [[ -n "${PROJECT_ROOT:-}" ]] && [[ ! -d "$PROJECT_ROOT" ]]; then
        validation_warnings+=("PROJECT_ROOT directory does not exist: $PROJECT_ROOT")
    fi
    
    # Report validation results
    if [[ ${#validation_errors[@]} -gt 0 ]]; then
        log_error "Validation environment check failed:"
        for error in "${validation_errors[@]}"; do
            log_error "  - $error"
        done
        return 1
    fi
    
    if [[ ${#validation_warnings[@]} -gt 0 ]]; then
        log_warning "Validation environment warnings:"
        for warning in "${validation_warnings[@]}"; do
            log_warning "  - $warning"
        done
    fi
    
    log_info "Validation environment check completed"
    return 0
}

# Enhanced error handling for individual validation tests
safe_command_check() {
    local command="$1"
    local description="$2"
    
    if command -v "$command" >/dev/null 2>&1; then
        return 0
    else
        log_warning "$description: $command not found"
        return 1
    fi
}

safe_network_test() {
    local target="$1"
    local description="$2"
    
    if [[ "${VALIDATION_NETWORK_TESTS:-true}" != "true" ]]; then
        log_info "Network tests disabled, skipping $description"
        return 0
    fi
    
    if ! command -v ping >/dev/null 2>&1; then
        log_warning "ping command not available, skipping network test for $description"
        return 0
    fi
    
    if timeout 5 ping -c 1 "$target" >/dev/null 2>&1; then
        return 0
    else
        log_warning "$description: Network connectivity test failed for $target"
        return 1
    fi
}

# Perform environment validation
if ! validate_validation_environment; then
    log_error "Validation environment is not properly configured"
    log_error "Please ensure basic system commands are available"
    exit 1
fi

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
    
    if safe_command_check "docker" "Docker"; then
        log_success "Docker is installed"
        
        # Try to get version with error handling
        local docker_version
        if docker_version=$(docker --version 2>/dev/null); then
            log_info "Docker version: $docker_version"
            
            # Test Docker daemon connectivity
            if docker info >/dev/null 2>&1; then
                log_success "Docker daemon is accessible"
            else
                log_warning "Docker is installed but daemon is not accessible"
                log_info "This may require starting Docker service or checking permissions"
                return 1
            fi
        else
            log_warning "Docker is installed but version check failed"
            return 1
        fi
    else
        log_error "Docker is not installed"
        log_error "Please install Docker to use this project"
        return 1
    fi
}

# Test Docker Compose availability
test_docker_compose_availability() {
    log_info "Testing Docker Compose availability"
    
    local compose_available=false
    local compose_version=""
    
    # Check for standalone docker-compose
    if safe_command_check "docker-compose" "Docker Compose (standalone)"; then
        if compose_version=$(docker-compose --version 2>/dev/null); then
            log_success "Docker Compose (standalone) is available"
            log_info "Version: $compose_version"
            compose_available=true
        fi
    fi
    
    # Check for docker compose plugin
    if [[ "$compose_available" != "true" ]] && safe_command_check "docker" "Docker"; then
        if compose_version=$(docker compose version 2>/dev/null); then
            log_success "Docker Compose (plugin) is available"
            log_info "Version: $compose_version"
            compose_available=true
        fi
    fi
    
    if [[ "$compose_available" != "true" ]]; then
        log_error "Docker Compose is not available"
        log_error "Please install Docker Compose to use this project"
        return 1
    fi
}

# Test network connectivity
test_network_connectivity() {
    log_info "Testing network connectivity"
    
    if safe_network_test "8.8.8.8" "Google DNS connectivity"; then
        log_success "Network connectivity is available"
    else
        log_warning "Network connectivity test failed"
        log_info "This may affect Docker image downloads and external integrations"
    fi
}

# Test disk space
test_disk_space() {
    log_info "Testing disk space"
    
    if ! command -v df >/dev/null 2>&1; then
        log_warning "df command not available, skipping disk space check"
        return 0
    fi
    
    local available_space
    if available_space=$(df -BG . 2>/dev/null | awk 'NR==2{print $4}' | sed 's/G//'); then
        if [[ -n "$available_space" && "$available_space" =~ ^[0-9]+$ ]]; then
            local min_required=${MIN_DISK_GB:-10}
            if [[ $available_space -ge $min_required ]]; then
                log_success "Sufficient disk space available (${available_space}GB >= ${min_required}GB required)"
            else
                log_warning "Low disk space (${available_space}GB < ${min_required}GB required)"
                log_info "Consider freeing up disk space before running N8N"
            fi
        else
            log_warning "Could not parse disk space information: '$available_space'"
        fi
    else
        log_warning "Failed to check disk space"
        log_info "This may indicate filesystem issues or permission problems"
    fi
}

# Test memory availability
test_memory_availability() {
    log_info "Testing memory availability"
    
    if ! command -v free >/dev/null 2>&1; then
        log_warning "free command not available, skipping memory check"
        return 0
    fi
    
    local mem_gb
    if mem_gb=$(free -g 2>/dev/null | awk 'NR==2{print $2}'); then
        if [[ -n "$mem_gb" && "$mem_gb" =~ ^[0-9]+$ ]]; then
            local min_required=${MIN_MEMORY_GB:-4}
            if [[ $mem_gb -ge $min_required ]]; then
                log_success "Sufficient memory available (${mem_gb}GB >= ${min_required}GB required)"
            else
                log_warning "Low memory (${mem_gb}GB < ${min_required}GB required)"
                log_info "N8N may require memory tuning or additional RAM"
                log_info "Consider adjusting Docker memory limits or closing other applications"
            fi
        else
            log_warning "Could not parse memory information: '$mem_gb'"
        fi
    else
        log_warning "Failed to check memory availability"
        log_info "This may indicate system issues or permission problems"
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
    
    local project_root
    if [[ -n "${PROJECT_ROOT:-}" ]]; then
        project_root="$PROJECT_ROOT"
    else
        project_root="$(dirname "$(dirname "$SCRIPT_DIR")")"
    fi
    
    local env_file="$project_root/.env"
    local env_example_file="$project_root/.env.example"
    
    # Check if environment file exists
    if [[ -f "$env_file" ]]; then
        log_success "Environment file exists: $env_file"
        
        # Validate file is readable
        if [[ ! -r "$env_file" ]]; then
            log_error "Environment file exists but is not readable: $env_file"
            log_error "Please check file permissions"
            return 1
        fi
        
        # Check for critical variables with better error handling
        local missing_vars=()
        local critical_vars=("N8N_BASIC_AUTH_PASSWORD" "POSTGRES_PASSWORD" "REDIS_PASSWORD")
        
        for var in "${critical_vars[@]}"; do
            if grep -q "^${var}=" "$env_file" 2>/dev/null; then
                # Check if variable has a non-empty value
                local var_value
                var_value=$(grep "^${var}=" "$env_file" | cut -d'=' -f2- | tr -d '"' | tr -d "'")
                if [[ -n "$var_value" && "$var_value" != "your_password_here" && "$var_value" != "changeme" ]]; then
                    log_success "$var is configured with a value"
                else
                    log_warning "$var is set but appears to use a default/placeholder value"
                    missing_vars+=("$var")
                fi
            else
                log_warning "$var is not configured in environment file"
                missing_vars+=("$var")
            fi
        done
        
        if [[ ${#missing_vars[@]} -gt 0 ]]; then
            log_warning "The following critical variables need attention:"
            for var in "${missing_vars[@]}"; do
                log_warning "  - $var"
            done
            log_info "Please review and update these variables for security"
        fi
        
    else
        log_warning "Environment file not found: $env_file"
        
        # Check if example file exists
        if [[ -f "$env_example_file" ]]; then
            log_info "Example environment file found: $env_example_file"
            log_info "You can copy this file to create your environment configuration:"
            log_info "  cp '$env_example_file' '$env_file'"
        else
            log_warning "No example environment file found: $env_example_file"
        fi
        
        log_info "Environment configuration is required for proper N8N operation"
        return 1
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

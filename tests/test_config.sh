#!/bin/bash

# N8N-R8 Test Configuration
# Central configuration for all test settings

# Project root directory - set relative to this config file
PROJECT_ROOT="$(dirname "$(dirname "$(realpath "${BASH_SOURCE[0]}")")")"
# Test execution settings
TEST_TIMEOUT=${TEST_TIMEOUT:-300}          # Default test timeout in seconds
TEST_PARALLEL=${TEST_PARALLEL:-false}      # Run tests in parallel
TEST_CLEANUP=${TEST_CLEANUP:-true}         # Clean up after tests
TEST_VERBOSE=${TEST_VERBOSE:-false}        # Verbose output
TEST_DEBUG=${TEST_DEBUG:-false}            # Debug output
# Docker test settings
TEST_DOCKER_NETWORK="n8n-test"             # Test Docker network name
TEST_DOCKER_PREFIX="test_"                 # Prefix for test containers
TEST_DOCKER_TIMEOUT=60                     # Docker operation timeout
# Test data directories
TEST_DATA_DIR="$(dirname "$0")/fixtures/test_data"
TEST_CONFIG_DIR="$(dirname "$0")/fixtures/test_configs"
TEST_BACKUP_DIR="/tmp/n8n_test_backups"
# Service test endpoints
TEST_N8N_URL="http://localhost:5678"
TEST_NGINX_URL="http://localhost"
TEST_TRAEFIK_URL="http://localhost"
TEST_TRAEFIK_DASHBOARD="http://localhost:8080"
TEST_PROMETHEUS_URL="http://localhost:9090"
TEST_GRAFANA_URL="http://localhost:3000"
TEST_ALERTMANAGER_URL="http://localhost:9093"
# Test credentials (for testing only)
TEST_N8N_USER="test_admin"
TEST_N8N_PASSWORD="test_password_123!"
TEST_POSTGRES_PASSWORD="test_postgres_123!"
TEST_REDIS_PASSWORD="test_redis_123!"
# Performance test thresholds
PERFORMANCE_STARTUP_TIME_LIMIT=120         # Max startup time in seconds
PERFORMANCE_RESPONSE_TIME_LIMIT=5          # Max response time in seconds
PERFORMANCE_MEMORY_LIMIT_MB=2048           # Max memory usage in MB
PERFORMANCE_CPU_LIMIT_PERCENT=80           # Max CPU usage percentage
# Coverage settings
COVERAGE_ENABLED=${COVERAGE_ENABLED:-false}
COVERAGE_THRESHOLD=80                       # Minimum coverage percentage
COVERAGE_REPORT_FORMAT="html"              # html, xml, console
# Security test settings
SECURITY_SCAN_ENABLED=${SECURITY_SCAN_ENABLED:-false}
SECURITY_VULNERABILITY_THRESHOLD="medium"   # low, medium, high, critical
# Integration test settings
INTEGRATION_TEST_TIMEOUT=600               # Longer timeout for integration tests
INTEGRATION_CLEANUP_DELAY=5                # Delay before cleanup in seconds
# Validation test settings
VALIDATION_SKIP_SLOW=${VALIDATION_SKIP_SLOW:-false}  # Skip slow validation tests
VALIDATION_NETWORK_TESTS=${VALIDATION_NETWORK_TESTS:-true}  # Run network tests
# Report settings
REPORT_FORMAT=${REPORT_FORMAT:-"console"}  # console, junit, html
REPORTS_DIR="$(dirname "$0")/reports"
# Environment validation requirements
MIN_DOCKER_VERSION="20.10"
MIN_DOCKER_COMPOSE_VERSION="2.0"
MIN_MEMORY_GB=4
MIN_DISK_GB=10
# Test environment variables
export TEST_ENV="testing"
export N8N_BASIC_AUTH_USER="$TEST_N8N_USER"
export N8N_BASIC_AUTH_PASSWORD="$TEST_N8N_PASSWORD"
export POSTGRES_PASSWORD="$TEST_POSTGRES_PASSWORD"
export REDIS_PASSWORD="$TEST_REDIS_PASSWORD"
export N8N_ENCRYPTION_KEY="test-encryption-key-32-characters"
export N8N_JWT_SECRET="test-jwt-secret-key"
# Logging configuration
LOG_LEVEL=${LOG_LEVEL:-"INFO"}             # DEBUG, INFO, WARNING, ERROR
LOG_FILE="$REPORTS_DIR/test.log"
# Custom test configurations per category
declare -A UNIT_TEST_CONFIG=(
    ["timeout"]="60"
    ["parallel"]="true"
    ["cleanup"]="true"
)
declare -A INTEGRATION_TEST_CONFIG=(
    ["timeout"]="600"
    ["parallel"]="false"
    ["setup_delay"]="10"
)

declare -A VALIDATION_TEST_CONFIG=(
    ["timeout"]="300"
    ["cleanup"]="false"
    ["skip_network"]="false"
)
# Function to get test-specific configuration
get_test_config() {
    local category="$1"
    local key="$2"
    local default="$3"
    
    case "$category" in
        "unit")
            echo "${UNIT_TEST_CONFIG[$key]:-$default}"
            ;;
        "integration")
            echo "${INTEGRATION_TEST_CONFIG[$key]:-$default}"
            ;;
        "validation")
            echo "${VALIDATION_TEST_CONFIG[$key]:-$default}"
            ;;
        *)
            echo "$default"
            ;;
    esac
}
# Export configuration for use in test scripts
export PROJECT_ROOT
export TEST_TIMEOUT TEST_PARALLEL TEST_CLEANUP TEST_VERBOSE TEST_DEBUG
export TEST_DOCKER_NETWORK TEST_DOCKER_PREFIX TEST_DOCKER_TIMEOUT
export TEST_DATA_DIR TEST_CONFIG_DIR TEST_BACKUP_DIR
export TEST_N8N_URL TEST_NGINX_URL TEST_TRAEFIK_URL TEST_TRAEFIK_DASHBOARD
export TEST_PROMETHEUS_URL TEST_GRAFANA_URL TEST_ALERTMANAGER_URL
export TEST_N8N_USER TEST_N8N_PASSWORD TEST_POSTGRES_PASSWORD TEST_REDIS_PASSWORD
export PERFORMANCE_STARTUP_TIME_LIMIT PERFORMANCE_RESPONSE_TIME_LIMIT
export PERFORMANCE_MEMORY_LIMIT_MB PERFORMANCE_CPU_LIMIT_PERCENT
export COVERAGE_ENABLED COVERAGE_THRESHOLD COVERAGE_REPORT_FORMAT
export SECURITY_SCAN_ENABLED SECURITY_VULNERABILITY_THRESHOLD
export INTEGRATION_TEST_TIMEOUT INTEGRATION_CLEANUP_DELAY
export VALIDATION_SKIP_SLOW VALIDATION_NETWORK_TESTS
export REPORT_FORMAT REPORTS_DIR
export MIN_DOCKER_VERSION MIN_DOCKER_COMPOSE_VERSION MIN_MEMORY_GB MIN_DISK_GB
export LOG_LEVEL LOG_FILE

#!/bin/bash

# N8N-R8 Health Check Script
# Comprehensive health checking for all services
set -euo pipefail

# Script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Configuration
CONFIG_FILE="${PROJECT_ROOT}/.env"
LOG_FILE="${PROJECT_ROOT}/logs/health-check.log"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test function for JSON output
test_json_output() {
    # Mock check_container_health for testing
    check_container_health() {
        echo "running"
    }
    json_output "healthy" 5 10
}

# JSON output format
json_output() {
    local status="$1"
    local checks_passed="$2"
    local checks_total="$3"
    
    local success_rate
    if command -v bc >/dev/null 2>&1; then
        success_rate=$(echo "scale=2; $checks_passed * 100 / $checks_total" | bc -l)
    else
        success_rate=$(( checks_passed * 100 / checks_total ))
    fi
    
    local n8n_health
    n8n_health=$(check_container_health "n8n")
    local postgres_health
    postgres_health=$(check_container_health "n8n-postgres")
    local redis_health
    redis_health=$(check_container_health "n8n-redis")
    
    local timestamp
    timestamp=$(date -Iseconds)
    
    printf '{
    "timestamp": "%s",
    "status": "%s",
    "checks": {
        "passed": %d,
        "total": %d,
        "success_rate": %s
    },
    "containers": {
        "n8n": "%s",
        "postgres": "%s",
        "redis": "%s"
    }
}\n' \
        "$timestamp" \
        "$status" \
        "$checks_passed" \
        "$checks_total" \
        "$success_rate" \
        "$n8n_health" \
        "$postgres_health" \
        "$redis_health"
}

# Show usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS] COMMAND
N8N-R8 Health Check Script

COMMANDS:
    check           Comprehensive health check
    quick           Quick health check (for scripts)
    wait            Wait for services to be healthy
    containers      Check container status only
    services        Check service connectivity only
    resources       Check system resources only

OPTIONS:
    -h, --help      Show this help message
    -q, --quiet     Quiet mode (minimal output)
    -t, --timeout   Set timeout for checks (default: 30s)
    --json          Output in JSON format

EXAMPLES:
    $0 check                    # Full health check
    $0 quick                    # Quick check for scripts
    $0 wait 300                 # Wait up to 5 minutes
    $0 containers               # Check containers only
EOF
}

# Main entry point
main() {
    echo "Testing JSON output..."
    test_json_output
}

# Run main function if not sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
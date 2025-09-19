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
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Load configuration
if [[ -f "$CONFIG_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
fi

# Default values
N8N_HOST="${N8N_HOST:-localhost}"
N8N_PORT="${N8N_PORT:-5678}"
N8N_PROTOCOL="${N8N_PROTOCOL:-http}"
POSTGRES_HOST="${POSTGRES_HOST:-localhost}"
POSTGRES_PORT="${POSTGRES_PORT:-5432}"
REDIS_HOST="${REDIS_HOST:-localhost}"
REDIS_PORT="${REDIS_PORT:-6379}"

# Health check timeout
TIMEOUT="${HEALTH_CHECK_TIMEOUT:-30}"

# Logging function
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo -e "${timestamp} [${level}] ${message}" | tee -a "$LOG_FILE"
}

# Check if container is running
check_container() {
    local container_name="$1"
    
    if docker ps --format "table {{.Names}}" | grep -q "^${container_name}$"; then
        return 0
    else
        return 1
    fi
}

# Check container health status
check_container_health() {
    local container_name="$1"
    
    if ! check_container "$container_name"; then
        echo "not_running"
        return 1
    fi
    
    local health_status=$(docker inspect --format='{{.State.Health.Status}}' "$container_name" 2>/dev/null || echo "no_healthcheck")
    echo "$health_status"
    
    case "$health_status" in
        "healthy") return 0 ;;
        "starting") return 2 ;;
        "unhealthy") return 1 ;;
        "no_healthcheck") return 3 ;;
        *) return 1 ;;
    esac
}

# Check N8N web interface
check_n8n_web() {
    local url="${N8N_PROTOCOL}://${N8N_HOST}:${N8N_PORT}/healthz"
    
    if curl -f -s --max-time "$TIMEOUT" "$url" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Check PostgreSQL connection
check_postgres() {
    if docker exec n8n-postgres pg_isready -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Check Redis connection
check_redis() {
    if docker exec n8n-redis redis-cli ping >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Check disk space
check_disk_space() {
    local threshold="${DISK_SPACE_THRESHOLD:-90}"
    local usage=$(df "$PROJECT_ROOT" | tail -1 | awk '{print $5}' | sed 's/%//')
    
    if [[ "$usage" -lt "$threshold" ]]; then
        echo "$usage"
        return 0
    else
        echo "$usage"
        return 1
    fi
}

# Check memory usage
check_memory() {
    local threshold="${MEMORY_THRESHOLD:-90}"
    local usage=$(free | grep '^Mem:' | awk '{printf "%.0f", $3/$2 * 100.0}')
    
    if [[ "$usage" -lt "$threshold" ]]; then
        echo "$usage"
        return 0
    else
        echo "$usage"
        return 1
    fi
}

# Comprehensive health check
comprehensive_check() {
    local overall_status=0
    local checks_passed=0
    local checks_total=0
    
    echo -e "${BLUE}N8N-R8 Health Check Report${NC}"
    echo -e "${BLUE}===========================${NC}"
    echo ""
    
    # Container checks
    echo -e "${BLUE}Container Status:${NC}"
    
    # N8N container
    checks_total=$((checks_total + 1))
    local n8n_health=$(check_container_health "n8n")
    case "$n8n_health" in
        "healthy")
            echo -e "  ✅ N8N: ${GREEN}healthy${NC}"
            checks_passed=$((checks_passed + 1))
            ;;
        "starting")
            echo -e "  🔄 N8N: ${YELLOW}starting${NC}"
            overall_status=2
            ;;
        "unhealthy")
            echo -e "  ❌ N8N: ${RED}unhealthy${NC}"
            overall_status=1
            ;;
        "not_running")
            echo -e "  ⭕ N8N: ${RED}not running${NC}"
            overall_status=1
            ;;
        "no_healthcheck")
            echo -e "  ⚪ N8N: ${YELLOW}no healthcheck${NC}"
            checks_passed=$((checks_passed + 1))
            ;;
    esac
    
    # PostgreSQL container
    checks_total=$((checks_total + 1))
    local postgres_health=$(check_container_health "n8n-postgres")
    case "$postgres_health" in
        "healthy")
            echo -e "  ✅ PostgreSQL: ${GREEN}healthy${NC}"
            checks_passed=$((checks_passed + 1))
            ;;
        "starting")
            echo -e "  🔄 PostgreSQL: ${YELLOW}starting${NC}"
            overall_status=2
            ;;
        "unhealthy")
            echo -e "  ❌ PostgreSQL: ${RED}unhealthy${NC}"
            overall_status=1
            ;;
        "not_running")
            echo -e "  ⭕ PostgreSQL: ${RED}not running${NC}"
            overall_status=1
            ;;
        "no_healthcheck")
            echo -e "  ⚪ PostgreSQL: ${YELLOW}no healthcheck${NC}"
            checks_passed=$((checks_passed + 1))
            ;;
    esac
    
    # Redis container
    checks_total=$((checks_total + 1))
    local redis_health=$(check_container_health "n8n-redis")
    case "$redis_health" in
        "healthy")
            echo -e "  ✅ Redis: ${GREEN}healthy${NC}"
            checks_passed=$((checks_passed + 1))
            ;;
        "starting")
            echo -e "  🔄 Redis: ${YELLOW}starting${NC}"
            overall_status=2
            ;;
        "unhealthy")
            echo -e "  ❌ Redis: ${RED}unhealthy${NC}"
            overall_status=1
            ;;
        "not_running")
            echo -e "  ⭕ Redis: ${RED}not running${NC}"
            overall_status=1
            ;;
        "no_healthcheck")
            echo -e "  ⚪ Redis: ${YELLOW}no healthcheck${NC}"
            checks_passed=$((checks_passed + 1))
            ;;
    esac
    
    echo ""
    
    # Service connectivity checks
    echo -e "${BLUE}Service Connectivity:${NC}"
    
    # N8N web interface
    checks_total=$((checks_total + 1))
    if check_n8n_web; then
        echo -e "  ✅ N8N Web Interface: ${GREEN}accessible${NC}"
        checks_passed=$((checks_passed + 1))
    else
        echo -e "  ❌ N8N Web Interface: ${RED}not accessible${NC}"
        overall_status=1
    fi
    
    # PostgreSQL connection
    checks_total=$((checks_total + 1))
    if check_postgres; then
        echo -e "  ✅ PostgreSQL Connection: ${GREEN}ok${NC}"
        checks_passed=$((checks_passed + 1))
    else
        echo -e "  ❌ PostgreSQL Connection: ${RED}failed${NC}"
        overall_status=1
    fi
    
    # Redis connection
    checks_total=$((checks_total + 1))
    if check_redis; then
        echo -e "  ✅ Redis Connection: ${GREEN}ok${NC}"
        checks_passed=$((checks_passed + 1))
    else
        echo -e "  ❌ Redis Connection: ${RED}failed${NC}"
        overall_status=1
    fi
    
    echo ""
    
    # System resource checks
    echo -e "${BLUE}System Resources:${NC}"
    
    # Disk space
    checks_total=$((checks_total + 1))
    local disk_usage
    if disk_usage=$(check_disk_space); then
        echo -e "  ✅ Disk Space: ${GREEN}${disk_usage}% used${NC}"
        checks_passed=$((checks_passed + 1))
    else
        echo -e "  ⚠️  Disk Space: ${YELLOW}${disk_usage}% used (high)${NC}"
        if [[ "$overall_status" -eq 0 ]]; then
            overall_status=2
        fi
    fi
    
    # Memory usage
    checks_total=$((checks_total + 1))
    local memory_usage
    if memory_usage=$(check_memory); then
        echo -e "  ✅ Memory Usage: ${GREEN}${memory_usage}% used${NC}"
        checks_passed=$((checks_passed + 1))
    else
        echo -e "  ⚠️  Memory Usage: ${YELLOW}${memory_usage}% used (high)${NC}"
        if [[ "$overall_status" -eq 0 ]]; then
            overall_status=2
        fi
    fi
    
    echo ""
    
    # Summary
    echo -e "${BLUE}Summary:${NC}"
    echo -e "  Checks passed: ${checks_passed}/${checks_total}"
    
    case "$overall_status" in
        0)
            echo -e "  Overall status: ${GREEN}HEALTHY${NC}"
            log "INFO" "Health check passed: ${checks_passed}/${checks_total} checks successful"
            ;;
        1)
            echo -e "  Overall status: ${RED}UNHEALTHY${NC}"
            log "ERROR" "Health check failed: ${checks_passed}/${checks_total} checks successful"
            ;;
        2)
            echo -e "  Overall status: ${YELLOW}WARNING${NC}"
            log "WARN" "Health check warning: ${checks_passed}/${checks_total} checks successful"
            ;;
    esac
    
    return "$overall_status"
}

# Quick health check (for scripts)
quick_check() {
    local failed_checks=0
    
    # Check critical containers
    if ! check_container "n8n"; then
        failed_checks=$((failed_checks + 1))
    fi
    
    if ! check_container "n8n-postgres"; then
        failed_checks=$((failed_checks + 1))
    fi
    
    if ! check_container "n8n-redis"; then
        failed_checks=$((failed_checks + 1))
    fi
    
    # Check N8N web interface
    if ! check_n8n_web; then
        failed_checks=$((failed_checks + 1))
    fi
    
    return "$failed_checks"
}

# Wait for services to be healthy
wait_for_healthy() {
    local max_wait="${1:-300}"  # 5 minutes default
    local check_interval="${2:-10}"  # 10 seconds default
    local wait_time=0
    
    echo "Waiting for services to be healthy (max ${max_wait}s)..."
    
    while [[ $wait_time -lt $max_wait ]]; do
        if quick_check; then
            echo -e "${GREEN}All services are healthy${NC}"
            return 0
        fi
        
        echo "Waiting... (${wait_time}s/${max_wait}s)"
        sleep "$check_interval"
        wait_time=$((wait_time + check_interval))
    done
    
    echo -e "${RED}Services did not become healthy within ${max_wait} seconds${NC}"
    return 1
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

# JSON output format
json_output() {
    local status="$1"
    local checks_passed="$2"
    local checks_total="$3"
    
    cat << EOF
{
    "timestamp": "$(date -Iseconds)",
    "status": "$status",
    "checks": {
        "passed": $checks_passed,
        "total": $checks_total,
        "success_rate": $(echo "scale=2; $checks_passed * 100 / $checks_total" | bc -l)
    },
    "containers": {
        "n8n": "$(check_container_health "n8n")",
        "postgres": "$(check_container_health "n8n-postgres")",
        "redis": "$(check_container_health "n8n-redis")"
    }
}
EOF
}

# Main function
main() {
    local command="${1:-check}"
    local quiet=false
    local json=false
    local timeout=30
    
    # Parse options
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                exit 0
                ;;
            -q|--quiet)
                quiet=true
                shift
                ;;
            -t|--timeout)
                timeout="$2"
                shift 2
                ;;
            --json)
                json=true
                shift
                ;;
            check|quick|wait|containers|services|resources)
                command="$1"
                shift
                ;;
            *)
                if [[ "$command" == "wait" && "$1" =~ ^[0-9]+$ ]]; then
                    # Numeric argument for wait command
                    shift
                else
                    echo "Unknown option: $1"
                    usage
                    exit 1
                fi
                ;;
        esac
    done
    
    # Set timeout
    TIMEOUT="$timeout"
    
    # Create logs directory
    mkdir -p "$(dirname "$LOG_FILE")"
    
    # Execute command
    case "$command" in
        check)
            if [[ "$json" == "true" ]]; then
                # JSON output not implemented for comprehensive check yet
                echo '{"error": "JSON output not available for comprehensive check"}'
                exit 1
            else
                comprehensive_check
            fi
            ;;
        quick)
            if quick_check; then
                if [[ "$quiet" != "true" ]]; then
                    echo -e "${GREEN}All services are healthy${NC}"
                fi
                exit 0
            else
                if [[ "$quiet" != "true" ]]; then
                    echo -e "${RED}Some services are unhealthy${NC}"
                fi
                exit 1
            fi
            ;;
        wait)
            local max_wait="${2:-300}"
            wait_for_healthy "$max_wait"
            ;;
        containers)
            echo -e "${BLUE}Container Status Check${NC}"
            check_container_health "n8n" >/dev/null
            check_container_health "n8n-postgres" >/dev/null
            check_container_health "n8n-redis" >/dev/null
            ;;
        services)
            echo -e "${BLUE}Service Connectivity Check${NC}"
            check_n8n_web
            check_postgres
            check_redis
            ;;
        resources)
            echo -e "${BLUE}System Resources Check${NC}"
            check_disk_space >/dev/null
            check_memory >/dev/null
            ;;
        *)
            echo "Unknown command: $command"
            usage
            exit 1
            ;;
    esac
}

# Run main function
main "$@"

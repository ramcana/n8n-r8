#!/bin/bash

# N8N-R8 Monitoring Script
# Comprehensive monitoring for N8N services, health checks, and system resources
set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
MONITORING_DIR="$SCRIPT_DIR/.."
LOG_DIR="$MONITORING_DIR/logs"
CONFIG_FILE="$MONITORING_DIR/config/monitor.conf"

# Default configuration
DEFAULT_CHECK_INTERVAL=30
DEFAULT_DISK_THRESHOLD=80
DEFAULT_MEMORY_THRESHOLD=85
DEFAULT_LOG_RETENTION_DAYS=14
DEFAULT_ALERT_COOLDOWN=600

# Load configuration if available
if [[ -f "$CONFIG_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
fi

# Set defaults if not configured
CHECK_INTERVAL=${CHECK_INTERVAL:-$DEFAULT_CHECK_INTERVAL}
DISK_THRESHOLD=${DISK_THRESHOLD:-$DEFAULT_DISK_THRESHOLD}
MEMORY_THRESHOLD=${MEMORY_THRESHOLD:-$DEFAULT_MEMORY_THRESHOLD}
LOG_RETENTION_DAYS=${LOG_RETENTION_DAYS:-$DEFAULT_LOG_RETENTION_DAYS}
ALERT_COOLDOWN=${ALERT_COOLDOWN:-$DEFAULT_ALERT_COOLDOWN}

# Email configuration (optional)
ENABLE_EMAIL_ALERTS=${ENABLE_EMAIL_ALERTS:-false}
EMAIL_TO=${EMAIL_TO:-""}
EMAIL_FROM=${EMAIL_FROM:-"n8n-monitor@localhost"}
SMTP_SERVER=${SMTP_SERVER:-"localhost"}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging functions
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_DIR/monitor.log"
}

log_info() {
    log "INFO" "$@"
}

log_warn() {
    log "WARN" "$@"
}

log_error() {
    log "ERROR" "$@"
}

# Send email alert
send_email_alert() {
    local subject="$1"
    local body="$2"
    
    if [[ "$ENABLE_EMAIL_ALERTS" == "true" ]] && [[ -n "$EMAIL_TO" ]]; then
        log_info "Sending email alert to $EMAIL_TO"
        echo "$body" | mail -s "$subject" -r "$EMAIL_FROM" "$EMAIL_TO" 2>/dev/null || log_warn "Failed to send email alert"
    else
        log_info "Email alerts disabled or no recipient configured"
    fi
}

# Usage function
usage() {
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo ""
    echo "Commands:"
    echo "  check     - Run health checks"
    echo "  monitor   - Start continuous monitoring"
    echo "  status    - Show service status"
    echo "  disk      - Check disk usage"
    echo "  logs      - Show logs"
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help"
    echo "  -v, --verbose  Enable verbose output"
    echo "  -d, --daemon   Run in daemon mode"
    echo "  --no-email     Disable email alerts"
}

# Initialize monitoring
init_monitoring() {
    # Create log directory
    mkdir -p "$LOG_DIR"
    
    log_info "Monitoring initialized"
}

# Check service health
check_service_health() {
    local service="$1"
    local container_name="$2"
    
    # Check if container is running
    if ! docker ps --format "table {{.Names}}" | grep -q "^$container_name$"; then
        log_error "Service $service ($container_name) is not running"
        return 1
    fi
    
    # Check container health status
    local health_status
    health_status=$(docker inspect --format='{{.State.Health.Status}}' "$container_name" 2>/dev/null || echo "no-healthcheck")
    
    case "$health_status" in
        "healthy")
            log_info "Service $service is healthy"
            return 0
            ;;
        "unhealthy")
            log_error "Service $service is unhealthy"
            return 1
            ;;
        "starting")
            log_warn "Service $service is starting"
            return 2
            ;;
        "no-healthcheck")
            # For services without health checks, check if container is running
            local container_status
            container_status=$(docker inspect --format='{{.State.Status}}' "$container_name" 2>/dev/null || echo "not-found")
            if [[ "$container_status" == "running" ]]; then
                log_info "Service $service is running (no health check)"
                return 0
            else
                log_error "Service $service is not running"
                return 1
            fi
            ;;
        *)
            log_warn "Service $service has unknown health status: $health_status"
            return 2
            ;;
    esac
}

# Run health check
run_health_check() {
    log_info "Running health checks..."
    
    local services=(
        "n8n:n8n"
        "postgres:n8n-postgres"
        "redis:n8n-redis"
    )
    
    # Check for proxy services
    if docker ps --format "table {{.Names}}" | grep -q "n8n-nginx"; then
        services+=("nginx:n8n-nginx")
    fi
    if docker ps --format "table {{.Names}}" | grep -q "n8n-traefik"; then
        services+=("traefik:n8n-traefik")
    fi
    
    local all_healthy=true
    local service_status=()
    
    for service_info in "${services[@]}"; do
        IFS=':' read -r service container <<< "$service_info"
        
        if check_service_health "$service" "$container"; then
            service_status+=("✅ $service: healthy")
        else
            service_status+=("❌ $service: unhealthy")
            all_healthy=false
        fi
    done
    
    # Display results
    echo -e "${BLUE}Service Health Status:${NC}"
    for status in "${service_status[@]}"; do
        echo "  $status"
    done
    
    if [[ "$all_healthy" == "true" ]]; then
        log_info "All services are healthy"
        return 0
    else
        log_error "Some services are unhealthy"
        return 1
    fi
}

# Check disk usage
check_disk_usage() {
    log_info "Checking disk usage..."
    
    local data_dirs=(
        "$PROJECT_DIR/data"
        "$PROJECT_DIR/backups"
        "$LOG_DIR"
    )
    
    local disk_issues=false
    echo -e "${BLUE}Disk Usage:${NC}"
    
    for dir in "${data_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            local usage
            local disk_percent
            usage=$(du -sh "$dir" 2>/dev/null | cut -f1)
            disk_percent=$(df "$dir" | awk 'NR==2 {print $5}' | sed 's/%//')
            
            if [[ $disk_percent -gt $DISK_THRESHOLD ]]; then
                echo -e "  ⚠️  $dir: $usage (${RED}${disk_percent}%${NC})"
                log_warn "High disk usage in $dir: ${disk_percent}%"
                disk_issues=true
            else
                echo -e "  ✅ $dir: $usage (${GREEN}${disk_percent}%${NC})"
            fi
        else
            echo -e "  ⚪ $dir: directory not found"
        fi
    done
    
    if [[ "$disk_issues" == "true" ]]; then
        return 1
    else
        return 0
    fi
}

# Show monitoring logs
show_logs() {
    local log_type="monitor"
    
    case "$log_type" in
        "monitor"|"")
            tail -f "$LOG_DIR/monitor.log"
            ;;
        "alerts")
            tail -f "$LOG_DIR/alerts.log"
            ;;
        "health")
            tail -f "$LOG_DIR/health.log"
            ;;
        *)
            echo "Available log types: monitor, alerts, health"
            ;;
    esac
}

# Start monitoring
start_monitoring() {
    local daemon_mode="$1"
    
    log_info "Starting monitoring..."
    
    if [[ "$daemon_mode" == "true" ]]; then
        log_info "Running in daemon mode"
        # In a real implementation, this would daemonize
    fi
    
    while true; do
        run_health_check
        check_disk_usage
        sleep "$CHECK_INTERVAL"
    done
}

# Main function
main() {
    local command="check"
    local daemon_mode=false
    local disable_email=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                exit 0
                ;;
            -v|--verbose)
                # Could set DEBUG=true
                shift
                ;;
            -d|--daemon)
                daemon_mode=true
                shift
                ;;
            --no-email)
                disable_email=true
                shift
                ;;
            check|monitor|status|disk|logs)
                command="$1"
                shift
                ;;
            *)
                echo "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    # Disable email if requested
    if [[ "$disable_email" == "true" ]]; then
        ENABLE_EMAIL_ALERTS=false
    fi
    
    # Initialize monitoring
    init_monitoring
    
    # Execute command
    case "$command" in
        "check")
            run_health_check
            ;;
        "monitor")
            start_monitoring "$daemon_mode"
            ;;
        "status")
            run_health_check
            ;;
        "disk")
            check_disk_usage
            ;;
        "logs")
            show_logs
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

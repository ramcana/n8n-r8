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
DEFAULT_ALERT_COOLDOWN=600  # 10 minutes
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
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color
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
    echo -e "${GREEN}[INFO]${NC} $*"
log_warn() {
    log "WARN" "$@"
    echo -e "${YELLOW}[WARN]${NC} $*"
log_error() {
    log "ERROR" "$@"
    echo -e "${RED}[ERROR]${NC} $*"
log_debug() {
    if [[ "${DEBUG:-false}" == "true" ]]; then
        log "DEBUG" "$@"
        echo -e "${BLUE}[DEBUG]${NC} $*"
    fi
# Usage function
usage() {
    echo "Usage: $0 [OPTIONS] [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  check           Run one-time health check"
    echo "  monitor         Start continuous monitoring"
    echo "  status          Show current service status"
    echo "  disk            Check disk usage"
    echo "  logs            Show monitoring logs"
    echo "  test-alert      Test email alert system"
    echo "Options:"
    echo "  -h, --help      Show this help message"
    echo "  -v, --verbose   Enable verbose output"
    echo "  -d, --daemon    Run as daemon (background)"
    echo "  -i, --interval  Check interval in seconds (default: $DEFAULT_CHECK_INTERVAL)"
    echo "  --no-email      Disable email alerts for this run"
    echo "Examples:"
    echo "  $0 check                    # One-time health check"
    echo "  $0 monitor -d               # Start monitoring in background"
    echo "  $0 monitor -i 60            # Monitor with 60-second intervals"
    exit 1
# Initialize monitoring
init_monitoring() {
    log_info "Initializing monitoring system..."
    
    # Create log directory
    mkdir -p "$LOG_DIR"
    # Create monitoring log file
    touch "$LOG_DIR/monitor.log"
    touch "$LOG_DIR/alerts.log"
    touch "$LOG_DIR/health.log"
    # Load environment variables
    if [[ -f "$PROJECT_DIR/.env" ]]; then
        # shellcheck source=/dev/null
        source "$PROJECT_DIR/.env"
    log_info "Monitoring system initialized"
# Check if Docker is running
check_docker() {
    if ! docker info >/dev/null 2>&1; then
        log_error "Docker is not running"
        return 1
    return 0
# Check service health
check_service_health() {
    local service="$1"
    local container_name="$2"
    log_debug "Checking health for service: $service"
    # Check if container is running
    if ! docker ps --format "table {{.Names}}" | grep -q "^$container_name$"; then
        log_error "Service $service ($container_name) is not running"
    # Check container health status
    local health_status
    health_status=$(docker inspect --format='{{.State.Health.Status}}' "$container_name" 2>/dev/null || echo "no-healthcheck")
    case "$health_status" in
        "healthy")
            log_debug "Service $service is healthy"
            return 0
            ;;
        "unhealthy")
            log_error "Service $service is unhealthy"
            return 1
        "starting")
            log_warn "Service $service is starting"
            return 2
        "no-healthcheck")
            # For services without health checks, check if container is running
            local container_status
            container_status=$(docker inspect --format='{{.State.Status}}' "$container_name" 2>/dev/null || echo "not-found")
            if [[ "$container_status" == "running" ]]; then
                log_debug "Service $service is running (no health check)"
                return 0
            else
                log_error "Service $service is not running"
                return 1
            fi
        *)
            log_warn "Service $service has unknown health status: $health_status"
    esac
# Check all services
check_all_services() {
    log_info "Checking all services..."
    local services=(
        "n8n:n8n"
        "postgres:n8n-postgres"
        "redis:n8n-redis"
    )
    # Check for proxy services
    if docker ps --format "table {{.Names}}" | grep -q "n8n-nginx"; then
        services+=("nginx:n8n-nginx")
    if docker ps --format "table {{.Names}}" | grep -q "n8n-traefik"; then
        services+=("traefik:n8n-traefik")
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
    if [[ "$all_healthy" == "true" ]]; then
        log_info "All services are healthy"
        return 0
    else
        log_error "Some services are unhealthy"
# Check HTTP endpoints
check_http_endpoints() {
    log_info "Checking HTTP endpoints..."
    local endpoints=()
    # Check if nginx is running
        endpoints+=("http://localhost/health:Nginx Health")
        endpoints+=("http://localhost:N8N via Nginx")
    # Check if traefik is running
        endpoints+=("http://localhost:8080/ping:Traefik Ping")
        endpoints+=("http://localhost:N8N via Traefik")
    # Direct N8N check (if no proxy)
    if [[ ${#endpoints[@]} -eq 0 ]]; then
        endpoints+=("http://localhost:5678/healthz:N8N Direct")
    local all_endpoints_ok=true
    for endpoint_info in "${endpoints[@]}"; do
        IFS=':' read -r url description <<< "$endpoint_info"
        log_debug "Checking endpoint: $url"
        if curl -s -f --max-time 10 "$url" >/dev/null 2>&1; then
            echo -e "  ✅ $description: ${GREEN}OK${NC}"
            echo -e "  ❌ $description: ${RED}FAILED${NC}"
            log_error "Endpoint check failed: $url"
            all_endpoints_ok=false
    if [[ "$all_endpoints_ok" == "true" ]]; then
        log_info "All HTTP endpoints are responding"
        log_error "Some HTTP endpoints are not responding"
# Check disk usage
check_disk_usage() {
    log_info "Checking disk usage..."
    local data_dirs=(
        "$PROJECT_DIR/data"
        "$PROJECT_DIR/backups"
        "$LOG_DIR"
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
                echo -e "  ✅ $dir: $usage (${GREEN}${disk_percent}%${NC})"
    # Check Docker space usage
    local docker_space
    docker_space=$(docker system df --format "table {{.Type}}\t{{.Size}}" | tail -n +2 | awk '{sum += $2} END {print sum}' 2>/dev/null || echo "0")
    echo -e "  📦 Docker system: ${docker_space}MB"
    if [[ "$disk_issues" == "true" ]]; then
        log_error "Disk usage threshold exceeded"
        log_info "Disk usage is within acceptable limits"
# Check memory usage
check_memory_usage() {
    log_info "Checking memory usage..."
    local memory_percent
    memory_percent=$(free | awk 'NR==2{printf "%.0f", $3*100/$2}')
    echo -e "${BLUE}Memory Usage:${NC}"
    if [[ $memory_percent -gt $MEMORY_THRESHOLD ]]; then
        echo -e "  ⚠️  System memory: ${RED}${memory_percent}%${NC}"
        log_warn "High memory usage: ${memory_percent}%"
        # Show top memory consuming containers
        echo -e "${BLUE}Top memory consuming containers:${NC}"
        docker stats --no-stream --format "table {{.Container}}\t{{.MemUsage}}\t{{.MemPerc}}" | head -6
        echo -e "  ✅ System memory: ${GREEN}${memory_percent}%${NC}"
        log_info "Memory usage is within acceptable limits"
# Send email alert
send_email_alert() {
    local subject="$1"
    local body="$2"
    if [[ "$ENABLE_EMAIL_ALERTS" != "true" ]] || [[ -z "$EMAIL_TO" ]]; then
        log_debug "Email alerts disabled or no recipient configured"
    # Check cooldown
    local last_alert_file="$LOG_DIR/.last_alert"
    local current_time
    current_time=$(date +%s)
    if [[ -f "$last_alert_file" ]]; then
        local last_alert_time
        last_alert_time=$(cat "$last_alert_file")
        local time_diff
        time_diff=$((current_time - last_alert_time))
        if [[ $time_diff -lt $ALERT_COOLDOWN ]]; then
            log_debug "Alert cooldown active, skipping email"
    log_info "Sending email alert: $subject"
    # Create email content
    local email_content
    email_content="Subject: [N8N-R8] $subject
From: $EMAIL_FROM
To: $EMAIL_TO
$body
---
N8N-R8 Monitoring System
$(date)
"
    # Send email using sendmail or mail command
    if command -v sendmail >/dev/null 2>&1; then
        echo "$email_content" | sendmail "$EMAIL_TO"
    elif command -v mail >/dev/null 2>&1; then
        echo "$body" | mail -s "[N8N-R8] $subject" "$EMAIL_TO"
        log_error "No mail command available for sending alerts"
    # Update last alert time
    echo "$current_time" > "$last_alert_file"
    # Log alert
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $subject" >> "$LOG_DIR/alerts.log"
    log_info "Email alert sent successfully"
# Comprehensive health check
run_health_check() {
    log_info "Starting comprehensive health check..."
    local issues=()
    local warnings=()
    # Check Docker
    if ! check_docker; then
        issues+=("Docker is not running")
    # Check services
    if ! check_all_services; then
        issues+=("Service health check failed")
    # Check HTTP endpoints
    if ! check_http_endpoints; then
        issues+=("HTTP endpoint check failed")
    # Check disk usage
    if ! check_disk_usage; then
        warnings+=("High disk usage detected")
    # Check memory usage
    if ! check_memory_usage; then
        warnings+=("High memory usage detected")
    # Summary
    echo -e "${BLUE}Health Check Summary:${NC}"
    if [[ ${#issues[@]} -eq 0 ]]; then
        echo -e "  ✅ ${GREEN}All critical checks passed${NC}"
        log_info "Health check completed successfully"
        if [[ ${#warnings[@]} -gt 0 ]]; then
            echo -e "  ⚠️  ${YELLOW}Warnings:${NC}"
            for warning in "${warnings[@]}"; do
                echo -e "    - $warning"
            done
        echo -e "  ❌ ${RED}Critical issues found:${NC}"
        for issue in "${issues[@]}"; do
            echo -e "    - $issue"
        done
        # Send alert email
        local alert_body
        alert_body="Critical issues detected in N8N-R8:
$(printf '%s\n' "${issues[@]}")
$(if [[ ${#warnings[@]} -gt 0 ]]; then
    echo "Warnings:"
    printf '%s\n' "${warnings[@]}"
fi)
Please check the system immediately."
        send_email_alert "Critical Issues Detected" "$alert_body"
        log_error "Health check failed with critical issues"
# Continuous monitoring
start_monitoring() {
    local daemon_mode="$1"
    log_info "Starting continuous monitoring (interval: ${CHECK_INTERVAL}s)"
    if [[ "$daemon_mode" == "true" ]]; then
        log_info "Running in daemon mode"
        # Redirect output to log file in daemon mode
        exec 1>>"$LOG_DIR/monitor.log"
        exec 2>>"$LOG_DIR/monitor.log"
    # Create PID file
    echo $$ > "$LOG_DIR/monitor.pid"
    # Trap signals for graceful shutdown
    trap 'log_info "Monitoring stopped"; rm -f "$LOG_DIR/monitor.pid"; exit 0' SIGTERM SIGINT
    while true; do
        log_info "Running scheduled health check..."
        if run_health_check; then
            log_info "Health check passed"
            log_error "Health check failed"
        # Clean up old logs
        cleanup_logs
        sleep "$CHECK_INTERVAL"
# Clean up old logs
cleanup_logs() {
    log_debug "Cleaning up old logs..."
    # Remove logs older than retention period
    find "$LOG_DIR" -name "*.log" -type f -mtime +"$LOG_RETENTION_DAYS" -delete 2>/dev/null || true
    # Rotate large log files
    for log_file in "$LOG_DIR"/*.log; do
        if [[ -f "$log_file" ]] && [[ $(stat -f%z "$log_file" 2>/dev/null || stat -c%s "$log_file" 2>/dev/null || echo 0) -gt 10485760 ]]; then  # 10MB
            mv "$log_file" "${log_file}.$(date +%Y%m%d_%H%M%S)"
            touch "$log_file"
            log_info "Rotated log file: $(basename "$log_file")"
# Test email alerts
test_email_alert() {
    log_info "Testing email alert system..."
    if [[ "$ENABLE_EMAIL_ALERTS" != "true" ]]; then
        log_error "Email alerts are disabled in configuration"
    if [[ -z "$EMAIL_TO" ]]; then
        log_error "No email recipient configured"
    send_email_alert "Test Alert" "This is a test alert from N8N-R8 monitoring system.
If you receive this email, the alert system is working correctly."
    log_info "Test email sent"
# Show monitoring logs
show_logs() {
    local log_type="$1"
    case "$log_type" in
        "monitor"|"")
            tail -f "$LOG_DIR/monitor.log"
        "alerts")
            tail -f "$LOG_DIR/alerts.log"
        "health")
            tail -f "$LOG_DIR/health.log"
            echo "Available log types: monitor, alerts, health"
# Main function
main() {
    local command=""
    local daemon_mode=false
    local disable_email=false
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                ;;
            -v|--verbose)
                DEBUG=true
                shift
            -d|--daemon)
                daemon_mode=true
            -i|--interval)
                CHECK_INTERVAL="$2"
                shift 2
            --no-email)
                disable_email=true
            check|monitor|status|disk|logs|test-alert)
                command="$1"
            *)
                echo "Unknown option: $1"
        esac
    # Disable email if requested
    if [[ "$disable_email" == "true" ]]; then
        ENABLE_EMAIL_ALERTS=false
    # Initialize monitoring
    init_monitoring
    # Execute command
    case "$command" in
        "check")
            run_health_check
        "monitor")
            start_monitoring "$daemon_mode"
        "status")
            check_all_services
        "disk")
            check_disk_usage
        "logs")
            show_logs "${2:-}"
        "test-alert")
            test_email_alert
        "")
            # Default to one-time check
            echo "Unknown command: $command"
            usage
# Run main function
main "$@"

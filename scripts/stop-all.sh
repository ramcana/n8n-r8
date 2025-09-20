#!/bin/bash

# N8N-R8 Stop All Services Script
# This script stops all N8N-R8 services regardless of proxy configuration
set -euo pipefail
# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color
# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}
error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1" >&2
warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1"
info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO:${NC} $1"
# Usage function
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help          Show this help message"
    echo "  -f, --force         Force stop without confirmation"
    echo "  -v, --volumes       Remove volumes as well"
    echo "  -r, --remove-orphans Remove orphaned containers"
    echo "  --timeout SECONDS   Timeout for graceful shutdown (default: 30)"
    echo "  --kill              Kill containers immediately (no graceful shutdown)"
    echo "Examples:"
    echo "  $0                  # Interactive stop with confirmation"
    echo "  $0 -f               # Force stop without confirmation"
    echo "  $0 -f -v            # Force stop and remove volumes"
    echo "  $0 --kill           # Kill all containers immediately"
    exit 1
# Check Docker availability
check_docker() {
    if ! command -v docker >/dev/null 2>&1; then
        error "Docker command not found"
        exit 1
    fi
    
    if ! docker info >/dev/null 2>&1; then
        warning "Docker daemon is not running"
        return 1
    return 0
# Detect running configurations
detect_running_configurations() {
    log "Detecting running N8N-R8 configurations..."
    local configurations=()
    # Check for basic configuration
    if docker compose -f "$PROJECT_DIR/docker-compose.yml" ps -q 2>/dev/null | grep -q .; then
        configurations+=("basic")
    # Check for nginx configuration
    if docker compose -f "$PROJECT_DIR/docker-compose.yml" -f "$PROJECT_DIR/docker-compose.nginx.yml" ps -q 2>/dev/null | grep -q .; then
        configurations+=("nginx")
    # Check for traefik configuration
    if docker compose -f "$PROJECT_DIR/docker-compose.yml" -f "$PROJECT_DIR/docker-compose.traefik.yml" ps -q 2>/dev/null | grep -q .; then
        configurations+=("traefik")
    # Check for monitoring configuration
    if docker compose -f "$PROJECT_DIR/docker-compose.yml" -f "$PROJECT_DIR/docker-compose.monitoring.yml" ps -q 2>/dev/null | grep -q .; then
        configurations+=("monitoring")
    # Check for any N8N-related containers by name pattern
    local n8n_containers
    n8n_containers=$(docker ps --format "{{.Names}}" | grep -E "^n8n" || true)
    if [[ -n "$n8n_containers" ]]; then
        configurations+=("containers")
    # Remove duplicates
    printf '%s\n' "${configurations[@]}" | sort -u
# Show running services
show_running_services() {
    log "Current running services:"
    # Show Docker Compose services
    local compose_files=(
        "docker-compose.yml"
        "docker-compose.yml -f docker-compose.nginx.yml"
        "docker-compose.yml -f docker-compose.traefik.yml" 
        "docker-compose.yml -f docker-compose.monitoring.yml"
    )
    local found_services=false
    for compose_cmd in "${compose_files[@]}"; do
        local services
        services=$(docker compose -f $compose_cmd ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null | tail -n +2 || true)
        if [[ -n "$services" ]]; then
            found_services=true
            echo "$services"
        fi
    done
    # Show individual N8N containers
    local individual_containers
    individual_containers=$(docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "^n8n" || true)
    if [[ -n "$individual_containers" ]]; then
        found_services=true
        echo "$individual_containers"
    if [[ "$found_services" == "false" ]]; then
        info "No N8N-R8 services are currently running"
# Stop Docker Compose configurations
stop_compose_configurations() {
    local remove_volumes="$1"
    local remove_orphans="$2"
    local timeout="$3"
    local kill_containers="$4"
    log "Stopping Docker Compose configurations..."
    local compose_configs=(
        "docker-compose.yml -f docker-compose.monitoring.yml:Monitoring Stack"
        "docker-compose.yml -f docker-compose.traefik.yml:Traefik Proxy"
        "docker-compose.yml -f docker-compose.nginx.yml:Nginx Proxy"
        "docker-compose.yml:Basic N8N"
    for config_info in "${compose_configs[@]}"; do
        IFS=':' read -r compose_files description <<< "$config_info"
        
        # Check if this configuration has running services
        if docker compose -f $compose_files ps -q 2>/dev/null | grep -q .; then
            info "Stopping $description..."
            
            local compose_args=()
            if [[ "$remove_volumes" == "true" ]]; then
                compose_args+=("--volumes")
            fi
            if [[ "$remove_orphans" == "true" ]]; then
                compose_args+=("--remove-orphans")
            if [[ "$timeout" != "30" ]]; then
                compose_args+=("--timeout" "$timeout")
            # Stop services
            if [[ "$kill_containers" == "true" ]]; then
                # Kill containers immediately
                docker compose -f $compose_files kill 2>/dev/null || true
                docker compose -f $compose_files down "${compose_args[@]}" 2>/dev/null || true
            else
                # Graceful shutdown
            log "$description stopped"
# Stop individual containers
stop_individual_containers() {
    local kill_containers="$1"
    local timeout="$2"
    log "Checking for individual N8N containers..."
    # Find all containers with n8n in the name
    n8n_containers=$(docker ps -q --filter "name=n8n" 2>/dev/null || true)
        info "Found individual N8N containers, stopping them..."
        if [[ "$kill_containers" == "true" ]]; then
            # Kill containers immediately
            echo "$n8n_containers" | xargs -r docker kill 2>/dev/null || true
        else
            # Graceful shutdown
            echo "$n8n_containers" | xargs -r docker stop --time="$timeout" 2>/dev/null || true
        # Remove containers
        echo "$n8n_containers" | xargs -r docker rm -f 2>/dev/null || true
        log "Individual containers stopped and removed"
# Stop monitoring processes
stop_monitoring_processes() {
    log "Stopping monitoring processes..."
    local monitoring_pids=(
        "$PROJECT_DIR/monitoring/logs/monitor.pid"
        "$PROJECT_DIR/monitoring/logs/disk-monitor.pid"
    for pid_file in "${monitoring_pids[@]}"; do
        if [[ -f "$pid_file" ]]; then
            local pid
            pid=$(cat "$pid_file")
            local process_name
            process_name=$(basename "$pid_file" .pid)
            if kill -0 "$pid" 2>/dev/null; then
                info "Stopping $process_name (PID: $pid)..."
                kill -TERM "$pid" 2>/dev/null || true
                
                # Wait for graceful shutdown
                local attempts=0
                while [[ $attempts -lt 10 ]] && kill -0 "$pid" 2>/dev/null; do
                    sleep 1
                    ((attempts++))
                done
                # Force kill if still running
                if kill -0 "$pid" 2>/dev/null; then
                    warning "Force killing $process_name..."
                    kill -KILL "$pid" 2>/dev/null || true
                fi
                log "$process_name stopped"
            # Remove PID file
            rm -f "$pid_file"
# Clean up temporary files
cleanup_temporary_files() {
    log "Cleaning up temporary files..."
    # Remove temporary compose files
    find "$PROJECT_DIR" -name "docker-compose.*.tmp" -delete 2>/dev/null || true
    find "$PROJECT_DIR" -name "docker-compose.direct.yml" -delete 2>/dev/null || true
    # Clean up any lock files
    find "$PROJECT_DIR" -name "*.lock" -delete 2>/dev/null || true
    log "Temporary files cleaned up"
# Remove Docker networks
remove_networks() {
    log "Removing Docker networks..."
    local networks=("n8n-network")
    for network in "${networks[@]}"; do
        if docker network ls --format "{{.Name}}" | grep -q "^$network$"; then
            info "Removing network: $network"
            docker network rm "$network" 2>/dev/null || warning "Failed to remove network: $network"
# Show stop summary
show_stop_summary() {
    local start_time="$1"
    local end_time
    end_time=$(date +%s)
    local duration
    duration=$((end_time - start_time))
    log "Stop Summary:"
    echo "  Duration: ${duration}s"
    echo "  Stopped at: $(date)"
    # Check if any containers are still running
    local remaining_containers
    remaining_containers=$(docker ps --format "{{.Names}}" | grep -E "^n8n" || true)
    if [[ -n "$remaining_containers" ]]; then
        warning "Some containers may still be running:"
        echo "$remaining_containers" | sed 's/^/    /'
    else
        log "All N8N-R8 services have been stopped successfully"
    # Show remaining resources
    local remaining_networks
    remaining_networks=$(docker network ls --format "{{.Name}}" | grep -E "n8n" || true)
    if [[ -n "$remaining_networks" ]]; then
        info "Remaining networks:"
        echo "$remaining_networks" | sed 's/^/    /'
    local remaining_volumes
    remaining_volumes=$(docker volume ls --format "{{.Name}}" | grep -E "n8n" || true)
    if [[ -n "$remaining_volumes" ]]; then
        info "Remaining volumes:"
        echo "$remaining_volumes" | sed 's/^/    /'
# Confirmation prompt
confirm_stop() {
    local force="$1"
    local configurations=("$@")
    if [[ "$force" == "true" ]]; then
        return 0
    warning "This will stop all N8N-R8 services and configurations:"
    for config in "${configurations[@]:1}"; do
        echo "  - $config"
    read -p "Are you sure you want to continue? (y/N): " -r
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log "Stop operation cancelled by user"
        exit 0
# Main function
main() {
    local force=false
    local remove_volumes=false
    local remove_orphans=true
    local timeout=30
    local kill_containers=false
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                ;;
            -f|--force)
                force=true
                shift
            -v|--volumes)
                remove_volumes=true
            -r|--remove-orphans)
                remove_orphans=true
            --timeout)
                timeout="$2"
                shift 2
            --kill)
                kill_containers=true
            -*)
                error "Unknown option: $1"
            *)
                error "Unknown argument: $1"
        esac
    # Validate timeout
    if ! [[ "$timeout" =~ ^[0-9]+$ ]] || [[ "$timeout" -lt 1 ]]; then
        error "Invalid timeout: $timeout. Must be a positive integer."
    local start_time
    start_time=$(date +%s)
    log "N8N-R8 Stop All Services"
    log "========================"
    # Change to project directory
    cd "$PROJECT_DIR"
    # Check Docker availability
    if ! check_docker; then
        warning "Docker is not available, but will attempt to stop monitoring processes"
    # Detect running configurations
    local configurations
    mapfile -t configurations < <(detect_running_configurations)
    if [[ ${#configurations[@]} -eq 0 ]]; then
        # Check for monitoring processes even if no Docker services
        stop_monitoring_processes
        cleanup_temporary_files
    # Show current services
    show_running_services || true
    # Confirm stop operation
    confirm_stop "$force" "${configurations[@]}"
    log "Stopping all N8N-R8 services..."
    # Stop Docker Compose configurations
    stop_compose_configurations "$remove_volumes" "$remove_orphans" "$timeout" "$kill_containers"
    # Stop individual containers
    stop_individual_containers "$kill_containers" "$timeout"
    # Stop monitoring processes
    stop_monitoring_processes
    # Clean up temporary files
    cleanup_temporary_files
    # Remove networks if requested
    if [[ "$remove_volumes" == "true" ]]; then
        remove_networks
    # Show summary
    show_stop_summary "$start_time"
    log "All N8N-R8 services have been stopped"
    if [[ "$kill_containers" == "true" ]]; then
        warning "Containers were forcefully killed - data may not have been properly saved"
# Run main function
main "$@"

#!/bin/bash

# N8N-R8 Systemd Service Installation Script
# This script installs and manages systemd services for N8N-R8
set -euo pipefail
# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SYSTEMD_DIR="$PROJECT_DIR/systemd"
SYSTEM_SYSTEMD_DIR="/etc/systemd/system"
# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'
# Logging functions
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
    echo "Usage: $0 [OPTIONS] [COMMAND] [SERVICE]"
    echo ""
    echo "Commands:"
    echo "  install     Install systemd service(s)"
    echo "  uninstall   Remove systemd service(s)"
    echo "  enable      Enable service(s) to start on boot"
    echo "  disable     Disable service(s) from starting on boot"
    echo "  start       Start service(s)"
    echo "  stop        Stop service(s)"
    echo "  restart     Restart service(s)"
    echo "  status      Show service(s) status"
    echo "  logs        Show service(s) logs"
    echo "  list        List available service templates"
    echo "Services:"
    echo "  basic       n8n-local.service (basic N8N)"
    echo "  nginx       n8n-nginx.service (N8N with Nginx)"
    echo "  traefik     n8n-traefik.service (N8N with Traefik)"
    echo "  monitoring  n8n-monitoring.service (N8N with monitoring)"
    echo "  all         All available services"
    echo "Options:"
    echo "  -h, --help          Show this help message"
    echo "  -f, --force         Force operation without confirmation"
    echo "  -u, --user USER     Specify user (default: current user)"
    echo "  -p, --path PATH     Specify project path (default: current)"
    echo "Examples:"
    echo "  $0 install basic           # Install basic N8N service"
    echo "  $0 enable nginx            # Enable nginx service for boot"
    echo "  $0 start traefik           # Start traefik service"
    echo "  $0 logs monitoring -f      # Follow monitoring service logs"
    exit 1
# Check if running as root for system operations
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This operation requires root privileges"
        echo "Please run with sudo: sudo $0"
        exit 1
    fi
# Get service file mapping
get_service_file() {
    local service="$1"
    
    case "$service" in
        "basic")
            echo "n8n-local.service"
            ;;
        "nginx")
            echo "n8n-nginx.service"
        "traefik")
            echo "n8n-traefik.service"
        "monitoring")
            echo "n8n-monitoring.service"
        *)
            error "Unknown service: $service"
            echo "Available services: basic, nginx, traefik, monitoring"
            exit 1
    esac
# List available services
list_services() {
    log "Available systemd service templates:"
    if [[ -d "$SYSTEMD_DIR" ]]; then
        for service_file in "$SYSTEMD_DIR"/*.service; do
            if [[ -f "$service_file" ]]; then
                local filename
                local description
                filename=$(basename "$service_file")
                description=$(grep "^Description=" "$service_file" | cut -d'=' -f2- || echo "No description")
                printf "  %-20s %s\n" "$filename" "$description"
            fi
        done
    else
        error "Systemd directory not found: $SYSTEMD_DIR"
    log "Installed services:"
    for service_type in basic nginx traefik monitoring; do
        local service_file
        service_file=$(get_service_file "$service_type")
        if [[ -f "$SYSTEM_SYSTEMD_DIR/$service_file" ]]; then
            local status
            status=$(systemctl is-enabled "$service_file" 2>/dev/null || echo "disabled")
            local active
            active=$(systemctl is-active "$service_file" 2>/dev/null || echo "inactive")
            printf "  %-20s enabled: %-8s active: %s\n" "$service_file" "$status" "$active"
        fi
    done
# Customize service file
customize_service_file() {
    local source_file="$1"
    local target_file="$2"
    local user="$3"
    local project_path="$4"
    log "Customizing service file: $target_file"
    # Copy and customize the service file
    sed -e "s|User=ram|User=$user|g" \
        -e "s|Group=ram|Group=$user|g" \
        -e "s|WorkingDirectory=/home/ram/projects/n8n-r8|WorkingDirectory=$project_path|g" \
        -e "s|EnvironmentFile=/home/ram/projects/n8n-r8/.env|EnvironmentFile=$project_path/.env|g" \
        -e "s|EnvironmentFile=-/home/ram/projects/n8n-r8/.env.local|EnvironmentFile=-$project_path/.env.local|g" \
        "$source_file" > "$target_file"
    # Set proper permissions
    chmod 644 "$target_file"
    chown root:root "$target_file"
    info "Service file customized for user '$user' and path '$project_path'"
# Install service
install_service() {
    local user="$2"
    local project_path="$3"
    local force="$4"
    local service_file
    service_file=$(get_service_file "$service")
    local source_file="$SYSTEMD_DIR/$service_file"
    local target_file="$SYSTEM_SYSTEMD_DIR/$service_file"
    log "Installing systemd service: $service_file"
    # Check if source file exists
    if [[ ! -f "$source_file" ]]; then
        error "Service template not found: $source_file"
    # Check if target already exists
    if [[ -f "$target_file" ]] && [[ "$force" != "true" ]]; then
        warning "Service file already exists: $target_file"
        read -p "Overwrite? (y/N): " -r
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            info "Installation cancelled"
            return 0
    # Stop service if running
    if systemctl is-active --quiet "$service_file" 2>/dev/null; then
        warning "Stopping running service: $service_file"
        systemctl stop "$service_file"
    # Install and customize service file
    customize_service_file "$source_file" "$target_file" "$user" "$project_path"
    # Reload systemd
    systemctl daemon-reload
    log "Service installed successfully: $service_file"
    info "Next steps:"
    echo "  1. Enable service: sudo systemctl enable $service_file"
    echo "  2. Start service: sudo systemctl start $service_file"
    echo "  3. Check status: sudo systemctl status $service_file"
# Uninstall service
uninstall_service() {
    local force="$2"
    log "Uninstalling systemd service: $service_file"
    if [[ ! -f "$target_file" ]]; then
        warning "Service not installed: $service_file"
        return 0
    # Confirmation
    if [[ "$force" != "true" ]]; then
        warning "This will remove the systemd service: $service_file"
        read -p "Continue? (y/N): " -r
            info "Uninstallation cancelled"
    # Stop and disable service
        log "Stopping service: $service_file"
    if systemctl is-enabled --quiet "$service_file" 2>/dev/null; then
        log "Disabling service: $service_file"
        systemctl disable "$service_file"
    # Remove service file
    rm -f "$target_file"
    log "Service uninstalled successfully: $service_file"
# Manage service (enable/disable/start/stop/restart)
manage_service() {
    local action="$1"
    local service="$2"
    log "Performing action '$action' on service: $service_file"
    if [[ ! -f "$SYSTEM_SYSTEMD_DIR/$service_file" ]]; then
        error "Service not installed: $service_file"
        echo "Install it first with: sudo $0 install $service"
    case "$action" in
        "enable"|"disable")
            systemctl "$action" "$service_file"
            log "Service $service_file ${action}d"
        "start"|"stop"|"restart")
            log "Service $service_file ${action}ed"
        "status")
            systemctl status "$service_file" --no-pager
            error "Unknown action: $action"
# Show service logs
show_logs() {
    shift
    local extra_args=("$@")
    log "Showing logs for service: $service_file"
    journalctl -u "$service_file" "${extra_args[@]}"
# Handle multiple services
handle_multiple_services() {
    local services="$2"
    shift 2
    if [[ "$services" == "all" ]]; then
        services="basic nginx traefik monitoring"
    for service in $services; do
        case "$action" in
            "install"|"uninstall")
                if [[ "$action" == "install" ]]; then
                    install_service "$service" "${extra_args[@]}"
                else
                    uninstall_service "$service" "${extra_args[@]}"
                fi
                ;;
            "logs")
                show_logs "$service" "${extra_args[@]}"
            *)
                manage_service "$action" "$service"
        esac
        echo ""
# Main function
main() {
    local command=""
    local service=""
    local user="$(whoami)"
    local project_path="$PROJECT_DIR"
    local force=false
    local extra_args=()
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
            -f|--force)
                force=true
                shift
            -u|--user)
                user="$2"
                shift 2
            -p|--path)
                project_path="$2"
            install|uninstall|enable|disable|start|stop|restart|status|logs|list)
                command="$1"
            basic|nginx|traefik|monitoring|all)
                service="$1"
                extra_args+=("$1")
    # Validate command
    if [[ -z "$command" ]]; then
        error "No command specified"
        usage
    # Handle list command
    if [[ "$command" == "list" ]]; then
        list_services
        exit 0
    # Validate service
    if [[ -z "$service" ]]; then
        error "No service specified"
    # Check root for system operations
    case "$command" in
        install|uninstall|enable|disable|start|stop|restart)
            check_root
    log "N8N-R8 Systemd Service Manager"
    log "Command: $command, Service: $service, User: $user"
    # Execute command
        "install")
            handle_multiple_services "$command" "$service" "$user" "$project_path" "$force"
        "uninstall")
            handle_multiple_services "$command" "$service" "$force"
        "logs")
            handle_multiple_services "$command" "$service" "${extra_args[@]}"
            handle_multiple_services "$command" "$service"
# Run main function
main "$@"

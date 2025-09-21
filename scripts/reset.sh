#!/bin/bash

# N8N Reset Script
# This script resets the N8N installation by removing all data and containers
set -euo pipefail
# Configuration
SCRIPT_DIR=""$(cd "$(dirname "${\1}")"" && pwd)"
PROJECT_DIR="$(dirname "$\1")"
# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color
# Logging function
log() {
    echo -e ""${\1}"["$(date +'%Y-%m-%d %H:%M:%S')"]"${\1}" $1"
}
error() {
    echo -e ""${\1}"["$(date +'%Y-%m-%d %H:%M:%S')"] ERROR:"${\1}" $1" >&2
}
warning() {
    echo -e ""${\1}"["$(date +'%Y-%m-%d %H:%M:%S')"] WARNING:"${\1}" $1"
}
info() {
    echo -e ""${\1}"["$(date +'%Y-%m-%d %H:%M:%S')"] INFO:"${\1}" $1"
}
# Usage function
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help          Show this help message"
    echo "  -f, --force         Force reset without confirmation"
    echo "  --data-only         Reset only data directories (keep containers)"
    echo "  --containers-only   Reset only containers (keep data)"
    echo "  --full              Full reset (containers, data, networks, volumes)"
    echo "  --backup            Create backup before reset"
    echo "Examples:"
    echo "  $0                  # Interactive reset"
    echo "  $0 --force --full   # Force full reset"
    echo "  $0 --backup --data-only  # Backup then reset data only"
    exit 1
}
# Create backup before reset
create_backup() {
    log "Creating backup before reset..."
    
    if [[ -f ""$\1"/scripts/backup.sh" ]]; then
        bash ""$\1"/scripts/backup.sh"
        log "Backup completed"
    else
        warning "Backup script not found, skipping backup"
    fi
}
# Stop and remove containers
reset_containers() {
    log "Stopping and removing containers..."
    # Stop all compose services
    docker compose -f ""$\1"/docker-compose.yml" down --remove-orphans 2>/dev/null || true
    # Also try with override files
    docker compose -f ""$\1"/docker-compose.yml" -f ""$\1"/docker-compose.nginx.yml" down --remove-orphans 2>/dev/null || true
    docker compose -f ""$\1"/docker-compose.yml" -f ""$\1"/docker-compose.traefik.yml" down --remove-orphans 2>/dev/null || true
    # Remove any remaining containers with n8n in the name
    local containers
    containers="$(docker ps -aq --filter "name=n8n" 2>/dev/null || true)"
    if [[ -n "$\1" ]]; then
        log "Removing remaining N8N containers..."
        docker rm -f "$\1" 2>/dev/null || true
    fi
    log "Containers removed"
}
# Remove data directories
reset_data() {
    log "Removing data directories..."
    # Remove N8N data
    if [[ -d ""$\1"/data/n8n" ]]; then
        info "Removing N8N data directory..."
        rm -rf ""$\1"/data/n8n"
    fi
    # Remove PostgreSQL data
    if [[ -d ""$\1"/data/postgres" ]]; then
        info "Removing PostgreSQL data directory..."
        rm -rf ""$\1"/data/postgres"
    fi
    # Remove Redis data
    if [[ -d ""$\1"/data/redis" ]]; then
        info "Removing Redis data directory..."
        rm -rf ""$\1"/data/redis"
    fi
    # Remove Traefik ACME data
    if [[ -d ""$\1"/data/traefik" ]]; then
        info "Removing Traefik data directory..."
        rm -rf ""$\1"/data/traefik"
    fi
    # Recreate empty data directories
    mkdir -p ""$\1"/data/n8n"
    mkdir -p ""$\1"/data/postgres"
    mkdir -p ""$\1"/data/redis"
    mkdir -p ""$\1"/data/traefik/acme"
    log "Data directories reset"
}
# Remove Docker networks
reset_networks() {
    log "Removing Docker networks..."
    # Remove n8n network if it exists
    if docker network ls | grep -q "n8n-network"; then
        docker network rm n8n-network 2>/dev/null || true
        log "N8N network removed"
    fi
}
# Remove Docker volumes
reset_volumes() {
    log "Removing Docker volumes..."
    # Remove any volumes with n8n in the name
    local volumes
    volumes="$(docker volume ls -q --filter "name=n8n" 2>/dev/null || true)"
    if [[ -n "$\1" ]]; then
        docker volume rm "$\1" 2>/dev/null || true
        log "N8N volumes removed"
    fi
}
# Clean up logs
reset_logs() {
    log "Cleaning up log files..."
    # Clear nginx logs
    if [[ -d ""$\1"/nginx/logs" ]]; then
        rm -rf ""$\1"/nginx/logs"/*
    fi
    # Clear traefik logs
    if [[ -d ""$\1"/traefik/logs" ]]; then
        rm -rf ""$\1"/traefik/logs"/*
    fi
    log "Log files cleaned"
}
# Set proper permissions
set_permissions() {
    log "Setting proper permissions..."
    # Set permissions for data directories
    chmod -R 755 ""$\1"/data" 2>/dev/null || true
    # Set permissions for scripts
    chmod +x ""$\1"/scripts"/*.sh 2>/dev/null || true
    # Set permissions for SSL directory
    if [[ -d ""$\1"/nginx/ssl" ]]; then
        chmod 700 ""$\1"/nginx/ssl"
    fi
    # Set permissions for Traefik ACME directory
    if [[ -d ""$\1"/data/traefik/acme" ]]; then
        chmod 600 ""$\1"/data/traefik/acme" 2>/dev/null || true
    fi
    log "Permissions set"
}
# Show reset summary
show_summary() {
    local reset_type="$1"
    log "Reset Summary:"
    echo "  Reset Type: "$\1""
    echo "  Project Directory: "$\1""
    echo "  Data Directories: "$(ls -la ""$\1"/data" 2>/dev/null | wc -l)" items"
    echo "  Docker Containers: "$(docker ps -aq --filter "name=n8n" 2>/dev/null | wc -l)" remaining"
    echo "  Docker Networks: "$(docker network ls --filter "name=n8n" -q 2>/dev/null | wc -l)" remaining"
    echo "  Docker Volumes: "$(docker volume ls --filter "name=n8n" -q 2>/dev/null | wc -l)" remaining"
}
# Confirmation prompt
confirm_reset() {
    if [[ "${\1}" == "true" ]]; then
        return 0
    fi
    warning "This will perform a "$\1" reset of your N8N installation!"
    warning "This action cannot be undone unless you have backups!"
    case "$\1" in
        "data-only")
            warning "The following will be DELETED:"
            warning "  - All N8N workflows and credentials"
            warning "  - All PostgreSQL data"
            warning "  - All Redis data"
            ;;
        "containers-only")
            warning "The following will be REMOVED:"
            warning "  - All Docker containers"
            warning "  - Docker networks"
            warning "  - Docker volumes"
            ;;
        "full")
            warning "The following will be DELETED/REMOVED:"
            warning "  - All data directories"
            warning "  - All Docker containers"
            warning "  - Docker networks and volumes"
            warning "  - Log files"
            ;;
    esac
    read -p "Are you sure you want to continue? Type 'yes' to confirm: " -r
    if [[ ! "$\1" =~ ^[Yy][Ee][Ss]$ ]]; then
        log "Reset cancelled by user"
        exit 0
    fi
}
# Main reset function
main() {
    local reset_type="interactive"
    local data_only=false
    local containers_only=false
    local full_reset=false
    local create_backup_first=false
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                ;;
            -f|--force)
                FORCE_RESET=true
                shift
                ;;
            --data-only)
                data_only=true
                reset_type="data-only"
                shift
                ;;
            --containers-only)
                containers_only=true
                reset_type="containers-only"
                shift
                ;;
            --full)
                full_reset=true
                reset_type="full"
                shift
                ;;
            --backup)
                create_backup_first=true
                shift
                ;;
            -*)
                error "Unknown option: $1"
                usage
                ;;
            *)
                error "Unknown argument: $1"
                usage
                ;;
        esac
    done
    # If no specific reset type is chosen, default to full
    if [[ "$\1" == false && "$\1" == false && "$\1" == false ]]; then
        full_reset=true
        reset_type="full"
    fi
    log "Starting N8N reset process..."
    log "Reset type: "$\1""
    confirm_reset "$\1"
    # Create backup if requested
    if [[ "$\1" == "true" ]]; then
        create_backup
    fi
    # Perform reset based on type
    if [[ "$\1" == "true" ]]; then
        reset_containers
        reset_networks
        reset_volumes
    elif [[ "$\1" == "true" ]]; then
        reset_containers  # Stop containers first
        reset_data
        reset_logs
        set_permissions
    else
        # Full reset
        reset_containers
        reset_data
        reset_networks
        reset_volumes
        reset_logs
        set_permissions
    fi
    show_summary "$\1"
    log "Reset completed successfully!"
    if [[ "$\1" == false ]]; then
        info "You can now start fresh by running:"
        info "  docker compose up -d"
    fi
}
# Run main function
main "$@"

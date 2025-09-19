#!/bin/bash

# N8N Reset Script
# This script resets the N8N installation by removing all data and containers

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
}

warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1"
}

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO:${NC} $1"
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
    echo ""
    echo "Examples:"
    echo "  $0                  # Interactive reset"
    echo "  $0 --force --full   # Force full reset"
    echo "  $0 --backup --data-only  # Backup then reset data only"
    exit 1
}

# Create backup before reset
create_backup() {
    log "Creating backup before reset..."
    
    if [[ -f "$PROJECT_DIR/scripts/backup.sh" ]]; then
        bash "$PROJECT_DIR/scripts/backup.sh"
        log "Backup completed"
    else
        warning "Backup script not found, skipping backup"
    fi
}

# Stop and remove containers
reset_containers() {
    log "Stopping and removing containers..."
    
    # Stop all compose services
    docker compose -f "$PROJECT_DIR/docker-compose.yml" down --remove-orphans 2>/dev/null || true
    
    # Also try with override files
    docker compose -f "$PROJECT_DIR/docker-compose.yml" -f "$PROJECT_DIR/docker-compose.nginx.yml" down --remove-orphans 2>/dev/null || true
    docker compose -f "$PROJECT_DIR/docker-compose.yml" -f "$PROJECT_DIR/docker-compose.traefik.yml" down --remove-orphans 2>/dev/null || true
    
    # Remove any remaining containers with n8n in the name
    local containers=$(docker ps -aq --filter "name=n8n" 2>/dev/null || true)
    if [[ -n "$containers" ]]; then
        log "Removing remaining N8N containers..."
        docker rm -f $containers 2>/dev/null || true
    fi
    
    log "Containers removed"
}

# Remove data directories
reset_data() {
    log "Removing data directories..."
    
    # Remove N8N data
    if [[ -d "$PROJECT_DIR/data/n8n" ]]; then
        info "Removing N8N data directory..."
        rm -rf "$PROJECT_DIR/data/n8n"
    fi
    
    # Remove PostgreSQL data
    if [[ -d "$PROJECT_DIR/data/postgres" ]]; then
        info "Removing PostgreSQL data directory..."
        rm -rf "$PROJECT_DIR/data/postgres"
    fi
    
    # Remove Redis data
    if [[ -d "$PROJECT_DIR/data/redis" ]]; then
        info "Removing Redis data directory..."
        rm -rf "$PROJECT_DIR/data/redis"
    fi
    
    # Remove Traefik ACME data
    if [[ -d "$PROJECT_DIR/data/traefik" ]]; then
        info "Removing Traefik data directory..."
        rm -rf "$PROJECT_DIR/data/traefik"
    fi
    
    # Recreate empty data directories
    mkdir -p "$PROJECT_DIR/data/n8n"
    mkdir -p "$PROJECT_DIR/data/postgres"
    mkdir -p "$PROJECT_DIR/data/redis"
    mkdir -p "$PROJECT_DIR/data/traefik/acme"
    
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
    local volumes=$(docker volume ls -q --filter "name=n8n" 2>/dev/null || true)
    if [[ -n "$volumes" ]]; then
        docker volume rm $volumes 2>/dev/null || true
        log "N8N volumes removed"
    fi
}

# Clean up logs
reset_logs() {
    log "Cleaning up log files..."
    
    # Clear nginx logs
    if [[ -d "$PROJECT_DIR/nginx/logs" ]]; then
        rm -rf "$PROJECT_DIR/nginx/logs"/*
    fi
    
    # Clear traefik logs
    if [[ -d "$PROJECT_DIR/traefik/logs" ]]; then
        rm -rf "$PROJECT_DIR/traefik/logs"/*
    fi
    
    log "Log files cleaned"
}

# Set proper permissions
set_permissions() {
    log "Setting proper permissions..."
    
    # Set permissions for data directories
    chmod -R 755 "$PROJECT_DIR/data" 2>/dev/null || true
    
    # Set permissions for scripts
    chmod +x "$PROJECT_DIR/scripts"/*.sh 2>/dev/null || true
    
    # Set permissions for SSL directory
    if [[ -d "$PROJECT_DIR/nginx/ssl" ]]; then
        chmod 700 "$PROJECT_DIR/nginx/ssl"
    fi
    
    # Set permissions for Traefik ACME directory
    if [[ -d "$PROJECT_DIR/data/traefik/acme" ]]; then
        chmod 600 "$PROJECT_DIR/data/traefik/acme" 2>/dev/null || true
    fi
    
    log "Permissions set"
}

# Show reset summary
show_summary() {
    local reset_type="$1"
    
    echo ""
    log "Reset Summary:"
    echo "  Reset Type: $reset_type"
    echo "  Project Directory: $PROJECT_DIR"
    echo "  Data Directories: $(ls -la "$PROJECT_DIR/data" 2>/dev/null | wc -l) items"
    echo "  Docker Containers: $(docker ps -aq --filter "name=n8n" 2>/dev/null | wc -l) remaining"
    echo "  Docker Networks: $(docker network ls --filter "name=n8n" -q 2>/dev/null | wc -l) remaining"
    echo "  Docker Volumes: $(docker volume ls --filter "name=n8n" -q 2>/dev/null | wc -l) remaining"
    echo ""
}

# Confirmation prompt
confirm_reset() {
    local reset_type="$1"
    
    if [[ "${FORCE_RESET:-false}" == "true" ]]; then
        return 0
    fi
    
    echo ""
    warning "This will perform a $reset_type reset of your N8N installation!"
    warning "This action cannot be undone unless you have backups!"
    echo ""
    
    case "$reset_type" in
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
            warning "  - All N8N workflows and credentials"
            warning "  - All PostgreSQL data"
            warning "  - All Redis data"
            warning "  - All Docker containers"
            warning "  - Docker networks and volumes"
            warning "  - Log files"
            ;;
    esac
    
    echo ""
    read -p "Are you sure you want to continue? Type 'yes' to confirm: " -r
    echo ""
    
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
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
    if [[ "$data_only" == false && "$containers_only" == false && "$full_reset" == false ]]; then
        full_reset=true
        reset_type="full"
    fi
    
    log "Starting N8N reset process..."
    log "Reset type: $reset_type"
    
    confirm_reset "$reset_type"
    
    # Create backup if requested
    if [[ "$create_backup_first" == "true" ]]; then
        create_backup
    fi
    
    # Perform reset based on type
    if [[ "$containers_only" == "true" ]]; then
        reset_containers
        reset_networks
        reset_volumes
    elif [[ "$data_only" == "true" ]]; then
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
    
    show_summary "$reset_type"
    
    log "Reset completed successfully!"
    
    if [[ "$containers_only" == false ]]; then
        info "You can now start fresh by running:"
        info "  docker compose up -d"
    fi
}

# Run main function
main "$@"

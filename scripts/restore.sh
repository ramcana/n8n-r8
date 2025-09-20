#!/bin/bash

# N8N Restore Script
# This script restores N8N data, PostgreSQL database, and Redis data from a backup
set -euo pipefail
# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BACKUP_DIR="$PROJECT_DIR/backups"
# Load environment variables
if [[ -f "$PROJECT_DIR/.env" ]]; then
    # shellcheck source=/dev/null
    source "$PROJECT_DIR/.env"
else
    echo "Error: .env file not found in $PROJECT_DIR"
    exit 1
fi
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
    echo "Usage: $0 [OPTIONS] <backup_name>"
    echo ""
    echo "Options:"
    echo "  -h, --help          Show this help message"
    echo "  -l, --list          List available backups"
    echo "  -f, --force         Force restore without confirmation"
    echo "  --data-only         Restore only N8N data (skip database)"
    echo "  --db-only           Restore only database (skip N8N data)"
    echo "  --config-only       Restore only configuration files"
    echo "Examples:"
    echo "  $0 n8n_backup_20240101_120000"
    echo "  $0 --list"
    echo "  $0 --force --data-only n8n_backup_20240101_120000"
# List available backups
list_backups() {
    log "Available backups:"
    
    if [[ ! -d "$BACKUP_DIR" ]] || [[ -z "$(ls -A "$BACKUP_DIR" 2>/dev/null)" ]]; then
        warning "No backups found in $BACKUP_DIR"
        return
    fi
    for backup in "$BACKUP_DIR"/n8n_backup_*; do
        if [[ -d "$backup" ]]; then
            local backup_name
            local backup_date
            local backup_size
            backup_name=$(basename "$backup")
            backup_date=$(echo "$backup_name" | sed 's/n8n_backup_//' | sed 's/_/ /')
            backup_size=$(du -sh "$backup" | awk '{print $1}')
            
            echo "  📦 $backup_name"
            echo "     Date: $backup_date"
            echo "     Size: $backup_size"
            if [[ -f "$backup/backup_info.txt" ]]; then
                echo "     Info: $(head -n 1 "$backup/backup_info.txt" 2>/dev/null || echo "No info available")"
            fi
            echo ""
        fi
    done
# Validate backup
validate_backup() {
    local backup_path="$1"
    log "Validating backup: $(basename "$backup_path")"
    if [[ ! -d "$backup_path" ]]; then
        error "Backup directory not found: $backup_path"
        exit 1
    # Check for required backup files
    local has_data=false
    local has_db=false
    local has_redis=false
    if [[ -f "$backup_path/n8n_data.tar.gz" ]]; then
        has_data=true
        info "✓ N8N data backup found"
    else
        warning "✗ N8N data backup not found"
    if [[ -f "$backup_path/postgres_dump.sql.gz" ]]; then
        has_db=true
        info "✓ PostgreSQL backup found"
        warning "✗ PostgreSQL backup not found"
    if [[ -f "$backup_path/redis_data.tar.gz" ]]; then
        has_redis=true
        info "✓ Redis backup found"
        warning "✗ Redis backup not found"
    if [[ "$has_data" == false && "$has_db" == false && "$has_redis" == false ]]; then
        error "No valid backup data found"
# Stop services
stop_services() {
    log "Stopping N8N services..."
    docker compose -f "$PROJECT_DIR/docker-compose.yml" down
    log "Services stopped"
# Start services
start_services() {
    log "Starting N8N services..."
    docker compose -f "$PROJECT_DIR/docker-compose.yml" up -d
    # Wait for services to be healthy
    log "Waiting for services to be ready..."
    local max_attempts=30
    local attempt=0
    while [[ $attempt -lt $max_attempts ]]; do
        if docker compose -f "$PROJECT_DIR/docker-compose.yml" ps | grep -q "healthy"; then
            log "Services are ready"
            return 0
        
        attempt=$((attempt + 1))
        sleep 10
        echo -n "."
    warning "Services may not be fully ready yet"
# Restore N8N data
restore_n8n_data() {
    if [[ ! -f "$backup_path/n8n_data.tar.gz" ]]; then
        warning "N8N data backup not found, skipping..."
    log "Restoring N8N data..."
    # Backup current data if it exists
    if [[ -d "$PROJECT_DIR/data/n8n" ]]; then
        log "Backing up current N8N data..."
        mv "$PROJECT_DIR/data/n8n" "$PROJECT_DIR/data/n8n.backup.$(date +%s)" || true
    # Extract backup
    mkdir -p "$PROJECT_DIR/data"
    tar -xzf "$backup_path/n8n_data.tar.gz" -C "$PROJECT_DIR/data/"
    log "N8N data restored successfully"
# Restore PostgreSQL database
restore_postgres() {
    if [[ ! -f "$backup_path/postgres_dump.sql.gz" ]]; then
        warning "PostgreSQL backup not found, skipping..."
    log "Restoring PostgreSQL database..."
    # Start only postgres service for restore
    docker compose -f "$PROJECT_DIR/docker-compose.yml" up -d postgres
    # Wait for postgres to be ready
    log "Waiting for PostgreSQL to be ready..."
        if docker compose -f "$PROJECT_DIR/docker-compose.yml" exec -T postgres pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_DB" >/dev/null 2>&1; then
            break
        sleep 2
    if [[ $attempt -eq $max_attempts ]]; then
        error "PostgreSQL failed to start"
    # Restore database
    if gunzip -c "$backup_path/postgres_dump.sql.gz" | \
        docker compose -f "$PROJECT_DIR/docker-compose.yml" exec -T postgres psql \
            -U "$POSTGRES_USER" \
            -d "$POSTGRES_DB"; then
        log "PostgreSQL database restored successfully"
        error "PostgreSQL restore failed"
# Restore Redis data
restore_redis() {
    if [[ ! -f "$backup_path/redis_data.tar.gz" ]]; then
        warning "Redis backup not found, skipping..."
    log "Restoring Redis data..."
    if [[ -d "$PROJECT_DIR/data/redis" ]]; then
        log "Backing up current Redis data..."
        mv "$PROJECT_DIR/data/redis" "$PROJECT_DIR/data/redis.backup.$(date +%s)" || true
    tar -xzf "$backup_path/redis_data.tar.gz" -C "$PROJECT_DIR/data/"
    log "Redis data restored successfully"
# Restore configuration
restore_config() {
    if [[ ! -d "$backup_path/config" ]]; then
        warning "Configuration backup not found, skipping..."
    log "Restoring configuration files..."
    # Backup current config files
    local backup_suffix
    backup_suffix=".backup.$(date +%s)"
    [[ -f "$PROJECT_DIR/.env" ]] && cp "$PROJECT_DIR/.env" "$PROJECT_DIR/.env$backup_suffix"
    [[ -f "$PROJECT_DIR/docker-compose.yml" ]] && cp "$PROJECT_DIR/docker-compose.yml" "$PROJECT_DIR/docker-compose.yml$backup_suffix"
    # Restore config files
    if [[ -f "$backup_path/config/.env" ]]; then
        cp "$backup_path/config/.env" "$PROJECT_DIR/"
        log "Environment file restored"
    if [[ -f "$backup_path/config/docker-compose.yml" ]]; then
        cp "$backup_path/config/docker-compose.yml" "$PROJECT_DIR/"
        log "Docker Compose file restored"
    # Restore nginx config if exists
    if [[ -d "$backup_path/config/nginx" ]]; then
        [[ -d "$PROJECT_DIR/nginx" ]] && mv "$PROJECT_DIR/nginx" "$PROJECT_DIR/nginx$backup_suffix"
        cp -r "$backup_path/config/nginx" "$PROJECT_DIR/"
        log "Nginx configuration restored"
    # Restore traefik config if exists
    if [[ -d "$backup_path/config/traefik" ]]; then
        [[ -d "$PROJECT_DIR/traefik" ]] && mv "$PROJECT_DIR/traefik" "$PROJECT_DIR/traefik$backup_suffix"
        cp -r "$backup_path/config/traefik" "$PROJECT_DIR/"
        log "Traefik configuration restored"
    log "Configuration restored successfully"
# Confirmation prompt
confirm_restore() {
    local backup_name="$1"
    if [[ "${FORCE_RESTORE:-false}" == "true" ]]; then
        return 0
    warning "This will restore the backup '$backup_name' and may overwrite existing data!"
    read -p "Are you sure you want to continue? (yes/no): " -r
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        log "Restore cancelled by user"
        exit 0
# Main restore function
main() {
    local backup_name=""
    local data_only=false
    local db_only=false
    local config_only=false
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                ;;
            -l|--list)
                list_backups
                exit 0
            -f|--force)
                FORCE_RESTORE=true
                shift
            --data-only)
                data_only=true
            --db-only)
                db_only=true
            --config-only)
                config_only=true
            -*)
                error "Unknown option: $1"
            *)
                backup_name="$1"
        esac
    if [[ -z "$backup_name" ]]; then
        error "Backup name is required"
        usage
    local backup_path="$BACKUP_DIR/$backup_name"
    log "Starting N8N restore process..."
    log "Backup: $backup_name"
    validate_backup "$backup_path"
    confirm_restore "$backup_name"
    stop_services
    if [[ "$config_only" == "true" ]]; then
        restore_config "$backup_path"
    elif [[ "$data_only" == "true" ]]; then
        restore_n8n_data "$backup_path"
        restore_redis "$backup_path"
    elif [[ "$db_only" == "true" ]]; then
        restore_postgres "$backup_path"
        # Full restore
    start_services
    log "Restore completed successfully!"
    log "Please verify that all services are working correctly."
# Run main function
main "$@"

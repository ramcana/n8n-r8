#!/bin/bash

# N8N Backup Script
# This script creates backups of N8N data, PostgreSQL database, and Redis data

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BACKUP_DIR="$PROJECT_DIR/backups"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_NAME="n8n_backup_$TIMESTAMP"
BACKUP_PATH="$BACKUP_DIR/$BACKUP_NAME"

# Load environment variables
if [[ -f "$PROJECT_DIR/.env" ]]; then
    source "$PROJECT_DIR/.env"
else
    echo "Error: .env file not found in $PROJECT_DIR"
    exit 1
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# Check if Docker Compose is running
check_services() {
    log "Checking if services are running..."
    if ! docker compose -f "$PROJECT_DIR/docker-compose.yml" ps | grep -q "Up"; then
        error "N8N services are not running. Please start them first."
        exit 1
    fi
}

# Create backup directory
create_backup_dir() {
    log "Creating backup directory: $BACKUP_PATH"
    mkdir -p "$BACKUP_PATH"
}

# Backup N8N data
backup_n8n_data() {
    log "Backing up N8N data..."
    if [[ -d "$PROJECT_DIR/data/n8n" ]]; then
        tar -czf "$BACKUP_PATH/n8n_data.tar.gz" -C "$PROJECT_DIR/data" n8n/
        log "N8N data backup completed"
    else
        warning "N8N data directory not found"
    fi
}

# Backup PostgreSQL database
backup_postgres() {
    log "Backing up PostgreSQL database..."
    if docker compose -f "$PROJECT_DIR/docker-compose.yml" exec -T postgres pg_dump \
        -U "$POSTGRES_USER" \
        -d "$POSTGRES_DB" \
        --no-owner \
        --no-privileges \
        --clean \
        --if-exists \
        > "$BACKUP_PATH/postgres_dump.sql"; then
        log "PostgreSQL backup completed"
        gzip "$BACKUP_PATH/postgres_dump.sql"
    else
        error "PostgreSQL backup failed"
        exit 1
    fi
}

# Backup Redis data
backup_redis() {
    log "Backing up Redis data..."
    if [[ -d "$PROJECT_DIR/data/redis" ]]; then
        # Create Redis backup using BGSAVE
        docker compose -f "$PROJECT_DIR/docker-compose.yml" exec -T redis redis-cli \
            --pass "$REDIS_PASSWORD" BGSAVE
        
        # Wait for background save to complete
        while [[ $(docker compose -f "$PROJECT_DIR/docker-compose.yml" exec -T redis redis-cli \
            --pass "$REDIS_PASSWORD" LASTSAVE) == $(docker compose -f "$PROJECT_DIR/docker-compose.yml" exec -T redis redis-cli \
            --pass "$REDIS_PASSWORD" LASTSAVE) ]]; do
            sleep 1
        done
        
        # Copy Redis data
        tar -czf "$BACKUP_PATH/redis_data.tar.gz" -C "$PROJECT_DIR/data" redis/
        log "Redis backup completed"
    else
        warning "Redis data directory not found"
    fi
}

# Backup configuration files
backup_config() {
    log "Backing up configuration files..."
    
    # Create config backup directory
    mkdir -p "$BACKUP_PATH/config"
    
    # Copy important configuration files
    cp "$PROJECT_DIR/.env" "$BACKUP_PATH/config/" 2>/dev/null || warning ".env file not found"
    cp "$PROJECT_DIR/docker-compose.yml" "$BACKUP_PATH/config/" 2>/dev/null || warning "docker-compose.yml not found"
    cp "$PROJECT_DIR/docker-compose.nginx.yml" "$BACKUP_PATH/config/" 2>/dev/null || warning "docker-compose.nginx.yml not found"
    cp "$PROJECT_DIR/docker-compose.traefik.yml" "$BACKUP_PATH/config/" 2>/dev/null || warning "docker-compose.traefik.yml not found"
    
    # Copy nginx config if exists
    if [[ -d "$PROJECT_DIR/nginx" ]]; then
        cp -r "$PROJECT_DIR/nginx" "$BACKUP_PATH/config/"
    fi
    
    # Copy traefik config if exists
    if [[ -d "$PROJECT_DIR/traefik" ]]; then
        cp -r "$PROJECT_DIR/traefik" "$BACKUP_PATH/config/"
    fi
    
    log "Configuration backup completed"
}

# Create backup metadata
create_metadata() {
    log "Creating backup metadata..."
    
    cat > "$BACKUP_PATH/backup_info.txt" << EOF
N8N Backup Information
=====================
Backup Date: $(date)
Backup Name: $BACKUP_NAME
N8N Version: $(docker compose -f "$PROJECT_DIR/docker-compose.yml" exec -T n8n n8n --version 2>/dev/null || echo "Unknown")
PostgreSQL Version: $(docker compose -f "$PROJECT_DIR/docker-compose.yml" exec -T postgres psql --version 2>/dev/null || echo "Unknown")
Redis Version: $(docker compose -f "$PROJECT_DIR/docker-compose.yml" exec -T redis redis-server --version 2>/dev/null || echo "Unknown")

Backup Contents:
- N8N Data: $(ls -lh "$BACKUP_PATH/n8n_data.tar.gz" 2>/dev/null | awk '{print $5}' || echo "Not found")
- PostgreSQL Dump: $(ls -lh "$BACKUP_PATH/postgres_dump.sql.gz" 2>/dev/null | awk '{print $5}' || echo "Not found")
- Redis Data: $(ls -lh "$BACKUP_PATH/redis_data.tar.gz" 2>/dev/null | awk '{print $5}' || echo "Not found")
- Configuration Files: $(du -sh "$BACKUP_PATH/config" 2>/dev/null | awk '{print $1}' || echo "Not found")

Total Backup Size: $(du -sh "$BACKUP_PATH" | awk '{print $1}')
EOF

    log "Backup metadata created"
}

# Cleanup old backups
cleanup_old_backups() {
    local retention_days=${BACKUP_RETENTION_DAYS:-30}
    log "Cleaning up backups older than $retention_days days..."
    
    find "$BACKUP_DIR" -type d -name "n8n_backup_*" -mtime +$retention_days -exec rm -rf {} + 2>/dev/null || true
    
    log "Old backup cleanup completed"
}

# Main execution
main() {
    log "Starting N8N backup process..."
    
    check_services
    create_backup_dir
    backup_n8n_data
    backup_postgres
    backup_redis
    backup_config
    create_metadata
    cleanup_old_backups
    
    log "Backup completed successfully!"
    log "Backup location: $BACKUP_PATH"
    log "Total backup size: $(du -sh "$BACKUP_PATH" | awk '{print $1}')"
}

# Run main function
main "$@"

#!/bin/bash

# N8N-R8 Restore Script
# Restore N8N data from backup
set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Configuration
BACKUP_DIR="$PROJECT_DIR/backups"
LOG_DIR="$PROJECT_DIR/logs"
LOG_FILE="$LOG_DIR/restore.log"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Logging functions
log() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${timestamp} $*" | tee -a "$LOG_FILE"
}

info() {
    log "${GREEN}[INFO]${NC} $*"
}

warning() {
    log "${YELLOW}[WARN]${NC} $*"
}

error() {
    log "${RED}[ERROR]${NC} $*"
    exit 1
}

usage() {
    cat << EOF
N8N-R8 Restore Script
Usage: $0 [OPTIONS] <backup_name>

OPTIONS:
    -h, --help      Show this help message
    -f, --force     Force restore without confirmation
    --no-data      Skip N8N data restore
    --no-db        Skip database restore
    --no-redis     Skip Redis data restore

EXAMPLES:
    $0 backup_20250920_120000         # Restore specific backup
    $0 -f latest                      # Force restore latest backup
    $0 --no-redis backup_name         # Restore without Redis data
EOF
}

validate_backup() {
    local backup_path="$1"
    local has_data=false
    local has_db=false
    local has_redis=false
    
    info "Validating backup: $backup_path"
    
    if [[ ! -d "$backup_path" ]]; then
        error "Backup directory not found: $backup_path"
    fi
    
    if [[ -f "$backup_path/n8n_data.tar.gz" ]]; then
        has_data=true
        info "✓ N8N data backup found"
    else
        warning "✗ N8N data backup not found"
    fi
    
    if [[ -f "$backup_path/postgres_dump.sql" ]]; then
        has_db=true
        info "✓ PostgreSQL backup found"
    else
        warning "✗ PostgreSQL backup not found"
    fi
    
    if [[ -f "$backup_path/redis_data.tar.gz" ]]; then
        has_redis=true
        info "✓ Redis backup found"
    else
        warning "✗ Redis backup not found"
    fi

    if [[ "$has_data" == false && "$has_db" == false && "$has_redis" == false ]]; then
        error "No valid backup data found"
    fi
}

stop_services() {
    log "Stopping N8N services..."
    docker compose -f "$PROJECT_DIR/docker-compose.yml" down
    log "Services stopped"
}

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
        fi
        attempt=$((attempt + 1))
        sleep 10
        echo -n "."
    done
    warning "Services may not be fully ready yet"
}

restore_n8n_data() {
    local backup_path="$1"
    if [[ ! -f "$backup_path/n8n_data.tar.gz" ]]; then
        warning "N8N data backup not found, skipping..."
        return 0
    fi
    
    log "Restoring N8N data..."
    # Backup current data if it exists
    if [[ -d "$PROJECT_DIR/data" ]]; then
        mv "$PROJECT_DIR/data" "$PROJECT_DIR/data.old"
    fi
    
    # Extract backup
    tar -xzf "$backup_path/n8n_data.tar.gz" -C "$PROJECT_DIR"
    if [[ ! -d "$PROJECT_DIR/data" ]]; then
        error "Failed to restore N8N data"
    fi
    
    # Remove old backup if successful
    if [[ -d "$PROJECT_DIR/data.old" ]]; then
        rm -rf "$PROJECT_DIR/data.old"
    fi
    
    info "N8N data restored successfully"
}

restore_database() {
    local backup_path="$1"
    if [[ ! -f "$backup_path/postgres_dump.sql" ]]; then
        warning "Database backup not found, skipping..."
        return 0
    fi
    
    log "Restoring PostgreSQL database..."
    local pg_container
    pg_container=$(docker compose -f "$PROJECT_DIR/docker-compose.yml" ps -q postgres)
    if [[ -z "$pg_container" ]]; then
        error "PostgreSQL container not found"
    fi
    
    # Copy backup to container
    docker cp "$backup_path/postgres_dump.sql" "$pg_container:/tmp/postgres_dump.sql"
    
    # Import backup
    if ! docker exec -u postgres "$pg_container" psql -f /tmp/postgres_dump.sql; then
        error "Failed to restore database"
    fi
    
    # Clean up
    docker exec "$pg_container" rm /tmp/postgres_dump.sql
    info "Database restored successfully"
}

restore_redis() {
    local backup_path="$1"
    if [[ ! -f "$backup_path/redis_data.tar.gz" ]]; then
        warning "Redis backup not found, skipping..."
        return 0
    fi
    
    log "Restoring Redis data..."
    local redis_container
    redis_container=$(docker compose -f "$PROJECT_DIR/docker-compose.yml" ps -q redis)
    if [[ -z "$redis_container" ]]; then
        error "Redis container not found"
    fi
    
    # Copy and extract backup
    docker cp "$backup_path/redis_data.tar.gz" "$redis_container:/data/redis_data.tar.gz"
    docker exec "$redis_container" tar -xzf /data/redis_data.tar.gz -C /data
    docker exec "$redis_container" rm /data/redis_data.tar.gz
    
    # Restart Redis to load data
    docker compose -f "$PROJECT_DIR/docker-compose.yml" restart redis
    info "Redis data restored successfully"
}

main() {
    local force=false
    local skip_data=false
    local skip_db=false
    local skip_redis=false
    local backup_name=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                usage
                exit 0
                ;;
            -f|--force)
                force=true
                shift
                ;;
            --no-data)
                skip_data=true
                shift
                ;;
            --no-db)
                skip_db=true
                shift
                ;;
            --no-redis)
                skip_redis=true
                shift
                ;;
            *)
                if [[ -n "$backup_name" ]]; then
                    error "Multiple backup names specified"
                fi
                backup_name="$1"
                shift
                ;;
        esac
    done

    if [[ -z "$backup_name" ]]; then
        error "No backup name specified"
    fi

    local backup_path
    if [[ "$backup_name" == "latest" ]]; then
        backup_path=$(find "$BACKUP_DIR" -maxdepth 1 -type d -name "backup_*" | sort -r | head -n1)
    else
        backup_path="$BACKUP_DIR/$backup_name"
    fi

    # Validate backup
    validate_backup "$backup_path"

    # Confirm restore
    if [[ "$force" != "true" ]]; then
        read -rp "This will restore N8N from backup. Continue? [y/N] " confirm
        if [[ ! "$confirm" =~ ^[yY]$ ]]; then
            info "Restore cancelled"
            exit 0
        fi
    fi

    # Stop services
    stop_services

    # Restore components
    if [[ "$skip_data" != "true" ]]; then
        restore_n8n_data "$backup_path"
    fi

    if [[ "$skip_db" != "true" ]]; then
        restore_database "$backup_path"
    fi

    if [[ "$skip_redis" != "true" ]]; then
        restore_redis "$backup_path"
    fi

    # Start services
    start_services

    info "Restore completed successfully"
}

# Execute main function
main "$@"
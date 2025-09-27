#!/bin/bash

# N8N-R8 Traefik Start Script
# Starts N8N services with Traefik reverse proxy
set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

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
    exit 1
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
    echo "  -d, --detach        Run in detached mode (background)"
    echo ""
    echo "Examples:"
    echo "  $0                  # Start with logs"
    echo "  $0 -d               # Start in background"
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check if Docker is running
    if ! docker info >/dev/null 2>&1; then
        error "Docker is not running. Please start Docker first."
    fi
    
    log "Prerequisites check passed"
}

# Load environment variables
load_environment() {
    log "Loading environment variables..."
    if [[ -f "$PROJECT_DIR/.env" ]]; then
        # shellcheck source=/dev/null
        source "$PROJECT_DIR/.env"
        log "Environment variables loaded"
    fi
}

# Create necessary directories
create_directories() {
    log "Creating necessary directories..."
    mkdir -p "$PROJECT_DIR/logs"
    mkdir -p "$PROJECT_DIR/traefik"
}

# Set proper permissions
set_permissions() {
    log "Setting permissions..."
    chmod 755 "$PROJECT_DIR/scripts"/*.sh 2>/dev/null || true
}

# Setup SSL configuration
setup_ssl_config() {
    local use_staging="${1:-false}"
    log "Setting up SSL configuration..."
    
    if [[ "$use_staging" == "true" ]]; then
        warning "Using Let's Encrypt STAGING server - certificates will not be trusted!"
    else
        info "Using Let's Encrypt PRODUCTION server"
    fi
}

# Check running services
check_running_services() {
    log "Checking for running services..."
    # Basic check - could be expanded
}

# Start services
start_services() {
    local detach="$1"
    local build="$2"
    local force_recreate="$3"
    local no_deps="$4"
    
    log "Starting services..."
    
    local cmd="docker compose -f $PROJECT_DIR/docker-compose.yml -f $PROJECT_DIR/docker-compose.traefik.yml"
    
    if [[ "$build" == "true" ]]; then
        cmd="$cmd build"
    fi
    
    if [[ "$force_recreate" == "true" ]]; then
        cmd="$cmd --force-recreate"
    fi
    
    if [[ "$no_deps" == "true" ]]; then
        cmd="$cmd --no-deps"
    fi
    
    cmd="$cmd up"
    
    if [[ "$detach" == "true" ]]; then
        cmd="$cmd -d"
    fi
    
    log "Running: $cmd"
    eval "$cmd"
}

# Show service status
show_service_status() {
    log "Service Status:"
    docker compose -f "$PROJECT_DIR/docker-compose.yml" -f "$PROJECT_DIR/docker-compose.traefik.yml" ps
}

# Show access information
show_access_info() {
    log "Access Information:"
    echo "N8N: https://n8n.localhost"
    echo "Traefik Dashboard: https://traefik.localhost"
}

# Main function
main() {
    local detach=false
    local build=false
    local force_recreate=false
    local no_deps=false
    local use_staging=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                exit 0
                ;;
            -d|--detach)
                detach=true
                ;;
            --build)
                build=true
                ;;
            --force-recreate)
                force_recreate=true
                ;;
            --no-deps)
                no_deps=true
                ;;
            --staging)
                use_staging=true
                ;;
            *)
                error "Unknown option: $1"
                ;;
        esac
        shift
    done
    
    check_prerequisites
    load_environment
    create_directories
    set_permissions
    setup_ssl_config "$use_staging"
    check_running_services
    start_services "$detach" "$build" "$force_recreate" "$no_deps"
    
    if [[ "$detach" == "false" ]]; then
        show_service_status
        show_access_info
        log "Services started successfully"
    fi
}

# Run main function
main "$@"

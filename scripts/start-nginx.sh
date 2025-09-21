#!/bin/bash

# N8N with Nginx Proxy Start Script
# This script starts N8N with Nginx as a reverse proxy
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
    echo "  -d, --detach        Run in detached mode (background)"
    echo "  --build             Build images before starting"
    echo "  --force-recreate    Force recreate containers"
    echo "  --no-deps           Don't start linked services"
    echo "Examples:"
    echo "  $0                  # Start with logs"
    echo "  $0 -d               # Start in background"
    echo "  $0 --build -d       # Build and start in background"
    exit 1
}
# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check if Docker is running
    if ! docker info >/dev/null 2>&1; then
        error "Docker is not running. Please start Docker first."
        exit 1
    fi
    
    # Check if docker-compose is available
    if ! command -v docker >/dev/null 2>&1; then
        error "Docker Compose is not installed or not in PATH."
        exit 1
    fi
    
    # Check if .env file exists
    if [[ ! -f "$PROJECT_DIR/.env" ]]; then
        error ".env file not found. Please create it first."
        exit 1
    fi
    
    # Check if nginx configuration exists
    if [[ ! -f "$PROJECT_DIR/nginx/nginx.conf" ]]; then
        error "Nginx configuration not found. Please ensure nginx/nginx.conf exists."
        exit 1
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
    else
        error ".env file not found"
        exit 1
    fi
}

# Create necessary directories
create_directories() {
    log "Creating necessary directories..."
    # Create data directories
    mkdir -p "$PROJECT_DIR/data/n8n"
    mkdir -p "$PROJECT_DIR/data/postgres"
    mkdir -p "$PROJECT_DIR/data/redis"
    # Create nginx directories
    mkdir -p "$PROJECT_DIR/nginx/html"
    # Create log directories
    mkdir -p /var/log/nginx 2>/dev/null || true
    log "Directories created"
}
# Set proper permissions
set_permissions() {
    log "Setting proper permissions..."
    # Set permissions for data directories
    chmod -R 755 "$PROJECT_DIR/data" 2>/dev/null || true
    # Set permissions for SSL directory (more restrictive)
    chmod 700 "$PROJECT_DIR/nginx/ssl" 2>/dev/null || true
    # Set permissions for nginx config files
    chmod 644 "$PROJECT_DIR/nginx/nginx.conf" 2>/dev/null || true
    chmod 644 "$PROJECT_DIR/nginx/conf.d"/*.conf 2>/dev/null || true
    log "Permissions set"
}
# Check if services are already running
check_running_services() {
    log "Checking for running services..."
    local running_containers
    running_containers=$(docker compose -f "$PROJECT_DIR/docker-compose.yml" -f "$PROJECT_DIR/docker-compose.nginx.yml" ps -q 2>/dev/null | wc -l)
    if [[ $running_containers -gt 0 ]]; then
        warning "Some services are already running"
        info "Running containers: $running_containers"
        
        # Show running services
        docker compose -f "$PROJECT_DIR/docker-compose.yml" -f "$PROJECT_DIR/docker-compose.nginx.yml" ps
        echo ""
        read -p "Do you want to restart the services? (y/n): " -r
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log "Stopping existing services..."
            docker compose -f "$PROJECT_DIR/docker-compose.yml" -f "$PROJECT_DIR/docker-compose.nginx.yml" down
        else
            log "Keeping existing services running"
            exit 0
        fi
    fi
}
# Start services
start_services() {
    local detach="$1"
    local build="$2"
    local force_recreate="$3"
    local no_deps="$4"
    log "Starting N8N with Nginx proxy..."
    local compose_args=()
    # Add build flag if requested
    if [[ "$build" == "true" ]]; then
        compose_args+=("--build")
    fi
    # Add force recreate flag if requested
    if [[ "$force_recreate" == "true" ]]; then
        compose_args+=("--force-recreate")
    fi
    # Add no deps flag if requested
    if [[ "$no_deps" == "true" ]]; then
        compose_args+=("--no-deps")
    fi
    # Start services
    if [[ "$detach" == "true" ]]; then
        docker compose -f "$PROJECT_DIR/docker-compose.yml" -f "$PROJECT_DIR/docker-compose.nginx.yml" up -d "${compose_args[@]}"
        log "Services started in background"
        # Wait a moment for services to initialize
        sleep 5
        # Show service status
        show_service_status
        show_access_info
    else
        log "Starting services with logs (Press Ctrl+C to stop)..."
        docker compose -f "$PROJECT_DIR/docker-compose.yml" -f "$PROJECT_DIR/docker-compose.nginx.yml" up "${compose_args[@]}"
    fi
}
# Show service status
show_service_status() {
    log "Service Status:"
    docker compose -f "$PROJECT_DIR/docker-compose.yml" -f "$PROJECT_DIR/docker-compose.nginx.yml" ps
    log "Health Status:"
    # Check individual service health
    local services=("n8n" "postgres" "redis" "nginx")
    for service in "${services[@]}"; do
        local container_name="n8n-$service"
        if [[ "$service" == "n8n" ]]; then
            container_name="n8n"
        fi
        local health_status
        health_status=$(docker inspect --format='{{.State.Health.Status}}' "$container_name" 2>/dev/null || echo "no-healthcheck")
        case "$health_status" in
            "healthy")
                echo -e "  ✅ $service: ${GREEN}healthy${NC}"
                ;;
            "unhealthy")
                echo -e "  ❌ $service: ${RED}unhealthy${NC}"
                ;;
            "starting")
                echo -e "  🔄 $service: ${YELLOW}starting${NC}"
                ;;
            "no-healthcheck")
                echo -e "  ⚪ $service: ${BLUE}no healthcheck${NC}"
                ;;
            *)
                echo -e "  ❓ $service: ${YELLOW}unknown${NC}"
                ;;
        esac
    done
}
# Show access information
show_access_info() {
    log "Access Information:"
    # Load environment variables for display
    source "$PROJECT_DIR/.env" 2>/dev/null || true
    local nginx_port=${NGINX_PORT:-80}
    local nginx_ssl_port=${NGINX_SSL_PORT:-443}
    local n8n_host=${N8N_HOST:-localhost}
    echo "  🌐 N8N Web Interface:"
    echo "    HTTP:  http://$n8n_host:$nginx_port"
    if [[ -f "$PROJECT_DIR/nginx/ssl/cert.pem" ]]; then
        echo "    HTTPS: https://$n8n_host:$nginx_ssl_port"
    else
        echo "    HTTPS: Not configured (SSL certificates not found)"
    fi
    echo "  📊 Service URLs:"
    echo "    Nginx Status: http://$n8n_host:$nginx_port/health"
    echo "  📁 Important Paths:"
    echo "    Project Directory: $PROJECT_DIR"
    echo "    Data Directory: $PROJECT_DIR/data"
    echo "    Nginx Config: $PROJECT_DIR/nginx"
    echo "    Logs: /var/log/nginx"
    log "Useful Commands:"
    echo "  View logs:     docker compose -f docker-compose.yml -f docker-compose.nginx.yml logs -f"
    echo "  Stop services: docker compose -f docker-compose.yml -f docker-compose.nginx.yml down"
    echo "  Restart:       docker compose -f docker-compose.yml -f docker-compose.nginx.yml restart"
}

# Main function
main() {
    local detach=false
    local build=false
    local force_recreate=false
    local no_deps=false
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                ;;
            -d|--detach)
                detach=true
                shift
                ;;
            --build)
                build=true
                shift
                ;;
            --force-recreate)
                force_recreate=true
                shift
                ;;
            --no-deps)
                no_deps=true
                shift
                ;;
            *)
                error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
    check_prerequisites
    load_environment
    create_directories
    set_permissions
    check_running_services
    start_services "$detach" "$build" "$force_recreate" "$no_deps"
    if [[ "$detach" == "false" ]]; then
        log "Services stopped"
    fi
}

# Change to project directory
cd "$PROJECT_DIR"
# Run main function
main "$@"
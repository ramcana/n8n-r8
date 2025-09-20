#!/bin/bash

# N8N with Traefik Proxy Start Script
# This script starts N8N with Traefik as a reverse proxy
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
    echo "  -d, --detach        Run in detached mode (background)"
    echo "  --build             Build images before starting"
    echo "  --force-recreate    Force recreate containers"
    echo "  --no-deps           Don't start linked services"
    echo "  --staging           Use Let's Encrypt staging server"
    echo "Examples:"
    echo "  $0                  # Start with logs"
    echo "  $0 -d               # Start in background"
    echo "  $0 --staging -d     # Start with staging SSL in background"
    exit 1
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
    # Check if .env file exists
    if [[ ! -f "$PROJECT_DIR/.env" ]]; then
        error ".env file not found. Please create it first."
    # Check if traefik configuration exists
    if [[ ! -f "$PROJECT_DIR/traefik/traefik.yml" ]]; then
        error "Traefik configuration not found. Please ensure traefik/traefik.yml exists."
    log "Prerequisites check passed"
# Load environment variables
load_environment() {
    log "Loading environment variables..."
    if [[ -f "$PROJECT_DIR/.env" ]]; then
    # shellcheck source=/dev/null
        source "$PROJECT_DIR/.env"
        log "Environment variables loaded"
    else
        error ".env file not found"
# Create necessary directories
create_directories() {
    log "Creating necessary directories..."
    # Create data directories
    mkdir -p "$PROJECT_DIR/data/n8n"
    mkdir -p "$PROJECT_DIR/data/postgres"
    mkdir -p "$PROJECT_DIR/data/redis"
    mkdir -p "$PROJECT_DIR/data/traefik/acme"
    # Create traefik directories
    mkdir -p "$PROJECT_DIR/traefik/dynamic"
    mkdir -p "$PROJECT_DIR/traefik/logs"
    log "Directories created"
# Set proper permissions
set_permissions() {
    log "Setting proper permissions..."
    # Set permissions for data directories
    chmod -R 755 "$PROJECT_DIR/data" 2>/dev/null || true
    # Set permissions for Traefik ACME directory (more restrictive)
    chmod 600 "$PROJECT_DIR/data/traefik/acme" 2>/dev/null || true
    # Create acme.json file with proper permissions if it doesn't exist
    if [[ ! -f "$PROJECT_DIR/data/traefik/acme/acme.json" ]]; then
        touch "$PROJECT_DIR/data/traefik/acme/acme.json"
        chmod 600 "$PROJECT_DIR/data/traefik/acme/acme.json"
    # Set permissions for traefik config files
    chmod 644 "$PROJECT_DIR/traefik/traefik.yml" 2>/dev/null || true
    chmod 644 "$PROJECT_DIR/traefik/dynamic"/*.yml 2>/dev/null || true
    log "Permissions set"
# Setup SSL configuration
setup_ssl_config() {
    local use_staging="$1"
    log "Setting up SSL configuration..."
    # Load environment variables
    source "$PROJECT_DIR/.env" 2>/dev/null || true
    local ssl_email=${SSL_EMAIL:-"admin@localhost"}
    if [[ "$use_staging" == "true" ]]; then
        warning "Using Let's Encrypt STAGING server - certificates will not be trusted!"
        info "Using Let's Encrypt PRODUCTION server"
    # Update traefik.yml with the correct ACME server
    if [[ -f "$PROJECT_DIR/traefik/traefik.yml" ]]; then
        # Create a backup
        cp "$PROJECT_DIR/traefik/traefik.yml" "$PROJECT_DIR/traefik/traefik.yml.backup"
        
        # Update the configuration
        sed -i "s|email: .*|email: $ssl_email|g" "$PROJECT_DIR/traefik/traefik.yml"
        if [[ "$use_staging" == "true" ]]; then
            # Ensure staging server is uncommented
            sed -i "s|# caServer: https://acme-staging-v02.api.letsencrypt.org/directory|caServer: https://acme-staging-v02.api.letsencrypt.org/directory|g" "$PROJECT_DIR/traefik/traefik.yml"
        else
            # Comment out staging server line
            sed -i "s|caServer: https://acme-staging-v02.api.letsencrypt.org/directory|# caServer: https://acme-staging-v02.api.letsencrypt.org/directory|g" "$PROJECT_DIR/traefik/traefik.yml"
        fi
        log "SSL configuration updated"
# Check if services are already running
check_running_services() {
    log "Checking for running services..."
    local running_containers
    running_containers=$(docker compose -f "$PROJECT_DIR/docker-compose.yml" -f "$PROJECT_DIR/docker-compose.traefik.yml" ps -q 2>/dev/null | wc -l)
    if [[ $running_containers -gt 0 ]]; then
        warning "Some services are already running"
        info "Running containers: $running_containers"
        # Show running services
        docker compose -f "$PROJECT_DIR/docker-compose.yml" -f "$PROJECT_DIR/docker-compose.traefik.yml" ps
        echo ""
        read -p "Do you want to restart the services? (y/n): " -r
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log "Stopping existing services..."
            docker compose -f "$PROJECT_DIR/docker-compose.yml" -f "$PROJECT_DIR/docker-compose.traefik.yml" down
            log "Keeping existing services running"
            exit 0
# Start services
start_services() {
    local detach="$1"
    local build="$2"
    local force_recreate="$3"
    local no_deps="$4"
    log "Starting N8N with Traefik proxy..."
    local compose_args=()
    # Add build flag if requested
    if [[ "$build" == "true" ]]; then
        compose_args+=("--build")
    # Add force recreate flag if requested
    if [[ "$force_recreate" == "true" ]]; then
        compose_args+=("--force-recreate")
    # Add no deps flag if requested
    if [[ "$no_deps" == "true" ]]; then
        compose_args+=("--no-deps")
    # Start services
    if [[ "$detach" == "true" ]]; then
        docker compose -f "$PROJECT_DIR/docker-compose.yml" -f "$PROJECT_DIR/docker-compose.traefik.yml" up -d "${compose_args[@]}"
        log "Services started in background"
        # Wait a moment for services to initialize
        sleep 5
        # Show service status
        show_service_status
        show_access_info
        log "Starting services with logs (Press Ctrl+C to stop)..."
        docker compose -f "$PROJECT_DIR/docker-compose.yml" -f "$PROJECT_DIR/docker-compose.traefik.yml" up "${compose_args[@]}"
# Show service status
show_service_status() {
    log "Service Status:"
    docker compose -f "$PROJECT_DIR/docker-compose.yml" -f "$PROJECT_DIR/docker-compose.traefik.yml" ps
    log "Health Status:"
    # Check individual service health
    local services=("n8n" "postgres" "redis" "traefik")
    for service in "${services[@]}"; do
        local container_name="n8n-$service"
        if [[ "$service" == "n8n" ]]; then
            container_name="n8n"
        local health_status
        health_status=$(docker inspect --format='{{.State.Health.Status}}' "$container_name" 2>/dev/null || echo "no-healthcheck")
        case "$health_status" in
            "healthy")
                echo -e "  ✅ $service: ${GREEN}healthy${NC}"
                ;;
            "unhealthy")
                echo -e "  ❌ $service: ${RED}unhealthy${NC}"
            "starting")
                echo -e "  🔄 $service: ${YELLOW}starting${NC}"
            "no-healthcheck")
                echo -e "  ⚪ $service: ${BLUE}no healthcheck${NC}"
            *)
                echo -e "  ❓ $service: ${YELLOW}unknown${NC}"
        esac
    done
# Show access information
show_access_info() {
    log "Access Information:"
    # Load environment variables for display
    local n8n_host=${N8N_HOST:-localhost}
    local traefik_dashboard_host=${TRAEFIK_DASHBOARD_HOST:-traefik.localhost}
    echo "  🌐 N8N Web Interface:"
    echo "    HTTP:  http://$n8n_host"
    echo "    HTTPS: https://$n8n_host"
    echo "  📊 Traefik Dashboard:"
    echo "    URL: http://$traefik_dashboard_host:8080"
    echo "    API: http://localhost:8080/api/rawdata"
    echo "  🔒 SSL Certificates:"
    echo "    ACME Data: $PROJECT_DIR/data/traefik/acme/acme.json"
    echo "    Status: Check Traefik dashboard for certificate status"
    echo "  📁 Important Paths:"
    echo "    Project Directory: $PROJECT_DIR"
    echo "    Data Directory: $PROJECT_DIR/data"
    echo "    Traefik Config: $PROJECT_DIR/traefik"
    echo "    Traefik Logs: $PROJECT_DIR/traefik/logs"
    log "Useful Commands:"
    echo "  View logs:     docker compose -f docker-compose.yml -f docker-compose.traefik.yml logs -f"
    echo "  Stop services: docker compose -f docker-compose.yml -f docker-compose.traefik.yml down"
    echo "  Restart:       docker compose -f docker-compose.yml -f docker-compose.traefik.yml restart"
    echo "  Traefik logs:  docker logs n8n-traefik -f"
    warning "Note: If using custom domains, make sure they point to this server's IP address"
    warning "SSL certificates may take a few minutes to be issued by Let's Encrypt"
# Main function
main() {
    local detach=false
    local build=false
    local force_recreate=false
    local no_deps=false
    local use_staging=false
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
            -d|--detach)
                detach=true
                shift
            --build)
                build=true
            --force-recreate)
                force_recreate=true
            --no-deps)
                no_deps=true
            --staging)
                use_staging=true
            -*)
                error "Unknown option: $1"
                error "Unknown argument: $1"
    check_prerequisites
    load_environment
    create_directories
    set_permissions
    setup_ssl_config "$use_staging"
    check_running_services
    start_services "$detach" "$build" "$force_recreate" "$no_deps"
    if [[ "$detach" == "false" ]]; then
        log "Services stopped"
# Change to project directory
cd "$PROJECT_DIR"
# Run main function
main "$@"

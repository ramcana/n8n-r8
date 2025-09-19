#!/bin/bash

# N8N Direct Access Start Script
# This script starts N8N with direct port access (development mode)

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
    echo "  --port PORT         Override N8N port (default: 5678)"
    echo ""
    echo "Examples:"
    echo "  $0                  # Start with logs on port 5678"
    echo "  $0 -d               # Start in background"
    echo "  $0 --port 8080 -d   # Start on port 8080 in background"
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
    
    log "Prerequisites check passed"
}

# Validate environment variables
validate_environment() {
    log "Validating environment configuration..."
    
    # Load environment variables
    if [[ -f "$PROJECT_DIR/.env" ]]; then
        source "$PROJECT_DIR/.env"
    fi
    
    # Check required variables
    local required_vars=(
        "POSTGRES_DB"
        "POSTGRES_USER" 
        "POSTGRES_PASSWORD"
        "REDIS_PASSWORD"
        "N8N_ENCRYPTION_KEY"
        "N8N_JWT_SECRET"
    )
    
    local missing_vars=()
    
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            missing_vars+=("$var")
        fi
    done
    
    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        error "Missing required environment variables:"
        for var in "${missing_vars[@]}"; do
            echo "  - $var"
        done
        echo ""
        echo "Please update your .env file with the missing variables."
        exit 1
    fi
    
    # Validate encryption key length
    if [[ ${#N8N_ENCRYPTION_KEY} -lt 32 ]]; then
        error "N8N_ENCRYPTION_KEY must be at least 32 characters long"
        exit 1
    fi
    
    # Check for default passwords
    local default_passwords=(
        "changeme123!"
        "password"
        "admin"
        "123456"
    )
    
    for default_pass in "${default_passwords[@]}"; do
        if [[ "${POSTGRES_PASSWORD:-}" == "$default_pass" ]] || \
           [[ "${REDIS_PASSWORD:-}" == "$default_pass" ]] || \
           [[ "${N8N_BASIC_AUTH_PASSWORD:-}" == "$default_pass" ]]; then
            warning "Default password detected. Please change default passwords in .env file."
            break
        fi
    done
    
    log "Environment validation passed"
}

# Create necessary directories
create_directories() {
    log "Creating necessary directories..."
    
    # Create data directories
    mkdir -p "$PROJECT_DIR/data/n8n"
    mkdir -p "$PROJECT_DIR/data/postgres"
    mkdir -p "$PROJECT_DIR/data/redis"
    
    # Create log directories
    mkdir -p "$PROJECT_DIR/logs"
    
    log "Directories created"
}

# Set proper permissions
set_permissions() {
    log "Setting proper permissions..."
    
    # Set permissions for data directories
    chmod -R 755 "$PROJECT_DIR/data" 2>/dev/null || true
    
    log "Permissions set"
}

# Check for port conflicts
check_port_conflicts() {
    local port="$1"
    
    log "Checking for port conflicts on port $port..."
    
    # Check if port is already in use
    if netstat -tuln 2>/dev/null | grep -q ":$port " || \
       ss -tuln 2>/dev/null | grep -q ":$port " || \
       lsof -i ":$port" >/dev/null 2>&1; then
        error "Port $port is already in use"
        echo ""
        echo "Processes using port $port:"
        lsof -i ":$port" 2>/dev/null || netstat -tulpn 2>/dev/null | grep ":$port " || echo "Unable to determine process"
        echo ""
        echo "Please:"
        echo "1. Stop the service using port $port, or"
        echo "2. Use a different port with --port option, or"
        echo "3. Use a proxy configuration instead"
        exit 1
    fi
    
    log "Port $port is available"
}

# Check if services are already running
check_running_services() {
    log "Checking for running services..."
    
    local running_containers=$(docker compose -f "$PROJECT_DIR/docker-compose.yml" ps -q 2>/dev/null | wc -l)
    
    if [[ $running_containers -gt 0 ]]; then
        warning "Some services are already running"
        info "Running containers: $running_containers"
        
        # Show running services
        docker compose -f "$PROJECT_DIR/docker-compose.yml" ps
        
        echo ""
        read -p "Do you want to restart the services? (y/n): " -r
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log "Stopping existing services..."
            docker compose -f "$PROJECT_DIR/docker-compose.yml" down
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
    local custom_port="$5"
    
    log "Starting N8N with direct access..."
    
    local compose_args=()
    local env_args=()
    
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
    
    # Set custom port if specified
    if [[ -n "$custom_port" ]]; then
        env_args+=("N8N_PORT=$custom_port")
        log "Using custom port: $custom_port"
    fi
    
    # Create temporary compose file with port exposure
    local temp_compose="$PROJECT_DIR/docker-compose.direct.yml"
    create_direct_compose_override "$temp_compose" "${custom_port:-5678}"
    
    # Start services
    if [[ "$detach" == "true" ]]; then
        env "${env_args[@]}" docker compose -f "$PROJECT_DIR/docker-compose.yml" -f "$temp_compose" up -d "${compose_args[@]}"
        
        log "Services started in background"
        
        # Wait a moment for services to initialize
        sleep 5
        
        # Show service status
        show_service_status "$temp_compose" "${custom_port:-5678}"
        show_access_info "${custom_port:-5678}"
        
        # Cleanup temporary file
        rm -f "$temp_compose"
    else
        log "Starting services with logs (Press Ctrl+C to stop)..."
        env "${env_args[@]}" docker compose -f "$PROJECT_DIR/docker-compose.yml" -f "$temp_compose" up "${compose_args[@]}"
        
        # Cleanup temporary file on exit
        rm -f "$temp_compose"
    fi
}

# Create direct access compose override
create_direct_compose_override() {
    local temp_file="$1"
    local port="$2"
    
    cat > "$temp_file" << EOF
version: '3.8'

services:
  n8n:
    ports:
      - "${port}:5678"
    environment:
      - N8N_PORT=5678
      - N8N_HOST=localhost
      - N8N_PROTOCOL=http
      - WEBHOOK_URL=http://localhost:${port}/
    labels:
      - "com.docker.compose.service=n8n-direct"
EOF
}

# Show service status
show_service_status() {
    local compose_file="$1"
    local port="$2"
    
    log "Service Status:"
    docker compose -f "$PROJECT_DIR/docker-compose.yml" -f "$compose_file" ps
    
    echo ""
    log "Health Status:"
    
    # Check individual service health
    local services=("n8n" "n8n-postgres" "n8n-redis")
    
    for service in "${services[@]}"; do
        local health_status=$(docker inspect --format='{{.State.Health.Status}}' "$service" 2>/dev/null || echo "no-healthcheck")
        
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
    
    # Test N8N endpoint
    echo ""
    log "Testing N8N endpoint..."
    sleep 3
    
    if curl -s -f --max-time 10 "http://localhost:$port/healthz" >/dev/null 2>&1; then
        echo -e "  ✅ N8N endpoint: ${GREEN}responding${NC}"
    else
        echo -e "  ⚠️  N8N endpoint: ${YELLOW}not ready yet (may take a moment)${NC}"
    fi
}

# Show access information
show_access_info() {
    local port="$1"
    
    echo ""
    log "Access Information:"
    
    # Load environment variables for display
    source "$PROJECT_DIR/.env" 2>/dev/null || true
    
    echo "  🌐 N8N Web Interface:"
    echo "    URL: http://localhost:$port"
    echo "    Health Check: http://localhost:$port/healthz"
    
    if [[ "${N8N_BASIC_AUTH_ACTIVE:-true}" == "true" ]]; then
        echo "    Login: ${N8N_BASIC_AUTH_USER:-admin} / ${N8N_BASIC_AUTH_PASSWORD:-changeme123!}"
    fi
    
    echo ""
    echo "  📊 Service URLs:"
    echo "    PostgreSQL: localhost:5432 (internal only)"
    echo "    Redis: localhost:6379 (internal only)"
    
    echo ""
    echo "  📁 Important Paths:"
    echo "    Project Directory: $PROJECT_DIR"
    echo "    Data Directory: $PROJECT_DIR/data"
    echo "    Logs Directory: $PROJECT_DIR/logs"
    
    echo ""
    log "Useful Commands:"
    echo "  View logs:     docker compose logs -f"
    echo "  Stop services: docker compose down"
    echo "  Restart:       docker compose restart"
    echo "  Shell access:  docker compose exec n8n /bin/sh"
    
    echo ""
    warning "Development Mode Active:"
    echo "  - N8N is directly accessible on port $port"
    echo "  - No reverse proxy or SSL termination"
    echo "  - Suitable for development and testing only"
    echo "  - For production, use nginx or traefik proxy scripts"
}

# Perform health checks
perform_health_checks() {
    local port="$1"
    local max_attempts=30
    local attempt=0
    
    log "Performing health checks..."
    
    # Wait for N8N to be ready
    while [[ $attempt -lt $max_attempts ]]; do
        if curl -s -f --max-time 5 "http://localhost:$port/healthz" >/dev/null 2>&1; then
            log "N8N is ready and responding"
            return 0
        fi
        
        attempt=$((attempt + 1))
        echo -n "."
        sleep 2
    done
    
    echo ""
    warning "N8N health check timed out after $((max_attempts * 2)) seconds"
    warning "Service may still be starting up. Check logs with: docker compose logs -f n8n"
    return 1
}

# Main function
main() {
    local detach=false
    local build=false
    local force_recreate=false
    local no_deps=false
    local custom_port=""
    
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
            --port)
                custom_port="$2"
                shift 2
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
    
    # Validate port if specified
    if [[ -n "$custom_port" ]]; then
        if ! [[ "$custom_port" =~ ^[0-9]+$ ]] || [[ "$custom_port" -lt 1024 ]] || [[ "$custom_port" -gt 65535 ]]; then
            error "Invalid port: $custom_port. Please use a port between 1024 and 65535."
            exit 1
        fi
    fi
    
    local port="${custom_port:-5678}"
    
    log "Starting N8N in direct access mode..."
    log "Port: $port, Detached: $detach"
    
    check_prerequisites
    validate_environment
    create_directories
    set_permissions
    check_port_conflicts "$port"
    check_running_services
    start_services "$detach" "$build" "$force_recreate" "$no_deps" "$custom_port"
    
    if [[ "$detach" == "true" ]]; then
        # Perform health checks in background mode
        perform_health_checks "$port" || true
    fi
    
    if [[ "$detach" == "false" ]]; then
        log "Services stopped"
    fi
}

# Change to project directory
cd "$PROJECT_DIR"

# Run main function
main "$@"

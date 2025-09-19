#!/bin/bash

# N8N-R8 Custom Nodes Development Start Script
# This script starts N8N with custom nodes development environment

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
NODES_DIR="$PROJECT_DIR/nodes"

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
    echo "Usage: $0 [OPTIONS] [MODE]"
    echo ""
    echo "Modes:"
    echo "  dev         Start with development container (watch mode)"
    echo "  build       Build nodes and start N8N"
    echo "  production  Build for production and start N8N"
    echo ""
    echo "Options:"
    echo "  -h, --help          Show this help message"
    echo "  -d, --detach        Run in detached mode (background)"
    echo "  --clean             Clean build before starting"
    echo "  --no-build          Skip building nodes"
    echo "  --proxy TYPE        Use proxy (nginx/traefik)"
    echo ""
    echo "Examples:"
    echo "  $0 dev              # Start development environment"
    echo "  $0 build -d         # Build and start in background"
    echo "  $0 --proxy nginx    # Start with nginx proxy"
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
    
    # Check if nodes directory exists
    if [[ ! -d "$NODES_DIR" ]]; then
        error "Nodes directory not found: $NODES_DIR"
        exit 1
    fi
    
    # Check if package.json exists
    if [[ ! -f "$NODES_DIR/package.json" ]]; then
        error "package.json not found in nodes directory"
        exit 1
    fi
    
    log "Prerequisites check passed"
}

# Setup nodes development environment
setup_nodes_environment() {
    log "Setting up nodes development environment..."
    
    cd "$NODES_DIR"
    
    # Create necessary directories
    mkdir -p src/nodes src/credentials dist assets tests
    
    # Install dependencies if node_modules doesn't exist
    if [[ ! -d "node_modules" ]]; then
        log "Installing node dependencies..."
        npm install
    fi
    
    # Create assets directory for icons
    mkdir -p assets/icons
    
    log "Nodes environment setup completed"
}

# Build custom nodes
build_nodes() {
    local production="$1"
    local clean="$2"
    
    log "Building custom nodes..."
    
    cd "$NODES_DIR"
    
    # Clean if requested
    if [[ "$clean" == "true" ]]; then
        log "Cleaning previous build..."
        npm run clean 2>/dev/null || rm -rf dist/
    fi
    
    # Build nodes
    if [[ "$production" == "true" ]]; then
        log "Building for production..."
        NODE_ENV=production npm run build
    else
        log "Building for development..."
        npm run build
    fi
    
    # Verify build
    if [[ ! -d "dist" ]] || [[ -z "$(ls -A dist 2>/dev/null)" ]]; then
        error "Build failed - no output in dist directory"
        exit 1
    fi
    
    local node_count=$(find dist -name "*.node.js" 2>/dev/null | wc -l)
    local credential_count=$(find dist -name "*.credential.js" 2>/dev/null | wc -l)
    
    log "Build completed: $node_count node(s), $credential_count credential(s)"
}

# Start development environment
start_development() {
    local detach="$1"
    
    log "Starting custom nodes development environment..."
    
    # Build nodes first
    build_nodes false false
    
    # Start N8N with custom nodes and development container
    local compose_files=("-f" "$PROJECT_DIR/docker-compose.yml" "-f" "$PROJECT_DIR/docker-compose.custom-nodes.yml")
    
    if [[ "$detach" == "true" ]]; then
        docker compose "${compose_files[@]}" --profile dev up -d
        log "Development environment started in background"
        show_development_info
    else
        log "Starting development environment with logs (Press Ctrl+C to stop)..."
        docker compose "${compose_files[@]}" --profile dev up
    fi
}

# Start production environment
start_production() {
    local detach="$1"
    local proxy="$2"
    local no_build="$3"
    
    log "Starting production environment with custom nodes..."
    
    # Build nodes for production
    if [[ "$no_build" != "true" ]]; then
        build_nodes true false
    fi
    
    # Prepare compose files
    local compose_files=("-f" "$PROJECT_DIR/docker-compose.yml" "-f" "$PROJECT_DIR/docker-compose.custom-nodes.yml")
    
    # Add proxy if specified
    if [[ -n "$proxy" ]]; then
        case "$proxy" in
            "nginx")
                compose_files+=("-f" "$PROJECT_DIR/docker-compose.nginx.yml")
                ;;
            "traefik")
                compose_files+=("-f" "$PROJECT_DIR/docker-compose.traefik.yml")
                ;;
            *)
                error "Unknown proxy type: $proxy"
                exit 1
                ;;
        esac
    fi
    
    if [[ "$detach" == "true" ]]; then
        docker compose "${compose_files[@]}" up -d
        log "Production environment started in background"
        show_production_info "$proxy"
    else
        log "Starting production environment with logs (Press Ctrl+C to stop)..."
        docker compose "${compose_files[@]}" up
    fi
}

# Show development info
show_development_info() {
    echo ""
    log "Development Environment Information:"
    echo "  🌐 N8N Web Interface: http://localhost:5678"
    echo "  🔧 Development Container: n8n-node-dev (watch mode)"
    echo "  📁 Custom Nodes: $NODES_DIR/dist"
    echo "  📊 Node Build Status: $(find "$NODES_DIR/dist" -name "*.node.js" 2>/dev/null | wc -l) node(s) built"
    echo ""
    echo "  📋 Development Commands:"
    echo "    View N8N logs:     docker logs n8n -f"
    echo "    View dev logs:     docker logs n8n-node-dev -f"
    echo "    Rebuild nodes:     docker exec n8n-node-dev npm run build"
    echo "    Run tests:         docker exec n8n-node-dev npm test"
    echo "    Stop environment:  docker compose -f docker-compose.yml -f docker-compose.custom-nodes.yml --profile dev down"
    echo ""
    warning "Development Mode Active:"
    echo "  - Custom nodes are automatically rebuilt on file changes"
    echo "  - N8N container will restart when nodes are rebuilt"
    echo "  - Check the development container logs for build status"
}

# Show production info
show_production_info() {
    local proxy="$1"
    
    echo ""
    log "Production Environment Information:"
    
    if [[ -n "$proxy" ]]; then
        case "$proxy" in
            "nginx")
                echo "  🌐 N8N Web Interface: http://localhost (via Nginx)"
                echo "  🔒 SSL: Configure certificates in nginx/ssl/"
                ;;
            "traefik")
                echo "  🌐 N8N Web Interface: http://localhost (via Traefik)"
                echo "  📊 Traefik Dashboard: http://localhost:8080"
                echo "  🔒 SSL: Automatic Let's Encrypt certificates"
                ;;
        esac
    else
        echo "  🌐 N8N Web Interface: http://localhost:5678"
    fi
    
    echo "  📁 Custom Nodes: Mounted from $NODES_DIR/dist"
    echo "  📊 Node Status: $(find "$NODES_DIR/dist" -name "*.node.js" 2>/dev/null | wc -l) node(s) available"
    echo ""
    echo "  📋 Management Commands:"
    echo "    View logs:         docker compose logs -f"
    echo "    Restart N8N:       docker compose restart n8n"
    echo "    Update nodes:      ./scripts/start-custom-nodes.sh build -d"
    echo "    Stop environment:  docker compose down"
}

# Validate custom nodes
validate_nodes() {
    log "Validating custom nodes..."
    
    cd "$NODES_DIR"
    
    # Run validation
    if [[ -x "scripts/build.sh" ]]; then
        ./scripts/build.sh validate
    else
        npm run validate 2>/dev/null || {
            npm run lint
            npm run test
            npm run build
        }
    fi
    
    log "Node validation completed"
}

# Main function
main() {
    local mode="build"
    local detach=false
    local clean=false
    local no_build=false
    local proxy=""
    
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
            --clean)
                clean=true
                shift
                ;;
            --no-build)
                no_build=true
                shift
                ;;
            --proxy)
                proxy="$2"
                shift 2
                ;;
            dev|build|production|validate)
                mode="$1"
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
    
    log "N8N-R8 Custom Nodes Development Environment"
    log "==========================================="
    
    # Change to project directory
    cd "$PROJECT_DIR"
    
    check_prerequisites
    setup_nodes_environment
    
    # Execute based on mode
    case "$mode" in
        "dev")
            start_development "$detach"
            ;;
        "build")
            start_production "$detach" "$proxy" "$no_build"
            ;;
        "production")
            start_production "$detach" "$proxy" "$no_build"
            ;;
        "validate")
            validate_nodes
            ;;
        *)
            error "Unknown mode: $mode"
            usage
            ;;
    esac
}

# Run main function
main "$@"

#!/bin/bash

# N8N Start with Custom Nodes Script
# This script ensures custom nodes are built before starting N8N
set -euo pipefail
# Configuration
SCRIPT_DIR="$(cd "$(dirname "${1}")" && pwd)"
PROJECT_DIR="$(dirname "${1}")"
NODES_DIR="${1}/nodes"
# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'
# Logging functions
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] ${NC}$1"
}
error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: ${NC}$1" >&2
}
warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: ${NC}$1"
}
info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO: ${NC}$1"
}
# Usage function
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Start N8N with custom nodes support"
    echo "Options:"
    echo "  -h, --help          Show this help message"
    echo "  -d, --detach        Run in detached mode"
    echo "  --nginx             Start with Nginx proxy"
    echo "  --traefik           Start with Traefik proxy"
    echo "  --build-only        Only build nodes, don't start N8N"
    echo "  --skip-build        Skip building nodes"
    echo "Examples:"
    echo "  $0                  # Start N8N with custom nodes"
    echo "  $0 -d               # Start in detached mode"
    echo "  $0 --nginx -d       # Start with Nginx proxy in detached mode"
    echo "  $0 --build-only     # Only build custom nodes"
    exit 1
}
# Check if custom nodes directory exists
check_custom_nodes() {
    if [[ ! -d "${1}" ]]; then
        warning "Custom nodes directory not found: ${1}"
        return 1
    fi
    
    if [[ ! -f "${1}/package.json" ]]; then
        warning "No package.json found in custom nodes directory"
        return 1
    fi
    return 0
}

# Build custom nodes
build_custom_nodes() {
    log "Building custom N8N nodes..."
    cd "${1}"
    # Check if build script exists
    if [[ -x "scripts/build.sh" ]]; then
        ./scripts/build.sh build
    else
        # Fallback to npm commands
        if [[ -f "package.json" ]]; then
            npm install
            npm run build
        else
            error "No build script or package.json found"
            return 1
        fi
    fi
    # Verify build output
    if [[ ! -d "dist" ]] || [[ -z "$(ls -A dist 2>/dev/null)" ]]; then
        error "Build failed - no output in dist directory"
        return 1
    fi
    local node_files
    node_files="$(find dist -name "*.node.js" 2>/dev/null | wc -l)"
    local credential_files
    credential_files="$(find dist -name "*.credential.js" 2>/dev/null | wc -l)"
    log "✅ Custom nodes built successfully"
    info "Built ${node_files} node(s) and ${credential_files} credential(s)"
    return 0
}

# Start N8N services
start_n8n() {
    local detach="$1"
    local proxy="$2"
    cd "${PROJECT_DIR}"
    local compose_args="-f docker-compose.yml"
    case "${2}" in
        "nginx")
            compose_args="${compose_args} -f docker-compose.nginx.yml"
            info "Using Nginx proxy configuration"
            ;;
        "traefik")
            compose_args="${compose_args} -f docker-compose.traefik.yml"
            info "Using Traefik proxy configuration"
            ;;
        "")
            info "Using direct access configuration"
            ;;
        *)
            error "Unknown proxy type: ${2}"
            return 1
            ;;
    esac
    if [[ "${1}" == "true" ]]; then
        docker compose "${compose_args}" up -d
        log "✅ N8N started in detached mode"
        
        # Wait for services to be ready
        info "Waiting for services to be ready..."
        sleep 5
        # Show access information
        echo ""
        log "🌐 Access Information:"
        case "${2}" in
            "nginx")
                echo "  N8N Web Interface: http://localhost"
                ;;
            "traefik")
                echo "  N8N Web Interface: http://localhost"
                echo "  Traefik Dashboard: http://localhost:8080"
                ;;
            *)
                echo "  N8N Web Interface: http://localhost:5678"
                ;;
        esac
        if [[ -d "${NODES_DIR}/dist" ]]; then
            echo "  Custom Nodes: Mounted from ${NODES_DIR}/dist"
        fi
    else
        docker compose "${compose_args}" up
    fi
    return 0
}

# Main function
main() {
    local detach=false
    local proxy=""
    local build_only=false
    local skip_build=false
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
            --nginx)
                proxy="nginx"
                shift
                ;;
            --traefik)
                proxy="traefik"
                shift
                ;;
            --build-only)
                build_only=true
                shift
                ;;
            --skip-build)
                skip_build=true
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
    log "N8N Custom Nodes Startup"
    log "========================"
    # Check if custom nodes exist
    if check_custom_nodes "${NODES_DIR}"; then
        info "Custom nodes directory found: ${NODES_DIR}"
        # Build custom nodes unless skipped
        if [[ "${skip_build}" != "true" ]]; then
            if ! build_custom_nodes "${NODES_DIR}"; then
                error "Failed to build custom nodes"
                exit 1
            fi
        else
            info "Skipping custom nodes build"
        fi
        # Exit if build-only mode
        if [[ "${build_only}" == "true" ]]; then
            log "Build completed. Exiting (build-only mode)"
            exit 0
        fi
    else
        warning "No custom nodes found - starting N8N without custom nodes"
        if [[ "${build_only}" == "true" ]]; then
            error "No custom nodes to build"
            exit 1
        fi
    fi
    # Start N8N
    if ! start_n8n "${detach}" "${proxy}"; then
        error "Failed to start N8N"
        exit 1
    fi
}

# Run main function
main "$@"

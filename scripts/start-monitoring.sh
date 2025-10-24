#!/bin/bash

# N8N-R8 Monitoring Stack Starter
# Starts various monitoring configurations for N8N deployment

set -euo pipefail

# Script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
MONITORING_DIR="$PROJECT_DIR/monitoring"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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
    echo "Usage: $0 [OPTIONS] [MODE]"
    echo ""
    echo "Modes:"
    echo "  basic    - Start basic script-based monitoring (default)"
    echo "  minimal  - Start minimal Docker monitoring (Prometheus + Node Exporter)"
    echo "  full     - Start full monitoring stack (Grafana + Prometheus + Alertmanager)"
    echo "  stop     - Stop all monitoring services"
    echo ""
    echo "Options:"
    echo "  -h, --help           Show this help message"
    echo "  -d, --detach         Run in detached mode (background)"
    echo "  --build              Force rebuild of Docker images"
    echo "  --force-recreate     Force recreate containers"
    echo ""
    echo "Examples:"
    echo "  $0 basic             # Start basic monitoring"
    echo "  $0 full --detach     # Start full stack in background"
    echo "  $0 minimal --build   # Build and start minimal stack"
    exit 1
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check if Docker is running
    if ! docker info >/dev/null 2>&1; then
        error "Docker is not running. Please start Docker first."
    fi
    
    # Check if docker-compose is available
    if ! command -v docker-compose >/dev/null 2>&1 && ! docker compose version >/dev/null 2>&1; then
        error "Docker Compose is not available. Please install Docker Compose."
    fi
    
    # Check if .env file exists
    if [[ ! -f "$PROJECT_DIR/.env" ]]; then
        error ".env file not found. Please create it first."
    fi
    
    log "Prerequisites check passed"
}

# Setup monitoring directories and configuration
setup_monitoring() {
    log "Setting up monitoring directories and configuration..."
    
    # Create necessary directories
    mkdir -p "$MONITORING_DIR/data/prometheus"
    mkdir -p "$MONITORING_DIR/data/grafana"
    mkdir -p "$MONITORING_DIR/data/alertmanager"
    mkdir -p "$MONITORING_DIR/config/grafana/provisioning/datasources"
    mkdir -p "$MONITORING_DIR/config/grafana/provisioning/dashboards"
    mkdir -p "$MONITORING_DIR/logs"
    
    # Create Grafana configuration if it doesn't exist
    if [[ ! -f "$MONITORING_DIR/config/grafana/provisioning/datasources/prometheus.yml" ]]; then
        create_grafana_datasource_config
    fi
    
    if [[ ! -f "$MONITORING_DIR/config/grafana/provisioning/dashboards/default.yml" ]]; then
        create_grafana_dashboard_config
    fi
    
    log "Monitoring setup completed"
}

# Create Grafana datasource configuration
create_grafana_datasource_config() {
    cat > "$MONITORING_DIR/config/grafana/provisioning/datasources/prometheus.yml" << 'DATASOURCE_EOF'
apiVersion: 1
datasources:
  - name: Prometheus
    type: prometheus
    url: http://prometheus:9090
    isDefault: true
    access: proxy
DATASOURCE_EOF
}

# Create Grafana dashboard configuration
create_grafana_dashboard_config() {
    cat > "$MONITORING_DIR/config/grafana/provisioning/dashboards/default.yml" << 'DASHBOARD_EOF'
providers:
  - name: 'default'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /var/lib/grafana/dashboards
DASHBOARD_EOF
}

# Start basic monitoring (script-based)
start_basic_monitoring() {
    local detach="$1"
    log "Starting basic monitoring..."
    
    # Make monitoring scripts executable
    chmod +x "$MONITORING_DIR/scripts/monitor.sh" 2>/dev/null || true
    chmod +x "$MONITORING_DIR/scripts/disk-monitor.sh" 2>/dev/null || true
    
    if [[ "$detach" == "true" ]]; then
        log "Starting monitoring daemon..."
        nohup "$MONITORING_DIR/scripts/monitor.sh" monitor -d > "$MONITORING_DIR/logs/monitor-daemon.log" 2>&1 || true &
        log "Basic monitoring started in background"
        show_basic_monitoring_info
    else
        log "Starting monitoring with logs (Press Ctrl+C to stop)..."
        "$MONITORING_DIR/scripts/monitor.sh" monitor 2>/dev/null || log "Monitor script not available"
    fi
}

# Start minimal monitoring stack
start_minimal_monitoring() {
    local detach="$1"
    local build="$2"
    local force_recreate="$3"
    
    log "Starting minimal monitoring stack..."
    
    local compose_args=()
    if [[ "$build" == "true" ]]; then
        compose_args+=("--build")
    fi
    if [[ "$force_recreate" == "true" ]]; then
        compose_args+=("--force-recreate")
    fi
    
    local services=("prometheus" "node-exporter")
    
    if [[ "$detach" == "true" ]]; then
        docker compose -f "$PROJECT_DIR/docker-compose.yml" -f "$PROJECT_DIR/docker-compose.monitoring.yml" up -d "${compose_args[@]}" "${services[@]}"
        log "Minimal monitoring stack started in background"
        show_minimal_monitoring_info
    else
        show_minimal_monitoring_info
        docker compose -f "$PROJECT_DIR/docker-compose.yml" -f "$PROJECT_DIR/docker-compose.monitoring.yml" up "${compose_args[@]}" "${services[@]}"
    fi
}

# Start full monitoring stack
start_full_monitoring() {
    local detach="$1"
    local build="$2"
    local force_recreate="$3"
    
    log "Starting full monitoring stack..."
    
    local compose_args=()
    if [[ "$build" == "true" ]]; then
        compose_args+=("--build")
    fi
    if [[ "$force_recreate" == "true" ]]; then
        compose_args+=("--force-recreate")
    fi
    
    if [[ "$detach" == "true" ]]; then
        docker compose -f "$PROJECT_DIR/docker-compose.yml" -f "$PROJECT_DIR/docker-compose.monitoring.yml" up -d "${compose_args[@]}"
        log "Full monitoring stack started in background"
        show_full_monitoring_info
    else
        show_full_monitoring_info
        docker compose -f "$PROJECT_DIR/docker-compose.yml" -f "$PROJECT_DIR/docker-compose.monitoring.yml" up "${compose_args[@]}"
    fi
}

# Show monitoring information
show_basic_monitoring_info() {
    log "Basic Monitoring Information:"
    echo "  📊 Monitor Script: Running in background"
    echo "  📁 Log Files: $MONITORING_DIR/logs/"
    echo "  🔧 Manual check: $MONITORING_DIR/scripts/monitor.sh check"
}

show_minimal_monitoring_info() {
    log "Minimal Monitoring Stack Information:"
    echo "  🔍 Prometheus: http://localhost:9090"
    echo "  📊 Node Exporter: http://localhost:9100"
}

show_full_monitoring_info() {
    log "Full Monitoring Stack Information:"
    echo "  📈 Grafana: http://localhost:3000 (admin/admin)"
    echo "  🔍 Prometheus: http://localhost:9090"
    echo "  🚨 Alertmanager: http://localhost:9093"
}

# Stop monitoring
stop_monitoring() {
    log "Stopping monitoring services..."
    
    # Stop Docker-based monitoring
    docker compose -f "$PROJECT_DIR/docker-compose.yml" -f "$PROJECT_DIR/docker-compose.monitoring.yml" down 2>/dev/null || true
    
    # Stop script-based monitoring
    if [[ -f "$MONITORING_DIR/logs/monitor.pid" ]]; then
        local pid
        pid=$(cat "$MONITORING_DIR/logs/monitor.pid" 2>/dev/null || echo "")
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null || true
            rm -f "$MONITORING_DIR/logs/monitor.pid"
            log "Monitor script stopped"
        fi
    fi
    
    log "All monitoring services stopped"
}

# Main function
main() {
    local mode="basic"
    local detach=false
    local build=false
    local force_recreate=false
    
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
            basic|minimal|full|stop)
                mode="$1"
                shift
                ;;
            -*)
                error "Unknown option: $1"
                ;;
            *)
                error "Unknown argument: $1"
                ;;
        esac
    done
    
    # Handle stop command
    if [[ "$mode" == "stop" ]]; then
        stop_monitoring
        exit 0
    fi
    
    log "Starting N8N-R8 monitoring system (mode: $mode)..."
    check_prerequisites
    setup_monitoring
    
    case "$mode" in
        "basic")
            start_basic_monitoring "$detach"
            ;;
        "minimal")
            start_minimal_monitoring "$detach" "$build" "$force_recreate"
            ;;
        "full")
            start_full_monitoring "$detach" "$build" "$force_recreate"
            ;;
        *)
            error "Unknown mode: $mode"
            ;;
    esac
}

# Change to project directory
cd "$PROJECT_DIR"

# Run main function
main "$@"

#!/bin/bash

# N8N-R8 Monitoring System Start Script
# This script starts the comprehensive monitoring stack

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
MONITORING_DIR="$PROJECT_DIR/monitoring"

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
    echo "  basic       Start basic monitoring (monitor script only)"
    echo "  full        Start full monitoring stack (Prometheus, Grafana, etc.)"
    echo "  minimal     Start minimal monitoring (Prometheus + basic exporters)"
    echo ""
    echo "Options:"
    echo "  -h, --help          Show this help message"
    echo "  -d, --detach        Run in detached mode (background)"
    echo "  --build             Build images before starting"
    echo "  --force-recreate    Force recreate containers"
    echo "  --no-deps           Don't start linked services"
    echo ""
    echo "Examples:"
    echo "  $0 basic            # Start basic monitoring only"
    echo "  $0 full -d          # Start full stack in background"
    echo "  $0 minimal --build  # Build and start minimal stack"
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
    
    # Check if main N8N services are running
    if ! docker compose -f "$PROJECT_DIR/docker-compose.yml" ps | grep -q "Up"; then
        warning "Main N8N services are not running. Starting monitoring anyway..."
    fi
    
    # Check if .env file exists
    if [[ ! -f "$PROJECT_DIR/.env" ]]; then
        error ".env file not found. Please create it first."
        exit 1
    fi
    
    log "Prerequisites check passed"
}

# Create necessary directories and files
setup_monitoring() {
    log "Setting up monitoring directories and configuration..."
    
    # Create data directories for monitoring services
    mkdir -p "$MONITORING_DIR/data/prometheus"
    mkdir -p "$MONITORING_DIR/data/grafana"
    mkdir -p "$MONITORING_DIR/data/alertmanager"
    mkdir -p "$MONITORING_DIR/data/loki"
    mkdir -p "$MONITORING_DIR/data/uptime-kuma"
    mkdir -p "$MONITORING_DIR/logs"
    
    # Create Grafana provisioning directories
    mkdir -p "$MONITORING_DIR/config/grafana/provisioning/datasources"
    mkdir -p "$MONITORING_DIR/config/grafana/provisioning/dashboards"
    mkdir -p "$MONITORING_DIR/config/grafana/dashboards"
    
    # Set proper permissions
    chmod -R 755 "$MONITORING_DIR/data"
    chmod -R 755 "$MONITORING_DIR/logs"
    
    # Create Grafana datasource configuration
    if [[ ! -f "$MONITORING_DIR/config/grafana/provisioning/datasources/prometheus.yml" ]]; then
        create_grafana_datasource_config
    fi
    
    # Create Grafana dashboard configuration
    if [[ ! -f "$MONITORING_DIR/config/grafana/provisioning/dashboards/default.yml" ]]; then
        create_grafana_dashboard_config
    fi
    
    log "Monitoring setup completed"
}

# Create Grafana datasource configuration
create_grafana_datasource_config() {
    cat > "$MONITORING_DIR/config/grafana/provisioning/datasources/prometheus.yml" << 'EOF'
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: true

  - name: Loki
    type: loki
    access: proxy
    url: http://loki:3100
    editable: true
EOF
}

# Create Grafana dashboard configuration
create_grafana_dashboard_config() {
    cat > "$MONITORING_DIR/config/grafana/provisioning/dashboards/default.yml" << 'EOF'
apiVersion: 1

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
EOF
}

# Start basic monitoring (script-based)
start_basic_monitoring() {
    log "Starting basic monitoring..."
    
    # Make monitoring script executable
    chmod +x "$MONITORING_DIR/scripts/monitor.sh"
    chmod +x "$MONITORING_DIR/scripts/disk-monitor.sh"
    
    # Start monitoring script in background
    if [[ "$1" == "true" ]]; then
        log "Starting monitoring daemon..."
        nohup "$MONITORING_DIR/scripts/monitor.sh" monitor -d > "$MONITORING_DIR/logs/monitor-daemon.log" 2>&1 &
        echo $! > "$MONITORING_DIR/logs/monitor.pid"
        
        # Start disk monitoring
        nohup "$MONITORING_DIR/scripts/disk-monitor.sh" monitor > "$MONITORING_DIR/logs/disk-monitor.log" 2>&1 &
        echo $! > "$MONITORING_DIR/logs/disk-monitor.pid"
        
        log "Basic monitoring started in background"
        show_basic_monitoring_info
    else
        log "Starting monitoring with logs (Press Ctrl+C to stop)..."
        "$MONITORING_DIR/scripts/monitor.sh" monitor
    fi
}

# Start minimal monitoring stack
start_minimal_monitoring() {
    local detach="$1"
    local build="$2"
    local force_recreate="$3"
    
    log "Starting minimal monitoring stack..."
    
    local compose_args=()
    local services=("prometheus" "node-exporter" "cadvisor")
    
    if [[ "$build" == "true" ]]; then
        compose_args+=("--build")
    fi
    
    if [[ "$force_recreate" == "true" ]]; then
        compose_args+=("--force-recreate")
    fi
    
    if [[ "$detach" == "true" ]]; then
        docker compose -f "$PROJECT_DIR/docker-compose.yml" -f "$PROJECT_DIR/docker-compose.monitoring.yml" up -d "${compose_args[@]}" "${services[@]}"
        log "Minimal monitoring stack started in background"
        show_minimal_monitoring_info
    else
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
        
        # Wait for services to be ready
        sleep 10
        show_full_monitoring_info
    else
        docker compose -f "$PROJECT_DIR/docker-compose.yml" -f "$PROJECT_DIR/docker-compose.monitoring.yml" up "${compose_args[@]}"
    fi
}

# Show basic monitoring information
show_basic_monitoring_info() {
    echo ""
    log "Basic Monitoring Information:"
    echo "  📊 Monitor Script: Running in background"
    echo "  💾 Disk Monitor: Running in background"
    echo "  📁 Logs Directory: $MONITORING_DIR/logs"
    echo ""
    echo "  📋 Useful Commands:"
    echo "    View monitor logs: tail -f $MONITORING_DIR/logs/monitor-daemon.log"
    echo "    View disk logs:    tail -f $MONITORING_DIR/logs/disk-monitor.log"
    echo "    Stop monitoring:   kill \$(cat $MONITORING_DIR/logs/monitor.pid)"
    echo "    Manual check:      $MONITORING_DIR/scripts/monitor.sh check"
}

# Show minimal monitoring information
show_minimal_monitoring_info() {
    echo ""
    log "Minimal Monitoring Stack Information:"
    echo "  🔍 Prometheus: http://localhost:9090"
    echo "  📊 Node Exporter: http://localhost:9100"
    echo "  🐳 cAdvisor: http://localhost:8080"
    echo ""
    echo "  📋 Useful Commands:"
    echo "    View logs: docker compose -f docker-compose.yml -f docker-compose.monitoring.yml logs -f"
    echo "    Stop stack: docker compose -f docker-compose.yml -f docker-compose.monitoring.yml down"
}

# Show full monitoring information
show_full_monitoring_info() {
    echo ""
    log "Full Monitoring Stack Information:"
    echo "  🔍 Prometheus: http://localhost:9090"
    echo "  📈 Grafana: http://localhost:3000 (admin/admin)"
    echo "  🚨 Alertmanager: http://localhost:9093"
    echo "  📊 Node Exporter: http://localhost:9100"
    echo "  🐳 cAdvisor: http://localhost:8080"
    echo "  📝 Loki: http://localhost:3100"
    echo "  ⏰ Uptime Kuma: http://localhost:3001"
    echo ""
    echo "  📋 Useful Commands:"
    echo "    View all logs: docker compose -f docker-compose.yml -f docker-compose.monitoring.yml logs -f"
    echo "    Stop stack: docker compose -f docker-compose.yml -f docker-compose.monitoring.yml down"
    echo "    Restart service: docker compose -f docker-compose.yml -f docker-compose.monitoring.yml restart <service>"
}

# Stop monitoring
stop_monitoring() {
    log "Stopping monitoring services..."
    
    # Stop Docker-based monitoring
    docker compose -f "$PROJECT_DIR/docker-compose.yml" -f "$PROJECT_DIR/docker-compose.monitoring.yml" down 2>/dev/null || true
    
    # Stop script-based monitoring
    if [[ -f "$MONITORING_DIR/logs/monitor.pid" ]]; then
        local pid=$(cat "$MONITORING_DIR/logs/monitor.pid")
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid"
            rm -f "$MONITORING_DIR/logs/monitor.pid"
            log "Monitor script stopped"
        fi
    fi
    
    if [[ -f "$MONITORING_DIR/logs/disk-monitor.pid" ]]; then
        local pid=$(cat "$MONITORING_DIR/logs/disk-monitor.pid")
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid"
            rm -f "$MONITORING_DIR/logs/disk-monitor.pid"
            log "Disk monitor script stopped"
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
            --no-deps)
                # No dependencies mode - could be implemented
                shift
                ;;
            basic|full|minimal|stop)
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
            usage
            ;;
    esac
}

# Change to project directory
cd "$PROJECT_DIR"

# Run main function
main "$@"

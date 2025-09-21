#!/bin/bash

# Setup Log Rotation for N8N-R8
# This script configures system-wide log rotation for N8N-R8 services
set -euo pipefail
# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
LOGROTATE_CONFIG="$PROJECT_DIR/monitoring/config/logrotate.conf"
# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}
warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1" >&2
}
# Check if running as root
check_permissions() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root to configure system logrotate"
        echo "Usage: sudo $0"
        exit 1
    fi
}
# Install logrotate configuration
install_logrotate_config() {
    log "Installing logrotate configuration..."
    
    if [[ ! -f "$LOGROTATE_CONFIG" ]]; then
        error "Logrotate configuration file not found: $LOGROTATE_CONFIG"
        exit 1
    fi
    # Copy configuration to system logrotate directory
    cp "$LOGROTATE_CONFIG" /etc/logrotate.d/n8n-r8
    # Set proper permissions
    chmod 644 /etc/logrotate.d/n8n-r8
    chown root:root /etc/logrotate.d/n8n-r8
    log "Logrotate configuration installed to /etc/logrotate.d/n8n-r8"
}
# Test logrotate configuration
test_logrotate() {
    log "Testing logrotate configuration..."
    if logrotate -d /etc/logrotate.d/n8n-r8; then
        log "Logrotate configuration test passed"
    else
        error "Logrotate configuration test failed"
    fi
}
# Setup cron job for frequent log rotation (optional)
setup_frequent_rotation() {
    log "Setting up frequent log rotation cron job..."
    # Create a cron job that runs logrotate more frequently for monitoring logs
    cat > /etc/cron.d/n8n-r8-logrotate << 'EOF'
# N8N-R8 Log Rotation - Run every hour for monitoring logs
0 * * * * root /usr/sbin/logrotate /etc/logrotate.d/n8n-r8 >/dev/null 2>&1
EOF
    chmod 644 /etc/cron.d/n8n-r8-logrotate
    log "Frequent log rotation cron job installed"
}
# Main function
main() {
    local install_cron=false
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --with-cron)
                install_cron=true
                shift
                ;;
            -h|--help)
                echo "Usage: sudo $0 [--with-cron]"
                echo ""
                echo "Options:"
                echo "  --with-cron    Install hourly cron job for frequent rotation"
                echo "  -h, --help     Show this help message"
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    log "Setting up log rotation for N8N-R8..."
    check_permissions
    install_logrotate_config
    test_logrotate
    if [[ "$install_cron" == "true" ]]; then
        setup_frequent_rotation
        log "Hourly log rotation is now active via cron"
    fi
    log "Log rotation setup completed successfully!"
    log "Logs will be rotated according to the configuration in /etc/logrotate.d/n8n-r8"
    log "Log rotation will run with the system's daily logrotate (usually via cron.daily)"
}
# Run main function
main "$@"

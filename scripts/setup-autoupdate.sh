#!/bin/bash

# N8N-R8 Autoupdate Setup Script
set -euo pipefail

# Script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging function
log() {
    local level="$1"
    shift
    local message="$*"
    echo -e "[$(date +'%Y-%m-%d %H:%M:%S')] [${level}] ${message}"
}
}

check_root() {
    if [[ $EUID -eq 0 ]]; then
        log "WARN" "Running as root is not recommended"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}
# Check prerequisites
check_prerequisites() {
    log "INFO" "Checking prerequisites..."
}
    
    # Check Docker
    if ! command -v docker >/dev/null 2>&1; then
        log "ERROR" "Docker is not installed or not in PATH"
        exit 1
    fi
    
    # Check Docker Compose
    if ! command -v docker >/dev/null 2>&1 || ! docker compose version >/dev/null 2>&1; then
        log "ERROR" "Docker Compose is not available"
        exit 1
    fi
}
    # Check if in project directory
    if [[ ! -f "$PROJECT_ROOT/docker-compose.yml" ]]; then
        log "ERROR" "Not in N8N-R8 project directory"
        exit 1
    fi
    log "INFO" "Prerequisites check passed"
# Interactive configuration
interactive_config() {
    echo -e "${BLUE}N8N-R8 Autoupdate Setup Wizard${NC}"
    echo -e "${BLUE}================================${NC}"
    echo ""
    # Enable autoupdate
    echo -e "${YELLOW}1. Enable Autoupdate${NC}"
    read -p "Enable autoupdate functionality? (Y/n): " -n 1 -r
    echo
    local enable_autoupdate="true"
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        enable_autoupdate="false"
    fi
}

    if [[ "$enable_autoupdate" == "false" ]]; then
        log "INFO" "Autoupdate disabled. You can enable it later with: make autoupdate-enable"
        return 0
    fi
    # Update method
    echo -e "${YELLOW}2. Choose Update Method${NC}"
    echo "1) Watchtower (Recommended - Fully automated)"
    echo "2) Scheduled Script (More control)"
    echo "3) Manual only (No automation)"
    read -p "Choose update method (1-3): " -n 1 -r
    local update_method="watchtower"
    case $REPLY in
        2) update_method="scheduled" ;;
        3) update_method="manual" ;;
        *) update_method="watchtower" ;;
    esac
    # Backup settings
    echo -e "${YELLOW}3. Backup Settings${NC}"
    read -p "Create backup before updates? (Y/n): " -n 1 -r
    local backup_before_update="true"
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        backup_before_update="false"
    fi
    local rollback_on_failure="true"
    if [[ "$backup_before_update" == "true" ]]; then
        read -p "Rollback on update failure? (Y/n): " -n 1 -r
        if [[ $REPLY =~ ^[Nn]$ ]]; then
            rollback_on_failure="false"
        fi
    else
        rollback_on_failure="false"
    fi
    # Notification settings
    echo -e "${YELLOW}4. Notification Settings${NC}"
    read -p "Enable notifications? (Y/n): " -n 1 -r
    local notification_enabled="true"
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        notification_enabled="false"
    fi
    local slack_webhook=""
    local notification_email=""
    if [[ "$notification_enabled" == "true" ]]; then
        echo ""
        echo "Slack Webhook URL (optional, press Enter to skip):"
        read -r slack_webhook
        
        echo "Notification email (optional, press Enter to skip):"
        read -r notification_email
    fi
    # Schedule settings
    local update_schedule="0 2 * * *"  # Default: daily at 2 AM
    if [[ "$update_method" == "scheduled" ]]; then
        echo -e "${YELLOW}5. Schedule Settings${NC}"
        echo "Current schedule: Daily at 2 AM"
        read -p "Change schedule? (y/N): " -n 1 -r
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "Enter cron schedule (minute hour day month weekday):"
            echo "Examples:"
            echo "  0 2 * * *     - Daily at 2 AM"
            echo "  0 2 * * 0     - Weekly on Sunday at 2 AM"
            echo "  0 2 1 * *     - Monthly on 1st at 2 AM"
            read -r update_schedule
        fi
    fi
    # Apply configuration
    echo -e "${BLUE}Applying configuration...${NC}"
    # Update .env file
    update_env_file "$enable_autoupdate" "$backup_before_update" "$rollback_on_failure" \
                    "$notification_enabled" "$slack_webhook" "$notification_email" \
                    "$update_schedule"
    # Setup based on method
    case "$update_method" in
        "watchtower")
            setup_watchtower
            ;;
        "scheduled")
            setup_scheduled
            ;;
        "manual")
            log "INFO" "Manual update mode configured"
            ;;
            ;;
    esac
    # Show summary
    show_summary "$update_method"
# Update .env file
update_env_file() {
    local enable_autoupdate="$1"
    local backup_before_update="$2"
    local rollback_on_failure="$3"
    local notification_enabled="$4"
    local slack_webhook="$5"
    local notification_email="$6"
    local update_schedule="$7"
    log "INFO" "Updating configuration file..."
    # Backup existing .env
    if [[ -f "$CONFIG_FILE" ]]; then
        cp "$CONFIG_FILE" "${CONFIG_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
    fi
    # Add autoupdate settings to .env
    {
        echo "# Autoupdate Configuration (added by setup script)"
        echo "AUTOUPDATE_ENABLED=$enable_autoupdate"
        echo "BACKUP_BEFORE_UPDATE=$backup_before_update"
        echo "ROLLBACK_ON_FAILURE=$rollback_on_failure"
        echo "NOTIFICATION_ENABLED=$notification_enabled"
        echo "AUTOUPDATE_CRON_SCHEDULE=\"$update_schedule\""
        if [[ -n "$slack_webhook" ]]; then
            echo "SLACK_WEBHOOK_URL=$slack_webhook"
        fi
        if [[ -n "$notification_email" ]]; then
            echo "NOTIFICATION_EMAIL=$notification_email"
        fi
        echo "MAX_BACKUP_RETENTION=7"
        echo "UPDATE_CHECK_INTERVAL=86400"
        echo "WATCHTOWER_POLL_INTERVAL=86400"
        echo "WATCHTOWER_CLEANUP=true"
        echo "WATCHTOWER_ROLLING_RESTART=true"
        echo "WATCHTOWER_SCHEDULE=\"0 0 2 * * *\""
    } >> "$CONFIG_FILE"
# Setup Watchtower
setup_watchtower() {
    log "INFO" "Setting up Watchtower for automated updates..."
    "$SCRIPT_DIR/autoupdate.sh" enable
    log "INFO" "Watchtower setup complete"
    log "INFO" "To start with Watchtower: make start-with-autoupdate"
# Setup scheduled updates
setup_scheduled() {
    log "INFO" "Setting up scheduled updates..."
    # Install cron job
    "$SCRIPT_DIR/autoupdate.sh" schedule
    log "INFO" "Scheduled updates setup complete"
# Show configuration summary
show_summary() {
    local update_method="$1"
    echo -e "${GREEN}✅ Autoupdate Setup Complete!${NC}"
    echo -e "${GREEN}==============================${NC}"
    case "$update_method" in
        "watchtower")
            echo -e "${BLUE}Update Method:${NC} Watchtower (Fully Automated)"
            echo -e "${BLUE}Next Steps:${NC}"
            echo "  1. Start N8N with autoupdate: make start-with-autoupdate"
            echo "  2. Check status: make autoupdate-status"
            echo "  3. View logs: docker compose logs watchtower"
            ;;
        "scheduled")
            echo -e "${BLUE}Update Method:${NC} Scheduled Script"
            echo -e "${BLUE}Next Steps:${NC}"
            echo "  1. Check cron job: crontab -l"
            echo "  2. Manual update: make autoupdate-update"
            echo "  3. View logs: tail -f logs/autoupdate.log"
            ;;
        "manual")
            echo -e "${BLUE}Update Method:${NC} Manual Only"
            echo -e "${BLUE}Next Steps:${NC}"
            echo "  1. Check for updates: make autoupdate-check"
            echo "  2. Perform update: make autoupdate-update"
            echo "  3. Check status: make autoupdate-status"
            ;;
    esac
    echo -e "${BLUE}Useful Commands:${NC}"
    echo "  make autoupdate-status    # Check autoupdate status"
    echo "  make autoupdate-check     # Check for available updates"
    echo "  make autoupdate-update    # Perform manual update"
    echo "  make autoupdate-enable    # Enable autoupdate"
    echo "  make autoupdate-disable   # Disable autoupdate"
    echo -e "${BLUE}Documentation:${NC} docs/autoupdate.md"
# Non-interactive setup
non_interactive_setup() {
    log "INFO" "Setting up autoupdate with default configuration..."
    # Default configuration
    update_env_file "true" "true" "true" "false" "" "" "0 2 * * *"
    log "INFO" "Default autoupdate configuration applied"
    log "INFO" "Use 'make autoupdate-status' to check configuration"
    log "INFO" "Use './scripts/setup-autoupdate.sh --interactive' for custom setup"
# Show usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS]
N8N-R8 Autoupdate Setup Script
OPTIONS:
    -h, --help          Show this help message
    -i, --interactive   Interactive setup wizard (default)
    -d, --default       Use default configuration (non-interactive)
    -s, --status        Show current autoupdate status
EXAMPLES:
    $0                  # Interactive setup
    $0 --interactive    # Interactive setup
    $0 --default        # Default setup
    $0 --status         # Show status
EOF
# Main function
main() {
    local interactive=true
    local show_status=false
    # Parse options
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                exit 0
                ;;
            -i|--interactive)
                interactive=true
                shift
                ;;
            -d|--default)
                interactive=false
                shift
                ;;
            -s|--status)
                show_status=true
                shift
                ;;
            *)
                echo "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
    # Show status if requested
    if [[ "$show_status" == "true" ]]; then
        if [[ -x "$SCRIPT_DIR/autoupdate.sh" ]]; then
            "$SCRIPT_DIR/autoupdate.sh" status
        else
            log "ERROR" "Autoupdate script not found"
            exit 1
        fi
        exit 0
    # Check prerequisites
    check_root
    check_prerequisites
    # Run setup
    if [[ "$interactive" == "true" ]]; then
        interactive_config
    else
        non_interactive_setup
    fi
# Run main function
main "$@"
}

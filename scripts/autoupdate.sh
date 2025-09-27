#!/bin/bash

# N8N-R8 Autoupdate Script
# Automated update system with backup integration and rollback capability
set -euo pipefail

# Script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${0}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Configuration
CONFIG_FILE="${PROJECT_ROOT}/.env"
BACKUP_DIR="${PROJECT_ROOT}/backups"
LOG_DIR="${PROJECT_ROOT}/logs"
LOG_FILE="${PROJECT_ROOT}/autoupdate.log"
LOCK_FILE="/tmp/n8n-autoupdate.lock"

# Default settings
DEFAULT_BACKUP_BEFORE_UPDATE=true
DEFAULT_NOTIFICATION_ENABLED=true
DEFAULT_ROLLBACK_ON_FAILURE=true
DEFAULT_UPDATE_CHECK_INTERVAL=86400  # 24 hours
DEFAULT_MAX_BACKUP_RETENTION=7       # Keep 7 days of backups

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Load configuration
load_config() {
    if [[ -f "${CONFIG_FILE}" ]]; then
        # shellcheck source=/dev/null
        source "${CONFIG_FILE}"
    fi
    
    # Set defaults if not configured
    AUTOUPDATE_ENABLED="${AUTOUPDATE_ENABLED:-${DEFAULT_BACKUP_BEFORE_UPDATE}}"
    BACKUP_BEFORE_UPDATE="${BACKUP_BEFORE_UPDATE:-${DEFAULT_BACKUP_BEFORE_UPDATE}}"
    NOTIFICATION_ENABLED="${NOTIFICATION_ENABLED:-${DEFAULT_NOTIFICATION_ENABLED}}"
    ROLLBACK_ON_FAILURE="${ROLLBACK_ON_FAILURE:-${DEFAULT_ROLLBACK_ON_FAILURE}}"
    UPDATE_CHECK_INTERVAL="${UPDATE_CHECK_INTERVAL:-${DEFAULT_UPDATE_CHECK_INTERVAL}}"
    MAX_BACKUP_RETENTION="${MAX_BACKUP_RETENTION:-${DEFAULT_MAX_BACKUP_RETENTION}}"
    
    # Notification settings
    SLACK_WEBHOOK_URL="${SLACK_WEBHOOK_URL:-}"
    NOTIFICATION_EMAIL="${NOTIFICATION_EMAIL:-}"
    SMTP_SERVER="${SMTP_SERVER:-}"
    SMTP_PORT="${SMTP_PORT:-}"
    SMTP_USER="${SMTP_USER:-}"
    SMTP_PASSWORD="${SMTP_PASSWORD:-}"
}

# Logging function
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    case "${level}" in
        "INFO")
            echo -e "${GREEN}[${timestamp}] ${level}: ${message}${NC}" | tee -a "${LOG_FILE}"
            ;;
        "ERROR")
            echo -e "${RED}[${timestamp}] ${level}: ${message}${NC}" | tee -a "${LOG_FILE}" >&2
            ;;
        "WARN")
            echo -e "${YELLOW}[${timestamp}] ${level}: ${message}${NC}" | tee -a "${LOG_FILE}"
            ;;
        *)
            echo -e "${BLUE}[${timestamp}] ${level}: ${message}${NC}" | tee -a "${LOG_FILE}"
            ;;
    esac
}

# Error handling
error_exit() {
    log "ERROR" "$1"
    cleanup
    exit 1
}

# Cleanup function
cleanup() {
    if [[ -f "${LOCK_FILE}" ]]; then
        rm -f "${LOCK_FILE}"
    fi
}

# Trap for cleanup
trap cleanup EXIT

# Check if script is already running
check_lock() {
    if [[ -f "${LOCK_FILE}" ]]; then
        local running_pid
        running_pid="$(cat "${LOCK_FILE}")"
        if kill -0 "${running_pid}" 2>/dev/null; then
            error_exit "Autoupdate script is already running (PID: ${running_pid})"
        else
            log "WARN" "Stale lock file found, removing..."
            rm -f "${LOCK_FILE}"
        fi
    fi
    echo $$ > "${LOCK_FILE}"
}

# Initialize directories
init_directories() {
    mkdir -p "${BACKUP_DIR}" "${LOG_DIR}"
    chmod 755 "${BACKUP_DIR}" "${LOG_DIR}"
}

# Send notification
send_notification() {
    local subject="$1"
    local message="$2"
    local status="${3:-success}"
    
    if [[ "${NOTIFICATION_ENABLED}" != "true" ]]; then
        return 0
    fi
    
    # Slack notification
    if [[ -n "${SLACK_WEBHOOK_URL}" ]]; then
        local color="good"
        case "${status}" in
            "error") color="danger" ;;
            "warning") color="warning" ;;
            "success") color="good" ;;
            *) color="good" ;;
        esac
        
        local payload
        payload=$(cat <<EOF
{
    "attachments": [
        {
            "color": "${color}",
            "title": "${subject}",
            "text": "${message}",
            "footer": "N8N-R8 Autoupdate",
            "ts": "$(date +%s)"
        }
    ]
}
EOF
)
        curl -X POST -H 'Content-type: application/json' \
             --data "${payload}" \
             "${SLACK_WEBHOOK_URL}" >/dev/null 2>&1 || true
    fi
    
    # Email notification
    if [[ -n "${NOTIFICATION_EMAIL}" && -n "${SMTP_SERVER}" ]]; then
        local email_body="Subject: ${subject}\n\n${message}"
        if command -v sendmail >/dev/null 2>&1; then
            echo -e "${email_body}" | sendmail "${NOTIFICATION_EMAIL}"
        elif command -v mail >/dev/null 2>&1; then
            echo -e "${message}" | mail -s "${subject}" "${NOTIFICATION_EMAIL}"
        fi
    fi
}

# Check for available updates
check_updates() {
    log "INFO" "Checking for available updates..."
    cd "${PROJECT_ROOT}"
    
    # Pull latest images without updating containers
    local updates_available=false
    
    # Check n8n updates
    local current_n8n_id
    current_n8n_id="$(docker images --format "table {{.Repository}}:{{.Tag}}\t{{.ID}}" | grep "n8nio/n8n:latest" | awk '{print $2}' || echo "")"
    docker pull n8nio/n8n:latest >/dev/null 2>&1
    local latest_n8n_id
    latest_n8n_id="$(docker images --format "table {{.Repository}}:{{.Tag}}\t{{.ID}}" | grep "n8nio/n8n:latest" | awk '{print $2}' || echo "")"
    
    if [[ -n "${current_n8n_id}" && -n "${latest_n8n_id}" && "${current_n8n_id}" != "${latest_n8n_id}" ]]; then
        log "INFO" "N8N update available: ${current_n8n_id} -> ${latest_n8n_id}"
        updates_available=true
    fi
    
    # Check PostgreSQL updates
    local current_postgres_id
    current_postgres_id="$(docker images --format "table {{.Repository}}:{{.Tag}}\t{{.ID}}" | grep "postgres:15-alpine" | awk '{print $2}' || echo "")"
    docker pull postgres:15-alpine >/dev/null 2>&1
    local latest_postgres_id
    latest_postgres_id="$(docker images --format "table {{.Repository}}:{{.Tag}}\t{{.ID}}" | grep "postgres:15-alpine" | awk '{print $2}' || echo "")"
    
    if [[ -n "${current_postgres_id}" && -n "${latest_postgres_id}" && "${current_postgres_id}" != "${latest_postgres_id}" ]]; then
        log "INFO" "PostgreSQL update available: ${current_postgres_id} -> ${latest_postgres_id}"
        updates_available=true
    fi
    
    # Check Redis updates
    local current_redis_id
    current_redis_id="$(docker images --format "table {{.Repository}}:{{.Tag}}\t{{.ID}}" | grep "redis:7-alpine" | awk '{print $2}' || echo "")"
    docker pull redis:7-alpine >/dev/null 2>&1
    local latest_redis_id
    latest_redis_id="$(docker images --format "table {{.Repository}}:{{.Tag}}\t{{.ID}}" | grep "redis:7-alpine" | awk '{print $2}' || echo "")"
    
    if [[ -n "${current_redis_id}" && -n "${latest_redis_id}" && "${current_redis_id}" != "${latest_redis_id}" ]]; then
        log "INFO" "Redis update available: ${current_redis_id} -> ${latest_redis_id}"
        updates_available=true
    fi
    
    if [[ "${updates_available}" == "true" ]]; then
        log "INFO" "Updates are available"
        return 0
    else
        log "INFO" "No updates available"
        return 1
    fi
}

# Create backup before update
create_backup() {
    log "INFO" "Creating backup before update..."
    if [[ -x "${SCRIPT_DIR}/backup.sh" ]]; then
        local backup_name
        backup_name="pre-update-$(date +%Y%m%d_%H%M%S)"
        if "${SCRIPT_DIR}/backup.sh" --name "${backup_name}" --quiet; then
            log "INFO" "Backup created successfully: ${backup_name}"
            echo "${backup_name}" > "${PROJECT_ROOT}/.last_pre_update_backup"
            return 0
        else
            error_exit "Failed to create backup before update"
        fi
    else
        error_exit "Backup script not found or not executable"
    fi
}

# Perform update
perform_update() {
    log "INFO" "Starting update process..."
    
    # Stop services gracefully
    log "INFO" "Stopping services..."
    if ! docker compose down --timeout 30; then
        error_exit "Failed to stop services"
    fi
    
    # Start services with new images
    log "INFO" "Starting services with updated images..."
    if ! docker compose up -d; then
        error_exit "Failed to start services after update"
    fi
    
    # Wait for services to be healthy
    log "INFO" "Waiting for services to be healthy..."
    local max_wait=300  # 5 minutes
    local wait_time=0
    while [[ "${wait_time}" -lt "${max_wait}" ]]; do
        if docker compose ps --format json | jq -r '.[].Health' | grep -q "healthy\|starting"; then
            if docker compose ps --format json | jq -r '.[].Health' | grep -v "healthy" | grep -q "unhealthy"; then
                error_exit "Some services are unhealthy after update"
            elif ! docker compose ps --format json | jq -r '.[].Health' | grep -q "starting"; then
                log "INFO" "All services are healthy"
                return 0
            fi
        fi
        sleep 10
        wait_time=$((wait_time + 10))
    done
    error_exit "Services did not become healthy within ${max_wait} seconds"
}

# Rollback to previous backup
rollback() {
    log "WARN" "Rolling back to previous backup..."
    if [[ ! -f "${PROJECT_ROOT}/.last_pre_update_backup" ]]; then
        error_exit "No pre-update backup found for rollback"
    fi
    local backup_name
    backup_name="$(cat "${PROJECT_ROOT}/.last_pre_update_backup")"
    if [[ -x "${SCRIPT_DIR}/restore.sh" ]]; then
        log "INFO" "Restoring from backup: ${backup_name}"
        if "${SCRIPT_DIR}/restore.sh" "${backup_name}" --force; then
            log "INFO" "Rollback completed successfully"
            send_notification "N8N Update Rollback" "Update failed and system was rolled back to backup: ${backup_name}" "warning"
        else
            error_exit "Rollback failed - manual intervention required"
        fi
    else
        error_exit "Restore script not found - manual rollback required"
    fi
}

# Clean old backups
cleanup_old_backups() {
    log "INFO" "Cleaning up old backups (keeping last ${MAX_BACKUP_RETENTION} days)..."
    find "${BACKUP_DIR}" -name "pre-update-*.tar.gz" -type f -mtime +"${MAX_BACKUP_RETENTION}" -delete 2>/dev/null || true
    find "${BACKUP_DIR}" -name "pre-update-*.sql" -type f -mtime +"${MAX_BACKUP_RETENTION}" -delete 2>/dev/null || true
}

# Update with Watchtower
update_with_watchtower() {
    log "INFO" "Starting Watchtower update..."
    # Start Watchtower in run-once mode
    docker compose -f docker-compose.yml -f docker-compose.autoupdate.yml run --rm \
        -e WATCHTOWER_RUN_ONCE=true \
        -e WATCHTOWER_CLEANUP=true \
        -e WATCHTOWER_INCLUDE_STOPPED=true \
        watchtower
    log "INFO" "Watchtower update completed"
}

# Main update function
main_update() {
    local update_method="${1}"
    log "INFO" "Starting autoupdate process (method: ${update_method})"
    
    # Check if updates are available
    if ! check_updates; then
        log "INFO" "No updates available, exiting"
        return 0
    fi
    
    # Create backup if enabled
    if [[ "${BACKUP_BEFORE_UPDATE}" == "true" ]]; then
        create_backup
    fi
    
    # Perform update
    local update_success=false
    case "${update_method}" in
        "watchtower")
            if update_with_watchtower; then
                update_success=true
            fi
            ;;
        "manual"|*)
            if perform_update; then
                update_success=true
            fi
            ;;
    esac
    
    if [[ "${update_success}" == "true" ]]; then
        log "INFO" "Update completed successfully"
        send_notification "N8N Update Success" "N8N-R8 has been updated successfully" "success"
        cleanup_old_backups
    else
        log "ERROR" "Update failed"
        if [[ "${BACKUP_BEFORE_UPDATE}" == "true" && "${ROLLBACK_ON_FAILURE}" == "true" ]]; then
            rollback
        else
            send_notification "N8N Update Failed" "N8N-R8 update failed. Manual intervention may be required." "error"
        fi
    fi
}

# Show usage
usage() {
    cat << 'EOF'
Usage: $0 [OPTIONS] COMMAND

N8N-R8 Autoupdate Script

COMMANDS:
    check           Check for available updates
    update          Perform update (manual method)
    watchtower      Perform update using Watchtower
    enable          Enable autoupdate
    disable         Disable autoupdate
    status          Show autoupdate status
    schedule        Install cron job for scheduled updates

OPTIONS:
    -h, --help      Show this help message
    -v, --verbose   Enable verbose logging
    -f, --force     Force update even if no updates detected
    --no-backup     Skip backup creation
    --no-rollback   Disable rollback on failure

EXAMPLES:
    $0 check                    # Check for updates
    $0 update                   # Perform manual update
    $0 watchtower              # Update using Watchtower
    $0 enable                  # Enable autoupdate
    $0 schedule                # Install cron job
EOF
}

# Enable autoupdate
enable_autoupdate() {
    log "INFO" "Enabling autoupdate..."
    # Update .env file
    if grep -q "^AUTOUPDATE_ENABLED=" "$\1" 2>/dev/null; then
        sed -i 's/^AUTOUPDATE_ENABLED=.*/AUTOUPDATE_ENABLED=true/' "$\1"
    else
        echo "AUTOUPDATE_ENABLED=true" >> "$\1"
    fi
    log "INFO" "Autoupdate enabled"
}

# Disable autoupdate
disable_autoupdate() {
    log "INFO" "Disabling autoupdate..."
    # Update .env file
    if grep -q "^AUTOUPDATE_ENABLED=" "$\1" 2>/dev/null; then
        sed -i 's/^AUTOUPDATE_ENABLED=.*/AUTOUPDATE_ENABLED=false/' "$\1"
    else
        echo "AUTOUPDATE_ENABLED=false" >> "$\1"
    fi
    # Remove cron job
    crontab -l 2>/dev/null | grep -v "$0" | crontab - 2>/dev/null || true
    log "INFO" "Autoupdate disabled"
}

# Show status
show_status() {
    load_config
    echo -e "${BLUE}N8N-R8 Autoupdate Status${NC}"
    echo -e "${BLUE}=======================${NC}"
    echo -e "Enabled: ${AUTOUPDATE_ENABLED}"
    echo -e "Backup before update: ${BACKUP_BEFORE_UPDATE}"
    echo -e "Rollback on failure: ${ROLLBACK_ON_FAILURE}"
    echo -e "Notification enabled: ${NOTIFICATION_ENABLED}"
    echo -e "Update check interval: ${UPDATE_CHECK_INTERVAL}s"
    echo -e "Max backup retention: ${MAX_BACKUP_RETENTION} days"
    echo ""
    # Check cron job
    if crontab -l 2>/dev/null | grep -q "$0"; then
        echo -e "${GREEN}Cron job installed${NC}"
        crontab -l 2>/dev/null | grep "$0"
    else
        echo -e "${YELLOW}No cron job installed${NC}"
    fi
}

# Install cron job
install_cron() {
    log "INFO" "Installing cron job for scheduled updates..."
    # Default: daily at 2 AM
    local cron_schedule="0 2 * * *"
    local cron_entry="${cron_schedule} ${0} update >/dev/null 2>&1"
    # Add to crontab
    (crontab -l 2>/dev/null | grep -v "$0"; echo "${cron_entry}") | crontab -
    log "INFO" "Cron job installed: ${cron_entry}"
}

# Function to parse command line arguments
parse_arguments() {
    # Initialize variables
    FORCE_UPDATE=false
    command=""

    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                exit 0
                ;;
            -v|--verbose)
                # Verbose mode - could be used for debugging
                shift
                ;;
            -f|--force)
                FORCE_UPDATE=true
                shift
                ;;
            --no-backup)
                BACKUP_BEFORE_UPDATE=false
                shift
                ;;
            --no-rollback)
                ROLLBACK_ON_FAILURE=false
                shift
                ;;
            check|update|watchtower|enable|disable|status|schedule)
                command="$1"
                shift
                ;;
            *)
                echo "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
}

# Main function
main() {
    # Initialize
    load_config
    check_lock
    init_directories
    parse_arguments "$@"

    # Handle command execution
    if [[ -z "${command}" ]]; then
        echo "No command specified"
        usage
        exit 1
    fi
    
    case "${command}" in
        check)
            if check_updates; then
                echo -e "${GREEN}Updates are available${NC}"
            else
                echo -e "${YELLOW}No updates available${NC}"
            fi
            ;;
        update)
            if [[ "${AUTOUPDATE_ENABLED}" != "true" && "${FORCE_UPDATE}" != "true" ]]; then
                error_exit "Autoupdate is disabled. Use --force to override or run 'enable' first."
            fi
            main_update "manual"
            ;;
        watchtower)
            main_update "watchtower"
            ;;
        enable)
            enable_autoupdate
            ;;
        disable)
            disable_autoupdate
            ;;
        status)
            show_status
            ;;
        schedule)
            install_cron
            ;;
        *)
            echo "Unknown command: ${command}"
            usage
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
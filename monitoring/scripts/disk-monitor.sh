#!/bin/bash

# N8N-R8 Disk Space Monitoring Script
# Monitors disk usage for data directories and sends alerts
set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
MONITORING_DIR="$SCRIPT_DIR/.."
LOG_DIR="$MONITORING_DIR/logs"
CONFIG_FILE="$MONITORING_DIR/config/monitor.conf"

# Load configuration
if [[ -f "$CONFIG_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
fi

# Default thresholds
DISK_WARNING_THRESHOLD=${DISK_WARNING_THRESHOLD:-75}
DISK_CRITICAL_THRESHOLD=${DISK_CRITICAL_THRESHOLD:-85}
DISK_EMERGENCY_THRESHOLD=${DISK_EMERGENCY_THRESHOLD:-95}

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_DIR/disk-monitor.log"
}

# Generate detailed disk usage report
generate_report() {
    local report_file
    report_file="$LOG_DIR/disk-report-$(date +%Y%m%d_%H%M%S).txt"
    {
        echo "System Information:"
        echo "-------------------"
        df -h
        echo ""
        echo "Docker Usage:"
        echo "-------------"
        docker system df 2>/dev/null || echo "Docker not available"
        echo ""
        echo "Largest Files in Data Directory:"
        echo "--------------------------------"
        find "$PROJECT_DIR/data" -type f -exec ls -lh {} + 2>/dev/null | sort -k5 -hr | head -10 || echo "No files found"
    } > "$report_file"
    echo "Report saved to: $report_file"
    log "Disk usage report generated: $report_file"
}

# Send alert if thresholds exceeded
send_disk_alert() {
    local status="$1"
    local details="$2"
    # Check if monitoring script exists and use its alert function
    if [[ -f "$MONITORING_DIR/scripts/monitor.sh" ]]; then
        # shellcheck disable=SC1091
        source "$MONITORING_DIR/scripts/monitor.sh"
        local subject="Disk Space Alert - $status"
        local body
        body="Disk space alert for N8N-R8:
$details

Current disk usage:
$(df -h)

Please take action to free up disk space.

Generated: $(date)"
        send_email_alert "$subject" "$body"
    else
        log "WARNING: Cannot send alert - monitor.sh not found"
    fi
}

# Check disk usage for a directory
check_directory_usage() {
    log "Checking directory disk usage..."
    echo -e "${BLUE}Directory Disk Usage:${NC}"
    
    # Check project data directory
    local dir="$PROJECT_DIR/data"
    local name="Data Directory"
    
    if [[ -d "$dir" ]]; then
        local usage_percent
        usage_percent="$(df "$dir" | awk 'NR==2 {print $5}' | sed 's/%//')"
        local usage_size
        usage_size="$(df -h "$dir" | awk 'NR==2 {print $3}')"
        local available
        available="$(df -h "$dir" | awk 'NR==2 {print $4}')"
        
        printf "  %-15s %8s used (%3d%%), %8s available\n" "$name:" "$usage_size" "$usage_percent" "$available"
        
        local status
        if [[ "$usage_percent" -ge "$DISK_EMERGENCY_THRESHOLD" ]]; then
            status="EMERGENCY"
            echo -e "${RED}🚨 EMERGENCY: $name is at ${usage_percent}% capacity!${NC}"
        elif [[ "$usage_percent" -ge "$DISK_CRITICAL_THRESHOLD" ]]; then
            status="CRITICAL"
            echo -e "${RED}🔴 CRITICAL: $name is at ${usage_percent}% capacity!${NC}"
        elif [[ "$usage_percent" -ge "$DISK_WARNING_THRESHOLD" ]]; then
            status="WARNING"
            echo -e "${YELLOW}🟡 WARNING: $name is at ${usage_percent}% capacity${NC}"
        else
            status="OK"
            echo -e "${GREEN}🟢 OK: $name usage is normal${NC}"
        fi
        
        # Send alert if needed
        if [[ "$status" != "OK" ]]; then
            send_disk_alert "$status" "$name ($dir) is at ${usage_percent}% usage"
        fi
        
        log "$status: $name ($dir) is at ${usage_percent}% usage (${usage_size})"
        
        # Return status code
        case "$status" in
            "OK")
                return 0
                ;;
            "WARNING")
                return 1
                ;;
            "CRITICAL")
                return 2
                ;;
            "EMERGENCY")
                return 3
                ;;
            *)
                return 4
                ;;
        esac
    else
        echo "  Data directory not found: $dir"
        return 4
    fi
}

# Check Docker system usage
check_docker_usage() {
    log "Checking Docker system usage..."
    echo -e "${BLUE}Docker System Usage:${NC}"
    
    # Get Docker system info
    if docker system df >/dev/null 2>&1; then
        docker system df --format "table {{.Type}}\t{{.TotalCount}}\t{{.Size}}\t{{.Reclaimable}}"
        
        # Check for reclaimable space
        local reclaimable
        reclaimable=$(docker system df --format "{{.Type}} {{.Reclaimable}}" | grep -E "(Images|Containers|Volumes)" | awk '{print $2}' | sed 's/[^0-9.]//g' | awk '{sum += $1} END {print sum}')
        if [[ -n "$reclaimable" ]] && [[ "$(echo "$reclaimable > 1000" | bc -l 2>/dev/null || echo 0)" -eq 1 ]]; then
            echo -e "${YELLOW}💡 Tip: You can reclaim ${reclaimable}MB with 'docker system prune'${NC}"
        fi
    else
        echo "❌ Docker not available"
    fi
    return 0
}

# Check individual container disk usage
check_container_usage() {
    log "Checking container disk usage..."
    echo -e "${BLUE}Container Disk Usage:${NC}"
    
    # Get running containers
    local containers
    mapfile -t containers < <(docker ps --format "{{.Names}}" | grep "^n8n")
    
    for container in "${containers[@]}"; do
        local size
        size="$(docker exec "$container" df -h / 2>/dev/null | awk 'NR==2 {print $3}' || echo "N/A")"
        local usage
        usage="$(docker exec "$container" df / 2>/dev/null | awk 'NR==2 {print $5}' || echo "N/A")"
        printf "  %-15s %8s (%s)\n" "$container:" "$size" "$usage"
    done
}

# Clean up old files
cleanup_old_files() {
    log "Cleaning up old files..."
    local cleaned=false
    
    # Clean old logs
    if [[ -d "$LOG_DIR" ]]; then
        local old_logs
        old_logs="$(find "$LOG_DIR" -name "*.log.*" -mtime +7 2>/dev/null | wc -l)"
        if [[ "$old_logs" -gt 0 ]]; then
            find "$LOG_DIR" -name "*.log.*" -mtime +7 -delete
            log "Cleaned $old_logs old log files"
            cleaned=true
        fi
    fi
    
    # Clean old backups
    if [[ -d "$PROJECT_DIR/backups" ]]; then
        local retention_days=${BACKUP_RETENTION_DAYS:-30}
        local old_backups
        old_backups="$(find "$PROJECT_DIR/backups" -name "n8n_backup_*" -mtime +"$retention_days" 2>/dev/null | wc -l)"
        if [[ "$old_backups" -gt 0 ]]; then
            find "$PROJECT_DIR/backups" -name "n8n_backup_*" -mtime +"$retention_days" -exec rm -rf {} +
            log "Cleaned $old_backups old backups (older than $retention_days days)"
            cleaned=true
        fi
    fi
    
    # Clean Docker system if critically low on space
    local root_usage
    root_usage="$(df / | awk 'NR==2 {print $5}' | sed 's/%//')"
    if [[ "$root_usage" -ge "$DISK_EMERGENCY_THRESHOLD" ]]; then
        log "EMERGENCY: Root filesystem at ${root_usage}%, cleaning Docker system..."
        docker system prune -f --volumes
        cleaned=true
    fi
    
    if [[ "$cleaned" == "true" ]]; then
        log "Cleanup completed"
    else
        log "No old files to clean"
    fi
}

# Main monitoring function
main() {
    local command="${1:-check}"
    
    # Set up logging
    mkdir -p "$LOG_DIR"
    
    case "$command" in
        "check")
            check_directory_usage
            check_docker_usage
            check_container_usage
            ;;
        "cleanup")
            cleanup_old_files
            ;;
        "report")
            generate_report
            ;;
        "monitor")
            log "Starting continuous monitoring (Ctrl+C to stop)..."
            while true; do
                check_directory_usage
                check_docker_usage
                check_container_usage
                sleep 300  # Check every 5 minutes
            done
            ;;
        *)
            echo "Usage: $0 [check|cleanup|report|monitor]"
            echo "Commands:"
            echo "  check    - Check disk usage (default)"
            echo "  cleanup  - Clean up old files"
            echo "  report   - Generate detailed report"
            echo "  monitor  - Continuous monitoring"
            exit 1
            ;;
    esac
}

# Run main function
main "$@"

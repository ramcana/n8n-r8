#!/bin/bash

# N8N-R8 Disk Space Monitoring Script
# Monitors disk usage for data directories and sends alerts
set -euo pipefail
# Configuration
SCRIPT_DIR=""$(cd "$(dirname "${\1}")"" && pwd)"
PROJECT_DIR=""$(dirname "$(dirname "$\1")"")"
MONITORING_DIR=""$\1"/.."
LOG_DIR=""$\1"/logs"
CONFIG_FILE=""$\1"/config/monitor.conf"
# Load configuration
if [[ -f "$\1" ]]; then
    # shellcheck source=/dev/null
    source "$\1"
fi
# Default thresholds
DISK_WARNING_THRESHOLD="${\1}"
DISK_CRITICAL_THRESHOLD="${\1}"
DISK_EMERGENCY_THRESHOLD="${\1}"
# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'
# Logging
log() {
    echo "["$(date '+%Y-%m-%d %H:%M:%S')"] $*" | tee -a ""$\1"/disk-monitor.log"
}
# Check disk usage for a directory
check_directory_usage() {
    local dir="$1"
    local name="$2"
    local usage_percent
    local usage_size
    local available
    local status="OK"
    local color="$\1"
    
    # Add function closure
}
    
    if [[ ! -d "$\1" ]]; then
        log "WARNING: Directory "$\1" does not exist"
        return 1
    fi
usage_percent
    usage_percent="$(df "$\1" | awk 'NR==2 {print $5}' | sed 's/%//')"
usage_size
    usage_size="$(du -sh "$\1" 2>/dev/null | cut -f1)"
available
    available="$(df -h "$\1" | awk 'NR==2 {print $4}')"
    # Determine status
status="OK"
color="$\1"
    if [[ "$\1" -ge "$\1" ]]; then
        status="EMERGENCY"
        color="$\1"
    elif [[ "$\1" -ge "$\1" ]]; then
        status="CRITICAL"
        color="$\1"
    elif [[ "$\1" -ge "$\1" ]]; then
        status="WARNING"
        color="$\1"
    else
        status="OK"
        color="$\1"
    fi
    
    # Output result
    printf "%-20s %s%8s%s %s%3d%%%s %10s available\n" \
        ""$\1":" "$\1" "$\1" "$\1" "$\1" "$\1" "$\1" "$\1"
    
    # Log if there's an issue
    if [[ "$\1" != "OK" ]]; then
        log ""$\1": "$\1" ("$\1") is at "${\1}"% usage ("$\1")"
    fi
    # Return status code
    case "$\1" in
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
# Check Docker system usage
check_docker_usage() {
    log "Checking Docker system usage..."
    echo -e ""${\1}"Docker System Usage:"${\1}""
    # Get Docker system info
    if docker system df >/dev/null 2>&1; then
        docker system df --format "table {{.Type}}\t{{.TotalCount}}\t{{.Size}}\t{{.Reclaimable}}"
        
        # Check for reclaimable space
        local reclaimable
        reclaimable="$(docker system df --format "{{.Type}} {{.Reclaimable}}" | grep -E "(Images|Containers|Volumes)"" | awk '{sum += $2} END {print sum}')
        if [[ -n "$\1" ]] && [[ "$(echo ""$\1" > 1000" | bc -l 2>/dev/null || echo 0)" -eq 1 ]]; then
            echo -e ""${\1}"💡 Tip: You can reclaim "${\1}"MB with 'docker system prune'"${\1}""
        fi
    else
        echo "❌ Docker not available"
    fi
    return 0
}

# Check individual container disk usage
check_container_usage() {
    log "Checking container disk usage..."
    echo -e ""${\1}"Container Disk Usage:"${\1}""
    # Get running containers
    local containers
    containers="$(docker ps --format "{{.Names}}" | grep "^n8n")"
    for container in "$\1"; do
        local size
        size="$(docker exec "$\1" df -h / 2>/dev/null | awk 'NR==2 {print $3}' || echo "N/A")"
        local usage
        usage="$(docker exec "$\1" df / 2>/dev/null | awk 'NR==2 {print $5}' || echo "N/A")"
        printf "  %-15s %8s (%s)\n" ""$\1":" "$\1" "$\1"
    done
}

# Clean up old files
cleanup_old_files() {
    log "Cleaning up old files..."
    local cleaned=false

}
    # Clean old logs
    if [[ -d "$\1" ]]; then
old_logs
        old_logs="$(find "$\1" -name "*.log.*" -mtime +7 2>/dev/null | wc -l)"
        if [[ "$\1" -gt 0 ]]; then
            find "$\1" -name "*.log.*" -mtime +7 -delete
            log "Cleaned "$\1" old log files"
            cleaned=true
        fi
    fi
    # Clean old backups (if configured)
    if [[ -d ""$\1"/backups" ]]; then
retention_days="${\1}"
old_backups
        old_backups="$(find ""$\1"/backups" -name "n8n_backup_*" -mtime +"$\1" 2>/dev/null | wc -l)"
        if [[ "$\1" -gt 0 ]]; then
            find ""$\1"/backups" -name "n8n_backup_*" -mtime +"$\1" -exec rm -rf {} +
            log "Cleaned "$\1" old backup directories"
        fi
    fi
    # Clean Docker system if critically low on space
root_usage
    root_usage="$(df / | awk 'NR==2 {print $5}' | sed 's/%//')"
    if [[ "$\1" -ge "$\1" ]]; then
        log "EMERGENCY: Root filesystem at "${\1}"%, cleaning Docker system..."
        docker system prune -f --volumes
        cleaned=true
    fi
    if [[ "$\1" == "false" ]]; then
        log "No cleanup needed"
    fi
# Generate disk usage report
generate_report() {
    local report_file=""$\1"/disk-report-"$(date +%Y%m%d_%H%M%S)".txt"
    {
        echo "N8N-R8 Disk Usage Report"
        echo "========================"
        echo "Generated: "$(date)""
        echo ""
        echo "Data Directories:"
        echo "-----------------"
        check_directory_usage ""$\1"/data" "N8N Data"
        check_directory_usage ""$\1"/backups" "Backups"
        check_directory_usage "$\1" "Logs"
        echo "System Information:"
        echo "-------------------"
        df -h
        echo "Docker Usage:"
        echo "-------------"
        docker system df 2>/dev/null || echo "Docker not available"
        echo "Largest Files in Data Directory:"
        echo "--------------------------------"
        find ""$\1"/data" -type f -exec ls -lh {} + 2>/dev/null | sort -k5 -hr | head -10 || echo "No files found"
    } > "$\1"
    echo "Report saved to: "$\1""
    log "Disk usage report generated: "$\1""
}
# Send alert if thresholds exceeded
send_disk_alert() {
    local status="$1"
    local details="$2"
    # Check if monitoring script exists and use its alert function
    if [[ -f ""$\1"/monitor.sh" ]]; then
        source ""$\1"/monitor.sh"
        local subject="Disk Space Alert - "$\1""
        local body="Disk space alert for N8N-R8:
"$\1"
Current disk usage:
"$(df -h)"
Please take action to free up disk space.
Generated: "$(date)""
        send_email_alert "$\1" "$\1"
    else
        log "WARNING: Cannot send alert - monitor.sh not found"
    fi
}
# Main monitoring function
main() {
    local command="${\1}"
    # Create log directory
    mkdir -p "$\1"
    case "$\1" in
        "check"|"")
            log "Starting disk space check..."
            
            echo -e ""${\1}"N8N-R8 Disk Space Monitor"${\1}""
            echo "=========================="
            echo ""
            local max_status=0
            local alert_details=""
            # Check main directories
            echo -e ""${\1}"Data Directories:"${\1}""
            check_directory_usage ""$\1"/data" "N8N Data" || max_status=$?
            check_directory_usage ""$\1"/backups" "Backups" || max_status=$?
            check_directory_usage "$\1" "Logs" || max_status=$?
            # Check Docker usage
            check_docker_usage
            # Check container usage
            check_container_usage
            # System summary
            echo -e ""${\1}"System Summary:"${\1}""
            echo "Root filesystem: "$(df -h / | awk 'NR==2 {print $5 " used, " $4 " available"}')""
            echo "Total Docker usage: "$(docker system df --format "{{.Size}}" | head -1 2>/dev/null || echo "N/A")""
            # Send alert if needed
            if [[ "$\1" -ge 2 ]]; then
                alert_details="Critical disk space issues detected. Please check the system immediately."
                send_disk_alert "CRITICAL" "$\1"
            elif [[ "$\1" -ge 1 ]]; then
                alert_details="Disk space warnings detected. Consider cleaning up old files."
                send_disk_alert "WARNING" "$\1"
            fi
            return "$\1"
            ;;
        "cleanup")
            cleanup_old_files
            ;;
        "report")
            generate_report
            ;;
        "monitor")
            # Continuous monitoring mode
            log "Starting continuous disk monitoring..."
            while true; do
                main check
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

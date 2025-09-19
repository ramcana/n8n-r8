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
    source "$CONFIG_FILE"
fi

# Default thresholds
DISK_WARNING_THRESHOLD=${DISK_WARNING_THRESHOLD:-75}
DISK_CRITICAL_THRESHOLD=${DISK_THRESHOLD:-85}
DISK_EMERGENCY_THRESHOLD=${DISK_EMERGENCY_THRESHOLD:-95}

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_DIR/disk-monitor.log"
}

# Check disk usage for a directory
check_directory_usage() {
    local dir="$1"
    local name="$2"
    
    if [[ ! -d "$dir" ]]; then
        log "WARNING: Directory $dir does not exist"
        return 1
    fi
    
    # Get disk usage percentage
    local usage_percent=$(df "$dir" | awk 'NR==2 {print $5}' | sed 's/%//')
    local usage_size=$(du -sh "$dir" 2>/dev/null | cut -f1)
    local available=$(df -h "$dir" | awk 'NR==2 {print $4}')
    
    # Determine status
    local status="OK"
    local color="$GREEN"
    
    if [[ $usage_percent -ge $DISK_EMERGENCY_THRESHOLD ]]; then
        status="EMERGENCY"
        color="$RED"
    elif [[ $usage_percent -ge $DISK_CRITICAL_THRESHOLD ]]; then
        status="CRITICAL"
        color="$RED"
    elif [[ $usage_percent -ge $DISK_WARNING_THRESHOLD ]]; then
        status="WARNING"
        color="$YELLOW"
    fi
    
    # Output result
    printf "%-20s %s%8s%s %s%3d%%%s %10s available\n" \
        "$name:" "$color" "$usage_size" "$NC" "$color" "$usage_percent" "$NC" "$available"
    
    # Log if there's an issue
    if [[ "$status" != "OK" ]]; then
        log "$status: $name ($dir) is at ${usage_percent}% usage ($usage_size)"
    fi
    
    # Return status code
    case "$status" in
        "OK") return 0 ;;
        "WARNING") return 1 ;;
        "CRITICAL") return 2 ;;
        "EMERGENCY") return 3 ;;
    esac
}

# Check Docker system usage
check_docker_usage() {
    log "Checking Docker system usage..."
    
    echo -e "${BLUE}Docker System Usage:${NC}"
    
    # Get Docker system info
    if docker system df >/dev/null 2>&1; then
        docker system df --format "table {{.Type}}\t{{.TotalCount}}\t{{.Size}}\t{{.Reclaimable}}"
        
        # Check for reclaimable space
        local reclaimable=$(docker system df --format "{{.Type}} {{.Reclaimable}}" | grep -E "(Images|Containers|Volumes)" | awk '{sum += $2} END {print sum}')
        
        if [[ -n "$reclaimable" ]] && [[ $(echo "$reclaimable > 1000" | bc -l 2>/dev/null || echo 0) -eq 1 ]]; then
            echo -e "${YELLOW}💡 Tip: You can reclaim ${reclaimable}MB with 'docker system prune'${NC}"
        fi
    else
        echo "❌ Docker not available"
        return 1
    fi
    
    return 0
}

# Check individual container disk usage
check_container_usage() {
    log "Checking container disk usage..."
    
    echo -e "${BLUE}Container Disk Usage:${NC}"
    
    # Get running containers
    local containers=$(docker ps --format "{{.Names}}" | grep "^n8n")
    
    for container in $containers; do
        local size=$(docker exec "$container" df -h / 2>/dev/null | awk 'NR==2 {print $3}' || echo "N/A")
        local usage=$(docker exec "$container" df / 2>/dev/null | awk 'NR==2 {print $5}' || echo "N/A")
        
        printf "  %-15s %8s (%s)\n" "$container:" "$size" "$usage"
    done
}

# Clean up old files
cleanup_old_files() {
    log "Cleaning up old files..."
    
    local cleaned=false
    
    # Clean old logs
    if [[ -d "$LOG_DIR" ]]; then
        local old_logs=$(find "$LOG_DIR" -name "*.log.*" -mtime +7 2>/dev/null | wc -l)
        if [[ $old_logs -gt 0 ]]; then
            find "$LOG_DIR" -name "*.log.*" -mtime +7 -delete
            log "Cleaned $old_logs old log files"
            cleaned=true
        fi
    fi
    
    # Clean old backups (if configured)
    if [[ -d "$PROJECT_DIR/backups" ]]; then
        local retention_days=${BACKUP_RETENTION_DAYS:-30}
        local old_backups=$(find "$PROJECT_DIR/backups" -name "n8n_backup_*" -mtime +$retention_days 2>/dev/null | wc -l)
        if [[ $old_backups -gt 0 ]]; then
            find "$PROJECT_DIR/backups" -name "n8n_backup_*" -mtime +$retention_days -exec rm -rf {} +
            log "Cleaned $old_backups old backup directories"
            cleaned=true
        fi
    fi
    
    # Clean Docker system if critically low on space
    local root_usage=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
    if [[ $root_usage -ge $DISK_EMERGENCY_THRESHOLD ]]; then
        log "EMERGENCY: Root filesystem at ${root_usage}%, cleaning Docker system..."
        docker system prune -f --volumes
        cleaned=true
    fi
    
    if [[ "$cleaned" == "false" ]]; then
        log "No cleanup needed"
    fi
}

# Generate disk usage report
generate_report() {
    local report_file="$LOG_DIR/disk-report-$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "N8N-R8 Disk Usage Report"
        echo "========================"
        echo "Generated: $(date)"
        echo ""
        
        echo "Data Directories:"
        echo "-----------------"
        check_directory_usage "$PROJECT_DIR/data" "N8N Data"
        check_directory_usage "$PROJECT_DIR/backups" "Backups"
        check_directory_usage "$LOG_DIR" "Logs"
        echo ""
        
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
    if [[ -f "$SCRIPT_DIR/monitor.sh" ]]; then
        source "$SCRIPT_DIR/monitor.sh"
        
        local subject="Disk Space Alert - $status"
        local body="Disk space alert for N8N-R8:

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

# Main monitoring function
main() {
    local command="${1:-check}"
    
    # Create log directory
    mkdir -p "$LOG_DIR"
    
    case "$command" in
        "check"|"")
            log "Starting disk space check..."
            
            echo -e "${BLUE}N8N-R8 Disk Space Monitor${NC}"
            echo "=========================="
            echo ""
            
            local max_status=0
            local alert_details=""
            
            # Check main directories
            echo -e "${BLUE}Data Directories:${NC}"
            
            check_directory_usage "$PROJECT_DIR/data" "N8N Data" || max_status=$?
            check_directory_usage "$PROJECT_DIR/backups" "Backups" || max_status=$?
            check_directory_usage "$LOG_DIR" "Logs" || max_status=$?
            
            echo ""
            
            # Check Docker usage
            check_docker_usage
            echo ""
            
            # Check container usage
            check_container_usage
            echo ""
            
            # System summary
            echo -e "${BLUE}System Summary:${NC}"
            echo "Root filesystem: $(df -h / | awk 'NR==2 {print $5 " used, " $4 " available"}')"
            echo "Total Docker usage: $(docker system df --format "{{.Size}}" | head -1 2>/dev/null || echo "N/A")"
            
            # Send alert if needed
            if [[ $max_status -ge 2 ]]; then
                alert_details="Critical disk space issues detected. Please check the system immediately."
                send_disk_alert "CRITICAL" "$alert_details"
            elif [[ $max_status -ge 1 ]]; then
                alert_details="Disk space warnings detected. Consider cleaning up old files."
                send_disk_alert "WARNING" "$alert_details"
            fi
            
            return $max_status
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
            echo ""
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

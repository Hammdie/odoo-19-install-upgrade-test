#!/bin/bash

# Daily Maintenance Script for Odoo
# Performs daily system maintenance tasks

set -e  # Exit on any error

# Configuration
ODOO_USER="odoo"
ODOO_HOME="/opt/odoo"
LOG_DIR="/var/log/odoo-upgrade"
LOG_FILE="$LOG_DIR/daily-maintenance-$(date +%Y%m%d).log"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Maintenance thresholds
MAX_DISK_USAGE=85
MAX_MEMORY_USAGE=90
LOG_RETENTION_DAYS=30

# Logging function
log() {
    local level=$1
    shift
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

# Create log directory
create_log_dir() {
    if [[ ! -d "$LOG_DIR" ]]; then
        sudo mkdir -p "$LOG_DIR"
        sudo chmod 755 "$LOG_DIR"
    fi
}

# Log maintenance start
log_start() {
    log "INFO" "========================================"
    log "INFO" "Starting daily maintenance - $(date)"
    log "INFO" "========================================"
}

# Update system packages
update_system() {
    log "INFO" "Updating system packages..."
    
    export DEBIAN_FRONTEND=noninteractive
    
    # Update package lists
    if apt update 2>&1 | tee -a "$LOG_FILE"; then
        log "SUCCESS" "Package lists updated"
    else
        log "ERROR" "Failed to update package lists"
        return 1
    fi
    
    # Check for available updates
    local updates=$(apt list --upgradable 2>/dev/null | grep -c upgradable || echo "0")
    
    if [[ $updates -gt 0 ]]; then
        log "INFO" "Found $updates package updates available"
        
        # Install security updates
        if apt upgrade -y 2>&1 | tee -a "$LOG_FILE"; then
            log "SUCCESS" "System packages updated"
        else
            log "WARN" "Some package updates failed"
        fi
    else
        log "INFO" "System is up to date"
    fi
    
    # Clean package cache
    apt autoremove -y 2>&1 | tee -a "$LOG_FILE"
    apt autoclean 2>&1 | tee -a "$LOG_FILE"
    
    log "SUCCESS" "System update completed"
}

# Check system health
check_system_health() {
    log "INFO" "Checking system health..."
    
    # Check disk usage
    local disk_usage=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
    log "INFO" "Disk usage: ${disk_usage}%"
    
    if [[ $disk_usage -gt $MAX_DISK_USAGE ]]; then
        log "WARN" "High disk usage detected: ${disk_usage}%"
        
        # Try to free up space
        log "INFO" "Attempting to free up disk space..."
        
        # Clean apt cache
        apt clean 2>&1 | tee -a "$LOG_FILE"
        
        # Clean old kernels
        apt autoremove --purge -y 2>&1 | tee -a "$LOG_FILE"
        
        # Clean systemd journal
        journalctl --vacuum-time=7d 2>&1 | tee -a "$LOG_FILE"
        
        # Check new disk usage
        local new_disk_usage=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
        log "INFO" "Disk usage after cleanup: ${new_disk_usage}%"
    fi
    
    # Check memory usage
    local memory_usage=$(free | awk 'NR==2{printf "%.0f", $3*100/$2}')
    log "INFO" "Memory usage: ${memory_usage}%"
    
    if [[ $(echo "$memory_usage > $MAX_MEMORY_USAGE" | bc -l) -eq 1 ]]; then
        log "WARN" "High memory usage detected: ${memory_usage}%"
    fi
    
    # Check load average
    local load_avg=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
    log "INFO" "Load average: $load_avg"
    
    # Check available memory
    local available_memory=$(free -h | awk 'NR==2{print $7}')
    log "INFO" "Available memory: $available_memory"
    
    log "SUCCESS" "System health check completed"
}

# Check Odoo service health
check_odoo_health() {
    log "INFO" "Checking Odoo service health..."
    
    # Check if Odoo service is running
    if systemctl is-active --quiet odoo; then
        log "SUCCESS" "Odoo service is running"
        
        # Check if Odoo is responding
        if command -v curl &> /dev/null; then
            local response_code=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8069 || echo "000")
            
            if [[ "$response_code" =~ ^(200|302)$ ]]; then
                log "SUCCESS" "Odoo web interface is responding"
            else
                log "WARN" "Odoo web interface not responding (HTTP $response_code)"
                
                # Try to restart Odoo
                log "INFO" "Attempting to restart Odoo service..."
                systemctl restart odoo
                sleep 10
                
                # Check again
                local new_response_code=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8069 || echo "000")
                if [[ "$new_response_code" =~ ^(200|302)$ ]]; then
                    log "SUCCESS" "Odoo service restarted successfully"
                else
                    log "ERROR" "Odoo service still not responding after restart"
                fi
            fi
        fi
        
        # Check Odoo process memory usage
        local odoo_pid=$(systemctl show --property MainPID odoo | cut -d= -f2)
        if [[ "$odoo_pid" != "0" && -n "$odoo_pid" ]]; then
            local odoo_memory=$(ps -p "$odoo_pid" -o rss= 2>/dev/null || echo "0")
            local odoo_memory_mb=$((odoo_memory / 1024))
            log "INFO" "Odoo process memory usage: ${odoo_memory_mb}MB"
        fi
        
    else
        log "ERROR" "Odoo service is not running"
        
        # Try to start Odoo
        log "INFO" "Attempting to start Odoo service..."
        systemctl start odoo
        sleep 10
        
        if systemctl is-active --quiet odoo; then
            log "SUCCESS" "Odoo service started successfully"
        else
            log "ERROR" "Failed to start Odoo service"
            log "INFO" "Check logs with: journalctl -u odoo -f"
        fi
    fi
}

# Check PostgreSQL health
check_postgresql_health() {
    log "INFO" "Checking PostgreSQL health..."
    
    # Check if PostgreSQL is running
    if systemctl is-active --quiet postgresql; then
        log "SUCCESS" "PostgreSQL service is running"
        
        # Check database connections
        local connection_count=$(sudo -u postgres psql -t -c "SELECT count(*) FROM pg_stat_activity;" | tr -d ' ')
        log "INFO" "Active database connections: $connection_count"
        
        # Check database sizes
        log "INFO" "Database sizes:"
        sudo -u postgres psql -c "
            SELECT 
                datname as database,
                pg_size_pretty(pg_database_size(datname)) as size
            FROM pg_database 
            WHERE datistemplate = false
            ORDER BY pg_database_size(datname) DESC;
        " 2>&1 | while read -r line; do
            if [[ -n "$line" && "$line" != "+"* && "$line" != "("* ]]; then
                log "INFO" "  $line"
            fi
        done
        
        # Check for long-running queries
        local long_queries=$(sudo -u postgres psql -t -c "
            SELECT count(*) 
            FROM pg_stat_activity 
            WHERE state = 'active' 
            AND now() - query_start > interval '5 minutes';
        " | tr -d ' ')
        
        if [[ $long_queries -gt 0 ]]; then
            log "WARN" "Found $long_queries long-running queries (>5 minutes)"
        else
            log "INFO" "No long-running queries detected"
        fi
        
    else
        log "ERROR" "PostgreSQL service is not running"
        
        # Try to start PostgreSQL
        log "INFO" "Attempting to start PostgreSQL service..."
        systemctl start postgresql
        sleep 5
        
        if systemctl is-active --quiet postgresql; then
            log "SUCCESS" "PostgreSQL service started successfully"
        else
            log "ERROR" "Failed to start PostgreSQL service"
        fi
    fi
}

# Rotate Odoo logs
rotate_odoo_logs() {
    log "INFO" "Rotating Odoo logs..."
    
    local odoo_log="/var/log/odoo/odoo.log"
    
    if [[ -f "$odoo_log" ]]; then
        local log_size=$(du -h "$odoo_log" | cut -f1)
        log "INFO" "Current Odoo log size: $log_size"
        
        # Force log rotation
        if command -v logrotate &> /dev/null; then
            logrotate -f /etc/logrotate.d/odoo 2>&1 | tee -a "$LOG_FILE" || true
            log "INFO" "Log rotation completed"
        else
            # Manual log rotation if logrotate is not available
            if [[ -f "$odoo_log" ]]; then
                local backup_log="/var/log/odoo/odoo.log.$(date +%Y%m%d)"
                cp "$odoo_log" "$backup_log"
                > "$odoo_log"
                gzip "$backup_log"
                log "INFO" "Manual log rotation completed"
            fi
        fi
    else
        log "INFO" "Odoo log file not found"
    fi
}

# Clean old maintenance logs
clean_old_logs() {
    log "INFO" "Cleaning old maintenance logs..."
    
    local deleted_count=0
    
    # Clean old maintenance logs
    while IFS= read -r -d '' file; do
        rm -f "$file"
        ((deleted_count++))
    done < <(find "$LOG_DIR" -name "*.log" -mtime +$LOG_RETENTION_DAYS -print0 2>/dev/null)
    
    if [[ $deleted_count -gt 0 ]]; then
        log "INFO" "Deleted $deleted_count old log files"
    else
        log "INFO" "No old log files to delete"
    fi
    
    # Clean old systemd journal entries
    journalctl --vacuum-time=30d 2>&1 | tee -a "$LOG_FILE"
    
    log "SUCCESS" "Log cleanup completed"
}

# Update file permissions
fix_permissions() {
    log "INFO" "Checking and fixing file permissions..."
    
    # Fix Odoo directory permissions
    chown -R "$ODOO_USER:$ODOO_USER" "$ODOO_HOME"
    
    # Fix log directory permissions
    chown -R "$ODOO_USER:$ODOO_USER" /var/log/odoo
    chmod 755 /var/log/odoo
    
    # Fix run directory permissions
    if [[ -d /var/run/odoo ]]; then
        chown "$ODOO_USER:$ODOO_USER" /var/run/odoo
        chmod 755 /var/run/odoo
    fi
    
    log "SUCCESS" "Permissions check completed"
}

# Check and update Python packages
update_python_packages() {
    log "INFO" "Checking Python packages..."
    
    # Check if pip-review is available for checking outdated packages
    if command -v pip-review &> /dev/null; then
        local outdated_packages=$(pip-review --local --interactive=no | wc -l)
        if [[ $outdated_packages -gt 0 ]]; then
            log "INFO" "Found $outdated_packages outdated Python packages"
        else
            log "INFO" "Python packages are up to date"
        fi
    else
        # Use pip list --outdated as alternative
        local outdated_count=$(python3 -m pip list --outdated 2>/dev/null | wc -l)
        if [[ $outdated_count -gt 2 ]]; then  # Subtract header lines
            log "INFO" "Some Python packages may be outdated"
        fi
    fi
}

# Generate daily report
generate_report() {
    log "INFO" "========================================"
    log "INFO" "Daily Maintenance Summary"
    log "INFO" "========================================"
    
    # System information
    local uptime_info=$(uptime -p)
    local disk_usage=$(df -h / | awk 'NR==2 {print $5}')
    local memory_usage=$(free | awk 'NR==2{printf "%.1f%%", $3*100/$2}')
    local load_avg=$(uptime | awk -F'load average:' '{print $2}')
    
    log "INFO" "System Status:"
    log "INFO" "- Uptime: $uptime_info"
    log "INFO" "- Disk usage: $disk_usage"
    log "INFO" "- Memory usage: $memory_usage"
    log "INFO" "- Load average:$load_avg"
    
    # Service status
    local odoo_status=$(systemctl is-active odoo)
    local postgres_status=$(systemctl is-active postgresql)
    
    log "INFO" "Service Status:"
    log "INFO" "- Odoo: $odoo_status"
    log "INFO" "- PostgreSQL: $postgres_status"
    
    # Log file
    log "INFO" "Maintenance completed at: $(date)"
    log "INFO" "Log file: $LOG_FILE"
    log "INFO" "========================================"
}

# Main execution
main() {
    create_log_dir
    log_start
    
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        log "ERROR" "This script must be run as root or with sudo"
        exit 1
    fi
    
    # Perform maintenance tasks
    update_system
    check_system_health
    check_odoo_health
    check_postgresql_health
    rotate_odoo_logs
    clean_old_logs
    fix_permissions
    update_python_packages
    generate_report
    
    log "SUCCESS" "Daily maintenance completed successfully!"
}

# Run main function
main "$@"
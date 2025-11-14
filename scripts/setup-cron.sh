#!/bin/bash

# Odoo Cron Setup Script
# Sets up automated cron jobs for Odoo maintenance and updates

set -e  # Exit on any error

# Configuration
LOG_DIR="/var/log/odoo-upgrade"
LOG_FILE="$LOG_DIR/setup-cron-$(date +%Y%m%d-%H%M%S).log"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CRON_CONFIG="$PROJECT_ROOT/config/crontab"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    local level=$1
    shift
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
    
    case $level in
        "ERROR")
            echo -e "${RED}[ERROR]${NC} $message" >&2
            ;;
        "WARN")
            echo -e "${YELLOW}[WARN]${NC} $message"
            ;;
        "INFO")
            echo -e "${BLUE}[INFO]${NC} $message"
            ;;
        "SUCCESS")
            echo -e "${GREEN}[SUCCESS]${NC} $message"
            ;;
    esac
}

# Create log directory
create_log_dir() {
    if [[ ! -d "$LOG_DIR" ]]; then
        sudo mkdir -p "$LOG_DIR"
        sudo chmod 755 "$LOG_DIR"
        log "INFO" "Created log directory: $LOG_DIR"
    fi
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log "ERROR" "This script must be run as root or with sudo"
        exit 1
    fi
}

# Check prerequisites
check_prerequisites() {
    log "INFO" "Checking prerequisites..."
    
    # Check if Odoo is installed
    if [[ ! -d "/opt/odoo/odoo" ]]; then
        log "ERROR" "Odoo installation not found. Please run install-odoo19.sh first."
        exit 1
    fi
    
    # Check if required scripts exist
    local required_scripts=(
        "daily-maintenance.sh"
        "weekly-odoo-update.sh" 
        "backup-odoo.sh"
    )
    
    for script in "${required_scripts[@]}"; do
        if [[ ! -f "$SCRIPT_DIR/$script" ]]; then
            log "WARN" "Script not found: $script (will be created)"
        fi
    done
    
    log "SUCCESS" "Prerequisites check completed"
}

# Make scripts executable
make_scripts_executable() {
    log "INFO" "Making scripts executable..."
    
    # Make all scripts in the scripts directory executable
    find "$SCRIPT_DIR" -name "*.sh" -exec chmod +x {} \;
    
    log "SUCCESS" "Scripts made executable"
}

# Install crontab configuration
install_crontab() {
    log "INFO" "Installing crontab configuration..."
    
    # Check if crontab config exists
    if [[ ! -f "$CRON_CONFIG" ]]; then
        log "WARN" "Crontab configuration not found at $CRON_CONFIG"
        create_default_crontab
    fi
    
    # Backup existing crontab
    if crontab -l > /dev/null 2>&1; then
        crontab -l > "$LOG_DIR/crontab.backup.$(date +%Y%m%d-%H%M%S)" 2>/dev/null
        log "INFO" "Existing crontab backed up"
    fi
    
    # Create temporary crontab file with updated paths
    local temp_crontab="/tmp/odoo-crontab-$(date +%s)"
    
    # Replace placeholder paths with actual project path
    sed "s|/opt/odoo-upgrade-cron|$PROJECT_ROOT|g" "$CRON_CONFIG" > "$temp_crontab"
    
    # Ensure the crontab file ends with a newline
    echo "" >> "$temp_crontab"
    
    # Install the crontab
    crontab "$temp_crontab" 2>&1 | tee -a "$LOG_FILE"
    
    # Clean up
    rm -f "$temp_crontab"
    
    log "SUCCESS" "Crontab installed successfully"
}

# Create default crontab if it doesn't exist
create_default_crontab() {
    log "INFO" "Creating default crontab configuration..."
    
    cat > "$CRON_CONFIG" << EOF
# Odoo Upgrade Cron Jobs
# These cron jobs handle automatic updates and maintenance

# Daily system maintenance at 2:00 AM
0 2 * * * $PROJECT_ROOT/scripts/daily-maintenance.sh >> /var/log/odoo-upgrade/daily.log 2>&1

# Weekly Odoo updates on Sunday at 3:00 AM
0 3 * * 0 $PROJECT_ROOT/scripts/weekly-odoo-update.sh >> /var/log/odoo-upgrade/weekly.log 2>&1

# Database backup every day at 1:30 AM
30 1 * * * $PROJECT_ROOT/scripts/backup-odoo.sh --auto >> /var/log/odoo-upgrade/backup.log 2>&1

# System monitoring every hour
0 * * * * $PROJECT_ROOT/scripts/monitor-system.sh >> /var/log/odoo-upgrade/monitor.log 2>&1

# Clean old log files every month on the 1st at midnight
0 0 1 * * find /var/log/odoo-upgrade -name "*.log" -mtime +30 -delete

# Clean old backup files every week (keep 4 weeks)
0 4 * * 0 find $PROJECT_ROOT/backups -name "*.sql" -mtime +28 -delete

EOF
    
    log "INFO" "Default crontab configuration created"
}

# Create monitoring script
create_monitor_script() {
    log "INFO" "Creating system monitoring script..."
    
    cat > "$SCRIPT_DIR/monitor-system.sh" << 'EOF'
#!/bin/bash

# System monitoring script for Odoo

LOG_FILE="/var/log/odoo-upgrade/monitor-$(date +%Y%m%d).log"

# Function to log with timestamp
log_monitor() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Check Odoo service status
if ! systemctl is-active --quiet odoo; then
    log_monitor "WARNING: Odoo service is not running"
    systemctl start odoo && log_monitor "INFO: Odoo service restarted"
else
    log_monitor "INFO: Odoo service is running"
fi

# Check PostgreSQL status
if ! systemctl is-active --quiet postgresql; then
    log_monitor "WARNING: PostgreSQL service is not running"
    systemctl start postgresql && log_monitor "INFO: PostgreSQL service restarted"
fi

# Check disk space
DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
if [[ $DISK_USAGE -gt 80 ]]; then
    log_monitor "WARNING: Disk usage is at ${DISK_USAGE}%"
fi

# Check memory usage
MEMORY_USAGE=$(free | awk 'NR==2{printf "%.2f", $3*100/$2}')
if [[ $(echo "$MEMORY_USAGE > 90" | bc -l) -eq 1 ]]; then
    log_monitor "WARNING: Memory usage is at ${MEMORY_USAGE}%"
fi

# Check if Odoo is responding
if command -v curl &> /dev/null; then
    if ! curl -s -o /dev/null -w "%{http_code}" http://localhost:8069 | grep -q "200\|302"; then
        log_monitor "WARNING: Odoo is not responding on port 8069"
    else
        log_monitor "INFO: Odoo web interface is responding"
    fi
fi

log_monitor "INFO: System monitoring completed"
EOF
    
    chmod +x "$SCRIPT_DIR/monitor-system.sh"
    log "SUCCESS" "System monitoring script created"
}

# Verify cron service
verify_cron_service() {
    log "INFO" "Verifying cron service..."
    
    # Check if cron service is running
    if ! systemctl is-active --quiet cron; then
        log "WARN" "Cron service is not running, starting it..."
        systemctl start cron
        systemctl enable cron
    fi
    
    # Verify crontab installation
    if crontab -l > /dev/null 2>&1; then
        local cron_count=$(crontab -l | grep -c "$PROJECT_ROOT" || true)
        log "INFO" "Found $cron_count Odoo-related cron jobs"
        
        if [[ $cron_count -gt 0 ]]; then
            log "SUCCESS" "Cron jobs installed successfully"
        else
            log "WARN" "No Odoo-related cron jobs found"
        fi
    else
        log "ERROR" "Failed to verify crontab installation"
        exit 1
    fi
}

# Test cron jobs
test_cron_jobs() {
    log "INFO" "Testing cron job execution..."
    
    # Test if backup script works
    if [[ -f "$SCRIPT_DIR/backup-odoo.sh" ]]; then
        log "INFO" "Testing backup script..."
        if sudo -u odoo "$SCRIPT_DIR/backup-odoo.sh" --test 2>&1 | tee -a "$LOG_FILE"; then
            log "SUCCESS" "Backup script test passed"
        else
            log "WARN" "Backup script test failed"
        fi
    fi
    
    # Test monitoring script
    if [[ -f "$SCRIPT_DIR/monitor-system.sh" ]]; then
        log "INFO" "Testing monitoring script..."
        if "$SCRIPT_DIR/monitor-system.sh" 2>&1 | tee -a "$LOG_FILE"; then
            log "SUCCESS" "Monitoring script test passed"
        else
            log "WARN" "Monitoring script test failed"
        fi
    fi
}

# Show cron status
show_cron_status() {
    log "INFO" "Current Cron Configuration"
    log "INFO" "=========================="
    
    # Show installed cron jobs
    log "INFO" "Installed cron jobs:"
    crontab -l | grep -v "^#" | grep -v "^$" | while read -r line; do
        log "INFO" "  $line"
    done
    
    # Show next run times (if available)
    if command -v systemctl &> /dev/null; then
        local next_run=$(systemctl list-timers | grep cron | head -1)
        if [[ -n "$next_run" ]]; then
            log "INFO" "Next cron execution: $next_run"
        fi
    fi
    
    log "INFO" ""
    log "INFO" "Log files will be created in: /var/log/odoo-upgrade/"
    log "INFO" "Monitor logs with: tail -f /var/log/odoo-upgrade/*.log"
}

# Main execution
main() {
    log "INFO" "Starting Odoo cron setup..."
    log "INFO" "Log file: $LOG_FILE"
    
    create_log_dir
    check_root
    check_prerequisites
    make_scripts_executable
    create_monitor_script
    install_crontab
    verify_cron_service
    test_cron_jobs
    show_cron_status
    
    log "SUCCESS" "Odoo cron setup completed successfully!"
    
    echo
    echo -e "${GREEN}Odoo cron setup completed successfully!${NC}"
    echo -e "${BLUE}Cron jobs are now active and will run automatically${NC}"
    echo -e "${BLUE}Monitor logs in: /var/log/odoo-upgrade/${NC}"
    echo -e "${BLUE}Log file: $LOG_FILE${NC}"
}

# Run main function
main "$@"
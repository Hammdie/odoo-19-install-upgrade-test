#!/bin/bash

# Weekly Odoo Update Script
# Performs weekly Odoo updates and maintenance

set -e  # Exit on any error

# Configuration
ODOO_VERSION="19.0"
ODOO_USER="odoo"
ODOO_HOME="/opt/odoo"
ENTERPRISE_PATH="/opt/odoo/enterprise"
LOG_DIR="/var/log/odoo-upgrade"
LOG_FILE="$LOG_DIR/weekly-update-$(date +%Y%m%d-%H%M%S).log"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Backup configuration
BACKUP_BEFORE_UPDATE=true
BACKUP_DIR="$PROJECT_ROOT/backups"

# Pip options (Ubuntu/Debian enforce Externally Managed Env)
# Always use --break-system-packages for system-wide Odoo installation
declare -a PIP_INSTALL_ARGS=("--break-system-packages")

# Also set PEP 668 override environment variable
export PIP_BREAK_SYSTEM_PACKAGES=1

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Update flags
UPDATE_SYSTEM=true
UPDATE_ODOO=true
UPDATE_ADDONS=true
RESTART_SERVICES=true

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

# Log update start
log_start() {
    log "INFO" "========================================"
    log "INFO" "Starting weekly Odoo update - $(date)"
    log "INFO" "========================================"
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
    if [[ ! -d "$ODOO_HOME/odoo" ]]; then
        log "ERROR" "Odoo installation not found at $ODOO_HOME/odoo"
        exit 1
    fi
    
    # Check if Git is available
    if ! command -v git &> /dev/null; then
        log "ERROR" "Git is not installed"
        exit 1
    fi
    
    # Check if Odoo service exists
    if ! systemctl list-unit-files | grep -q "^odoo.service"; then
        log "ERROR" "Odoo service not found"
        exit 1
    fi
    
    log "SUCCESS" "Prerequisites check passed"
}

# Create pre-update backup
create_backup() {
    if [[ "$BACKUP_BEFORE_UPDATE" == true ]]; then
        log "INFO" "Creating backup before update..."
        
        if [[ -f "$SCRIPT_DIR/backup-odoo.sh" ]]; then
            if "$SCRIPT_DIR/backup-odoo.sh" --auto 2>&1 | tee -a "$LOG_FILE"; then
                log "SUCCESS" "Pre-update backup completed"
            else
                log "WARN" "Backup failed, continuing with update"
            fi
        else
            log "WARN" "Backup script not found, skipping backup"
        fi
    else
        log "INFO" "Backup disabled, skipping pre-update backup"
    fi
}

# Update system packages
update_system_packages() {
    if [[ "$UPDATE_SYSTEM" != true ]]; then
        log "INFO" "System update disabled, skipping"
        return 0
    fi
    
    log "INFO" "Updating system packages..."
    
    export DEBIAN_FRONTEND=noninteractive
    
    # Update package lists
    apt update 2>&1 | tee -a "$LOG_FILE"
    
    # Upgrade packages
    apt upgrade -y 2>&1 | tee -a "$LOG_FILE"
    
    # Install security updates
    apt dist-upgrade -y 2>&1 | tee -a "$LOG_FILE"
    
    # Clean up
    apt autoremove -y 2>&1 | tee -a "$LOG_FILE"
    apt autoclean 2>&1 | tee -a "$LOG_FILE"
    
    log "SUCCESS" "System packages updated"
}

# Stop Odoo service
stop_odoo() {
    log "INFO" "Stopping Odoo service..."
    
    if systemctl is-active --quiet odoo; then
        systemctl stop odoo
        
        # Wait for service to stop
        local timeout=30
        while systemctl is-active --quiet odoo && [[ $timeout -gt 0 ]]; do
            sleep 2
            ((timeout-=2))
        done
        
        if systemctl is-active --quiet odoo; then
            log "WARN" "Odoo service did not stop gracefully, forcing stop"
            systemctl kill odoo
            sleep 5
        fi
        
        log "SUCCESS" "Odoo service stopped"
    else
        log "INFO" "Odoo service is not running"
    fi
}

# Start Odoo service
start_odoo() {
    log "INFO" "Starting Odoo service..."
    
    systemctl start odoo
    
    # Wait for service to start
    local timeout=60
    while ! systemctl is-active --quiet odoo && [[ $timeout -gt 0 ]]; do
        sleep 2
        ((timeout-=2))
    done
    
    if systemctl is-active --quiet odoo; then
        log "SUCCESS" "Odoo service started"
        
        # Wait for Odoo to respond
        log "INFO" "Waiting for Odoo to respond..."
        local response_timeout=120
        while [[ $response_timeout -gt 0 ]]; do
            if command -v curl &> /dev/null; then
                local response_code=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8069 || echo "000")
                if [[ "$response_code" =~ ^(200|302)$ ]]; then
                    log "SUCCESS" "Odoo is responding"
                    break
                fi
            fi
            sleep 5
            ((response_timeout-=5))
        done
        
        if [[ $response_timeout -le 0 ]]; then
            log "WARN" "Odoo service started but may not be fully responsive"
        fi
    else
        log "ERROR" "Failed to start Odoo service"
        return 1
    fi
}

# Update Odoo source code
update_odoo_source() {
    if [[ "$UPDATE_ODOO" != true ]]; then
        log "INFO" "Odoo update disabled, skipping"
        return 0
    fi
    
    log "INFO" "Updating Odoo source code..."
    
    cd "$ODOO_HOME/odoo"
    
    # Check current version/commit
    local current_commit=$(git rev-parse HEAD)
    local current_branch=$(git branch --show-current)
    
    log "INFO" "Current branch: $current_branch"
    log "INFO" "Current commit: $current_commit"
    
    # Fetch latest changes
    sudo -u "$ODOO_USER" git fetch origin 2>&1 | tee -a "$LOG_FILE"
    
    # Check if updates are available
    local latest_commit=$(git rev-parse origin/$ODOO_VERSION)
    
    if [[ "$current_commit" == "$latest_commit" ]]; then
        log "INFO" "Odoo source code is already up to date"
        return 0
    fi
    
    log "INFO" "Updates available, updating Odoo source code..."
    log "INFO" "New commit: $latest_commit"
    
    # Stash any local changes
    sudo -u "$ODOO_USER" git stash 2>&1 | tee -a "$LOG_FILE" || true
    
    # Pull latest changes
    if sudo -u "$ODOO_USER" git pull origin "$ODOO_VERSION" 2>&1 | tee -a "$LOG_FILE"; then
        log "SUCCESS" "Odoo source code updated successfully"
        
        # Update Python dependencies
        log "INFO" "Updating Python dependencies..."
        if [[ -f requirements.txt ]]; then
            python3 -m pip install "${PIP_INSTALL_ARGS[@]}" -r requirements.txt --upgrade 2>&1 | tee -a "$LOG_FILE"
        fi
        
        # Reinstall Odoo package
        python3 -m pip install "${PIP_INSTALL_ARGS[@]}" -e . --upgrade 2>&1 | tee -a "$LOG_FILE"
        
        return 0
    else
        log "ERROR" "Failed to update Odoo source code"
        
        # Try to recover
        log "INFO" "Attempting to recover..."
        sudo -u "$ODOO_USER" git reset --hard "$current_commit" 2>&1 | tee -a "$LOG_FILE"
        
        return 1
    fi
}

# Update Odoo Enterprise edition
update_enterprise() {
    # Check if enterprise is installed
    if [[ ! -d "$ENTERPRISE_PATH/.git" ]]; then
        log "INFO" "Enterprise edition not installed, skipping"
        return 0
    fi
    
    log "INFO" "Updating Odoo Enterprise..."
    
    cd "$ENTERPRISE_PATH"
    
    # Check current version/commit
    local current_commit=$(git rev-parse HEAD)
    local current_branch=$(git branch --show-current)
    
    log "INFO" "Enterprise current branch: $current_branch"
    log "INFO" "Enterprise current commit: $current_commit"
    
    # Fetch latest changes
    if sudo -u "$ODOO_USER" git fetch origin 2>&1 | tee -a "$LOG_FILE"; then
        log "INFO" "Enterprise repository fetched"
    else
        log "WARN" "Failed to fetch Enterprise repository (may require SSH access)"
        return 1
    fi
    
    # Check if updates are available
    local latest_commit=$(git rev-parse origin/$ODOO_VERSION)
    
    if [[ "$current_commit" == "$latest_commit" ]]; then
        log "INFO" "Enterprise edition is already up to date"
        return 0
    fi
    
    log "INFO" "Enterprise updates available, updating..."
    log "INFO" "New commit: $latest_commit"
    
    # Stash any local changes
    sudo -u "$ODOO_USER" git stash 2>&1 | tee -a "$LOG_FILE" || true
    
    # Pull latest changes
    if sudo -u "$ODOO_USER" git pull origin "$ODOO_VERSION" 2>&1 | tee -a "$LOG_FILE"; then
        log "SUCCESS" "Enterprise edition updated successfully"
        return 0
    else
        log "ERROR" "Failed to update Enterprise edition"
        
        # Try to recover
        log "INFO" "Attempting to recover..."
        sudo -u "$ODOO_USER" git reset --hard "$current_commit" 2>&1 | tee -a "$LOG_FILE"
        
        return 1
    fi
}

# Update custom addons
update_custom_addons() {
    if [[ "$UPDATE_ADDONS" != true ]]; then
        log "INFO" "Addon update disabled, skipping"
        return 0
    fi
    
    log "INFO" "Checking for custom addon updates..."
    
    local addons_dir="$ODOO_HOME/custom-addons"
    local updated_count=0
    
    if [[ -d "$addons_dir" ]]; then
        # Find Git repositories in custom addons
        while IFS= read -r -d '' addon_dir; do
            if [[ -d "$addon_dir/.git" ]]; then
                local addon_name=$(basename "$addon_dir")
                log "INFO" "Updating addon: $addon_name"
                
                cd "$addon_dir"
                
                # Fetch and pull updates
                if sudo -u "$ODOO_USER" git fetch 2>&1 | tee -a "$LOG_FILE" && \
                   sudo -u "$ODOO_USER" git pull 2>&1 | tee -a "$LOG_FILE"; then
                    log "SUCCESS" "Updated addon: $addon_name"
                    ((updated_count++))
                else
                    log "WARN" "Failed to update addon: $addon_name"
                fi
            fi
        done < <(find "$addons_dir" -maxdepth 1 -type d -print0 2>/dev/null)
        
        log "INFO" "Updated $updated_count custom addons"
    else
        log "INFO" "Custom addons directory not found"
    fi
}

# Update database modules
update_database_modules() {
    log "INFO" "Checking for database module updates..."
    
    # Get list of databases
    local databases
    mapfile -t databases < <(sudo -u "$ODOO_USER" psql -h localhost -p 5432 -U "$ODOO_USER" -lqt | cut -d \| -f 1 | grep -vwE 'postgres|template[0-1]|Name' | sed '/^$/d' | tr -d ' ')
    
    if [[ ${#databases[@]} -eq 0 ]]; then
        log "INFO" "No databases found for module updates"
        return 0
    fi
    
    log "INFO" "Found ${#databases[@]} database(s) for module updates"
    
    for db in "${databases[@]}"; do
        log "INFO" "Updating modules in database: $db"
        
        # Update all modules in the database
        if sudo -u "$ODOO_USER" python3 "$ODOO_HOME/odoo/odoo-bin" -d "$db" -u all --stop-after-init 2>&1 | tee -a "$LOG_FILE"; then
            log "SUCCESS" "Modules updated in database: $db"
        else
            log "WARN" "Failed to update modules in database: $db"
        fi
    done
}

# Check for configuration updates
check_config_updates() {
    log "INFO" "Checking configuration updates..."
    
    local config_file="/etc/odoo/odoo.conf"
    local example_config="$PROJECT_ROOT/config/odoo.conf.example"
    
    if [[ -f "$example_config" && -f "$config_file" ]]; then
        # Check if example config has been updated
        if [[ "$example_config" -nt "$config_file" ]]; then
            log "INFO" "Example configuration is newer than current config"
            log "INFO" "Consider reviewing configuration updates in: $example_config"
        else
            log "INFO" "Configuration is up to date"
        fi
    fi
}

# Restart related services
restart_services() {
    if [[ "$RESTART_SERVICES" != true ]]; then
        log "INFO" "Service restart disabled, skipping"
        return 0
    fi
    
    log "INFO" "Restarting related services..."
    
    # Restart PostgreSQL if needed
    log "INFO" "Restarting PostgreSQL..."
    systemctl restart postgresql
    
    # Wait for PostgreSQL to be ready
    sleep 10
    
    # Restart Odoo
    start_odoo
    
    log "SUCCESS" "Services restarted"
}

# Post-update checks
post_update_checks() {
    log "INFO" "Performing post-update checks..."
    
    # Check service status
    local odoo_status=$(systemctl is-active odoo)
    local postgres_status=$(systemctl is-active postgresql)
    
    log "INFO" "Service status after update:"
    log "INFO" "- Odoo: $odoo_status"
    log "INFO" "- PostgreSQL: $postgres_status"
    
    # Check if Odoo is responding
    if command -v curl &> /dev/null; then
        local response_code=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8069 || echo "000")
        if [[ "$response_code" =~ ^(200|302)$ ]]; then
            log "SUCCESS" "Odoo web interface is responding"
        else
            log "WARN" "Odoo web interface not responding (HTTP $response_code)"
        fi
    fi
    
    # Check log files for errors
    if [[ -f /var/log/odoo/odoo.log ]]; then
        local error_count=$(tail -100 /var/log/odoo/odoo.log | grep -c "ERROR" || echo "0")
        if [[ $error_count -gt 0 ]]; then
            log "WARN" "Found $error_count errors in recent Odoo logs"
        else
            log "INFO" "No recent errors found in Odoo logs"
        fi
    fi
    
    log "SUCCESS" "Post-update checks completed"
}

# Generate update report
generate_report() {
    log "INFO" "========================================"
    log "INFO" "Weekly Update Summary"
    log "INFO" "========================================"
    
    # System information
    local uptime_info=$(uptime -p)
    local odoo_version=""
    
    if [[ -f "$ODOO_HOME/odoo/odoo-bin" ]]; then
        odoo_version=$(sudo -u "$ODOO_USER" python3 "$ODOO_HOME/odoo/odoo-bin" --version 2>/dev/null | head -1 || echo "Unknown")
    fi
    
    log "INFO" "Update Summary:"
    log "INFO" "- Date: $(date)"
    log "INFO" "- System uptime: $uptime_info"
    log "INFO" "- Odoo version: $odoo_version"
    
    # Service status
    local odoo_status=$(systemctl is-active odoo)
    local postgres_status=$(systemctl is-active postgresql)
    
    log "INFO" "Final Service Status:"
    log "INFO" "- Odoo: $odoo_status"
    log "INFO" "- PostgreSQL: $postgres_status"
    
    # Database count
    local db_count=$(sudo -u "$ODOO_USER" psql -h localhost -p 5432 -U "$ODOO_USER" -lqt | cut -d \| -f 1 | grep -vwE 'postgres|template[0-1]|Name' | sed '/^$/d' | wc -l)
    log "INFO" "- Databases: $db_count"
    
    log "INFO" "Update completed at: $(date)"
    log "INFO" "Log file: $LOG_FILE"
    log "INFO" "========================================"
}

# Handle errors
handle_error() {
    local exit_code=$?
    log "ERROR" "Update failed with exit code: $exit_code"
    
    # Try to start Odoo if it's not running
    if ! systemctl is-active --quiet odoo; then
        log "INFO" "Attempting to start Odoo service..."
        start_odoo || true
    fi
    
    exit $exit_code
}

# Main execution
main() {
    create_log_dir
    log_start
    
    # Set error handler
    trap handle_error ERR
    
    check_root
    check_prerequisites
    
    # Create backup before update
    create_backup
    
    # Stop Odoo for updates
    stop_odoo
    
    # Perform updates
    update_system_packages
    update_odoo_source
    update_enterprise
    update_custom_addons
    check_config_updates
    
    # Update database modules
    update_database_modules
    
    # Restart services
    restart_services
    
    # Post-update checks
    post_update_checks
    
    # Generate report
    generate_report
    
    log "SUCCESS" "Weekly Odoo update completed successfully!"
}

# Run main function
main "$@"
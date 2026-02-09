#!/bin/bash

###############################################################################
# Odoo Configuration Setup Script
# 
# Ersetzt die Standard-Odoo-Konfiguration mit einer angepassten Version
# Verwendet die Datei config/odoo.conf.example als Vorlage
#
# Features:
# - Backup der ursprünglichen Konfiguration
# - Installation der benutzerdefinierten Konfiguration
# - Erstellung aller notwendigen Verzeichnisse
# - Korrekte Berechtigungen und Ownership
# - Service-Neustart
#
# Usage:
#   sudo ./setup-odoo-config.sh
###############################################################################

set -e  # Exit on any error

# Configuration
LOG_DIR="/var/log/odoo-upgrade"
LOG_FILE="$LOG_DIR/config-setup-$(date +%Y%m%d-%H%M%S).log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
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
    if [ ! -d "$LOG_DIR" ]; then
        mkdir -p "$LOG_DIR"
        chmod 755 "$LOG_DIR"
    fi
}

# Check if running as root
check_root() {
    if [ "$(id -u)" != "0" ]; then
        echo -e "${RED}This script must be run as root or with sudo${NC}"
        echo -e "Please run: ${YELLOW}sudo $0${NC}"
        exit 1
    fi
}

# Display banner
show_banner() {
    clear
    echo -e "${CYAN}${BOLD}"
    cat << 'EOF'
   ____                  __ _       
  / ___|___  _ __   ___  / _(_) __ _ 
 | |   / _ \| '_ \ / _ \| |_| |/ _` |
 | |__| (_) | | | |  __/  _| | (_| |
  \____\___/|_| |_|\___|_| |_|\__, |
                              |___/ 
    Setup Script                    
EOF
    echo -e "${NC}"
    echo -e "${GREEN}Odoo Configuration Setup${NC}"
    echo -e "${BLUE}Ersetzt Standard-Konfiguration mit angepasster Version${NC}"
    echo
}

# Check prerequisites
check_prerequisites() {
    log "INFO" "Checking prerequisites..."
    
    # Check if Odoo is installed
    if [ ! -f /etc/odoo/odoo.conf ] && [ ! -d /opt/odoo ]; then
        log "ERROR" "✗ Odoo is not installed on this system"
        echo -e "${RED}Please install Odoo first:${NC}"
        echo -e "  ${GREEN}sudo ./install-official-odoo.sh${NC}"
        exit 1
    fi
    
    # Check if odoo user exists
    if ! id odoo >/dev/null 2>&1; then
        log "ERROR" "✗ Odoo user does not exist"
        exit 1
    fi
    
    log "SUCCESS" "✓ Prerequisites satisfied"
}

# Find and validate config source
find_config_source() {
    local script_dir=$(dirname "$(readlink -f "$0")" 2>/dev/null) || local script_dir=$(dirname "$0")
    local config_source="$script_dir/config/odoo.conf.example"
    
    log "INFO" "Looking for config source: $config_source"
    
    if [ -f "$config_source" ]; then
        log "SUCCESS" "✓ Found configuration source: $config_source"
        echo "$config_source"
    else
        log "ERROR" "✗ Configuration source not found: $config_source"
        echo -e "${RED}Please ensure config/odoo.conf.example exists${NC}"
        exit 1
    fi
}

# Backup existing configuration
backup_existing_config() {
    local config_target="/etc/odoo/odoo.conf"
    
    if [ -f "$config_target" ]; then
        local backup_file="$config_target.backup.$(date +%Y%m%d-%H%M%S)"
        log "INFO" "Backing up existing configuration..."
        
        if cp "$config_target" "$backup_file" 2>&1 | tee -a "$LOG_FILE"; then
            log "SUCCESS" "✓ Configuration backed up to: $backup_file"
        else
            log "ERROR" "✗ Failed to backup configuration"
            return 1
        fi
    else
        log "INFO" "No existing configuration to backup"
    fi
}

# Stop Odoo service
stop_odoo_service() {
    log "INFO" "Stopping Odoo service..."
    
    if systemctl stop odoo 2>&1 | tee -a "$LOG_FILE"; then
        log "SUCCESS" "✓ Odoo service stopped"
    else
        log "WARN" "⚠ Failed to stop Odoo service (may not be running)"
    fi
    
    # Wait a moment for service to stop
    sleep 2
}

# Get admin password from user
get_admin_password() {
    log "INFO" "Admin password configuration..."
    
    echo -e "${YELLOW}Enter admin password for Odoo master password:${NC}"
    echo -e "${BLUE}This password will be used for database operations and admin access.${NC}"
    echo -e "${BLUE}Leave empty to use default 'admin123'${NC}"
    echo
    
    # First attempt - use stty for password input
    echo -n "Admin Password: "
    stty -echo
    read admin_pass1
    stty echo
    echo
    
    # If empty, use default
    if [ -z "$admin_pass1" ]; then
        admin_pass1="admin123"
        log "INFO" "Using default password"
    else
        # Confirm password
        echo -n "Confirm Password: "
        stty -echo
        read admin_pass2
        stty echo
        echo
        
        # Check if passwords match
        if [ "$admin_pass1" != "$admin_pass2" ]; then
            log "ERROR" "Passwords do not match!"
            echo -e "${RED}Passwords do not match. Please try again.${NC}"
            echo
            get_admin_password
            return
        fi
        
        log "SUCCESS" "Password confirmed"
    fi
    
    # Store password globally
    ADMIN_PASSWORD="$admin_pass1"
    echo
}

# Install new configuration
install_configuration() {
    local config_source="$1"
    local config_target="/etc/odoo/odoo.conf"
    local temp_config="/tmp/odoo.conf.temp"
    
    log "INFO" "Installing new configuration..."
    
    # Ensure config directory exists
    if [ ! -d "$(dirname "$config_target")" ]; then
        mkdir -p "$(dirname "$config_target")"
    fi
    
    # Copy configuration to temp file first
    if cp "$config_source" "$temp_config" 2>&1 | tee -a "$LOG_FILE"; then
        log "SUCCESS" "✓ Configuration copied to temporary file"
    else
        log "ERROR" "✗ Failed to copy configuration"
        return 1
    fi
    
    # Replace the admin password in the temp file
    log "INFO" "Setting admin password in configuration..."
    if sed -i "s/change_me_admin_password/$ADMIN_PASSWORD/g" "$temp_config" 2>&1 | tee -a "$LOG_FILE"; then
        log "SUCCESS" "✓ Admin password configured"
    else
        log "ERROR" "✗ Failed to set admin password"
        rm -f "$temp_config"
        return 1
    fi
    
    # Move temp file to final location
    if mv "$temp_config" "$config_target" 2>&1 | tee -a "$LOG_FILE"; then
        log "SUCCESS" "✓ Configuration installed: $config_target"
    else
        log "ERROR" "✗ Failed to install configuration"
        rm -f "$temp_config"
        return 1
    fi
    
    # Set proper ownership and permissions
    chown odoo:odoo "$config_target"
    chmod 640 "$config_target"
    log "SUCCESS" "✓ Configuration permissions set"
}

# Create directories from configuration
create_directories() {
    log "INFO" "Creating directories based on configuration..."
    
    # Create directories one by one for shell compatibility
    create_single_directory "/var/log/odoo" "odoo" "odoo" "755"
    create_single_directory "/var/lib/odoo" "odoo" "odoo" "755"
    create_single_directory "/opt/odoo" "odoo" "odoo" "755"
    create_single_directory "/opt/odoo/addons" "odoo" "odoo" "755"
    create_single_directory "/opt/odoo/enterprise" "odoo" "odoo" "755"
    create_single_directory "/var/odoo_addons" "odoo" "odoo" "755"
}

# Helper function to create a single directory
create_single_directory() {
    local dir_path="$1"
    local dir_owner="$2"
    local dir_group="$3"
    local dir_perms="$4"
    
    if [ ! -d "$dir_path" ]; then
        if mkdir -p "$dir_path" 2>&1 | tee -a "$LOG_FILE"; then
            chown "$dir_owner:$dir_group" "$dir_path"
            chmod "$dir_perms" "$dir_path"
            log "SUCCESS" "✓ Created directory: $dir_path"
        else
            log "ERROR" "✗ Failed to create directory: $dir_path"
        fi
    else
        # Ensure correct ownership even if directory exists
        chown "$dir_owner:$dir_group" "$dir_path"
        chmod "$dir_perms" "$dir_path"
        log "SUCCESS" "✓ Directory exists and updated: $dir_path"
    fi
}

# Start Odoo service
start_odoo_service() {
    log "INFO" "Starting Odoo service..."
    
    if systemctl start odoo 2>&1 | tee -a "$LOG_FILE"; then
        log "SUCCESS" "✓ Odoo service started"
    else
        log "ERROR" "✗ Failed to start Odoo service"
        return 1
    fi
    
    # Wait for service to stabilize
    sleep 5
    
    # Check service status
    local service_status=$(systemctl is-active odoo 2>/dev/null || echo "unknown")
    case $service_status in
        "active")
            log "SUCCESS" "✓ Odoo service is running"
            ;;
        "activating")
            log "INFO" "Odoo service is starting up..."
            ;;
        *)
            log "WARN" "⚠ Odoo service status: $service_status"
            ;;
    esac
}

# Validate configuration
validate_configuration() {
    log "INFO" "Validating new configuration..."
    
    local config_file="/etc/odoo/odoo.conf"
    
    # Check if config file is readable
    if [ ! -r "$config_file" ]; then
        log "ERROR" "✗ Configuration file is not readable"
        return 1
    fi
    
    # Check for key configuration parameters using simple approach
    local missing_params=""
    
    if ! grep -q "^db_host" "$config_file"; then
        missing_params="$missing_params db_host"
    fi
    
    if ! grep -q "^db_port" "$config_file"; then
        missing_params="$missing_params db_port"
    fi
    
    if ! grep -q "^xmlrpc_port" "$config_file"; then
        missing_params="$missing_params xmlrpc_port"
    fi
    
    if ! grep -q "^addons_path" "$config_file"; then
        missing_params="$missing_params addons_path"
    fi
    
    if [ -n "$missing_params" ]; then
        log "WARN" "⚠ Missing configuration parameters:$missing_params"
    else
        log "SUCCESS" "✓ All required configuration parameters present"
    fi
    
    # Display key configuration values
    log "INFO" "Configuration summary:"
    
    local db_host=$(grep "^db_host" "$config_file" | cut -d'=' -f2- | xargs 2>/dev/null || echo "not set")
    log "INFO" "  db_host = $db_host"
    
    local db_port=$(grep "^db_port" "$config_file" | cut -d'=' -f2- | xargs 2>/dev/null || echo "not set")
    log "INFO" "  db_port = $db_port"
    
    local xmlrpc_port=$(grep "^xmlrpc_port" "$config_file" | cut -d'=' -f2- | xargs 2>/dev/null || echo "not set")
    log "INFO" "  xmlrpc_port = $xmlrpc_port"
    
    local addons_path=$(grep "^addons_path" "$config_file" | cut -d'=' -f2- | xargs 2>/dev/null || echo "not set")
    log "INFO" "  addons_path = $addons_path"
}

# Show summary
show_summary() {
    local service_status=$(systemctl is-active odoo 2>/dev/null || echo "unknown")
    
    echo
    echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}${BOLD}  Odoo Configuration Setup Completed!${NC}"
    echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo
    echo -e "${BLUE}Configuration Details:${NC}"
    echo -e "  📁 Config file: ${GREEN}/etc/odoo/odoo.conf${NC}"
    echo -e "  📁 Log directory: ${GREEN}/var/log/odoo/${NC}"
    echo -e "  📁 Data directory: ${GREEN}/var/lib/odoo${NC}"
    echo -e "  📁 Addons paths: ${GREEN}/usr/lib/python3/dist-packages/odoo/addons,/opt/odoo/addons,/opt/odoo/enterprise,/var/odoo_addons${NC}"
    echo
    echo -e "${BLUE}Service Status:${NC}"
    if [ "$service_status" = "active" ]; then
        echo -e "  🟢 Odoo Service: ${GREEN}Running${NC}"
        
        # Check if port is listening
        if ss -tuln 2>/dev/null | grep -q ":8069 "; then
            echo -e "  🌐 Port 8069: ${GREEN}Listening${NC}"
        else
            echo -e "  🌐 Port 8069: ${YELLOW}Not yet listening${NC}"
        fi
    else
        echo -e "  🔴 Odoo Service: ${RED}$service_status${NC}"
    fi
    echo
    echo -e "${BLUE}Configuration Features:${NC}"
    echo -e "  ⚡ Workers: ${GREEN}4 (optimized for production)${NC}"
    echo -e "  🔒 Memory limits: ${GREEN}2.5GB hard, 2GB soft${NC}"
    echo -e "  📊 Logging: ${GREEN}File-based (/var/log/odoo/odoo.log)${NC}"
    echo -e "  🚀 Performance tuning: ${GREEN}Enabled${NC}"
    echo -e "  🔐 Security: ${GREEN}Admin password configured${NC}"
    echo
    echo -e "${BLUE}Next Steps:${NC}"
    echo -e "  🌐 Access Odoo: ${GREEN}http://localhost:8069${NC}"
    echo -e "  🔑 Master Password: ${GREEN}[Set during configuration]${NC}"
    echo -e "  🔧 Check service: ${GREEN}sudo systemctl status odoo${NC}"
    echo -e "  📋 View logs: ${GREEN}sudo journalctl -u odoo -f${NC}"
    echo
    echo -e "${BLUE}Log File:${NC} ${GREEN}$LOG_FILE${NC}"
    echo
}

# Main function
main() {
    # Create log directory first
    mkdir -p "$LOG_DIR" 2>/dev/null || true
    chmod 755 "$LOG_DIR" 2>/dev/null || true
    
    # Show banner
    show_banner
    
    # Check root
    check_root
    
    # Call create_log_dir for consistency
    create_log_dir
    
    # Start logging
    log "INFO" "Starting Odoo configuration setup"
    log "INFO" "Log file: $LOG_FILE"
    
    echo -e "${BLUE}Starting configuration setup...${NC}"
    echo
    
    # Setup steps
    check_prerequisites
    
    local config_source
    config_source=$(find_config_source)
    
    # Get admin password from user
    get_admin_password
    
    backup_existing_config
    
    stop_odoo_service
    
    if install_configuration "$config_source"; then
        log "SUCCESS" "Configuration installation completed"
    else
        log "ERROR" "Configuration installation failed"
        exit 1
    fi
    
    create_directories
    
    validate_configuration
    
    start_odoo_service
    
    # Show summary
    show_summary
    
    log "SUCCESS" "Odoo configuration setup completed successfully!"
}

# Run main function
main "$@"
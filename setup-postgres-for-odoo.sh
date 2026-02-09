#!/bin/bash

###############################################################################
# PostgreSQL Setup für Odoo
# 
# Richtet PostgreSQL-Benutzer und -Berechtigungen für Odoo ein
# Behebt Authentifizierungsprobleme zwischen Odoo und PostgreSQL
#
# Usage:
#   sudo ./setup-postgres-for-odoo.sh
###############################################################################

set -e  # Exit on any error

# Configuration
LOG_DIR="/var/log/odoo-upgrade"
LOG_FILE="$LOG_DIR/postgres-setup-$(date +%Y%m%d-%H%M%S).log"

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
  _____           _                  _____ _____ _      
 |  __ \         | |                / ____|  _  | |     
 | |__) |__  ___ | |_ __ _ _ __ ___  | (___ | | | | |     
 |  ___/ _ \/ __|| __/ _` | '__/ _ \  \___ \| | | | |     
 | |  | (_) \__ \| || (_| | | |  __/  ____) \ \/' / |____ 
 |_|   \___/|___/ \__\__, |_|  \___| |_____/ \_/\_\______|
                      __/ |                              
                     |___/                               
EOF
    echo -e "${NC}"
    echo -e "${GREEN}PostgreSQL Setup für Odoo${NC}"
    echo -e "${BLUE}Behebt Datenbank-Authentifizierungsprobleme${NC}"
    echo
}

# Check PostgreSQL service
check_postgresql_service() {
    log "INFO" "Checking PostgreSQL service..."
    
    if systemctl is-active postgresql >/dev/null 2>&1; then
        log "SUCCESS" "✓ PostgreSQL service is running"
    else
        log "WARN" "⚠ PostgreSQL service is not running - starting it..."
        if systemctl start postgresql 2>&1 | tee -a "$LOG_FILE"; then
            log "SUCCESS" "✓ PostgreSQL service started"
        else
            log "ERROR" "✗ Failed to start PostgreSQL service"
            return 1
        fi
    fi
    
    # Enable PostgreSQL to start on boot
    systemctl enable postgresql >/dev/null 2>&1 || true
}

# Check if odoo user exists
check_odoo_user() {
    log "INFO" "Checking if system user 'odoo' exists..."
    
    if id odoo >/dev/null 2>&1; then
        log "SUCCESS" "✓ System user 'odoo' exists"
    else
        log "ERROR" "✗ System user 'odoo' does not exist"
        echo -e "${RED}Please install Odoo first or create the odoo user${NC}"
        exit 1
    fi
}

# Create PostgreSQL user and database
setup_postgresql_user() {
    log "INFO" "Setting up PostgreSQL user and database..."
    
    # Check if PostgreSQL user 'odoo' exists
    if sudo -u postgres psql -t -c "SELECT 1 FROM pg_roles WHERE rolname='odoo'" | grep -q 1; then
        log "SUCCESS" "✓ PostgreSQL user 'odoo' exists"
        
        # Update user to ensure it has the right permissions
        log "INFO" "Updating PostgreSQL user permissions..."
        sudo -u postgres psql -c "ALTER USER odoo CREATEDB;" 2>&1 | tee -a "$LOG_FILE" || true
        sudo -u postgres psql -c "ALTER USER odoo PASSWORD 'odoo';" 2>&1 | tee -a "$LOG_FILE"
        log "SUCCESS" "✓ PostgreSQL user permissions updated"
    else
        log "INFO" "Creating PostgreSQL user 'odoo'..."
        if sudo -u postgres createuser --createdb --login --no-createrole --no-superuser odoo 2>&1 | tee -a "$LOG_FILE"; then
            log "SUCCESS" "✓ PostgreSQL user 'odoo' created"
        else
            log "ERROR" "✗ Failed to create PostgreSQL user"
            return 1
        fi
        
        # Set password for the user
        log "INFO" "Setting password for PostgreSQL user 'odoo'..."
        if sudo -u postgres psql -c "ALTER USER odoo PASSWORD 'odoo';" 2>&1 | tee -a "$LOG_FILE"; then
            log "SUCCESS" "✓ Password set for PostgreSQL user 'odoo'"
        else
            log "ERROR" "✗ Failed to set password"
            return 1
        fi
    fi
}

# Configure PostgreSQL authentication
configure_pg_hba() {
    log "INFO" "Configuring PostgreSQL authentication..."
    
    local pg_hba_file="/etc/postgresql/*/main/pg_hba.conf"
    local pg_hba_found=""
    
    # Find the actual pg_hba.conf file
    for file in $pg_hba_file; do
        if [ -f "$file" ]; then
            pg_hba_found="$file"
            break
        fi
    done
    
    if [ -z "$pg_hba_found" ]; then
        log "ERROR" "✗ Could not find pg_hba.conf file"
        return 1
    fi
    
    log "INFO" "Found pg_hba.conf: $pg_hba_found"
    
    # Backup original file
    if [ ! -f "$pg_hba_found.backup" ]; then
        cp "$pg_hba_found" "$pg_hba_found.backup"
        log "SUCCESS" "✓ Backup created: $pg_hba_found.backup"
    fi
    
    # Check if odoo-specific rules already exist
    if grep -q "# Odoo configuration" "$pg_hba_found"; then
        log "SUCCESS" "✓ Odoo configuration already exists in pg_hba.conf"
    else
        log "INFO" "Adding Odoo configuration to pg_hba.conf..."
        
        # Add Odoo-specific authentication rules
        cat >> "$pg_hba_found" << EOF

# Odoo configuration
local   all             odoo                                    md5
host    all             odoo            127.0.0.1/32            md5
host    all             odoo            ::1/128                 md5
EOF
        log "SUCCESS" "✓ Odoo configuration added to pg_hba.conf"
        
        # Reload PostgreSQL configuration
        log "INFO" "Reloading PostgreSQL configuration..."
        if systemctl reload postgresql 2>&1 | tee -a "$LOG_FILE"; then
            log "SUCCESS" "✓ PostgreSQL configuration reloaded"
        else
            log "ERROR" "✗ Failed to reload PostgreSQL configuration"
            return 1
        fi
    fi
}

# Test database connection
test_database_connection() {
    log "INFO" "Testing database connection..."
    
    # Test connection as odoo user
    export PGPASSWORD="odoo"
    
    if psql -h localhost -U odoo -d postgres -c "SELECT version();" >/dev/null 2>&1; then
        log "SUCCESS" "✓ Database connection test successful"
        
        # Show PostgreSQL version
        local pg_version=$(psql -h localhost -U odoo -d postgres -t -c "SELECT version();" 2>/dev/null | head -1 | xargs)
        log "INFO" "PostgreSQL version: $pg_version"
        
        return 0
    else
        log "ERROR" "✗ Database connection test failed"
        
        # Try to get more detailed error
        log "INFO" "Attempting detailed connection test..."
        psql -h localhost -U odoo -d postgres -c "SELECT 1;" 2>&1 | tee -a "$LOG_FILE" || true
        
        return 1
    fi
    
    unset PGPASSWORD
}

# Update Odoo configuration
update_odoo_config() {
    log "INFO" "Checking Odoo configuration..."
    
    local config_file="/etc/odoo/odoo.conf"
    
    if [ ! -f "$config_file" ]; then
        log "WARN" "⚠ Odoo configuration file not found: $config_file"
        return 0
    fi
    
    # Check current database settings
    local current_db_host=$(grep "^db_host" "$config_file" | cut -d'=' -f2 | xargs 2>/dev/null || echo "not set")
    local current_db_user=$(grep "^db_user" "$config_file" | cut -d'=' -f2 | xargs 2>/dev/null || echo "not set")
    local current_db_password=$(grep "^db_password" "$config_file" | cut -d'=' -f2 | xargs 2>/dev/null || echo "not set")
    
    log "INFO" "Current configuration:"
    log "INFO" "  db_host = $current_db_host"
    log "INFO" "  db_user = $current_db_user"
    log "INFO" "  db_password = $current_db_password"
    
    # If config looks good, don't change it
    if [ "$current_db_host" = "localhost" ] && [ "$current_db_user" = "odoo" ] && [ "$current_db_password" = "odoo" ]; then
        log "SUCCESS" "✓ Odoo configuration is already correct"
    else
        log "WARN" "⚠ Odoo configuration may need updating"
        echo -e "${YELLOW}Consider running: sudo sh setup-odoo-config.sh${NC}"
    fi
}

# Show summary
show_summary() {
    echo
    echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}${BOLD}  PostgreSQL Setup für Odoo abgeschlossen!${NC}"
    echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo
    echo -e "${BLUE}Database Konfiguration:${NC}"
    echo -e "  🐘 PostgreSQL: ${GREEN}Running${NC}"
    echo -e "  👤 User: ${GREEN}odoo${NC}"
    echo -e "  🔑 Password: ${GREEN}odoo${NC}"
    echo -e "  🔌 Host: ${GREEN}localhost:5432${NC}"
    echo
    
    # Test final connection
    export PGPASSWORD="odoo"
    if psql -h localhost -U odoo -d postgres -c "SELECT 1;" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Database connection: Working${NC}"
        echo
        echo -e "${BLUE}Next Steps:${NC}"
        echo -e "  🔄 Restart Odoo: ${GREEN}sudo systemctl restart odoo${NC}"
        echo -e "  📋 Check status: ${GREEN}sudo systemctl status odoo${NC}"
        echo -e "  📄 View logs: ${GREEN}sudo tail -f /var/log/odoo/odoo-server.log${NC}"
    else
        echo -e "${RED}❌ Database connection: Still failing${NC}"
        echo
        echo -e "${BLUE}Troubleshooting:${NC}"
        echo -e "  📋 Check logs: ${GREEN}$LOG_FILE${NC}"
        echo -e "  🔧 Manual test: ${GREEN}sudo -u postgres psql${NC}"
    fi
    unset PGPASSWORD
    
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
    log "INFO" "Starting PostgreSQL setup for Odoo"
    log "INFO" "Log file: $LOG_FILE"
    
    echo -e "${BLUE}Starting PostgreSQL setup...${NC}"
    echo
    
    # Setup steps
    check_postgresql_service
    check_odoo_user
    setup_postgresql_user
    configure_pg_hba
    
    # Wait a moment for configuration to take effect
    sleep 2
    
    if test_database_connection; then
        log "SUCCESS" "PostgreSQL setup completed successfully"
    else
        log "ERROR" "PostgreSQL setup completed but connection test failed"
    fi
    
    update_odoo_config
    
    # Show summary
    show_summary
    
    log "SUCCESS" "PostgreSQL setup process completed!"
}

# Run main function
main "$@"
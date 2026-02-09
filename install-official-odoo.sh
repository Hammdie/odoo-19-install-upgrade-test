#!/bin/bash

###############################################################################
# Automatische Odoo 19.0 Installation via offizielles Paket
# 
# Installiert Odoo 19.0 über das offizielle Odoo Repository ohne Benutzer-Prompts
# Folgt der offiziellen Odoo-Dokumentation für Debian/Ubuntu
#
# Features:
# - Vollautomatisch ohne Prompts
# - PostgreSQL Installation und Konfiguration
# - Offizielles Odoo Repository Setup
# - Automatischer Service-Start
# - Umfassende Tests am Ende
#
# Usage:
#   sudo ./install-official-odoo.sh
###############################################################################

set -e  # Exit on any error

# Configuration
LOG_DIR="/var/log/odoo-upgrade"
LOG_FILE="$LOG_DIR/official-install-$(date +%Y%m%d-%H%M%S).log"

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
    if [[ ! -d "$LOG_DIR" ]]; then
        mkdir -p "$LOG_DIR"
        chmod 755 "$LOG_DIR"
    fi
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
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
   ____  _____  ______ _____ _____ _____ _____          _      
  / __ \|  ___|  ____|_   _/ ____|_   _|  __ \        | |     
 | |  | | |_  | |__    | || |      | | | |__) |       | |     
 | |  | |  _| |  __|   | || |      | | |  _  /        | |     
 | |__| | |   | |     _| || |____ _| |_| | \ \        | |____ 
  \____/|_|   |_|    |_____\_____|_____|_|  \_\       |______|
                                                              
EOF
    echo -e "${NC}"
    echo -e "${GREEN}Automatische Installation von Odoo 19.0 (Offizielles Paket)${NC}"
    echo -e "${BLUE}Folgt der offiziellen Odoo-Dokumentation für Ubuntu/Debian${NC}"
    echo
}

# Update system packages
update_system() {
    log "INFO" "Updating system packages..."
    
    # Set noninteractive mode to avoid prompts
    export DEBIAN_FRONTEND=noninteractive
    
    # Update package list
    if apt update 2>&1 | tee -a "$LOG_FILE"; then
        log "SUCCESS" "✓ Package list updated"
    else
        log "ERROR" "✗ Failed to update package list"
        return 1
    fi
    
    # Install essential packages
    log "INFO" "Installing essential packages..."
    if apt install -y curl wget gnupg2 software-properties-common 2>&1 | tee -a "$LOG_FILE"; then
        log "SUCCESS" "✓ Essential packages installed"
    else
        log "ERROR" "✗ Failed to install essential packages"
        return 1
    fi
}

# Install PostgreSQL
install_postgresql() {
    log "INFO" "Installing PostgreSQL server..."
    
    # Check if PostgreSQL is already installed
    if command -v psql &>/dev/null; then
        log "SUCCESS" "✓ PostgreSQL already installed"
        return 0
    fi
    
    # Install PostgreSQL
    if apt install -y postgresql postgresql-contrib 2>&1 | tee -a "$LOG_FILE"; then
        log "SUCCESS" "✓ PostgreSQL installed successfully"
    else
        log "ERROR" "✗ Failed to install PostgreSQL"
        return 1
    fi
    
    # Start and enable PostgreSQL
    systemctl start postgresql
    systemctl enable postgresql
    
    # Verify PostgreSQL is running
    if systemctl is-active postgresql &>/dev/null; then
        log "SUCCESS" "✓ PostgreSQL service is running"
    else
        log "ERROR" "✗ PostgreSQL service failed to start"
        return 1
    fi
}

# Setup Odoo repository
setup_odoo_repository() {
    log "INFO" "Setting up official Odoo repository..."
    
    # Download and install GPG key
    log "INFO" "Adding Odoo GPG key..."
    if wget -q -O - https://nightly.odoo.com/odoo.key | gpg --dearmor -o /usr/share/keyrings/odoo-archive-keyring.gpg 2>&1 | tee -a "$LOG_FILE"; then
        log "SUCCESS" "✓ Odoo GPG key added"
    else
        log "ERROR" "✗ Failed to add Odoo GPG key"
        return 1
    fi
    
    # Add repository to sources list
    log "INFO" "Adding Odoo repository..."
    echo 'deb [signed-by=/usr/share/keyrings/odoo-archive-keyring.gpg] https://nightly.odoo.com/19.0/nightly/deb/ ./' > /etc/apt/sources.list.d/odoo.list
    
    if [[ -f /etc/apt/sources.list.d/odoo.list ]]; then
        log "SUCCESS" "✓ Odoo repository added"
    else
        log "ERROR" "✗ Failed to add Odoo repository"
        return 1
    fi
    
    # Update package list with new repository
    log "INFO" "Updating package list with Odoo repository..."
    if apt update 2>&1 | tee -a "$LOG_FILE"; then
        log "SUCCESS" "✓ Package list updated with Odoo repository"
    else
        log "ERROR" "✗ Failed to update package list"
        return 1
    fi
}

# Install Odoo
install_odoo() {
    log "INFO" "Installing Odoo 19.0..."
    
    # Install Odoo package
    if apt install -y odoo 2>&1 | tee -a "$LOG_FILE"; then
        log "SUCCESS" "✓ Odoo 19.0 installed successfully"
    else
        log "ERROR" "✗ Failed to install Odoo"
        return 1
    fi
    
    # Enable Odoo service
    log "INFO" "Enabling Odoo service..."
    if systemctl enable odoo 2>&1 | tee -a "$LOG_FILE"; then
        log "SUCCESS" "✓ Odoo service enabled"
    else
        log "ERROR" "✗ Failed to enable Odoo service"
        return 1
    fi
    
    # Start Odoo service
    log "INFO" "Starting Odoo service..."
    if systemctl start odoo 2>&1 | tee -a "$LOG_FILE"; then
        log "SUCCESS" "✓ Odoo service started"
    else
        log "WARN" "⚠ Odoo service start command completed (checking status separately)"
    fi
}

# Test installation
test_installation() {
    log "INFO" "Testing Odoo installation..."
    
    # Wait for service to stabilize
    log "INFO" "Waiting for Odoo service to stabilize..."
    sleep 15
    
    # Test 1: Check if Odoo service is installed
    if systemctl list-unit-files 2>/dev/null | grep -q "^odoo.service"; then
        log "SUCCESS" "✓ Test 1: Odoo service is installed in systemd"
    else
        log "ERROR" "✗ Test 1: Odoo service is NOT installed in systemd"
        return 1
    fi
    
    # Test 2: Check service status
    local service_status=$(systemctl is-active odoo 2>/dev/null || echo "unknown")
    case $service_status in
        "active")
            log "SUCCESS" "✓ Test 2: Odoo service is running (status: $service_status)"
            ;;
        "activating")
            log "WARN" "⚠ Test 2: Odoo service is starting up (status: $service_status)"
            log "INFO" "Waiting additional 30 seconds for startup..."
            sleep 30
            service_status=$(systemctl is-active odoo 2>/dev/null || echo "unknown")
            if [[ "$service_status" == "active" ]]; then
                log "SUCCESS" "✓ Test 2: Odoo service is now running (status: $service_status)"
            else
                log "ERROR" "✗ Test 2: Odoo service failed to start (status: $service_status)"
                show_service_logs
                return 1
            fi
            ;;
        *)
            log "ERROR" "✗ Test 2: Odoo service is NOT running (status: $service_status)"
            show_service_logs
            return 1
            ;;
    esac
    
    # Test 3: Check if port 8069 is listening
    log "INFO" "Checking if Odoo is listening on port 8069..."
    local port_check_attempts=0
    local max_port_attempts=6
    
    while [[ $port_check_attempts -lt $max_port_attempts ]]; do
        if ss -tuln 2>/dev/null | grep -q ":8069 "; then
            log "SUCCESS" "✓ Test 3: Odoo is listening on port 8069"
            
            # Show what's listening
            local listening_info=$(ss -tuln 2>/dev/null | grep ":8069 " | head -1)
            log "INFO" "Port 8069 details: $listening_info"
            break
        else
            ((port_check_attempts++))
            if [[ $port_check_attempts -lt $max_port_attempts ]]; then
                log "WARN" "⚠ Port 8069 not yet listening (attempt $port_check_attempts/$max_port_attempts) - waiting 10 seconds..."
                sleep 10
            else
                log "ERROR" "✗ Test 3: Odoo is NOT listening on port 8069 after $max_port_attempts attempts"
                log "ERROR" "Current listening ports:"
                ss -tuln 2>/dev/null | grep -E ":(80|8069|443)" | sed 's/^/    /' || echo "    No relevant ports found"
                return 1
            fi
        fi
    done
    
    # Test 4: HTTP connectivity test
    log "INFO" "Testing HTTP connectivity to Odoo..."
    if curl -s -f -m 10 http://localhost:8069 >/dev/null 2>&1; then
        log "SUCCESS" "✓ Test 4: Odoo web interface is accessible"
    else
        log "WARN" "⚠ Test 4: Odoo web interface not yet ready (this can be normal during first startup)"
        
        # Try to get more info about the response
        local http_response=$(curl -s -o /dev/null -w "%{http_code}" -m 10 http://localhost:8069 2>/dev/null || echo "000")
        if [[ "$http_response" != "000" ]]; then
            log "INFO" "HTTP response code: $http_response"
        fi
    fi
    
    return 0
}

# Show service logs for troubleshooting
show_service_logs() {
    log "INFO" "Recent Odoo service logs for troubleshooting:"
    echo
    journalctl -u odoo --no-pager -n 20 2>&1 | sed 's/^/    /' | tee -a "$LOG_FILE"
    echo
}

# Show final summary
show_summary() {
    local service_status=$(systemctl is-active odoo 2>/dev/null || echo "unknown")
    local port_listening=""
    
    if ss -tuln 2>/dev/null | grep -q ":8069 "; then
        port_listening="✅ Listening"
    else
        port_listening="❌ Not listening"
    fi
    
    echo
    echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}${BOLD}  Official Odoo 19.0 Installation Completed!${NC}"
    echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo
    echo -e "${BLUE}Installation Summary:${NC}"
    echo -e "  📦 Method: Official Odoo Repository Package"
    echo -e "  🗂️  Version: Odoo 19.0 Community Edition"
    echo -e "  🐘 Database: PostgreSQL"
    echo
    echo -e "${BLUE}Service Status:${NC}"
    if [[ "$service_status" == "active" ]]; then
        echo -e "  🟢 Odoo Service: ${GREEN}Running${NC}"
    else
        echo -e "  🔴 Odoo Service: ${RED}$service_status${NC}"
    fi
    echo -e "  🌐 Port 8069: $port_listening"
    echo
    
    if [[ "$service_status" == "active" ]] && ss -tuln 2>/dev/null | grep -q ":8069 "; then
        echo -e "${GREEN}✅ Installation successful!${NC}"
        echo
        echo -e "${BLUE}Access your Odoo installation:${NC}"
        echo -e "  🌐 Web Interface: ${GREEN}http://localhost:8069${NC}"
        if command -v hostname &>/dev/null; then
            local hostname=$(hostname -I | awk '{print $1}' 2>/dev/null || echo "your-server-ip")
            if [[ -n "$hostname" && "$hostname" != "your-server-ip" ]]; then
                echo -e "  🌐 External Access: ${GREEN}http://$hostname:8069${NC}"
            fi
        fi
        echo
        echo -e "${BLUE}Default Configuration:${NC}"
        echo -e "  📁 Config file: ${GREEN}/etc/odoo/odoo.conf${NC}"
        echo -e "  📁 Log files: ${GREEN}/var/log/odoo/${NC}"
        echo -e "  📁 Data directory: ${GREEN}/var/lib/odoo/${NC}"
        echo
    else
        echo -e "${YELLOW}⚠️ Installation completed with issues${NC}"
        echo -e "${BLUE}Troubleshooting:${NC}"
        echo -e "  🔧 Check service: ${GREEN}sudo systemctl status odoo${NC}"
        echo -e "  📋 View logs: ${GREEN}sudo journalctl -u odoo -f${NC}"
        echo
    fi
    
    echo -e "${BLUE}Log File:${NC} ${GREEN}$LOG_FILE${NC}"
    echo
    echo -e "${BLUE}Useful Commands:${NC}"
    echo -e "  Check status: ${GREEN}sudo systemctl status odoo${NC}"
    echo -e "  View logs: ${GREEN}sudo journalctl -u odoo -f${NC}"
    echo -e "  Restart: ${GREEN}sudo systemctl restart odoo${NC}"
    echo -e "  Stop: ${GREEN}sudo systemctl stop odoo${NC}"
    echo -e "  Update: ${GREEN}sudo apt upgrade odoo${NC}"
    echo
}

# Main function
main() {
    # Create log directory
    create_log_dir
    
    # Show banner
    show_banner
    
    # Check root
    check_root
    
    # Set noninteractive mode globally
    export DEBIAN_FRONTEND=noninteractive
    
    # Start logging
    log "INFO" "Starting official Odoo 19.0 installation"
    log "INFO" "Log file: $LOG_FILE"
    
    echo -e "${BLUE}Starting installation process...${NC}"
    echo
    
    # Installation steps
    if update_system; then
        log "SUCCESS" "System update completed"
    else
        log "ERROR" "System update failed"
        exit 1
    fi
    
    if install_postgresql; then
        log "SUCCESS" "PostgreSQL installation completed"
    else
        log "ERROR" "PostgreSQL installation failed"
        exit 1
    fi
    
    if setup_odoo_repository; then
        log "SUCCESS" "Odoo repository setup completed"
    else
        log "ERROR" "Odoo repository setup failed"
        exit 1
    fi
    
    if install_odoo; then
        log "SUCCESS" "Odoo installation completed"
    else
        log "ERROR" "Odoo installation failed"
        exit 1
    fi
    
    # Test installation
    echo
    echo -e "${YELLOW}Testing installation...${NC}"
    echo
    
    if test_installation; then
        log "SUCCESS" "All installation tests passed!"
    else
        log "ERROR" "Some installation tests failed - check logs for details"
    fi
    
    # Show summary
    show_summary
    
    log "SUCCESS" "Official Odoo installation process completed!"
}

# Run main function
main "$@"
#!/bin/bash

###############################################################################
# Odoo Service Diagnosis Tool
# 
# Umfassende Diagnose von Odoo-Service-Problemen
# Zeigt alle relevanten Informationen zur Problemdiagnose
#
# Usage:
#   sudo ./diagnose-service.sh
###############################################################################

set -e  # Exit on any error

# Configuration
ODOO_USER="odoo"
ODOO_HOME="/opt/odoo"
ODOO_CONFIG="/etc/odoo/odoo.conf"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Helper functions
check_mark() { echo -e "${GREEN}✓${NC}"; }
cross_mark() { echo -e "${RED}✗${NC}"; }
warn_mark() { echo -e "${YELLOW}⚠${NC}"; }
info_mark() { echo -e "${BLUE}ℹ${NC}"; }

# Display banner
show_banner() {
    clear
    echo -e "${CYAN}${BOLD}"
    cat << 'EOF'
  ____  _                                   
 |  _ \(_) __ _  __ _ _ __   ___  ___  ___ 
 | | | | |/ _` |/ _` | '_ \ / _ \/ __|/ _ \
 | |_| | | (_| | (_| | | | | (_) \__ \  __/
 |____/|_|\__,_|\__, |_| |_|\___/|___/\___|
                |___/                    
EOF
    echo -e "${NC}"
    echo -e "${CYAN}Odoo Service Diagnosis Tool${NC}"
    echo -e "${BLUE}Comprehensive analysis of Odoo installation and service status${NC}"
    echo
}

# Section header
section_header() {
    local title="$1"
    echo
    echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}${CYAN}  $title${NC}"
    echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Check system prerequisites
check_system() {
    section_header "SYSTEM PREREQUISITES"
    
    # Check if running as root
    if [[ $EUID -eq 0 ]]; then
        echo -e "$(check_mark) Running as root/sudo"
    else
        echo -e "$(cross_mark) Not running as root - some checks may fail"
        echo -e "  ${YELLOW}Recommendation: run with sudo${NC}"
    fi
    
    # Check OS
    if [[ -f /etc/os-release ]]; then
        local os_info=$(grep PRETTY_NAME /etc/os-release | cut -d'"' -f2)
        echo -e "$(check_mark) Operating System: $os_info"
    else
        echo -e "$(cross_mark) Cannot determine operating system"
    fi
    
    # Check systemd
    if command -v systemctl &>/dev/null; then
        echo -e "$(check_mark) Systemd available"
    else
        echo -e "$(cross_mark) Systemd not found - cannot manage services"
    fi
    
    # Check Python
    if command -v python3 &>/dev/null; then
        local py_version=$(python3 --version 2>&1 | cut -d' ' -f2)
        echo -e "$(check_mark) Python 3 available: $py_version"
    else
        echo -e "$(cross_mark) Python 3 not found"
    fi
    
    # Check PostgreSQL
    if command -v psql &>/dev/null; then
        echo -e "$(check_mark) PostgreSQL client available"
        if sudo -u postgres psql -c "SELECT version();" &>/dev/null; then
            echo -e "$(check_mark) PostgreSQL server accessible"
        else
            echo -e "$(warn_mark) PostgreSQL server not accessible"
        fi
    else
        echo -e "$(cross_mark) PostgreSQL not found"
    fi
}

# Check Odoo user and permissions
check_user() {
    section_header "ODOO USER & PERMISSIONS"
    
    if id "$ODOO_USER" &>/dev/null; then
        echo -e "$(check_mark) Odoo user exists: $ODOO_USER"
        
        # User info
        local user_info=$(id "$ODOO_USER" 2>/dev/null)
        echo -e "  ${BLUE}User info:${NC} $user_info"
        
        # Home directory
        local user_home=$(getent passwd "$ODOO_USER" | cut -d: -f6)
        echo -e "  ${BLUE}Home directory:${NC} $user_home"
        
        # Shell
        local user_shell=$(getent passwd "$ODOO_USER" | cut -d: -f7)
        echo -e "  ${BLUE}Shell:${NC} $user_shell"
        
        # Check if user can login
        if [[ "$user_shell" == "/bin/false" ]] || [[ "$user_shell" == "/usr/sbin/nologin" ]]; then
            echo -e "$(check_mark) User login disabled (good for security)"
        else
            echo -e "$(warn_mark) User can login (security consideration)"
        fi
    else
        echo -e "$(cross_mark) Odoo user does not exist: $ODOO_USER"
    fi
}

# Check Odoo installation
check_installation() {
    section_header "ODOO INSTALLATION"
    
    # Check Odoo directory
    if [[ -d "$ODOO_HOME" ]]; then
        echo -e "$(check_mark) Odoo home directory exists: $ODOO_HOME"
        
        # Check ownership
        local owner=$(stat -c '%U:%G' "$ODOO_HOME" 2>/dev/null)
        echo -e "  ${BLUE}Directory owner:${NC} $owner"
        
        # Check Odoo source
        if [[ -d "$ODOO_HOME/odoo" ]]; then
            echo -e "$(check_mark) Odoo source directory found"
            
            # Check for key files
            if [[ -f "$ODOO_HOME/odoo/odoo-bin" ]]; then
                echo -e "$(check_mark) odoo-bin executable found"
            elif [[ -f "$ODOO_HOME/odoo/__init__.py" ]]; then
                echo -e "$(check_mark) Odoo Python package found"
            else
                echo -e "$(cross_mark) Odoo executable/package not found"
            fi
            
            # Check custom addons
            if [[ -d "$ODOO_HOME/custom-addons" ]]; then
                local addon_count=$(find "$ODOO_HOME/custom-addons" -maxdepth 1 -type d | wc -l)
                echo -e "$(check_mark) Custom addons directory exists ($addon_count addons)"
            else
                echo -e "$(warn_mark) No custom addons directory"
            fi
            
        else
            echo -e "$(cross_mark) Odoo source directory not found: $ODOO_HOME/odoo"
        fi
    else
        echo -e "$(cross_mark) Odoo home directory not found: $ODOO_HOME"
    fi
}

# Check configuration
check_config() {
    section_header "CONFIGURATION"
    
    # Check config file
    if [[ -f "$ODOO_CONFIG" ]]; then
        echo -e "$(check_mark) Configuration file exists: $ODOO_CONFIG"
        
        # Check ownership and permissions
        local config_owner=$(stat -c '%U:%G' "$ODOO_CONFIG" 2>/dev/null)
        local config_perms=$(stat -c '%a' "$ODOO_CONFIG" 2>/dev/null)
        echo -e "  ${BLUE}Config owner:${NC} $config_owner"
        echo -e "  ${BLUE}Config permissions:${NC} $config_perms"
        
        # Check for key settings
        echo -e "  ${BLUE}Key configuration settings:${NC}"
        
        local db_host=$(grep -E "^db_host\s*=" "$ODOO_CONFIG" | cut -d'=' -f2 | xargs || echo "localhost")
        echo -e "    Database host: $db_host"
        
        local db_port=$(grep -E "^db_port\s*=" "$ODOO_CONFIG" | cut -d'=' -f2 | xargs || echo "5432")
        echo -e "    Database port: $db_port"
        
        local db_user=$(grep -E "^db_user\s*=" "$ODOO_CONFIG" | cut -d'=' -f2 | xargs || echo "odoo")
        echo -e "    Database user: $db_user"
        
        local xmlrpc_port=$(grep -E "^xmlrpc_port\s*=" "$ODOO_CONFIG" | cut -d'=' -f2 | xargs || echo "8069")
        echo -e "    HTTP port: $xmlrpc_port"
        
        local workers=$(grep -E "^workers\s*=" "$ODOO_CONFIG" | cut -d'=' -f2 | xargs || echo "0")
        echo -e "    Workers: $workers"
        
        local log_level=$(grep -E "^log_level\s*=" "$ODOO_CONFIG" | cut -d'=' -f2 | xargs || echo "info")
        echo -e "    Log level: $log_level"
        
        local logfile=$(grep -E "^logfile\s*=" "$ODOO_CONFIG" | cut -d'=' -f2 | xargs || echo "False")
        echo -e "    Log file: $logfile"
        
    else
        echo -e "$(cross_mark) Configuration file not found: $ODOO_CONFIG"
    fi
    
    # Check config directory
    local config_dir=$(dirname "$ODOO_CONFIG")
    if [[ -d "$config_dir" ]]; then
        echo -e "$(check_mark) Configuration directory exists: $config_dir"
    else
        echo -e "$(cross_mark) Configuration directory not found: $config_dir"
    fi
}

# Check Python dependencies
check_dependencies() {
    section_header "PYTHON DEPENDENCIES"
    
    echo -e "${BLUE}Testing critical Odoo dependencies...${NC}"
    
    local deps_ok=true
    local critical_deps=(
        "odoo"
        "psycopg2"
        "lxml"
        "Pillow"
        "werkzeug"
        "passlib"
        "babel"
        "python-dateutil"
        "pytz"
        "reportlab"
        "qrcode"
    )
    
    for dep in "${critical_deps[@]}"; do
        if python3 -c "import $dep" 2>/dev/null; then
            echo -e "$(check_mark) $dep"
        else
            echo -e "$(cross_mark) $dep"
            deps_ok=false
        fi
    done
    
    # Special check for zope.event (the problematic dependency)
    echo
    echo -e "${BLUE}Testing zope packages specifically...${NC}"
    local zope_deps=("zope.event" "zope.interface")
    
    for dep in "${zope_deps[@]}"; do
        if python3 -c "import $dep" 2>/dev/null; then
            echo -e "$(check_mark) $dep"
        else
            echo -e "$(cross_mark) $dep ${YELLOW}(common issue)${NC}"
            deps_ok=false
        fi
    done
    
    if ! $deps_ok; then
        echo
        echo -e "${YELLOW}⚠️  Dependency issues detected!${NC}"
        echo -e "   ${BLUE}Fix with:${NC} sudo ./fix-python-dependencies.sh"
    fi
}

# Check systemd service
check_service() {
    section_header "SYSTEMD SERVICE"
    
    # Check if service file exists
    if [[ -f /etc/systemd/system/odoo.service ]]; then
        echo -e "$(check_mark) Service file exists: /etc/systemd/system/odoo.service"
        
        # Check service file syntax
        if systemd-analyze verify /etc/systemd/system/odoo.service 2>/dev/null; then
            echo -e "$(check_mark) Service file syntax is valid"
        else
            echo -e "$(cross_mark) Service file has syntax errors"
            echo -e "  ${YELLOW}Syntax check output:${NC}"
            systemd-analyze verify /etc/systemd/system/odoo.service 2>&1 | sed 's/^/    /'
        fi
        
        # Check service status
        local service_status=$(systemctl is-active odoo 2>/dev/null || echo "unknown")
        local service_enabled=$(systemctl is-enabled odoo 2>/dev/null || echo "unknown")
        
        echo -e "  ${BLUE}Service status:${NC} $service_status"
        echo -e "  ${BLUE}Service enabled:${NC} $service_enabled"
        
        case $service_status in
            "active")
                echo -e "$(check_mark) Service is running"
                ;;
            "inactive")
                echo -e "$(warn_mark) Service is stopped"
                ;;
            "failed")
                echo -e "$(cross_mark) Service has failed"
                ;;
            "activating")
                echo -e "$(warn_mark) Service is starting up"
                ;;
            *)
                echo -e "$(cross_mark) Service status unknown: $service_status"
                ;;
        esac
        
        # Show recent logs if service has issues
        if [[ "$service_status" == "failed" ]] || [[ "$service_status" == "inactive" ]]; then
            echo
            echo -e "  ${BLUE}Recent service logs:${NC}"
            journalctl -u odoo --no-pager -n 10 2>/dev/null | sed 's/^/    /' || echo "    No logs available"
        fi
        
    else
        echo -e "$(cross_mark) Service file does not exist: /etc/systemd/system/odoo.service"
        
        # Check if service is listed in systemd
        if systemctl list-unit-files 2>/dev/null | grep -q "^odoo.service"; then
            echo -e "$(warn_mark) Service is registered in systemd but file missing"
        else
            echo -e "$(cross_mark) Service is not registered in systemd"
        fi
    fi
}

# Check network and ports
check_network() {
    section_header "NETWORK & PORTS"
    
    # Check if port 8069 is listening
    if ss -tuln 2>/dev/null | grep -q ":8069 "; then
        echo -e "$(check_mark) Port 8069 is listening"
        
        # Show what's listening
        local listening=$(ss -tuln 2>/dev/null | grep ":8069 " | head -1)
        echo -e "  ${BLUE}Listening on:${NC} $listening"
    else
        echo -e "$(cross_mark) Port 8069 is not listening"
    fi
    
    # Check for competing services
    if ss -tuln 2>/dev/null | grep -E ":(8069|80|443) " | grep -v ":8069 "; then
        echo -e "$(warn_mark) Other web services detected:"
        ss -tuln 2>/dev/null | grep -E ":(8069|80|443) " | sed 's/^/    /'
    fi
    
    # Check firewall status
    if command -v ufw &>/dev/null; then
        local ufw_status=$(ufw status 2>/dev/null | head -1)
        echo -e "  ${BLUE}UFW Firewall:${NC} $ufw_status"
    elif command -v firewall-cmd &>/dev/null; then
        if firewall-cmd --state 2>/dev/null; then
            echo -e "  ${BLUE}Firewall:${NC} firewalld active"
        else
            echo -e "  ${BLUE}Firewall:${NC} firewalld inactive"
        fi
    else
        echo -e "  ${BLUE}Firewall:${NC} Not detected"
    fi
}

# Check log files and recent activity
check_logs() {
    section_header "LOG FILES & RECENT ACTIVITY"
    
    # Check Odoo log directory
    if [[ -d /var/log/odoo ]]; then
        echo -e "$(check_mark) Odoo log directory exists: /var/log/odoo"
        
        local log_count=$(find /var/log/odoo -name "*.log" 2>/dev/null | wc -l)
        echo -e "  ${BLUE}Log files found:${NC} $log_count"
        
        # Show recent log activity
        if [[ $log_count -gt 0 ]]; then
            echo -e "  ${BLUE}Recent log files:${NC}"
            find /var/log/odoo -name "*.log" -type f -printf "%T@ %p\n" 2>/dev/null | sort -nr | head -5 | while read timestamp file; do
                local date=$(date -d "@${timestamp}" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "unknown")
                echo -e "    $date - $(basename "$file")"
            done
        fi
    else
        echo -e "$(cross_mark) Odoo log directory not found: /var/log/odoo"
    fi
    
    # Check systemd journal
    echo
    echo -e "${BLUE}Recent systemd journal entries for Odoo:${NC}"
    if journalctl -u odoo --no-pager -n 5 --since "1 hour ago" 2>/dev/null | grep -v "No entries"; then
        :  # Logs were shown
    else
        echo -e "  ${YELLOW}No recent journal entries found${NC}"
    fi
}

# Show recommendations
show_recommendations() {
    section_header "RECOMMENDATIONS & NEXT STEPS"
    
    echo -e "${BLUE}Based on the diagnosis, here are the recommended actions:${NC}"
    echo
    
    # Check for common issues and provide specific recommendations
    local needs_service_repair=false
    local needs_dependency_fix=false
    local needs_config_fix=false
    
    # Service issues
    if ! systemctl is-active odoo &>/dev/null; then
        needs_service_repair=true
        echo -e "🔧 ${YELLOW}Service Issues Detected:${NC}"
        echo -e "   • Run: ${GREEN}sudo ./emergency-service-repair.sh${NC}"
        echo
    fi
    
    # Dependency issues
    if ! python3 -c "import odoo" 2>/dev/null || ! python3 -c "import zope.event" 2>/dev/null; then
        needs_dependency_fix=true
        echo -e "📦 ${YELLOW}Dependency Issues Detected:${NC}"
        echo -e "   • Run: ${GREEN}sudo ./fix-python-dependencies.sh${NC}"
        echo
    fi
    
    # Configuration issues
    if [[ ! -f "$ODOO_CONFIG" ]]; then
        needs_config_fix=true
        echo -e "⚙️  ${YELLOW}Configuration Issues Detected:${NC}"
        echo -e "   • Create config: ${GREEN}sudo mkdir -p /etc/odoo${NC}"
        echo -e "   • Copy config: ${GREEN}sudo cp config/odoo.conf.example $ODOO_CONFIG${NC}"
        echo
    fi
    
    # If everything looks good
    if ! $needs_service_repair && ! $needs_dependency_fix && ! $needs_config_fix; then
        echo -e "✅ ${GREEN}No major issues detected!${NC}"
        echo
        echo -e "🌐 ${BLUE}Access your Odoo installation:${NC}"
        echo -e "   • Web interface: ${GREEN}http://localhost:8069${NC}"
        echo
    fi
    
    echo -e "📋 ${BLUE}Useful commands for ongoing maintenance:${NC}"
    echo -e "   • Check status: ${GREEN}sudo systemctl status odoo${NC}"
    echo -e "   • View logs: ${GREEN}sudo journalctl -u odoo -f${NC}"
    echo -e "   • Restart service: ${GREEN}sudo systemctl restart odoo${NC}"
    echo -e "   • Run full diagnosis: ${GREEN}sudo ./diagnose-service.sh${NC}"
    echo
}

# Main function
main() {
    show_banner
    
    check_system
    check_user
    check_installation
    check_config
    check_dependencies
    check_service
    check_network
    check_logs
    show_recommendations
    
    echo
    echo -e "${CYAN}${BOLD}Diagnosis completed!${NC}"
    echo -e "${BLUE}For detailed service repair, run: ${GREEN}sudo ./emergency-service-repair.sh${NC}"
    echo
}

# Run main function
main "$@"
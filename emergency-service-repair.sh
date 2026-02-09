#!/bin/bash

###############################################################################
# Emergency Odoo Service Repair Script
# 
# Repariert Odoo-Service-Probleme wenn der systemd-Service nicht erstellt wurde
# oder nicht funktioniert
#
# Usage:
#   sudo ./emergency-service-repair.sh
###############################################################################

set -e  # Exit on any error

# Configuration
LOG_DIR="/var/log/odoo-upgrade"
LOG_FILE="$LOG_DIR/service-repair-$(date +%Y%m%d-%H%M%S).log"
ODOO_USER="odoo"
ODOO_HOME="/opt/odoo"
ODOO_CONFIG="/etc/odoo/odoo.conf"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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
    echo -e "${RED}${BOLD}"
    cat << 'EOF'
  _____ __  __ ______ _____   _____ ______ _   _  _______     __
 |  ___|  \/  |  ____|  __ \ / ____|  ____| \ | |/ ____\ \   / /
 | |__ | |\/| | |__  | |__) | |  __| |__  |  \| | |     \ \_/ / 
 |  __|| |  | |  __| |  _  /| | |_ |  __| | . ` | |      \   /  
 | |___| |  | | |____| | \ \| |__| | |____| |\  | |____   | |   
 |_____|_|  |_|______|_|  \_\\_____|______|_| \_|\_____|  |_|   
                                                               
           Service Repair Tool                               
EOF
    echo -e "${NC}"
    echo -e "${GREEN}Emergency Reparatur für Odoo-Systemd-Service${NC}"
    echo
}

# Diagnose current state
diagnose_current_state() {
    log "INFO" "Diagnosing current Odoo installation state..."
    
    # Check if Odoo user exists
    if id "$ODOO_USER" &>/dev/null; then
        log "SUCCESS" "✓ Odoo user exists: $ODOO_USER"
    else
        log "ERROR" "✗ Odoo user does not exist: $ODOO_USER"
        return 1
    fi
    
    # Check if Odoo installation exists
    if [[ -d "$ODOO_HOME/odoo" ]]; then
        log "SUCCESS" "✓ Odoo installation found: $ODOO_HOME/odoo"
    else
        log "ERROR" "✗ Odoo installation not found: $ODOO_HOME/odoo"
        return 1
    fi
    
    # Check if Odoo config exists
    if [[ -f "$ODOO_CONFIG" ]]; then
        log "SUCCESS" "✓ Odoo configuration found: $ODOO_CONFIG"
    else
        log "ERROR" "✗ Odoo configuration not found: $ODOO_CONFIG"
        return 1
    fi
    
    # Check if Python can import Odoo
    if python3 -c "import sys; sys.path.insert(0, '/opt/odoo/odoo'); import odoo" 2>/dev/null; then
        log "SUCCESS" "✓ Odoo Python modules can be imported"
    else
        log "WARN" "⚠ Odoo Python modules cannot be imported"
        log "WARN" "  You may need to run: sudo ./fix-python-dependencies.sh"
    fi
    
    # Check current service status
    if systemctl list-unit-files 2>/dev/null | grep -q "^odoo.service"; then
        local service_status=$(systemctl is-active odoo 2>/dev/null || echo "unknown")
        log "INFO" "📊 Current service status: $service_status"
        
        if [[ "$service_status" == "active" ]]; then
            log "SUCCESS" "✓ Odoo service is already running"
            return 0
        elif [[ "$service_status" == "failed" ]]; then
            log "WARN" "⚠ Odoo service exists but has failed"
        else
            log "WARN" "⚠ Odoo service exists but is not active"
        fi
    else
        log "WARN" "⚠ Odoo service does not exist in systemd"
    fi
    
    return 1
}

# Force create systemd service
force_create_service() {
    log "INFO" "Force creating Odoo systemd service..."
    
    # Remove any existing service
    if systemctl list-unit-files 2>/dev/null | grep -q "^odoo.service"; then
        log "INFO" "Removing existing service..."
        systemctl stop odoo 2>/dev/null || true
        systemctl disable odoo 2>/dev/null || true
        rm -f /etc/systemd/system/odoo.service
    fi
    
    # Create new service file
    log "INFO" "Creating new service file..."
    cat > /etc/systemd/system/odoo.service << EOF
[Unit]
Description=Odoo 19.0 ERP and CRM
Documentation=http://www.odoo.com
Requires=postgresql.service
After=network.target postgresql.service

[Service]
Type=simple
User=$ODOO_USER
Group=$ODOO_USER
WorkingDirectory=$ODOO_HOME/odoo
Environment=PYTHONPATH=$ODOO_HOME/odoo:$ODOO_HOME/custom-addons
ExecStart=/usr/bin/python3 -m odoo --config=$ODOO_CONFIG --no-daemon
ExecReload=/bin/kill -s HUP \$MAINPID
Restart=on-failure
RestartSec=10
KillMode=mixed
TimeoutStartSec=300
TimeoutStopSec=120

# Logging
StandardOutput=journal+console
StandardError=journal+console
SyslogIdentifier=odoo

# Security settings
NoNewPrivileges=true
ProtectSystem=strict
ReadWritePaths=/var/log/odoo $ODOO_HOME /tmp /var/lib/odoo
ProtectHome=true
PrivateTmp=true
PrivateDevices=true

# Resource limits
LimitNOFILE=65535
LimitNPROC=65535

[Install]
WantedBy=multi-user.target
EOF
    
    # Create necessary directories
    log "INFO" "Creating necessary directories..."
    mkdir -p /var/log/odoo /var/lib/odoo
    chown "$ODOO_USER:$ODOO_USER" /var/log/odoo /var/lib/odoo
    chmod 755 /var/log/odoo /var/lib/odoo
    
    # Create tmpfiles configuration
    cat > /etc/tmpfiles.d/odoo.conf << EOF
d /var/log/odoo 0755 $ODOO_USER $ODOO_USER -
d /var/lib/odoo 0755 $ODOO_USER $ODOO_USER -
EOF
    
    # Reload systemd
    log "INFO" "Reloading systemd..."
    systemctl daemon-reload
    
    # Verify service was created
    if systemctl list-unit-files 2>/dev/null | grep -q "^odoo.service"; then
        log "SUCCESS" "✓ Service file created successfully"
        
        # Enable service
        systemctl enable odoo
        log "SUCCESS" "✓ Service enabled"
        
        return 0
    else
        log "ERROR" "✗ Failed to create service file"
        return 1
    fi
}

# Test and start service
test_and_start_service() {
    log "INFO" "Testing and starting Odoo service..."
    
    # Stop any running instance first
    systemctl stop odoo 2>/dev/null || true
    sleep 2
    
    # Test service syntax
    if systemd-analyze verify /etc/systemd/system/odoo.service 2>&1 | tee -a "$LOG_FILE"; then
        log "SUCCESS" "✓ Service file syntax is valid"
    else
        log "ERROR" "✗ Service file has syntax errors"
        return 1
    fi
    
    # Try to start the service
    log "INFO" "Starting Odoo service..."
    if systemctl start odoo; then
        log "SUCCESS" "✓ Service start command successful"
    else
        log "ERROR" "✗ Failed to start service"
        systemctl status odoo --no-pager -l 2>&1 | tee -a "$LOG_FILE"
        return 1
    fi
    
    # Wait for service to stabilize
    log "INFO" "Waiting for service to stabilize..."
    sleep 10
    
    local service_status=$(systemctl is-active odoo 2>/dev/null || echo "unknown")
    
    if [[ "$service_status" == "active" ]]; then
        log "SUCCESS" "✓ Odoo service is running successfully"
        
        # Test if port is listening
        if ss -tuln | grep -q ":8069 "; then
            log "SUCCESS" "✓ Odoo is listening on port 8069"
        else
            log "WARN" "⚠ Port 8069 not yet listening (may need more time)"
        fi
        
        return 0
    else
        log "ERROR" "✗ Service failed to start properly (status: $service_status)"
        
        # Show recent logs for troubleshooting
        log "INFO" "Recent service logs:"
        journalctl -u odoo --no-pager -n 20 2>&1 | tee -a "$LOG_FILE"
        
        return 1
    fi
}

# Show final summary
show_summary() {
    local service_status=$(systemctl is-active odoo 2>/dev/null || echo "unknown")
    
    echo
    echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}${BOLD}  Emergency Service Repair Completed!${NC}"
    echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo
    echo -e "${BLUE}Service Status:${NC}"
    if [[ "$service_status" == "active" ]]; then
        echo -e "  🟢 Odoo Service: ${GREEN}Running${NC}"
        echo -e "  🌐 Web Access: http://localhost:8069"
        echo -e "  ✅ Repair: ${GREEN}Successful${NC}"
    elif [[ "$service_status" == "activating" ]]; then
        echo -e "  🟡 Odoo Service: ${YELLOW}Starting up...${NC}"
        echo -e "  🌐 Web Access: http://localhost:8069 (wait a few minutes)"
        echo -e "  ⏳ Repair: ${YELLOW}In progress${NC}"
    else
        echo -e "  🔴 Odoo Service: ${RED}Failed${NC}"
        echo -e "  ❌ Repair: ${RED}Failed${NC}"
        echo -e "  📋 Check logs: ${BLUE}sudo journalctl -u odoo -f${NC}"
    fi
    echo
    echo -e "${BLUE}Log File:${NC} ${GREEN}$LOG_FILE${NC}"
    echo
    echo -e "${BLUE}Useful Commands:${NC}"
    echo -e "  Check status:  ${GREEN}sudo systemctl status odoo${NC}"
    echo -e "  View logs:     ${GREEN}sudo journalctl -u odoo -f${NC}"
    echo -e "  Restart:       ${GREEN}sudo systemctl restart odoo${NC}"
    echo -e "  Stop:          ${GREEN}sudo systemctl stop odoo${NC}"
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
    
    # Start logging
    log "INFO" "Starting emergency Odoo service repair"
    log "INFO" "Log file: $LOG_FILE"
    
    # Diagnose current state
    if diagnose_current_state; then
        echo
        echo -e "${GREEN}✅ Odoo service is already running properly!${NC}"
        echo -e "${BLUE}No repair needed.${NC}"
        echo
        show_summary
        return 0
    fi
    
    echo
    echo -e "${YELLOW}⚠️  Service issues detected - proceeding with repair...${NC}"
    echo
    
    # Force create service
    if force_create_service; then
        log "SUCCESS" "Service creation successful"
    else
        log "ERROR" "Service creation failed"
        show_summary
        return 1
    fi
    
    # Test and start service
    if test_and_start_service; then
        log "SUCCESS" "Service repair completed successfully"
    else
        log "ERROR" "Service repair failed"
    fi
    
    # Show summary
    show_summary
    
    log "SUCCESS" "Emergency service repair completed!"
}

# Run main function
main "$@"
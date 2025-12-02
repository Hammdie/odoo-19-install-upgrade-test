#!/bin/bash
################################################################################
# Script: fix-phonenumbers.sh
# Description: Install python3-phonenumbers for Odoo account_peppol module
# Error: "Es ist nicht möglich das Modul 'account_peppol' zu installieren,
#         da eine Abhängigkeit nicht erfüllt ist: phonenumbers"
# Solution: apt install python3-phonenumbers
################################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging
LOG_DIR="/var/log/odoo"
LOG_FILE="$LOG_DIR/fix-phonenumbers_$(date +%Y%m%d_%H%M%S).log"

log() {
    local level=$1
    shift
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
    
    case $level in
        ERROR)
            echo -e "${RED}[ERROR]${NC} $message"
            ;;
        SUCCESS)
            echo -e "${GREEN}[SUCCESS]${NC} $message"
            ;;
        WARN)
            echo -e "${YELLOW}[WARN]${NC} $message"
            ;;
        INFO)
            echo -e "${BLUE}[INFO]${NC} $message"
            ;;
    esac
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}This script must be run as root${NC}"
        echo "Please run: sudo $0"
        exit 1
    fi
}

# Create log directory
create_log_dir() {
    mkdir -p "$LOG_DIR"
    chmod 755 "$LOG_DIR"
}

# Main fix function
fix_phonenumbers() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════════════════════╗"
    echo "║                                                                            ║"
    echo "║  Python phonenumbers Module Fix                                           ║"
    echo "║  Required for: account_peppol and other Odoo modules                      ║"
    echo "║                                                                            ║"
    echo "╚════════════════════════════════════════════════════════════════════════════╝"
    echo ""
    
    log "INFO" "Starting phonenumbers installation..."
    log "INFO" "This fixes: 'Abhängigkeit nicht erfüllt: phonenumbers'"
    
    # Check if already installed
    if dpkg -l | grep -q "^ii.*python3-phonenumbers"; then
        local installed_version=$(dpkg -l | grep "python3-phonenumbers" | awk '{print $3}')
        log "INFO" "python3-phonenumbers is already installed (version: $installed_version)"
        
        echo ""
        read -p "Do you want to reinstall/upgrade? (y/N): " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log "INFO" "Installation cancelled by user"
            exit 0
        fi
    fi
    
    # Update package list
    log "INFO" "Updating package list..."
    if apt-get update 2>&1 | tee -a "$LOG_FILE"; then
        log "SUCCESS" "Package list updated"
    else
        echo ""
        echo "╔════════════════════════════════════════════════════════════════════════════╗"
        echo "║                                                                            ║"
        echo "║  ❌ APT UPDATE FAILED ❌                                                   ║"
        echo "║                                                                            ║"
        echo "╚════════════════════════════════════════════════════════════════════════════╝"
        echo ""
        log "ERROR" "Failed to update package list"
        echo ""
        echo "📋 Full log details: $LOG_FILE"
        echo ""
        exit 1
    fi
    
    # Install python3-phonenumbers
    log "INFO" "Installing python3-phonenumbers..."
    if apt-get install -y python3-phonenumbers 2>&1 | tee -a "$LOG_FILE"; then
        log "SUCCESS" "python3-phonenumbers installed successfully"
    else
        echo ""
        echo "╔════════════════════════════════════════════════════════════════════════════╗"
        echo "║                                                                            ║"
        echo "║  ❌ INSTALLATION FAILED ❌                                                 ║"
        echo "║                                                                            ║"
        echo "╚════════════════════════════════════════════════════════════════════════════╝"
        echo ""
        log "ERROR" "Failed to install python3-phonenumbers"
        echo ""
        echo "📋 Full log details: $LOG_FILE"
        echo ""
        exit 1
    fi
    
    # Verify installation
    log "INFO" "Verifying installation..."
    if python3 -c "import phonenumbers; print(phonenumbers.__version__)" 2>&1 | tee -a "$LOG_FILE"; then
        local py_version=$(python3 -c "import phonenumbers; print(phonenumbers.__version__)" 2>/dev/null)
        
        echo ""
        echo "╔════════════════════════════════════════════════════════════════════════════╗"
        echo "║                                                                            ║"
        echo "║  ✅ PHONENUMBERS INSTALLATION SUCCESSFUL ✅                                ║"
        echo "║                                                                            ║"
        echo "╚════════════════════════════════════════════════════════════════════════════╝"
        echo ""
        log "SUCCESS" "phonenumbers module installed and verified"
        log "INFO" "Python phonenumbers version: $py_version"
        
        # Get package info
        local pkg_version=$(dpkg -l | grep "python3-phonenumbers" | awk '{print $3}')
        log "INFO" "Debian package version: $pkg_version"
        
        echo ""
        echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║                                                              ║${NC}"
        echo -e "${GREEN}║  NEXT STEPS                                                  ║${NC}"
        echo -e "${GREEN}║                                                              ║${NC}"
        echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo "1️⃣  Restart Odoo service:"
        echo "    sudo systemctl restart odoo"
        echo ""
        echo "2️⃣  Verify Odoo is running:"
        echo "    sudo systemctl status odoo"
        echo ""
        echo "3️⃣  Install account_peppol module in Odoo:"
        echo "    • Go to Apps menu in Odoo"
        echo "    • Search for 'PEPPOL'"
        echo "    • Click 'Install' on 'account_peppol'"
        echo ""
        echo "4️⃣  Check Odoo logs if needed:"
        echo "    sudo journalctl -u odoo -f"
        echo ""
        
        # Ask if user wants to restart Odoo
        echo ""
        read -p "Do you want to restart Odoo now? (Y/n): " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            log "INFO" "Restarting Odoo service..."
            if systemctl restart odoo 2>&1 | tee -a "$LOG_FILE"; then
                log "SUCCESS" "Odoo service restarted successfully"
                sleep 3
                
                if systemctl is-active --quiet odoo; then
                    log "SUCCESS" "Odoo is running"
                else
                    log "ERROR" "Odoo failed to start - check logs: sudo journalctl -u odoo -f"
                fi
            else
                log "ERROR" "Failed to restart Odoo service"
            fi
        fi
    else
        log "WARN" "Could not verify Python import - but package is installed"
        log "INFO" "Try restarting Odoo and testing the module installation"
    fi
    
    echo ""
    echo "📋 Full log: $LOG_FILE"
    echo ""
}

# Main execution
main() {
    create_log_dir
    check_root
    fix_phonenumbers
}

main "$@"

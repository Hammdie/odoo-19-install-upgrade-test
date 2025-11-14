#!/bin/bash

# Odoo 19.0 Upgrade System Installation Script
# Master installation script that coordinates the entire setup process

set -e  # Exit on any error

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"
LOG_DIR="/var/log/odoo-upgrade"
LOG_FILE="$LOG_DIR/install-$(date +%Y%m%d-%H%M%S).log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Installation options
SKIP_SYSTEM_UPDATE=false
SKIP_ODOO_INSTALL=false
SKIP_CRON_SETUP=false
AUTO_MODE=false
BACKUP_EXISTING=true

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

# Display banner
show_banner() {
    clear
    echo -e "${BLUE}${BOLD}"
    cat << 'EOF'
   ___      _             _  _   ___     ___  
  / _ \  __| | ___   ___ / |(_) / _ \   / _ \ 
 | | | |/ _` |/ _ \ / _ \| || || (_) | | | | |
 | |_| | (_| | (_) | (_) | || | \__, | | |_| |
  \___/ \__,_|\___/ \___/|_||_|   /_/   \___/ 
                                              
     Upgrade System Installation Script      
EOF
    echo -e "${NC}"
    echo -e "${GREEN}Automated installation and configuration for Odoo 19.0${NC}"
    echo -e "${YELLOW}This script will prepare your system for Odoo 19.0 with automatic updates${NC}"
    echo
}

# Usage function
usage() {
    cat << EOF
${BOLD}Usage:${NC} $0 [OPTIONS]

${BOLD}Options:${NC}
    --skip-system       Skip system upgrade step
    --skip-odoo         Skip Odoo installation step
    --skip-cron         Skip cron setup step
    --auto              Run in automatic mode (no prompts)
    --no-backup         Don't backup existing installations
    --help              Show this help message

${BOLD}Examples:${NC}
    $0                          # Full interactive installation
    $0 --auto                   # Automatic installation
    $0 --skip-system --auto     # Skip system update, auto install
    
${BOLD}Installation Steps:${NC}
    1. System preparation and package updates
    2. Odoo 19.0 download and installation
    3. Database and service configuration
    4. Automatic update cron jobs setup
    5. System verification and testing

${BOLD}Requirements:${NC}
    - Ubuntu 20.04 LTS or higher
    - Root/sudo access
    - Internet connection
    - At least 4GB RAM and 20GB disk space

${BOLD}Log Files:${NC}
    - Installation: $LOG_DIR/install-*.log
    - System Updates: $LOG_DIR/upgrade-system-*.log
    - Odoo Installation: $LOG_DIR/install-odoo19-*.log
    - Cron Setup: $LOG_DIR/setup-cron-*.log
EOF
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --skip-system)
                SKIP_SYSTEM_UPDATE=true
                shift
                ;;
            --skip-odoo)
                SKIP_ODOO_INSTALL=true
                shift
                ;;
            --skip-cron)
                SKIP_CRON_SETUP=true
                shift
                ;;
            --auto)
                AUTO_MODE=true
                shift
                ;;
            --no-backup)
                BACKUP_EXISTING=false
                shift
                ;;
            --help)
                usage
                exit 0
                ;;
            *)
                log "ERROR" "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
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
        echo -e "${RED}Please run: sudo $0${NC}"
        exit 1
    fi
}

# Check system requirements
check_requirements() {
    log "INFO" "Checking system requirements..."
    
    # Check OS
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        log "INFO" "Detected OS: $NAME $VERSION_ID"
        
        if [[ "$NAME" != *"Ubuntu"* ]]; then
            log "WARN" "This script is optimized for Ubuntu. Other distributions may require manual adjustments."
            if [[ "$AUTO_MODE" == false ]]; then
                read -p "Continue anyway? (y/N): " -n 1 -r
                echo
                if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                    exit 1
                fi
            fi
        fi
    else
        log "ERROR" "Cannot detect operating system"
        exit 1
    fi
    
    # Check available disk space (minimum 20GB)
    local available_space=$(df / | awk 'NR==2 {print $4}')
    local required_space=$((20 * 1024 * 1024))  # 20GB in KB
    
    if [[ $available_space -lt $required_space ]]; then
        log "ERROR" "Insufficient disk space. Required: 20GB, Available: $(($available_space / 1024 / 1024))GB"
        exit 1
    fi
    
    # Check available memory (minimum 2GB)
    local available_memory=$(free -m | awk 'NR==2{print $2}')
    if [[ $available_memory -lt 2048 ]]; then
        log "WARN" "Low memory detected: ${available_memory}MB. Recommended: 4GB or higher"
    fi
    
    # Check internet connectivity
    if ! curl -s --connect-timeout 5 http://google.com > /dev/null; then
        log "ERROR" "No internet connection detected"
        exit 1
    fi
    
    log "SUCCESS" "System requirements check passed"
}

# Display installation summary
show_installation_plan() {
    if [[ "$AUTO_MODE" == true ]]; then
        return 0
    fi
    
    echo
    echo -e "${BOLD}Installation Plan:${NC}"
    echo -e "${BLUE}=================${NC}"
    
    if [[ "$SKIP_SYSTEM_UPDATE" == false ]]; then
        echo -e "${GREEN}✓${NC} System Upgrade: Update packages and install dependencies"
    else
        echo -e "${YELLOW}⚠${NC} System Upgrade: ${YELLOW}SKIPPED${NC}"
    fi
    
    if [[ "$SKIP_ODOO_INSTALL" == false ]]; then
        echo -e "${GREEN}✓${NC} Odoo 19.0 Installation: Download and configure Odoo"
    else
        echo -e "${YELLOW}⚠${NC} Odoo 19.0 Installation: ${YELLOW}SKIPPED${NC}"
    fi
    
    if [[ "$SKIP_CRON_SETUP" == false ]]; then
        echo -e "${GREEN}✓${NC} Cron Setup: Configure automatic updates and maintenance"
    else
        echo -e "${YELLOW}⚠${NC} Cron Setup: ${YELLOW}SKIPPED${NC}"
    fi
    
    echo -e "${BLUE}Backup existing installations: $([ "$BACKUP_EXISTING" == true ] && echo "${GREEN}Yes${NC}" || echo "${YELLOW}No${NC}")${NC}"
    echo -e "${BLUE}Installation directory: $PROJECT_ROOT${NC}"
    echo -e "${BLUE}Log file: $LOG_FILE${NC}"
    echo
    
    read -p "Continue with installation? (Y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        log "INFO" "Installation cancelled by user"
        exit 0
    fi
}

# Make scripts executable
prepare_scripts() {
    log "INFO" "Preparing installation scripts..."
    
    # Make all scripts executable
    find "$PROJECT_ROOT/scripts" -name "*.sh" -exec chmod +x {} \;
    
    # Verify critical scripts exist
    local critical_scripts=(
        "scripts/upgrade-system.sh"
        "scripts/install-odoo19.sh"
        "scripts/setup-cron.sh"
        "scripts/backup-odoo.sh"
        "scripts/restore-odoo.sh"
        "scripts/daily-maintenance.sh"
        "scripts/weekly-odoo-update.sh"
    )
    
    for script in "${critical_scripts[@]}"; do
        if [[ ! -f "$PROJECT_ROOT/$script" ]]; then
            log "ERROR" "Critical script not found: $script"
            exit 1
        fi
    done
    
    log "SUCCESS" "Scripts prepared successfully"
}

# Backup existing Odoo installation
backup_existing_installation() {
    if [[ "$BACKUP_EXISTING" == false ]]; then
        log "INFO" "Backup disabled, skipping"
        return 0
    fi
    
    log "INFO" "Checking for existing Odoo installation..."
    
    local backup_created=false
    
    # Backup existing Odoo directory
    if [[ -d "/opt/odoo" ]]; then
        log "INFO" "Found existing Odoo installation, creating backup..."
        local backup_dir="/opt/odoo.backup.$(date +%Y%m%d-%H%M%S)"
        
        if cp -r "/opt/odoo" "$backup_dir"; then
            log "SUCCESS" "Odoo directory backed up to: $backup_dir"
            backup_created=true
        else
            log "WARN" "Failed to backup existing Odoo directory"
        fi
    fi
    
    # Backup existing configuration
    if [[ -f "/etc/odoo/odoo.conf" ]]; then
        log "INFO" "Backing up existing Odoo configuration..."
        local config_backup="/etc/odoo/odoo.conf.backup.$(date +%Y%m%d-%H%M%S)"
        
        if cp "/etc/odoo/odoo.conf" "$config_backup"; then
            log "SUCCESS" "Configuration backed up to: $config_backup"
            backup_created=true
        else
            log "WARN" "Failed to backup existing configuration"
        fi
    fi
    
    if [[ "$backup_created" == true ]]; then
        log "INFO" "Existing installation backed up successfully"
    else
        log "INFO" "No existing installation found to backup"
    fi
}

# Run system upgrade
run_system_upgrade() {
    if [[ "$SKIP_SYSTEM_UPDATE" == true ]]; then
        log "INFO" "System upgrade skipped as requested"
        return 0
    fi
    
    log "INFO" "Starting system upgrade..."
    
    local upgrade_script="$PROJECT_ROOT/scripts/upgrade-system.sh"
    
    if [[ -f "$upgrade_script" ]]; then
        if "$upgrade_script" 2>&1 | tee -a "$LOG_FILE"; then
            log "SUCCESS" "System upgrade completed successfully"
            return 0
        else
            log "ERROR" "System upgrade failed"
            return 1
        fi
    else
        log "ERROR" "System upgrade script not found: $upgrade_script"
        return 1
    fi
}

# Run Odoo installation
run_odoo_installation() {
    if [[ "$SKIP_ODOO_INSTALL" == true ]]; then
        log "INFO" "Odoo installation skipped as requested"
        return 0
    fi
    
    log "INFO" "Starting Odoo 19.0 installation..."
    
    local install_script="$PROJECT_ROOT/scripts/install-odoo19.sh"
    
    if [[ -f "$install_script" ]]; then
        if "$install_script" 2>&1 | tee -a "$LOG_FILE"; then
            log "SUCCESS" "Odoo 19.0 installation completed successfully"
            return 0
        else
            log "ERROR" "Odoo installation failed"
            return 1
        fi
    else
        log "ERROR" "Odoo installation script not found: $install_script"
        return 1
    fi
}

# Run cron setup
run_cron_setup() {
    if [[ "$SKIP_CRON_SETUP" == true ]]; then
        log "INFO" "Cron setup skipped as requested"
        return 0
    fi
    
    log "INFO" "Setting up automatic update cron jobs..."
    
    local cron_script="$PROJECT_ROOT/scripts/setup-cron.sh"
    
    if [[ -f "$cron_script" ]]; then
        if "$cron_script" 2>&1 | tee -a "$LOG_FILE"; then
            log "SUCCESS" "Cron setup completed successfully"
            return 0
        else
            log "ERROR" "Cron setup failed"
            return 1
        fi
    else
        log "ERROR" "Cron setup script not found: $cron_script"
        return 1
    fi
}

# Verify installation
verify_installation() {
    log "INFO" "Verifying installation..."
    
    local verification_passed=true
    
    # Check if Odoo service is running
    if systemctl is-active --quiet odoo; then
        log "SUCCESS" "Odoo service is running"
    else
        log "ERROR" "Odoo service is not running"
        verification_passed=false
    fi
    
    # Check if PostgreSQL is running
    if systemctl is-active --quiet postgresql; then
        log "SUCCESS" "PostgreSQL service is running"
    else
        log "ERROR" "PostgreSQL service is not running"
        verification_passed=false
    fi
    
    # Check if Odoo is responding
    if command -v curl &> /dev/null; then
        local max_attempts=6
        local attempt=1
        
        while [[ $attempt -le $max_attempts ]]; do
            local response_code=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8069 || echo "000")
            
            if [[ "$response_code" =~ ^(200|302)$ ]]; then
                log "SUCCESS" "Odoo web interface is responding"
                break
            fi
            
            if [[ $attempt -eq $max_attempts ]]; then
                log "WARN" "Odoo web interface not responding after $max_attempts attempts"
                verification_passed=false
            else
                log "INFO" "Waiting for Odoo to respond... (attempt $attempt/$max_attempts)"
                sleep 10
            fi
            
            ((attempt++))
        done
    fi
    
    # Check cron jobs
    if crontab -l 2>/dev/null | grep -q "$PROJECT_ROOT"; then
        log "SUCCESS" "Cron jobs are installed"
    else
        log "WARN" "Cron jobs may not be installed correctly"
    fi
    
    if [[ "$verification_passed" == true ]]; then
        log "SUCCESS" "Installation verification completed successfully"
        return 0
    else
        log "WARN" "Installation verification completed with warnings"
        return 1
    fi
}

# Display final summary and instructions
show_final_summary() {
    log "INFO" "========================================"
    log "INFO" "Installation Complete!"
    log "INFO" "========================================"
    
    echo
    echo -e "${GREEN}${BOLD}🎉 Odoo 19.0 Upgrade System Installation Complete!${NC}"
    echo
    echo -e "${BLUE}${BOLD}Installation Summary:${NC}"
    echo -e "${BLUE}===================${NC}"
    
    # Service status
    local odoo_status=$(systemctl is-active odoo)
    local postgres_status=$(systemctl is-active postgresql)
    
    echo -e "${GREEN}✓${NC} Odoo Service: $odoo_status"
    echo -e "${GREEN}✓${NC} PostgreSQL Service: $postgres_status"
    
    # Access information
    echo
    echo -e "${BLUE}${BOLD}Access Information:${NC}"
    echo -e "${BLUE}==================${NC}"
    echo -e "${GREEN}🌐 Web Interface:${NC} http://localhost:8069"
    echo -e "${GREEN}🌐 External Access:${NC} http://your-server-ip:8069"
    echo -e "${GREEN}📁 Odoo Directory:${NC} /opt/odoo"
    echo -e "${GREEN}⚙️  Configuration:${NC} /etc/odoo/odoo.conf"
    echo -e "${GREEN}📋 Log Files:${NC} /var/log/odoo/"
    
    # Cron information
    echo
    echo -e "${BLUE}${BOLD}Automated Tasks:${NC}"
    echo -e "${BLUE}===============${NC}"
    echo -e "${GREEN}📅 Daily Maintenance:${NC} 2:00 AM (system updates, health checks)"
    echo -e "${GREEN}📅 Weekly Updates:${NC} Sunday 3:00 AM (Odoo updates)"
    echo -e "${GREEN}💾 Daily Backups:${NC} 1:30 AM (database and filestore)"
    echo -e "${GREEN}🔍 Hourly Monitoring:${NC} System health checks"
    
    # Next steps
    echo
    echo -e "${BLUE}${BOLD}Next Steps:${NC}"
    echo -e "${BLUE}===========${NC}"
    echo -e "${YELLOW}1.${NC} Access Odoo at http://your-server-ip:8069"
    echo -e "${YELLOW}2.${NC} Create your first database"
    echo -e "${YELLOW}3.${NC} Configure your Odoo instance"
    echo -e "${YELLOW}4.${NC} Review configuration file: /etc/odoo/odoo.conf"
    echo -e "${YELLOW}5.${NC} Set up SSL/TLS with nginx (recommended for production)"
    
    # Useful commands
    echo
    echo -e "${BLUE}${BOLD}Useful Commands:${NC}"
    echo -e "${BLUE}===============${NC}"
    echo -e "${GREEN}Service Control:${NC}"
    echo -e "  sudo systemctl status odoo     # Check Odoo status"
    echo -e "  sudo systemctl restart odoo    # Restart Odoo"
    echo -e "  sudo systemctl stop odoo       # Stop Odoo"
    echo -e "  sudo systemctl start odoo      # Start Odoo"
    echo
    echo -e "${GREEN}Logs:${NC}"
    echo -e "  sudo tail -f /var/log/odoo/odoo.log              # Odoo logs"
    echo -e "  sudo tail -f /var/log/odoo-upgrade/daily.log     # Daily maintenance"
    echo -e "  sudo journalctl -u odoo -f                       # Service logs"
    echo
    echo -e "${GREEN}Backup & Restore:${NC}"
    echo -e "  sudo $PROJECT_ROOT/scripts/backup-odoo.sh        # Manual backup"
    echo -e "  sudo $PROJECT_ROOT/scripts/restore-odoo.sh --list # List backups"
    echo
    echo -e "${GREEN}Maintenance:${NC}"
    echo -e "  sudo $PROJECT_ROOT/scripts/daily-maintenance.sh  # Manual maintenance"
    echo -e "  crontab -l                                       # Show cron jobs"
    
    # Support information
    echo
    echo -e "${BLUE}${BOLD}Support & Documentation:${NC}"
    echo -e "${BLUE}========================${NC}"
    echo -e "${GREEN}📖 Project Repository:${NC} https://github.com/Hammdie/odoo-upgrade-cron"
    echo -e "${GREEN}📋 Installation Log:${NC} $LOG_FILE"
    echo -e "${GREEN}🐛 Report Issues:${NC} https://github.com/Hammdie/odoo-upgrade-cron/issues"
    echo
    
    log "INFO" "Installation log saved to: $LOG_FILE"
    log "INFO" "Thank you for using the Odoo 19.0 Upgrade System!"
}

# Error handler
handle_error() {
    local exit_code=$?
    local line_number=$1
    
    log "ERROR" "Installation failed at line $line_number with exit code $exit_code"
    
    echo
    echo -e "${RED}${BOLD}❌ Installation Failed!${NC}"
    echo -e "${YELLOW}Error occurred at line $line_number${NC}"
    echo -e "${YELLOW}Check the log file for details: $LOG_FILE${NC}"
    echo
    echo -e "${BLUE}Common solutions:${NC}"
    echo -e "${YELLOW}•${NC} Check internet connectivity"
    echo -e "${YELLOW}•${NC} Ensure sufficient disk space (20GB+)"
    echo -e "${YELLOW}•${NC} Verify system requirements"
    echo -e "${YELLOW}•${NC} Run with sudo privileges"
    echo
    echo -e "${BLUE}For help:${NC} https://github.com/Hammdie/odoo-upgrade-cron/issues"
    
    exit $exit_code
}

# Main execution
main() {
    # Set error handler
    trap 'handle_error $LINENO' ERR
    
    # Parse arguments
    parse_arguments "$@"
    
    # Show banner
    show_banner
    
    # Create log directory
    create_log_dir
    
    # Start logging
    log "INFO" "Starting Odoo 19.0 Upgrade System Installation"
    log "INFO" "Installation directory: $PROJECT_ROOT"
    log "INFO" "Log file: $LOG_FILE"
    log "INFO" "Arguments: $*"
    
    # Pre-installation checks
    check_root
    check_requirements
    prepare_scripts
    
    # Show installation plan
    show_installation_plan
    
    # Start installation
    log "INFO" "========================================"
    log "INFO" "Beginning installation process..."
    log "INFO" "========================================"
    
    # Backup existing installation
    backup_existing_installation
    
    # Run installation steps
    if ! run_system_upgrade; then
        log "ERROR" "System upgrade failed"
        exit 1
    fi
    
    if ! run_odoo_installation; then
        log "ERROR" "Odoo installation failed"
        exit 1
    fi
    
    if ! run_cron_setup; then
        log "ERROR" "Cron setup failed"
        exit 1
    fi
    
    # Verify installation
    verify_installation
    
    # Show final summary
    show_final_summary
    
    log "SUCCESS" "Odoo 19.0 Upgrade System installation completed successfully!"
}

# Run main function
main "$@"
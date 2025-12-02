#!/bin/bash

###############################################################################
# Odoo Enterprise Edition Installation Script
# 
# Installiert Odoo Enterprise Edition nachträglich zu einer bestehenden
# Odoo Community Installation
#
# Usage:
#   sudo ./install-enterprise.sh
###############################################################################

set -e  # Exit on any error

# Configuration
ODOO_USER="odoo"
ENTERPRISE_PATH="/opt/odoo/enterprise"
ODOO_CONFIG="/etc/odoo/odoo.conf"
LOG_DIR="/var/log/odoo-upgrade"
LOG_FILE="$LOG_DIR/install-enterprise-$(date +%Y%m%d-%H%M%S).log"

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
    echo -e "${BLUE}${BOLD}"
    cat << 'EOF'
   ___      _               _____       _                       _          
  / _ \  __| | ___   ___   | ____|_ __ | |_ ___ _ __ _ __  _ __(_)___  ___ 
 | | | |/ _` |/ _ \ / _ \  |  _| | '_ \| __/ _ \ '__| '_ \| '__| / __|/ _ \
 | |_| | (_| | (_) | (_) | | |___| | | | ||  __/ |  | |_) | |  | \__ \  __/
  \___/ \__,_|\___/ \___/  |_____|_| |_|\__\___|_|  | .__/|_|  |_|___/\___|
                                                     |_|                    
           Enterprise Edition Installation           
EOF
    echo -e "${NC}"
    echo -e "${GREEN}Installiert Odoo Enterprise Edition für Ihre bestehende Installation${NC}"
    echo
}

# Check prerequisites
check_prerequisites() {
    log "INFO" "Checking prerequisites..."
    
    # Check if odoo user exists
    if ! id -u "$ODOO_USER" &>/dev/null; then
        log "ERROR" "User '$ODOO_USER' does not exist"
        log "ERROR" "Please install Odoo Community first with: sudo ./install.sh"
        exit 1
    fi
    
    # Check if Odoo is installed
    if [[ ! -d "/opt/odoo/odoo" ]]; then
        log "ERROR" "Odoo installation not found at /opt/odoo/odoo"
        log "ERROR" "Please install Odoo Community first with: sudo ./install.sh"
        exit 1
    fi
    
    # Check if Git is available
    if ! command -v git &> /dev/null; then
        log "ERROR" "Git is not installed"
        log "INFO" "Installing Git..."
        apt-get update
        apt-get install -y git
    fi
    
    # Check if Odoo config exists
    if [[ ! -f "$ODOO_CONFIG" ]]; then
        log "ERROR" "Odoo configuration not found at $ODOO_CONFIG"
        exit 1
    fi
    
    log "SUCCESS" "Prerequisites check passed"
}

# Check if Enterprise is already installed
check_existing_installation() {
    if [[ -d "$ENTERPRISE_PATH" ]] && [[ -d "$ENTERPRISE_PATH/.git" ]]; then
        log "WARN" "Enterprise edition already installed at $ENTERPRISE_PATH"
        echo
        read -p "Do you want to reinstall? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log "INFO" "Installation cancelled by user"
            exit 0
        fi
        
        # Backup existing installation
        local backup_path="$ENTERPRISE_PATH.backup.$(date +%Y%m%d-%H%M%S)"
        log "INFO" "Backing up existing installation to $backup_path"
        mv "$ENTERPRISE_PATH" "$backup_path"
    elif [[ -d "$ENTERPRISE_PATH" ]]; then
        log "WARN" "Directory exists but is not a git repository"
        log "INFO" "Removing directory..."
        rm -rf "$ENTERPRISE_PATH"
    fi
}

# Setup SSH key for current user
setup_ssh_key() {
    # Get current user (the one who called sudo)
    local current_user="${SUDO_USER:-$USER}"
    local user_home=$(eval echo ~$current_user)
    local ssh_dir="$user_home/.ssh"
    local ssh_key_ed25519="$ssh_dir/id_ed25519"
    local ssh_key_rsa="$ssh_dir/id_rsa"
    
    log "INFO" "Checking SSH configuration for user: $current_user"
    log "INFO" "SSH directory: $ssh_dir"
    
    # Check if any SSH key exists
    local has_ed25519=false
    local has_rsa=false
    
    if [[ -f "$ssh_key_ed25519" ]]; then
        has_ed25519=true
        log "INFO" "Found ED25519 key: $ssh_key_ed25519"
    fi
    
    if [[ -f "$ssh_key_rsa" ]]; then
        has_rsa=true
        log "INFO" "Found RSA key: $ssh_key_rsa"
    fi
    
    # Test SSH connection with current user
    if $has_ed25519 || $has_rsa; then
        if sudo -u "$current_user" ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
            log "SUCCESS" "SSH authentication verified for $current_user"
            return 0
        else
            log "WARN" "SSH key exists but GitHub authentication failed"
        fi
    else
        log "WARN" "No SSH keys found for $current_user"
    fi
    
    # Ask user to configure SSH
    echo
    echo -e "${YELLOW}${BOLD}SSH Key Configuration Required${NC}"
    echo -e "${BLUE}To install Enterprise edition, you need:${NC}"
    echo -e "  1. Valid Odoo Partner access"
    echo -e "  2. SSH key configured for GitHub"
    echo
    echo -e "${BOLD}Current Status:${NC}"
    if $has_ed25519; then
        echo -e "  ${GREEN}✓${NC} ED25519 key exists"
    else
        echo -e "  ${RED}✗${NC} No ED25519 key"
    fi
    if $has_rsa; then
        echo -e "  ${GREEN}✓${NC} RSA key exists"
    else
        echo -e "  ${RED}✗${NC} No RSA key"
    fi
    echo
    echo -e "${BOLD}Choose an option:${NC}"
    echo -e "  ${GREEN}1)${NC} I have already added SSH key to GitHub (test connection)"
    echo -e "  ${GREEN}2)${NC} Generate new ED25519 SSH key and show public key"
    echo -e "  ${GREEN}3)${NC} Skip SSH check and try to clone anyway"
    echo -e "  ${RED}4)${NC} Cancel installation"
    echo
    
    while true; do
        read -p "Select option [1-4]: " choice
        case $choice in
            1)
                # Test connection
                if sudo -u "$current_user" ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
                    log "SUCCESS" "SSH authentication verified!"
                    return 0
                else
                    log "ERROR" "SSH authentication failed"
                    log "INFO" "Please add your SSH key to GitHub: https://github.com/settings/keys"
                    if $has_ed25519; then
                        echo
                        echo -e "${BLUE}Your ED25519 public key:${NC}"
                        sudo -u "$current_user" cat "$ssh_key_ed25519.pub"
                    elif $has_rsa; then
                        echo
                        echo -e "${BLUE}Your RSA public key:${NC}"
                        sudo -u "$current_user" cat "$ssh_key_rsa.pub"
                    fi
                    read -p "Press Enter to try again or Ctrl+C to cancel..."
                    continue
                fi
                ;;
            2)
                # Generate SSH key
                log "INFO" "Generating ED25519 SSH key for $current_user..."
                sudo -u "$current_user" mkdir -p "$ssh_dir"
                sudo -u "$current_user" chmod 700 "$ssh_dir"
                
                if [[ ! -f "$ssh_key_ed25519" ]]; then
                    sudo -u "$current_user" ssh-keygen -t ed25519 -C "$current_user@$(hostname)" -f "$ssh_key_ed25519" -N ""
                    log "SUCCESS" "SSH key generated"
                else
                    log "INFO" "SSH key already exists, showing public key"
                fi
                
                echo
                echo -e "${GREEN}${BOLD}Public SSH Key:${NC}"
                echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
                sudo -u "$current_user" cat "$ssh_key_ed25519.pub"
                echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
                echo
                echo -e "${YELLOW}Please add this key to GitHub:${NC}"
                echo -e "  1. Go to: ${BLUE}https://github.com/settings/keys${NC}"
                echo -e "  2. Click 'New SSH key'"
                echo -e "  3. Paste the key above"
                echo -e "  4. Click 'Add SSH key'"
                echo
                read -p "Press Enter when done..."
                
                # Test connection
                if sudo -u "$current_user" ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
                    log "SUCCESS" "SSH authentication verified!"
                    return 0
                else
                    log "WARN" "SSH authentication not working yet"
                    log "INFO" "Continuing anyway..."
                fi
                return 0
                ;;
            3)
                log "WARN" "Skipping SSH check - installation may fail"
                return 0
                ;;
            4)
                log "INFO" "Installation cancelled by user"
                exit 0
                ;;
            *)
                echo "Invalid option. Please select 1-4."
                ;;
        esac
    done
}

# Clone Enterprise repository
clone_enterprise() {
    local current_user="${SUDO_USER:-$USER}"
    
    log "INFO" "Cloning Odoo Enterprise repository..."
    log "INFO" "Source: git@github.com:odoo/enterprise.git (branch 19.0)"
    log "INFO" "Target: $ENTERPRISE_PATH"
    log "INFO" "Cloning as user: $current_user"
    
    # Create parent directory
    local parent_dir="$(dirname "$ENTERPRISE_PATH")"
    if [[ ! -d "$parent_dir" ]]; then
        mkdir -p "$parent_dir"
    fi
    
    # Clone repository as current user (who has SSH key)
    # Capture output and exit code properly
    local clone_output
    local clone_exit_code
    
    clone_output=$(sudo -u "$current_user" git clone --depth 1 --branch 19.0 git@github.com:odoo/enterprise.git "$ENTERPRISE_PATH" 2>&1)
    clone_exit_code=$?
    
    # Log the output
    echo "$clone_output" | tee -a "$LOG_FILE"
    
    # Check if clone was successful
    if [[ $clone_exit_code -ne 0 ]] || [[ ! -d "$ENTERPRISE_PATH" ]]; then
        log "ERROR" "Failed to clone Enterprise repository (exit code: $clone_exit_code)"
        echo
        echo -e "${RED}${BOLD}Common Issues:${NC}"
        echo -e "  ${YELLOW}1. SSH Key not added to GitHub${NC}"
        echo -e "     → Add your SSH key at: ${BLUE}https://github.com/settings/keys${NC}"
        echo
        echo -e "  ${YELLOW}2. No access to Odoo Enterprise repository${NC}"
        echo -e "     → Contact Odoo Partner or sales@odoo.com"
        echo -e "     → Provide your GitHub username for access"
        echo
        echo -e "  ${YELLOW}3. SSH connection issues${NC}"
        echo -e "     → Test connection: ${BLUE}ssh -T git@github.com${NC}"
        echo -e "     → Expected: 'Hi <username>! You've successfully authenticated...'"
        echo
        echo -e "${RED}Installation aborted.${NC}"
        exit 1
    fi
    
    # Verify repository was cloned successfully
    if [[ ! -f "$ENTERPRISE_PATH/README.md" ]] && [[ ! -d "$ENTERPRISE_PATH/.git" ]]; then
        log "ERROR" "Repository directory exists but appears incomplete"
        log "ERROR" "Path: $ENTERPRISE_PATH"
        rm -rf "$ENTERPRISE_PATH"
        exit 1
    fi
    
    log "SUCCESS" "Enterprise repository cloned successfully"
    
    # Set permissions to odoo user
    log "INFO" "Setting ownership to $ODOO_USER..."
    
    if ! chown -R "$ODOO_USER:$ODOO_USER" "$ENTERPRISE_PATH" 2>/dev/null; then
        log "ERROR" "Failed to set ownership to $ODOO_USER"
        log "ERROR" "Path: $ENTERPRISE_PATH"
        exit 1
    fi
    
    if ! chmod -R 755 "$ENTERPRISE_PATH" 2>/dev/null; then
        log "ERROR" "Failed to set permissions"
        exit 1
    fi
    
    log "SUCCESS" "Permissions set correctly"
}

# Update Odoo configuration
update_odoo_config() {
    log "INFO" "Updating Odoo configuration..."
    
    # Verify Enterprise directory exists before updating config
    if [[ ! -d "$ENTERPRISE_PATH" ]]; then
        log "ERROR" "Enterprise directory does not exist: $ENTERPRISE_PATH"
        log "ERROR" "Cannot update configuration without Enterprise repository"
        exit 1
    fi
    
    # Verify it's a valid git repository
    if [[ ! -d "$ENTERPRISE_PATH/.git" ]] && [[ ! -f "$ENTERPRISE_PATH/README.md" ]]; then
        log "ERROR" "Enterprise directory exists but appears to be incomplete"
        log "ERROR" "Path: $ENTERPRISE_PATH"
        exit 1
    fi
    
    # Backup configuration
    local config_backup="${ODOO_CONFIG}.backup.$(date +%Y%m%d-%H%M%S)"
    if ! cp "$ODOO_CONFIG" "$config_backup" 2>/dev/null; then
        log "ERROR" "Failed to backup Odoo configuration"
        log "ERROR" "Config file: $ODOO_CONFIG"
        exit 1
    fi
    log "INFO" "Configuration backed up to: $config_backup"
    
    # Check if enterprise is already in addons_path
    if grep -q "addons_path.*$ENTERPRISE_PATH" "$ODOO_CONFIG"; then
        log "INFO" "Enterprise path already in addons_path"
        return 0
    fi
    
    # Get current addons_path
    local current_addons=$(grep "^addons_path" "$ODOO_CONFIG" | cut -d'=' -f2- | tr -d ' ')
    
    if [[ -z "$current_addons" ]]; then
        log "ERROR" "Could not find addons_path in configuration"
        log "ERROR" "Config file: $ODOO_CONFIG"
        exit 1
    fi
    
    # Build new addons_path with enterprise first (highest priority)
    local new_addons="$ENTERPRISE_PATH,$current_addons"
    
    # Update configuration
    if ! sed -i "s|^addons_path.*|addons_path = $new_addons|" "$ODOO_CONFIG" 2>/dev/null; then
        log "ERROR" "Failed to update Odoo configuration"
        log "INFO" "Restoring backup..."
        cp "$config_backup" "$ODOO_CONFIG"
        exit 1
    fi
    
    log "SUCCESS" "Configuration updated"
    log "INFO" "New addons_path: $new_addons"
}

# Restart Odoo service
restart_odoo() {
    log "INFO" "Restarting Odoo service..."
    
    # Check if service exists
    if ! systemctl list-unit-files | grep -q "^odoo.service"; then
        log "ERROR" "Odoo service not found"
        log "ERROR" "Please ensure Odoo is installed correctly"
        exit 1
    fi
    
    if ! systemctl is-active --quiet odoo 2>/dev/null; then
        log "WARN" "Odoo service is not running"
        log "INFO" "Starting Odoo service..."
    fi
    
    # Restart the service
    if ! systemctl restart odoo 2>/dev/null; then
        log "ERROR" "Failed to restart Odoo service"
        log "INFO" "Checking service status..."
        systemctl status odoo --no-pager -l
        log "ERROR" "Check logs: sudo journalctl -u odoo -f"
        exit 1
    fi
    
    # Wait for service to start
    log "INFO" "Waiting for Odoo to start..."
    sleep 5
    
    # Verify service is running
    if systemctl is-active --quiet odoo; then
        log "SUCCESS" "Odoo service is running"
    else
        log "ERROR" "Odoo failed to start"
        echo
        echo -e "${RED}${BOLD}Service Status:${NC}"
        systemctl status odoo --no-pager -l
        echo
        log "ERROR" "Check logs: sudo journalctl -u odoo -f"
        exit 1
    fi
}

# Show final summary
show_summary() {
    echo
    echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}${BOLD}  Odoo Enterprise Edition Installation Complete!${NC}"
    echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo
    echo -e "${BLUE}Installation Details:${NC}"
    echo -e "  📁 Enterprise Path: ${GREEN}$ENTERPRISE_PATH${NC}"
    echo -e "  ⚙️  Configuration: ${GREEN}$ODOO_CONFIG${NC}"
    echo -e "  📋 Log File: ${GREEN}$LOG_FILE${NC}"
    echo
    echo -e "${BLUE}Next Steps:${NC}"
    echo -e "  1. Access Odoo in your browser"
    echo -e "  2. Go to Apps menu"
    echo -e "  3. Click 'Update Apps List'"
    echo -e "  4. Search for Enterprise modules (e.g., 'Studio', 'Documents')"
    echo -e "  5. Install the modules you need"
    echo
    echo -e "${YELLOW}Note:${NC} Enterprise modules require a valid Odoo Enterprise subscription"
    echo -e "      Contact Odoo or your partner for licensing information"
    echo
    echo -e "${BLUE}Useful Commands:${NC}"
    echo -e "  Check Odoo status: ${GREEN}sudo systemctl status odoo${NC}"
    echo -e "  View Odoo logs:    ${GREEN}sudo journalctl -u odoo -f${NC}"
    echo -e "  Restart Odoo:      ${GREEN}sudo systemctl restart odoo${NC}"
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
    log "INFO" "Starting Odoo Enterprise Edition installation"
    log "INFO" "Log file: $LOG_FILE"
    
    # Check prerequisites
    check_prerequisites
    
    # Check existing installation
    check_existing_installation
    
    # Setup SSH
    setup_ssh_key
    
    # Clone Enterprise
    clone_enterprise
    
    # Update configuration
    update_odoo_config
    
    # Restart Odoo
    restart_odoo
    
    # Show summary
    show_summary
    
    log "SUCCESS" "Enterprise installation completed successfully!"
}

# Run main function
main "$@"

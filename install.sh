#!/bin/bash

# Odoo Upgrade Cron - Hauptinstallationsscript
# Intelligente Installation mit Erkennung bestehender Odoo-Installationen

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
FORCE_REINSTALL=false
BACKUP_EXISTING=true

# Detection results
EXISTING_ODOO_FOUND=false
EXISTING_CONFIG_PATH=""
EXISTING_VERSION=""
EXISTING_SERVICE_ACTIVE=false
EXISTING_INSTALL_PATH=""

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
    --auto              Run in automatic mode (no prompts)
    --force             Force reinstall even if Odoo exists
    --skip-system       Skip system upgrade step
    --skip-odoo         Skip Odoo installation step
    --skip-cron         Skip cron setup step
    --no-backup         Don't backup existing installations
    --help              Show this help message

${BOLD}Installation Modes:${NC}
    Default:            Detect and upgrade existing Odoo or install new
    --auto:             Fully automated installation with smart detection
    --force:            Remove existing Odoo and install fresh
    --skip-system:      Keep existing system, only install/upgrade Odoo

${BOLD}Examples:${NC}
    $0                          # Interactive installation with detection
    $0 --auto                   # Automatic installation (recommended)
    $0 --force --auto           # Force clean installation
    $0 --skip-system --auto     # Skip system updates, only Odoo
    
${BOLD}Existing Installation Handling:${NC}
    The script automatically detects existing Odoo installations and:
    - Backs up existing configuration (/etc/odoo/odoo.conf)
    - Preserves database data and filestore
    - Upgrades to Odoo 19.0 while maintaining settings
    - Merges new configuration options

${BOLD}Installation Steps:${NC}
    1. Detection of existing Odoo installations
    2. System preparation and package updates (if not skipped)
    3. Backup of existing installation (if found)
    4. Odoo 19.0 installation or upgrade
    5. Configuration merge and service setup
    6. Automatic update cron jobs setup
    7. System verification and testing

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
            --auto)
                AUTO_MODE=true
                shift
                ;;
            --force)
                FORCE_REINSTALL=true
                shift
                ;;
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
    if [[ "$AUTO_MODE" == true ]] && [[ "$EXISTING_ODOO_FOUND" == false ]]; then
        return 0
    fi
    
    echo
    echo -e "${BOLD}Installation Plan:${NC}"
    echo -e "${BLUE}=================${NC}"
    
    # Show detection results
    if [[ "$EXISTING_ODOO_FOUND" == true ]]; then
        echo -e "${YELLOW}🔍 Existing Odoo Installation Detected:${NC}"
        [[ -n "$EXISTING_CONFIG_PATH" ]] && echo -e "   Config: $EXISTING_CONFIG_PATH"
        [[ -n "$EXISTING_VERSION" ]] && echo -e "   Version: $EXISTING_VERSION"
        [[ -n "$EXISTING_INSTALL_PATH" ]] && echo -e "   Path: $EXISTING_INSTALL_PATH"
        echo -e "   Status: $([ "$EXISTING_SERVICE_ACTIVE" = true ] && echo "Running" || echo "Stopped")"
        echo
        
        if [[ "$FORCE_REINSTALL" == true ]]; then
            echo -e "${RED}⚠ FORCE MODE: Will remove existing installation!${NC}"
        else
            echo -e "${GREEN}✓ Will upgrade existing installation${NC}"
        fi
        echo
    else
        echo -e "${GREEN}✓ Fresh Installation (no existing Odoo found)${NC}"
        echo
    fi
    
    # Show installation steps
    if [[ "$SKIP_SYSTEM_UPDATE" == false ]]; then
        echo -e "${GREEN}✓${NC} System Upgrade: Update packages and install dependencies"
    else
        echo -e "${YELLOW}⚠${NC} System Upgrade: ${YELLOW}SKIPPED${NC}"
    fi
    
    if [[ "$SKIP_ODOO_INSTALL" == false ]]; then
        if [[ "$EXISTING_ODOO_FOUND" == true ]] && [[ "$FORCE_REINSTALL" == false ]]; then
            echo -e "${GREEN}✓${NC} Odoo 19.0: Upgrade existing installation"
        else
            echo -e "${GREEN}✓${NC} Odoo 19.0: Fresh installation"
        fi
    else
        echo -e "${YELLOW}⚠${NC} Odoo 19.0 Installation: ${YELLOW}SKIPPED${NC}"
    fi
    
    if [[ "$SKIP_CRON_SETUP" == false ]]; then
        echo -e "${GREEN}✓${NC} Cron Setup: Configure automatic updates and maintenance"
    else
        echo -e "${YELLOW}⚠${NC} Cron Setup: ${YELLOW}SKIPPED${NC}"
    fi
    
    echo -e "${BLUE}Backup existing: $([ "$BACKUP_EXISTING" == true ] && echo "${GREEN}Yes${NC}" || echo "${YELLOW}No${NC}")${NC}"
    echo -e "${BLUE}Installation directory: $PROJECT_ROOT${NC}"
    echo -e "${BLUE}Log file: $LOG_FILE${NC}"
    
    if [[ "$AUTO_MODE" != true ]]; then
        echo
        read -p "Continue with installation? (Y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Nn]$ ]]; then
            log "INFO" "Installation cancelled by user"
            exit 0
        fi
    fi
}

# Detect existing Odoo installation
detect_existing_odoo() {
    log "INFO" "Scanning for existing Odoo installations..."
    
    # Check for systemd service
    if systemctl list-unit-files 2>/dev/null | grep -q "^odoo.service"; then
        log "INFO" "Found Odoo systemd service"
        EXISTING_ODOO_FOUND=true
        
        # Check if service is active
        if systemctl is-active --quiet odoo 2>/dev/null; then
            EXISTING_SERVICE_ACTIVE=true
            log "INFO" "Odoo service is currently running"
        else
            log "INFO" "Odoo service exists but is not running"
        fi
    fi
    
    # Check for configuration files in common locations
    local config_locations=(
        "/etc/odoo/odoo.conf"
        "/etc/odoo.conf"
        "/opt/odoo/odoo.conf"
        "/usr/local/etc/odoo.conf"
        "/home/odoo/.odoorc"
    )
    
    for config_path in "${config_locations[@]}"; do
        if [[ -f "$config_path" ]]; then
            log "INFO" "Found Odoo configuration: $config_path"
            EXISTING_CONFIG_PATH="$config_path"
            EXISTING_ODOO_FOUND=true
            break
        fi
    done
    
    # Check for Odoo installation directories
    local install_locations=(
        "/opt/odoo"
        "/usr/lib/python*/dist-packages/odoo"
        "/home/odoo"
        "/var/lib/odoo"
    )
    
    for install_path in "${install_locations[@]}"; do
        if [[ -d "$install_path" ]]; then
            # Look for Odoo binaries
            local odoo_bin=""
            if find "$install_path" -name "odoo-bin" -type f 2>/dev/null | grep -q .; then
                odoo_bin=$(find "$install_path" -name "odoo-bin" -type f 2>/dev/null | head -1)
            elif find "$install_path" -name "odoo.py" -type f 2>/dev/null | grep -q .; then
                odoo_bin=$(find "$install_path" -name "odoo.py" -type f 2>/dev/null | head -1)
            fi
            
            if [[ -n "$odoo_bin" ]]; then
                log "INFO" "Found Odoo installation: $install_path"
                EXISTING_INSTALL_PATH="$install_path"
                EXISTING_ODOO_FOUND=true
                
                # Try to detect version
                if [[ -x "$odoo_bin" ]]; then
                    local detected_version=$(python3 "$odoo_bin" --version 2>/dev/null | head -1 | grep -oP '\d+\.\d+' || echo "")
                    if [[ -n "$detected_version" ]]; then
                        EXISTING_VERSION="$detected_version"
                        log "INFO" "Detected Odoo version: $EXISTING_VERSION"
                    fi
                fi
                break
            fi
        fi
    done
    
    # Check for Odoo processes
    if pgrep -f "odoo" > /dev/null 2>&1; then
        log "INFO" "Found running Odoo processes"
        EXISTING_ODOO_FOUND=true
        
        # Try to get version from running process
        if [[ -z "$EXISTING_VERSION" ]]; then
            local proc_info=$(ps aux | grep odoo | grep -v grep | head -1)
            if [[ -n "$proc_info" ]]; then
                log "INFO" "Detected running Odoo process"
            fi
        fi
    fi
    
    # Check for Odoo databases
    if systemctl is-active --quiet postgresql 2>/dev/null; then
        local odoo_databases=$(sudo -u postgres psql -lqt 2>/dev/null | cut -d \| -f 1 | grep -v -E '^$|template|postgres' | grep -E 'odoo|production|test' | wc -l)
        if [[ $odoo_databases -gt 0 ]]; then
            log "INFO" "Found $odoo_databases potential Odoo database(s)"
            EXISTING_ODOO_FOUND=true
        fi
    fi
    
    # Summary
    if [[ "$EXISTING_ODOO_FOUND" == true ]]; then
        echo
        log "WARN" "🔍 EXISTING ODOO INSTALLATION DETECTED!"
        log "INFO" "==========================================="
        [[ -n "$EXISTING_CONFIG_PATH" ]] && log "INFO" "📋 Configuration: $EXISTING_CONFIG_PATH"
        [[ -n "$EXISTING_INSTALL_PATH" ]] && log "INFO" "📂 Installation: $EXISTING_INSTALL_PATH"
        [[ -n "$EXISTING_VERSION" ]] && log "INFO" "🏷️  Version: $EXISTING_VERSION" || log "INFO" "🏷️  Version: Unknown"
        log "INFO" "🔄 Service Status: $([ "$EXISTING_SERVICE_ACTIVE" = true ] && echo "Running" || echo "Stopped")"
        log "INFO" "==========================================="
        echo
    else
        log "SUCCESS" "No existing Odoo installation found - clean installation possible"
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
    if [[ "$EXISTING_ODOO_FOUND" != true ]] || [[ "$BACKUP_EXISTING" != true ]]; then
        return 0
    fi
    
    log "INFO" "Creating comprehensive backup of existing Odoo installation..."
    
    local backup_dir="/opt/odoo-backup-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$backup_dir"
    
    local backup_created=false
    
    # Backup configuration files
    if [[ -n "$EXISTING_CONFIG_PATH" ]]; then
        log "INFO" "Backing up Odoo configuration: $EXISTING_CONFIG_PATH"
        local config_name=$(basename "$EXISTING_CONFIG_PATH")
        cp "$EXISTING_CONFIG_PATH" "$backup_dir/$config_name"
        backup_created=true
    fi
    
    # Backup Odoo installation directory
    if [[ -n "$EXISTING_INSTALL_PATH" ]] && [[ -d "$EXISTING_INSTALL_PATH" ]]; then
        log "INFO" "Backing up Odoo installation: $EXISTING_INSTALL_PATH"
        cp -r "$EXISTING_INSTALL_PATH" "$backup_dir/odoo-installation" 2>/dev/null || {
            log "WARN" "Some files could not be backed up (permissions or in use)"
        }
        backup_created=true
    fi
    
    # Backup systemd service file
    if [[ -f "/etc/systemd/system/odoo.service" ]]; then
        log "INFO" "Backing up systemd service file"
        cp "/etc/systemd/system/odoo.service" "$backup_dir/"
        backup_created=true
    fi
    
    # Backup databases
    if systemctl is-active --quiet postgresql 2>/dev/null; then
        log "INFO" "Creating database backup..."
        local db_backup_dir="$backup_dir/databases"
        mkdir -p "$db_backup_dir"
        
        # Get list of potential Odoo databases
        local databases
        mapfile -t databases < <(sudo -u postgres psql -lqt 2>/dev/null | cut -d \| -f 1 | grep -v -E '^$|template|postgres' | sed 's/^ *//g')
        
        for db in "${databases[@]}"; do
            if [[ -n "$db" ]]; then
                log "INFO" "Backing up database: $db"
                sudo -u postgres pg_dump "$db" > "$db_backup_dir/${db}.sql" 2>/dev/null || {
                    log "WARN" "Could not backup database: $db"
                }
            fi
        done
        
        if [[ -n "$(ls -A "$db_backup_dir" 2>/dev/null)" ]]; then
            backup_created=true
        fi
    fi
    
    # Create restore script
    cat > "$backup_dir/restore.sh" << EOF
#!/bin/bash
# Odoo Installation Restore Script
# Created: $(date)

echo "Restoring Odoo installation from backup..."

# Stop current Odoo service
sudo systemctl stop odoo 2>/dev/null || true

# Restore configuration
if [[ -f "$backup_dir/$(basename "$EXISTING_CONFIG_PATH")" ]]; then
    sudo cp "$backup_dir/$(basename "$EXISTING_CONFIG_PATH")" "$EXISTING_CONFIG_PATH"
    echo "Configuration restored"
fi

# Restore installation
if [[ -d "$backup_dir/odoo-installation" ]]; then
    sudo cp -r "$backup_dir/odoo-installation" "$EXISTING_INSTALL_PATH"
    echo "Installation directory restored"
fi

# Restore systemd service
if [[ -f "$backup_dir/odoo.service" ]]; then
    sudo cp "$backup_dir/odoo.service" "/etc/systemd/system/"
    sudo systemctl daemon-reload
    echo "Systemd service restored"
fi

# Restore databases
if [[ -d "$backup_dir/databases" ]]; then
    echo "Database files available in: $backup_dir/databases"
    echo "Restore manually with: sudo -u postgres psql < database_file.sql"
fi

# Start Odoo service
sudo systemctl start odoo
echo "Restore completed"
EOF
    
    chmod +x "$backup_dir/restore.sh"
    
    # Create backup info file
    cat > "$backup_dir/backup_info.txt" << EOF
Odoo Installation Backup
========================
Created: $(date)
Original Config: $EXISTING_CONFIG_PATH
Original Installation: $EXISTING_INSTALL_PATH  
Original Version: $EXISTING_VERSION
Service Active: $EXISTING_SERVICE_ACTIVE
Backup Location: $backup_dir

Contents:
- Configuration files
- Installation directory
- Systemd service file
- Database dumps (if accessible)
- Automatic restore script

To restore:
1. Run: $backup_dir/restore.sh
   OR
2. Follow manual steps in this file

Manual Restore Steps:
1. Stop Odoo: sudo systemctl stop odoo
2. Restore config: sudo cp backup_dir/config_file $EXISTING_CONFIG_PATH
3. Restore installation: sudo cp -r backup_dir/odoo-installation $EXISTING_INSTALL_PATH
4. Restore service: sudo cp backup_dir/odoo.service /etc/systemd/system/
5. Reload systemd: sudo systemctl daemon-reload
6. Start Odoo: sudo systemctl start odoo
EOF
    
    if [[ "$backup_created" == true ]]; then
        log "SUCCESS" "Backup created successfully at: $backup_dir"
        log "INFO" "Restore script: $backup_dir/restore.sh"
        log "INFO" "Backup info: $backup_dir/backup_info.txt"
        
        # Set proper permissions
        chown -R root:root "$backup_dir"
        chmod -R 600 "$backup_dir"
        chmod 700 "$backup_dir"
        chmod +x "$backup_dir/restore.sh"
    else
        log "WARN" "No backup was created (no files to backup or access denied)"
        rmdir "$backup_dir" 2>/dev/null || true
    fi
}

# Handle existing installation intelligently  
handle_existing_installation() {
    if [[ "$EXISTING_ODOO_FOUND" != true ]]; then
        return 0
    fi
    
    log "INFO" "Handling existing Odoo installation..."
    
    # Force reinstall mode
    if [[ "$FORCE_REINSTALL" == true ]]; then
        log "WARN" "Force reinstall requested - will remove existing installation"
        if [[ "$AUTO_MODE" != true ]]; then
            echo
            echo -e "${RED}⚠️  WARNING: Force reinstall will completely remove existing Odoo!${NC}"
            echo -e "${YELLOW}This will delete:${NC}"
            echo -e "${YELLOW}  - Current installation${NC}"
            echo -e "${YELLOW}  - Configuration files${NC}" 
            echo -e "${YELLOW}  - Service files${NC}"
            echo -e "${RED}Database and filestore will be preserved${NC}"
            echo
            read -p "Are you absolutely sure? Type 'YES' to continue: " confirm
            if [[ "$confirm" != "YES" ]]; then
                log "INFO" "Force reinstall cancelled by user"
                exit 0
            fi
        fi
        remove_existing_installation
        return 0
    fi
    
    # Interactive mode - ask user what to do
    if [[ "$AUTO_MODE" != true ]]; then
        echo
        echo -e "${YELLOW}🔍 Existing Odoo installation detected!${NC}"
        echo -e "${BLUE}Current version: ${EXISTING_VERSION:-Unknown}${NC}"
        echo -e "${BLUE}Config location: ${EXISTING_CONFIG_PATH}${NC}"
        echo -e "${BLUE}Install location: ${EXISTING_INSTALL_PATH}${NC}"
        echo
        echo "How would you like to proceed?"
        echo "1) Upgrade existing installation (recommended)"
        echo "2) Install cron automation only (keep current Odoo)"
        echo "3) Force clean installation (removes existing)"
        echo "4) Cancel installation"
        echo
        
        while true; do
            read -p "Select option [1-4]: " choice
            case $choice in
                1)
                    log "INFO" "User selected: Upgrade existing installation"
                    upgrade_existing_installation
                    break
                    ;;
                2)
                    log "INFO" "User selected: Install cron automation only"
                    install_automation_only
                    break
                    ;;
                3)
                    log "INFO" "User selected: Force clean installation"
                    backup_existing_installation
                    remove_existing_installation
                    break
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
    else
        # Auto mode - intelligent upgrade
        log "INFO" "Auto mode: Upgrading existing installation to Odoo 19.0"
        upgrade_existing_installation
    fi
}

# Remove existing installation
remove_existing_installation() {
    log "INFO" "Removing existing Odoo installation..."
    
    # Stop services
    if systemctl is-active --quiet odoo 2>/dev/null; then
        log "INFO" "Stopping Odoo service..."
        systemctl stop odoo
        
        # Wait for graceful shutdown
        local timeout=30
        while systemctl is-active --quiet odoo && [[ $timeout -gt 0 ]]; do
            sleep 2
            ((timeout-=2))
        done
        
        if systemctl is-active --quiet odoo; then
            log "WARN" "Force stopping Odoo service..."
            systemctl kill odoo
            sleep 5
        fi
    fi
    
    # Disable and remove service
    if systemctl list-unit-files 2>/dev/null | grep -q "^odoo.service"; then
        systemctl disable odoo 2>/dev/null || true
        rm -f "/etc/systemd/system/odoo.service"
        systemctl daemon-reload
        log "INFO" "Removed Odoo systemd service"
    fi
    
    # Remove installation directory (preserve data)
    if [[ -n "$EXISTING_INSTALL_PATH" ]] && [[ -d "$EXISTING_INSTALL_PATH" ]]; then
        # Preserve important data directories
        local data_backup="/tmp/odoo-data-preservation"
        mkdir -p "$data_backup"
        
        # Preserve filestore
        if [[ -d "$EXISTING_INSTALL_PATH/.local/share/Odoo" ]]; then
            mv "$EXISTING_INSTALL_PATH/.local/share/Odoo" "$data_backup/" 2>/dev/null || true
            log "INFO" "Preserved Odoo filestore data"
        fi
        
        # Preserve custom addons if they exist
        if [[ -d "$EXISTING_INSTALL_PATH/custom-addons" ]] || [[ -d "$EXISTING_INSTALL_PATH/addons-custom" ]]; then
            find "$EXISTING_INSTALL_PATH" -name "*custom*" -type d -exec cp -r {} "$data_backup/" \; 2>/dev/null || true
            log "INFO" "Preserved custom addons"
        fi
        
        # Remove installation
        rm -rf "$EXISTING_INSTALL_PATH"
        log "INFO" "Removed installation directory: $EXISTING_INSTALL_PATH"
        
        # Restore preserved data to standard location
        if [[ -d "$data_backup/Odoo" ]]; then
            mkdir -p "/opt/odoo/.local/share"
            mv "$data_backup/Odoo" "/opt/odoo/.local/share/"
            log "INFO" "Restored filestore to standard location"
        fi
        
        # Clean up
        rm -rf "$data_backup" 2>/dev/null || true
    fi
    
    log "SUCCESS" "Existing installation removed successfully"
}

# Upgrade existing installation
upgrade_existing_installation() {
    log "INFO" "Upgrading existing Odoo installation to version 19.0..."
    
    # Stop service for upgrade
    if systemctl is-active --quiet odoo 2>/dev/null; then
        log "INFO" "Stopping Odoo service for upgrade..."
        systemctl stop odoo
    fi
    
    # Backup configuration before merge
    if [[ -n "$EXISTING_CONFIG_PATH" ]]; then
        local config_backup="${EXISTING_CONFIG_PATH}.pre-upgrade-$(date +%Y%m%d-%H%M%S)"
        cp "$EXISTING_CONFIG_PATH" "$config_backup"
        log "INFO" "Configuration backed up to: $config_backup"
    fi
    
    # Merge configurations
    merge_configurations
    
    # Set flag to modify install script behavior for upgrade
    export ODOO_UPGRADE_MODE="true"
    export EXISTING_CONFIG_PATH="$EXISTING_CONFIG_PATH"
    
    log "SUCCESS" "Existing installation prepared for upgrade"
}

# Install automation only (no Odoo changes)
install_automation_only() {
    log "INFO" "Installing automation scripts for existing Odoo installation..."
    
    # Skip Odoo installation
    SKIP_ODOO_INSTALL=true
    SKIP_SYSTEM_UPDATE=true
    
    # Verify existing installation is working
    if systemctl is-active --quiet odoo; then
        log "SUCCESS" "Existing Odoo service is running - automation will be compatible"
    else
        log "WARN" "Existing Odoo service is not running - automation may need configuration"
        
        if [[ "$AUTO_MODE" != true ]]; then
            read -p "Continue anyway? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                log "INFO" "Installation cancelled by user"
                exit 0
            fi
        fi
    fi
    
    log "INFO" "Will install only cron automation scripts"
}

# Merge configurations intelligently
merge_configurations() {
    if [[ -z "$EXISTING_CONFIG_PATH" ]] || [[ ! -f "$PROJECT_ROOT/config/odoo.conf.example" ]]; then
        log "INFO" "No configuration merge needed"
        return 0
    fi
    
    log "INFO" "Merging Odoo configuration files..."
    
    # Read existing configuration
    local temp_merged="/tmp/odoo.conf.merged.$$"
    cp "$EXISTING_CONFIG_PATH" "$temp_merged"
    
    # Preserve critical database settings
    local existing_db_password=$(grep -E "^[[:space:]]*db_password[[:space:]]*=" "$EXISTING_CONFIG_PATH" | cut -d'=' -f2 | tr -d ' ' | tr -d '"' | tr -d "'")
    local existing_db_user=$(grep -E "^[[:space:]]*db_user[[:space:]]*=" "$EXISTING_CONFIG_PATH" | cut -d'=' -f2 | tr -d ' ' | tr -d '"' | tr -d "'")
    local existing_db_host=$(grep -E "^[[:space:]]*db_host[[:space:]]*=" "$EXISTING_CONFIG_PATH" | cut -d'=' -f2 | tr -d ' ' | tr -d '"' | tr -d "'")
    
    log "INFO" "Preserving existing database configuration"
    log "INFO" "- DB User: ${existing_db_user:-odoo}"
    log "INFO" "- DB Host: ${existing_db_host:-localhost}"
    log "INFO" "- DB Password: $([ -n "$existing_db_password" ] && echo "Preserved" || echo "Not set")"
    
    # Add new configuration options from template that don't exist
    log "INFO" "Adding new Odoo 19.0 configuration options..."
    
    # Options to add for Odoo 19.0 compatibility (but preserve database settings)
    local new_options=(
        "workers = 4"
        "max_cron_threads = 2" 
        "limit_memory_hard = 2684354560"
        "limit_memory_soft = 2147483648"
        "limit_request = 8192"
        "limit_time_cpu = 600" 
        "limit_time_real = 1200"
        "proxy_mode = True"
        "without_demo = all"
    )
    
    for option in "${new_options[@]}"; do
        local option_name=$(echo "$option" | cut -d'=' -f1 | tr -d ' ')
        
        # Check if option already exists
        if ! grep -q "^[[:space:]]*${option_name}[[:space:]]*=" "$temp_merged"; then
            echo "$option" >> "$temp_merged"
            log "INFO" "Added configuration: $option"
        fi
    done
    
    # Replace original configuration
    mv "$temp_merged" "$EXISTING_CONFIG_PATH"
    
    # Ensure correct permissions
    chown odoo:odoo "$EXISTING_CONFIG_PATH" 2>/dev/null || chown root:odoo "$EXISTING_CONFIG_PATH" 2>/dev/null || true
    chmod 640 "$EXISTING_CONFIG_PATH"
    
    # Export database settings for install script
    export PRESERVE_DB_PASSWORD="$existing_db_password"
    export PRESERVE_DB_USER="$existing_db_user"
    export PRESERVE_DB_HOST="$existing_db_host"
    
    log "SUCCESS" "Configuration merged successfully"
    log "INFO" "Updated configuration: $EXISTING_CONFIG_PATH"
    log "INFO" "Database settings have been preserved"
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
    
    # Show actual configuration location
    local config_location="/etc/odoo/odoo.conf"
    if [[ -n "$EXISTING_CONFIG_PATH" ]] && [[ -f "$EXISTING_CONFIG_PATH" ]]; then
        config_location="$EXISTING_CONFIG_PATH"
    fi
    echo -e "${GREEN}⚙️  Configuration:${NC} $config_location"
    echo -e "${GREEN}📋 Log Files:${NC} /var/log/odoo/"
    
    # Show installation type
    if [[ "$EXISTING_ODOO_FOUND" == true ]] && [[ "$FORCE_REINSTALL" != true ]]; then
        echo -e "${GREEN}🔄 Installation Type:${NC} Upgrade from existing"
        [[ -n "$EXISTING_VERSION" ]] && echo -e "${GREEN}📈 Upgraded From:${NC} Version $EXISTING_VERSION"
    else
        echo -e "${GREEN}🆕 Installation Type:${NC} Fresh installation"
    fi
    
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
    
    # Start installation
    log "INFO" "========================================"
    log "INFO" "Beginning installation process..."
    log "INFO" "========================================"
    
    # Detection phase
    detect_existing_odoo
    
    # Handle existing installation
    handle_existing_installation
    
    # Show installation plan (after detection)
    show_installation_plan
    
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
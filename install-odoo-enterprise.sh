#!/bin/bash

###############################################################################
# Odoo Enterprise 19.0 Installation Script
# 
# - Installiert Odoo Enterprise 19.0 nach /opt/odoo/enterprise
# - Umfassende Fehlerbehandlung und Logging
# - Backup von vorhandenen Installationen
# - Proper Git-basierte Installation
# - Berechtigungen und Ownership konfiguration
#
# Usage:
#   sudo ./install-odoo-enterprise.sh
###############################################################################

# Configuration
ENTERPRISE_DIR="/opt/odoo/enterprise"
ENTERPRISE_REPO="https://github.com/odoo/enterprise.git"
ENTERPRISE_BRANCH="19.0"
ODOO_USER="odoo"
ODOO_GROUP="odoo"
LOG_DIR="/var/log/odoo-upgrade"
LOG_FILE="$LOG_DIR/enterprise-install-$(date +%Y%m%d-%H%M%S).log"
BACKUP_DIR="/opt/odoo/backups"

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
   ____      _             
  / __ \  __| | ___   ___  
 | |  | |/ _` |/ _ \ / _ \ 
 | |__| | (_| | (_) | (_) |
  \____/ \__,_|\___/ \___/ 
                          
   Enterprise 19.0        
EOF
    echo -e "${NC}"
    echo -e "${GREEN}Odoo Enterprise 19.0 Installation${NC}"
    echo -e "${BLUE}Installation nach /opt/odoo/enterprise${NC}"
    echo
}

# Check prerequisites
check_prerequisites() {
    log "INFO" "Checking prerequisites..."
    
    # Check Git
    if ! command -v git >/dev/null 2>&1; then
        log "ERROR" "Git is not installed"
        log "INFO" "Installing Git..."
        if apt update && apt install -y git 2>&1 | tee -a "$LOG_FILE"; then
            log "SUCCESS" "✓ Git installed"
        else
            log "ERROR" "✗ Failed to install Git"
            exit 1
        fi
    else
        log "SUCCESS" "✓ Git is available"
    fi
    
    # Check if odoo user exists
    if ! id "$ODOO_USER" >/dev/null 2>&1; then
        log "WARN" "⚠ Odoo user does not exist - creating it..."
        if useradd -r -d /var/lib/odoo -s /bin/bash "$ODOO_USER" 2>&1 | tee -a "$LOG_FILE"; then
            log "SUCCESS" "✓ Odoo user created"
        else
            log "ERROR" "✗ Failed to create Odoo user"
            exit 1
        fi
    else
        log "SUCCESS" "✓ Odoo user exists"
    fi
}

# Get GitHub credentials
get_github_credentials() {
    log "INFO" "GitHub-Anmeldedaten für Odoo Enterprise Repository..."
    
    echo -e "${YELLOW}Odoo Enterprise benötigt Zugang zum privaten GitHub Repository.${NC}"
    echo -e "${BLUE}Sie benötigen entweder:${NC}"
    echo -e "  1. ${GREEN}GitHub Personal Access Token${NC}"
    echo -e "  2. ${GREEN}SSH-Schlüssel für GitHub${NC}"
    echo -e "  3. ${GREEN}Odoo Enterprise Subscription Credentials${NC}"
    echo
    
    echo -e "${YELLOW}Welche Authentifizierungsmethode möchten Sie verwenden?${NC}"
    echo -e "  ${GREEN}1)${NC} Personal Access Token (empfohlen)"
    echo -e "  ${GREEN}2)${NC} SSH-Schlüssel"
    echo -e "  ${GREEN}3)${NC} Öffentliches Repository versuchen (kann fehlschlagen)"
    echo
    
    while true; do
        echo -n "Auswahl (1-3): "
        read auth_choice
        
        case $auth_choice in
            1)
                echo -e "${YELLOW}Geben Sie Ihren GitHub Personal Access Token ein:${NC}"
                echo -e "${BLUE}Erstellen Sie einen Token unter: https://github.com/settings/tokens${NC}"
                echo -e "${BLUE}Benötigte Berechtigung: repo (Full control of private repositories)${NC}"
                echo
                echo -n "Personal Access Token: "
                stty -echo
                read GITHUB_TOKEN
                stty echo
                echo
                
                if [ -z "$GITHUB_TOKEN" ]; then
                    echo -e "${RED}Token kann nicht leer sein${NC}"
                    continue
                fi
                
                ENTERPRISE_REPO="https://$GITHUB_TOKEN@github.com/odoo/enterprise.git"
                log "SUCCESS" "GitHub Token konfiguriert"
                break
                ;;
            2)
                echo -e "${YELLOW}SSH-Schlüssel wird verwendet...${NC}"
                echo -e "${BLUE}Stellen Sie sicher, dass Ihr SSH-Schlüssel zu GitHub hinzugefügt ist${NC}"
                ENTERPRISE_REPO="git@github.com:odoo/enterprise.git"
                log "SUCCESS" "SSH-Authentifizierung konfiguriert"
                break
                ;;
            3)
                echo -e "${YELLOW}Versuche öffentliches Repository...${NC}"
                echo -e "${RED}WARNUNG: Das kann fehlschlagen, da Enterprise privat ist${NC}"
                ENTERPRISE_REPO="https://github.com/odoo/enterprise.git"
                log "WARN" "Öffentliches Repository wird versucht"
                break
                ;;
            *)
                echo -e "${RED}Ungültige Auswahl. Bitte wählen Sie 1, 2 oder 3.${NC}"
                ;;
        esac
    done
    echo
}

# Backup existing installation
backup_existing_installation() {
    if [ -d "$ENTERPRISE_DIR" ]; then
        log "INFO" "Existing Odoo Enterprise installation found - creating backup..."
        
        # Create backup directory
        mkdir -p "$BACKUP_DIR"
        
        local backup_name="enterprise-backup-$(date +%Y%m%d-%H%M%S)"
        local backup_path="$BACKUP_DIR/$backup_name"
        
        if cp -r "$ENTERPRISE_DIR" "$backup_path" 2>&1 | tee -a "$LOG_FILE"; then
            log "SUCCESS" "✓ Backup created: $backup_path"
        else
            log "ERROR" "✗ Failed to create backup"
            exit 1
        fi
        
        # Remove existing installation
        log "INFO" "Removing existing installation..."
        if rm -rf "$ENTERPRISE_DIR" 2>&1 | tee -a "$LOG_FILE"; then
            log "SUCCESS" "✓ Existing installation removed"
        else
            log "ERROR" "✗ Failed to remove existing installation"
            exit 1
        fi
    else
        log "INFO" "No existing installation found"
    fi
}

# Create directory structure
create_directory_structure() {
    log "INFO" "Creating directory structure..."
    
    # Create parent directories
    local parent_dir=$(dirname "$ENTERPRISE_DIR")
    if mkdir -p "$parent_dir" 2>&1 | tee -a "$LOG_FILE"; then
        log "SUCCESS" "✓ Parent directory created: $parent_dir"
    else
        log "ERROR" "✗ Failed to create parent directory"
        exit 1
    fi
}

# Clone Enterprise repository
clone_enterprise_repository() {
    log "INFO" "Cloning Odoo Enterprise 19.0 repository..."
    
    # Clone the repository
    if git clone --branch "$ENTERPRISE_BRANCH" --depth 1 "$ENTERPRISE_REPO" "$ENTERPRISE_DIR" 2>&1 | tee -a "$LOG_FILE"; then
        log "SUCCESS" "✓ Odoo Enterprise repository cloned successfully"
    else
        log "ERROR" "✗ Failed to clone Odoo Enterprise repository"
        log "INFO" "Possible causes:"
        log "INFO" "  - Invalid GitHub credentials"
        log "INFO" "  - No access to Odoo Enterprise repository"
        log "INFO" "  - Network connectivity issues"
        log "INFO" "  - Invalid branch name"
        return 1
    fi
    
    # Verify the installation
    if [ -d "$ENTERPRISE_DIR" ] && [ -f "$ENTERPRISE_DIR/__init__.py" ]; then
        log "SUCCESS" "✓ Enterprise repository structure verified"
    else
        log "ERROR" "✗ Invalid repository structure"
        return 1
    fi
}

# Set permissions and ownership
set_permissions() {
    log "INFO" "Setting permissions and ownership..."
    
    # Set ownership to odoo user
    if chown -R "$ODOO_USER:$ODOO_GROUP" "$ENTERPRISE_DIR" 2>&1 | tee -a "$LOG_FILE"; then
        log "SUCCESS" "✓ Ownership set to $ODOO_USER:$ODOO_GROUP"
    else
        log "ERROR" "✗ Failed to set ownership"
        return 1
    fi
    
    # Set proper permissions
    if chmod -R 755 "$ENTERPRISE_DIR" 2>&1 | tee -a "$LOG_FILE"; then
        log "SUCCESS" "✓ Permissions set to 755"
    else
        log "ERROR" "✗ Failed to set permissions"
        return 1
    fi
}

# Validate installation
validate_installation() {
    log "INFO" "Validating Odoo Enterprise installation..."
    
    # Check main directory
    if [ ! -d "$ENTERPRISE_DIR" ]; then
        log "ERROR" "✗ Enterprise directory does not exist"
        return 1
    fi
    
    # Check for essential files
    if [ ! -f "$ENTERPRISE_DIR/__init__.py" ]; then
        log "ERROR" "✗ __init__.py not found"
        return 1
    fi
    
    # Count modules
    local module_count=$(find "$ENTERPRISE_DIR" -maxdepth 2 -name "__manifest__.py" | wc -l)
    if [ "$module_count" -lt 10 ]; then
        log "WARN" "⚠ Only $module_count modules found (expected more)"
    else
        log "SUCCESS" "✓ $module_count Enterprise modules found"
    fi
    
    # Check some essential enterprise modules
    log "INFO" "Checking essential enterprise modules..."
    
    if [ -d "$ENTERPRISE_DIR/account_accountant" ]; then
        log "SUCCESS" "✓ Essential module found: account_accountant"
    else
        log "WARN" "⚠ Essential module missing: account_accountant"
    fi
    
    if [ -d "$ENTERPRISE_DIR/project_enterprise" ]; then
        log "SUCCESS" "✓ Essential module found: project_enterprise"
    else
        log "WARN" "⚠ Essential module missing: project_enterprise"
    fi
    
    if [ -d "$ENTERPRISE_DIR/helpdesk" ]; then
        log "SUCCESS" "✓ Essential module found: helpdesk"
    else
        log "WARN" "⚠ Essential module missing: helpdesk"
    fi
    
    if [ -d "$ENTERPRISE_DIR/planning" ]; then
        log "SUCCESS" "✓ Essential module found: planning"
    else
        log "WARN" "⚠ Essential module missing: planning"
    fi
    
    if [ -d "$ENTERPRISE_DIR/documents" ]; then
        log "SUCCESS" "✓ Essential module found: documents"
    else
        log "WARN" "⚠ Essential module missing: documents"
    fi
    
    # Check Git repository information
    if [ -d "$ENTERPRISE_DIR/.git" ]; then
        local current_branch=$(cd "$ENTERPRISE_DIR" && git branch --show-current 2>/dev/null)
        local latest_commit=$(cd "$ENTERPRISE_DIR" && git log -1 --format="%h - %s (%ci)" 2>/dev/null)
        log "SUCCESS" "✓ Git repository information:"
        log "INFO" "   Branch: $current_branch"
        log "INFO" "   Latest commit: $latest_commit"
    fi
    
    log "SUCCESS" "✓ Installation validation completed"
}

# Update Odoo configuration hint
show_configuration_hint() {
    log "INFO" "Configuration update required..."
    
    echo
    echo -e "${YELLOW}${BOLD}WICHTIG: Odoo-Konfiguration aktualisieren${NC}"
    echo
    echo -e "${BLUE}Um Enterprise-Module zu verwenden, fügen Sie den Pfad zur Odoo-Konfiguration hinzu:${NC}"
    echo
    echo -e "${GREEN}1. Bearbeiten Sie die Odoo-Konfigurationsdatei:${NC}"
    echo -e "   ${CYAN}sudo nano /etc/odoo/odoo.conf${NC}"
    echo
    echo -e "${GREEN}2. Fügen Sie den Enterprise-Pfad zu addons_path hinzu:${NC}"
    echo -e "   ${CYAN}addons_path = /usr/lib/python3/dist-packages/odoo/addons,/opt/odoo/enterprise${NC}"
    echo
    echo -e "${GREEN}3. Starten Sie Odoo neu:${NC}"
    echo -e "   ${CYAN}sudo systemctl restart odoo${NC}"
    echo
    echo -e "${BLUE}Alternativ können Sie das setup-odoo-config.sh Script verwenden:${NC}"
    echo -e "   ${CYAN}sudo ./setup-odoo-config.sh${NC}"
    echo
}

# Show summary
show_summary() {
    echo
    echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}${BOLD}  Odoo Enterprise 19.0 Installation abgeschlossen!${NC}"
    echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo
    echo -e "${BLUE}Installation Details:${NC}"
    echo -e "  📁 Installationspfad: ${GREEN}$ENTERPRISE_DIR${NC}"
    echo -e "  🔖 Version: ${GREEN}Odoo Enterprise 19.0${NC}"
    echo -e "  👤 Besitzer: ${GREEN}$ODOO_USER:$ODOO_GROUP${NC}"
    echo -e "  🔒 Berechtigungen: ${GREEN}755${NC}"
    
    if [ -d "$ENTERPRISE_DIR" ]; then
        local module_count=$(find "$ENTERPRISE_DIR" -maxdepth 2 -name "__manifest__.py" | wc -l)
        echo -e "  📦 Module gefunden: ${GREEN}$module_count${NC}"
    fi
    
    echo
    echo -e "${BLUE}Nächste Schritte:${NC}"
    echo -e "  1️⃣  ${GREEN}Odoo-Konfiguration aktualisieren${NC}"
    echo -e "  2️⃣  ${GREEN}Odoo-Service neu starten${NC}"
    echo -e "  3️⃣  ${GREEN}Enterprise-Module in Odoo-Interface aktivieren${NC}"
    echo
    echo -e "${BLUE}Nützliche Befehle:${NC}"
    echo -e "  📝 Konfiguration bearbeiten: ${GREEN}sudo nano /etc/odoo/odoo.conf${NC}"
    echo -e "  🔄 Odoo neu starten: ${GREEN}sudo systemctl restart odoo${NC}"
    echo -e "  📊 Odoo Status: ${GREEN}sudo systemctl status odoo${NC}"
    echo -e "  📋 Odoo Logs: ${GREEN}sudo tail -f /var/log/odoo/odoo-server.log${NC}"
    echo
    echo -e "${BLUE}Enterprise Module Beispiele:${NC}"
    echo -e "  💼 Accounting: ${GREEN}account_accountant${NC}"
    echo -e "  🎫 Helpdesk: ${GREEN}helpdesk${NC}"
    echo -e "  📋 Project Enterprise: ${GREEN}project_enterprise${NC}"
    echo -e "  📅 Planning: ${GREEN}planning${NC}"
    echo -e "  📄 Documents: ${GREEN}documents${NC}"
    echo
    if [ -d "$BACKUP_DIR" ] && [ "$(ls -A $BACKUP_DIR 2>/dev/null)" ]; then
        echo -e "${BLUE}Backup-Verzeichnis:${NC} ${GREEN}$BACKUP_DIR${NC}"
    fi
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
    
    # Create log directory
    create_log_dir
    
    # Start logging
    log "INFO" "Starting Odoo Enterprise 19.0 installation"
    log "INFO" "Log file: $LOG_FILE"
    
    echo -e "${BLUE}Starting Enterprise installation...${NC}"
    echo
    
    # Installation steps
    check_prerequisites || { log "ERROR" "Prerequisites check failed"; exit 1; }
    get_github_credentials || { log "ERROR" "GitHub credentials setup failed"; exit 1; }
    backup_existing_installation || { log "ERROR" "Backup failed"; exit 1; }
    create_directory_structure || { log "ERROR" "Directory creation failed"; exit 1; }
    
    if clone_enterprise_repository; then
        if set_permissions; then
            if validate_installation; then
                show_configuration_hint
                show_summary
                log "SUCCESS" "Odoo Enterprise 19.0 installation completed successfully!"
            else
                log "ERROR" "Installation validation failed"
                # Cleanup on validation failure
                if [ -d "$ENTERPRISE_DIR" ]; then
                    log "INFO" "Removing invalid installation..."
                    rm -rf "$ENTERPRISE_DIR" 2>/dev/null || true
                fi
                exit 1
            fi
        else
            log "ERROR" "Setting permissions failed"
            # Cleanup on permission failure
            if [ -d "$ENTERPRISE_DIR" ]; then
                log "INFO" "Removing incomplete installation..."
                rm -rf "$ENTERPRISE_DIR" 2>/dev/null || true
            fi
            exit 1
        fi
    else
        log "ERROR" "Enterprise installation failed"
        # Cleanup on clone failure
        if [ -d "$ENTERPRISE_DIR" ]; then
            log "INFO" "Removing incomplete installation..."
            rm -rf "$ENTERPRISE_DIR" 2>/dev/null || true
        fi
        exit 1
    fi
}

# Run main function
main "$@"
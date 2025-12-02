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
SKIP_NGINX_SETUP=false
AUTO_MODE=false
FORCE_REINSTALL=false
BACKUP_EXISTING=true
SETUP_NGINX=false
NGINX_DOMAIN=""
NGINX_EMAIL=""
INSTALL_ENTERPRISE=false
ENTERPRISE_PATH="/opt/odoo/enterprise"

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
    echo -e "${BLUE}📖 Documentation: ${BOLD}https://github.com/Hammdie/odoo-upgrade-cron${NC}"
    echo
}

# Show Fixes & Patches submenu
show_fixes_menu() {
    while true; do
        clear
        echo -e "${BLUE}${BOLD}"
        echo "╔════════════════════════════════════════════════════════════╗"
        echo "║          Fixes & Patches - Maintenance Tools               ║"
        echo "╚════════════════════════════════════════════════════════════╝"
        echo -e "${NC}"
        echo
        echo -e "${YELLOW}System Fixes:${NC}"
        echo -e "  ${GREEN}1)${NC} Fix PostgreSQL Authentication"
        echo -e "     Configure localhost trust (no password)"
        echo
        echo -e "  ${GREEN}2)${NC} Fix Firewall Settings"
        echo -e "     Configure UFW for Odoo ports (8069, 8072, 80, 443)"
        echo
        echo -e "  ${GREEN}3)${NC} Fix Odoo Dependencies"
        echo -e "     Reinstall Python packages and dependencies"
        echo
        echo -e "  ${GREEN}4)${NC} Repair Database"
        echo -e "     Run database maintenance and repair tools"
        echo
        echo -e "  ${GREEN}5)${NC} Test Odoo Dependencies"
        echo -e "     Verify all Python dependencies are installed"
        echo
        echo -e "  ${GREEN}6)${NC} Test Odoo User Permissions"
        echo -e "     Verify file permissions and user access"
        echo
        echo -e "  ${GREEN}7)${NC} Set PostgreSQL Password"
        echo -e "     Configure database password manually"
        echo
        echo -e "  ${GREEN}8)${NC} Test Cron Jobs"
        echo -e "     Verify automated tasks are configured correctly"
        echo
        echo -e "  ${GREEN}9)${NC} Check Odoo Version & Status"
        echo -e "     Display installed Odoo version and Enterprise status"
        echo
        echo -e "  ${GREEN}10)${NC} Fix Enterprise Installation"
        echo -e "      Repair failed or incomplete Enterprise installation"
        echo
        echo -e "  ${GREEN}11)${NC} Install pgvector for RAG/AI"
        echo -e "      Add PostgreSQL vector extension for AI agents"
        echo
        echo -e "  ${RED}0)${NC} Back to Main Menu"
        echo
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo
        
        read -p "$(echo -e ${BOLD}"Enter your choice [0-11]: "${NC})" fix_choice
        
        case $fix_choice in
            1)
                echo
                echo -e "${YELLOW}PostgreSQL Authentication Fix${NC}"
                echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
                echo
                if [[ -f "$PROJECT_ROOT/fix-postgres-auth.sh" ]]; then
                    bash "$PROJECT_ROOT/fix-postgres-auth.sh"
                else
                    echo -e "${RED}Error: fix-postgres-auth.sh not found${NC}"
                fi
                echo
                read -p "Press Enter to continue..."
                ;;
            2)
                echo
                echo -e "${YELLOW}Firewall Configuration${NC}"
                echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━${NC}"
                echo
                if [[ -f "$PROJECT_ROOT/fix-firewall.sh" ]]; then
                    bash "$PROJECT_ROOT/fix-firewall.sh"
                else
                    echo -e "${RED}Error: fix-firewall.sh not found${NC}"
                fi
                echo
                read -p "Press Enter to continue..."
                ;;
            3)
                echo
                echo -e "${YELLOW}Odoo Dependencies Fix${NC}"
                echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━${NC}"
                echo
                if [[ -f "$PROJECT_ROOT/fix-odoo-dependencies.sh" ]]; then
                    bash "$PROJECT_ROOT/fix-odoo-dependencies.sh"
                else
                    echo -e "${RED}Error: fix-odoo-dependencies.sh not found${NC}"
                fi
                echo
                read -p "Press Enter to continue..."
                ;;
            4)
                echo
                echo -e "${YELLOW}Database Repair${NC}"
                echo -e "${BLUE}━━━━━━━━━━━━━━${NC}"
                echo
                if [[ -f "$PROJECT_ROOT/repair-database.sh" ]]; then
                    bash "$PROJECT_ROOT/repair-database.sh"
                else
                    echo -e "${RED}Error: repair-database.sh not found${NC}"
                fi
                echo
                read -p "Press Enter to continue..."
                ;;
            5)
                echo
                echo -e "${YELLOW}Test Odoo Dependencies${NC}"
                echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━${NC}"
                echo
                if [[ -f "$PROJECT_ROOT/test-odoo-dependencies.sh" ]]; then
                    bash "$PROJECT_ROOT/test-odoo-dependencies.sh"
                else
                    echo -e "${RED}Error: test-odoo-dependencies.sh not found${NC}"
                fi
                echo
                read -p "Press Enter to continue..."
                ;;
            6)
                echo
                echo -e "${YELLOW}Test Odoo User Permissions${NC}"
                echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
                echo
                if [[ -f "$PROJECT_ROOT/test-odoo-user-permissions.sh" ]]; then
                    bash "$PROJECT_ROOT/test-odoo-user-permissions.sh"
                else
                    echo -e "${RED}Error: test-odoo-user-permissions.sh not found${NC}"
                fi
                echo
                read -p "Press Enter to continue..."
                ;;
            7)
                echo
                echo -e "${YELLOW}Set PostgreSQL Password${NC}"
                echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━${NC}"
                echo
                if [[ -f "$PROJECT_ROOT/scripts/set-postgres-password.sh" ]]; then
                    bash "$PROJECT_ROOT/scripts/set-postgres-password.sh"
                else
                    echo -e "${RED}Error: set-postgres-password.sh not found${NC}"
                fi
                echo
                read -p "Press Enter to continue..."
                ;;
            8)
                echo
                echo -e "${YELLOW}Test Cron Jobs${NC}"
                echo -e "${BLUE}━━━━━━━━━━━━━━${NC}"
                echo
                if [[ -f "$PROJECT_ROOT/test-cron.sh" ]]; then
                    bash "$PROJECT_ROOT/test-cron.sh"
                else
                    echo -e "${RED}Error: test-cron.sh not found${NC}"
                fi
                echo
                read -p "Press Enter to continue..."
                ;;
            9)
                echo
                echo -e "${YELLOW}Odoo Version & Status Check${NC}"
                echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
                echo
                if [[ -f "$PROJECT_ROOT/check-odoo-version.sh" ]]; then
                    bash "$PROJECT_ROOT/check-odoo-version.sh"
                else
                    echo -e "${RED}Error: check-odoo-version.sh not found${NC}"
                fi
                echo
                read -p "Press Enter to continue..."
                ;;
            10)
                echo
                echo -e "${YELLOW}Fix Enterprise Installation${NC}"
                echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
                echo
                if [[ -f "$PROJECT_ROOT/fix-enterprise-installation.sh" ]]; then
                    bash "$PROJECT_ROOT/fix-enterprise-installation.sh"
                else
                    echo -e "${RED}Error: fix-enterprise-installation.sh not found${NC}"
                fi
                echo
                read -p "Press Enter to continue..."
                ;;
            11)
                echo
                echo -e "${YELLOW}Install pgvector for RAG/AI${NC}"
                echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
                echo
                echo -e "${GREEN}About pgvector:${NC}"
                echo "PostgreSQL extension for vector similarity search"
                echo "Required for RAG (Retrieval-Augmented Generation) in Odoo AI agents"
                echo "Documentation: https://github.com/pgvector/pgvector"
                echo
                if [[ -f "$PROJECT_ROOT/scripts/install-pgvector.sh" ]]; then
                    bash "$PROJECT_ROOT/scripts/install-pgvector.sh"
                else
                    echo -e "${RED}Error: scripts/install-pgvector.sh not found${NC}"
                fi
                echo
                read -p "Press Enter to continue..."
                ;;
            0)
                show_banner
                return 0
                ;;
            *)
                echo
                echo -e "${RED}Invalid option. Please select 0-11.${NC}"
                sleep 2
                ;;
        esac
    done
}

# Usage function
usage() {
    echo -e "${BOLD}Odoo 19.0 Installation & Upgrade Script${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo
    echo -e "${BOLD}USAGE:${NC}"
    echo "    sudo ./install.sh [OPTIONS]"
    echo
    echo -e "${BOLD}QUICK START:${NC}"
    echo "    sudo ./install.sh                      # Interactive mode with menu"
    echo "    sudo ./install.sh --auto               # Fully automated installation"
    echo "    sudo ./install.sh --help               # Show this help"
    echo
    echo -e "${BOLD}INTERACTIVE MENU:${NC}"
    echo "    When running without --auto flag, an interactive menu will guide you through:"
    echo
    echo -e "    ${GREEN}1. System Upgrade${NC}           - Update Ubuntu packages and dependencies"
    echo -e "    ${GREEN}2. Odoo Installation${NC}        - Install or upgrade Odoo 19.0"
    echo -e "    ${GREEN}3. Cron Setup${NC}               - Configure automated updates"
    echo -e "    ${GREEN}4. Nginx + SSL Setup${NC}        - Reverse proxy with Let's Encrypt (optional)"
    echo -e "    ${GREEN}5. Enterprise Edition${NC}       - Install Odoo Enterprise addons (optional)"
    echo -e "    ${GREEN}6. Full Installation${NC}        - Run all steps (incl. pgvector for AI/RAG)"
    echo -e "    ${GREEN}7. Exit${NC}                     - Cancel installation"
    echo
    echo -e "${BOLD}OPTIONS:${NC}"
    echo -e "    ${YELLOW}Mode Control:${NC}"
    echo "    --auto              Fully automated mode (no prompts, recommended for scripts)"
    echo "    --force             Force clean reinstall (removes existing Odoo)"
    echo
    echo -e "    ${YELLOW}Skip Steps:${NC}"
    echo "    --skip-system       Skip system package updates"
    echo "    --skip-odoo         Skip Odoo installation"
    echo "    --skip-cron         Skip cron job setup"
    echo "    --skip-nginx        Skip Nginx reverse proxy setup"
    echo
    echo -e "    ${YELLOW}Nginx Configuration:${NC}"
    echo "    --nginx-domain      Domain name for Nginx + SSL (e.g., odoo.example.com)"
    echo "    --nginx-email       Email for Let's Encrypt certificate"
    echo
    echo -e "    ${YELLOW}Enterprise Edition:${NC}"
    echo "    --enterprise        Install Odoo Enterprise edition (requires partner access)"
    echo
    echo -e "    ${YELLOW}Other:${NC}"
    echo "    --no-backup         Don't backup existing installations"
    echo "    --help              Show this help message"
    echo
    echo -e "${BOLD}EXAMPLES:${NC}"
    echo -e "    ${GREEN}# Interactive installation with menu${NC}"
    echo "    sudo ./install.sh"
    echo
    echo -e "    ${GREEN}# Fully automated installation${NC}"
    echo "    sudo ./install.sh --auto"
    echo
    echo -e "    ${GREEN}# Force clean installation${NC}"
    echo "    sudo ./install.sh --force --auto"
    echo
    echo -e "    ${GREEN}# Install with Nginx + SSL${NC}"
    echo "    sudo ./install.sh --auto \\"
    echo "        --nginx-domain odoo.example.com \\"
    echo "        --nginx-email admin@example.com"
    echo
    echo -e "    ${GREEN}# Install Enterprise edition${NC}"
    echo "    sudo ./install.sh --auto --enterprise"
    echo
    echo -e "    ${GREEN}# Skip system updates, only install Odoo${NC}"
    echo "    sudo ./install.sh --skip-system --auto"
    echo
    echo -e "${BOLD}FEATURES:${NC}"
    echo "    ✓ Automatic detection of existing Odoo installations"
    echo "    ✓ Intelligent upgrade from older versions to 19.0"
    echo "    ✓ Backup of existing configurations and data"
    echo "    ✓ Automated weekly updates via cron jobs"
    echo "    ✓ Optional Nginx reverse proxy with Let's Encrypt SSL"
    echo "    ✓ Optional Odoo Enterprise edition support"
    echo "    ✓ Custom addons directories: /opt/odoo/custom-addons, /var/custom-addons"
    echo "    ✓ Comprehensive logging and error handling"
    echo
    echo -e "${BOLD}REQUIREMENTS:${NC}"
    echo "    - Ubuntu 20.04 LTS or higher"
    echo "    - Root/sudo access"
    echo "    - Internet connection"
    echo "    - 4GB RAM (minimum 2GB)"
    echo "    - 20GB free disk space"
    echo "    - For Nginx: Domain must point to server IP"
    echo "    - For Enterprise: Valid Odoo partner access + GitHub SSH key"
    echo
    echo -e "${BOLD}DOCUMENTATION:${NC}"
    echo -e "    📖 Full documentation: ${BLUE}https://github.com/Hammdie/odoo-upgrade-cron${NC}"
    echo "    📝 Enterprise setup guide: See README.md section \"Odoo Enterprise Edition\""
    echo "    🔧 Troubleshooting: See README.md section \"Troubleshooting\""
    echo
    echo -e "${BOLD}LOG FILES:${NC}"
    echo -e "    Installation logs: ${BLUE}$LOG_DIR/install-*.log${NC}"
    echo -e "    Odoo logs:        ${BLUE}/var/log/odoo/odoo.log${NC}"
    echo
    echo -e "${BOLD}SUPPORT:${NC}"
    echo "    🐛 Issues: https://github.com/Hammdie/odoo-upgrade-cron/issues"
    echo "    💬 Discussions: https://github.com/Hammdie/odoo-upgrade-cron/discussions"
    echo "    📧 Enterprise support: support@detelx.de"
    echo
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
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
            --skip-nginx)
                SKIP_NGINX_SETUP=true
                shift
                ;;
            --nginx-domain)
                SETUP_NGINX=true
                NGINX_DOMAIN="$2"
                shift 2
                ;;
            --nginx-email)
                NGINX_EMAIL="$2"
                shift 2
                ;;
            --enterprise)
                INSTALL_ENTERPRISE=true
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

# Display interactive menu
show_interactive_menu() {
    # Skip menu in auto mode
    if [[ "$AUTO_MODE" == true ]]; then
        return 0
    fi
    
    while true; do
        echo
        echo -e "${BLUE}${BOLD}╔════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${BLUE}${BOLD}║        Odoo 19.0 Installation - Interactive Menu           ║${NC}"
        echo -e "${BLUE}${BOLD}╚════════════════════════════════════════════════════════════╝${NC}"
        echo
        echo -e "${GREEN}Please select an option:${NC}"
        echo
        echo -e "  ${YELLOW}1)${NC} ${BOLD}System Upgrade${NC}"
        echo -e "     Update Ubuntu packages and install dependencies"
        echo
        echo -e "  ${YELLOW}2)${NC} ${BOLD}Odoo Installation${NC}"
        echo -e "     Install or upgrade Odoo 19.0"
        echo
        echo -e "  ${YELLOW}3)${NC} ${BOLD}Cron Setup${NC}"
        echo -e "     Configure automated updates and backups"
        echo
        echo -e "  ${YELLOW}4)${NC} ${BOLD}Nginx + SSL Setup${NC}"
        echo -e "     Setup reverse proxy with Let's Encrypt certificate"
        echo
        echo -e "  ${YELLOW}5)${NC} ${BOLD}Enterprise Edition${NC}"
        echo -e "     Install Odoo Enterprise addons (requires partner access)"
        echo
        echo -e "  ${YELLOW}6)${NC} ${BOLD}Full Installation${NC}"
        echo -e "     Run all steps automatically (incl. pgvector for AI/RAG)"
        echo
        echo -e "  ${YELLOW}7)${NC} ${BOLD}Show Help${NC}"
        echo -e "     Display detailed usage information"
        echo
        echo -e "  ${YELLOW}9)${NC} ${BOLD}Fixes & Patches${NC}"
        echo -e "     Access system fixes and maintenance tools"
        echo
        echo -e "  ${RED}0)${NC} ${BOLD}Exit${NC}"
        echo -e "     Cancel installation"
        echo
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        
        # Show additional option for Enterprise installation if Odoo already exists
        if [[ "$EXISTING_ODOO_FOUND" == true ]]; then
            echo
            echo -e "${YELLOW}Additional Options:${NC}"
            echo -e "  ${YELLOW}8)${NC} ${BOLD}Install Enterprise (Post-Installation)${NC}"
            echo -e "     Add Enterprise edition to existing Odoo installation"
            echo
        fi
        
        read -p "$(echo -e ${BOLD}"Enter your choice [0-9]: "${NC})" choice
        
        case $choice in
            1)
                echo
                log "INFO" "Starting System Upgrade..."
                SKIP_ODOO_INSTALL=true
                SKIP_CRON_SETUP=true
                SKIP_NGINX_SETUP=true
                return 0
                ;;
            2)
                echo
                log "INFO" "Starting Odoo Installation..."
                SKIP_SYSTEM_UPDATE=true
                SKIP_CRON_SETUP=true
                SKIP_NGINX_SETUP=true
                return 0
                ;;
            3)
                echo
                log "INFO" "Starting Cron Setup..."
                SKIP_SYSTEM_UPDATE=true
                SKIP_ODOO_INSTALL=true
                SKIP_NGINX_SETUP=true
                return 0
                ;;
            4)
                echo
                echo -e "${YELLOW}Nginx + SSL Setup${NC}"
                echo -e "${BLUE}━━━━━━━━━━━━━━━━━${NC}"
                echo
                
                # Rufe das Nginx-Setup-Script direkt auf (es ist bereits interaktiv)
                if [[ -f "$SCRIPT_DIR/scripts/setup-odoo-nginx.sh" ]]; then
                    bash "$SCRIPT_DIR/scripts/setup-odoo-nginx.sh"
                else
                    echo -e "${RED}Error: setup-odoo-nginx.sh not found${NC}"
                    echo -e "${YELLOW}Expected location: $SCRIPT_DIR/scripts/setup-odoo-nginx.sh${NC}"
                fi
                
                echo
                read -p "Press Enter to return to menu..."
                continue
                ;;
            5)
                echo
                echo -e "${YELLOW}Enterprise Edition Setup${NC}"
                echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━${NC}"
                echo -e "${YELLOW}Requirements:${NC}"
                echo -e "  • Valid Odoo Enterprise subscription"
                echo -e "  • SSH key configured for GitHub"
                echo -e "  • Access to git@github.com:odoo/enterprise.git"
                echo
                echo -e "${BLUE}For SSH key setup instructions, see:${NC}"
                echo -e "  https://github.com/Hammdie/odoo-upgrade-cron#odoo-enterprise-edition"
                echo
                read -p "Continue with Enterprise installation? (y/N): " -n 1 -r
                echo
                
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    INSTALL_ENTERPRISE=true
                    SKIP_SYSTEM_UPDATE=true
                    SKIP_ODOO_INSTALL=true
                    SKIP_CRON_SETUP=true
                    SKIP_NGINX_SETUP=true
                    return 0
                else
                    continue
                fi
                ;;
            6)
                echo
                log "INFO" "Starting Full Installation..."
                echo -e "${GREEN}This will run all installation steps:${NC}"
                echo -e "  1. System Upgrade"
                echo -e "  2. Odoo Installation"
                echo -e "  3. pgvector Extension (AI/RAG support)"
                echo -e "  4. Cron Setup"
                echo -e "  5. Nginx + SSL Setup (optional)"
                echo -e "  6. Enterprise Edition (optional)"
                echo
                
                # Ask for Nginx/SSL setup
                read -p "Setup Nginx reverse proxy with SSL/TLS? (Y/n): " -n 1 -r
                echo
                
                if [[ ! $REPLY =~ ^[Nn]$ ]]; then
                    echo
                    echo -e "${BLUE}Nginx + SSL Configuration${NC}"
                    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
                    
                    # Domain input with validation
                    while true; do
                        read -p "$(echo -e ${GREEN}Enter domain name${NC}) (e.g., odoo.example.com): " NGINX_DOMAIN
                        if [[ -n "$NGINX_DOMAIN" ]]; then
                            if [[ $NGINX_DOMAIN =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*\.([a-zA-Z]{2,})$ ]]; then
                                break
                            else
                                echo -e "${RED}Invalid domain format. Please try again.${NC}"
                            fi
                        else
                            echo -e "${RED}Domain is required.${NC}"
                        fi
                    done
                    
                    # Email input with default
                    read -p "$(echo -e ${GREEN}Let\'s Encrypt email${NC}) (default: admin@${NGINX_DOMAIN}): " NGINX_EMAIL
                    NGINX_EMAIL="${NGINX_EMAIL:-admin@${NGINX_DOMAIN}}"
                    
                    SETUP_NGINX=true
                    
                    echo
                    echo -e "${GREEN}✓${NC} Nginx will be configured for: ${GREEN}$NGINX_DOMAIN${NC}"
                    echo -e "${GREEN}✓${NC} SSL certificate email: ${GREEN}$NGINX_EMAIL${NC}"
                else
                    SETUP_NGINX=false
                fi
                
                echo
                read -p "Install Odoo Enterprise edition? (y/N): " -n 1 -r
                echo
                
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    INSTALL_ENTERPRISE=true
                    echo -e "${GREEN}✓${NC} Enterprise edition will be installed"
                else
                    INSTALL_ENTERPRISE=false
                fi
                
                echo
                return 0
                ;;
            7)
                clear
                usage
                echo
                read -p "Press Enter to continue..."
                show_banner
                continue
                ;;
            8)
                # Only available when existing Odoo is found
                if [[ "$EXISTING_ODOO_FOUND" != true ]]; then
                    echo -e "${RED}Error: This option is only available for existing installations${NC}"
                    sleep 2
                    show_banner
                    continue
                fi
                
                echo
                echo -e "${YELLOW}Enterprise Edition Post-Installation${NC}"
                echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
                echo
                echo -e "${YELLOW}Requirements:${NC}"
                echo -e "  • Valid Odoo Enterprise subscription"
                echo -e "  • SSH key configured for GitHub (odoo user)"
                echo -e "  • Access to git@github.com:odoo/enterprise.git"
                echo
                echo -e "${BLUE}SSH Key Setup Instructions:${NC}"
                echo -e "  1. Generate SSH key for odoo user:"
                echo -e "     ${GREEN}sudo -u odoo ssh-keygen -t ed25519 -C \"odoo@\$(hostname)\" -f /var/lib/odoo/.ssh/id_ed25519 -N \"\"${NC}"
                echo
                echo -e "  2. Show public key:"
                echo -e "     ${GREEN}sudo -u odoo cat /var/lib/odoo/.ssh/id_ed25519.pub${NC}"
                echo
                echo -e "  3. Add to GitHub: ${BLUE}https://github.com/settings/keys${NC}"
                echo
                echo -e "  4. Test connection:"
                echo -e "     ${GREEN}sudo -u odoo ssh -T git@github.com${NC}"
                echo
                echo -e "${BLUE}Full documentation:${NC}"
                echo -e "  ${BLUE}https://github.com/Hammdie/odoo-upgrade-cron#odoo-enterprise-edition${NC}"
                echo
                
                read -p "Do you want to continue? (y/N): " -n 1 -r
                echo
                
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    echo
                    log "INFO" "Running Enterprise installation script..."
                    
                    local enterprise_script="$PROJECT_ROOT/scripts/install-enterprise.sh"
                    
                    if [[ -f "$enterprise_script" ]]; then
                        # Make sure script is executable
                        chmod +x "$enterprise_script"
                        
                        # Run the enterprise installation script
                        if bash "$enterprise_script" 2>&1 | tee -a "$LOG_FILE"; then
                            log "SUCCESS" "Enterprise installation completed"
                            echo
                            read -p "Press Enter to return to menu..."
                            show_banner
                            continue
                        else
                            log "ERROR" "Enterprise installation failed"
                            echo
                            read -p "Press Enter to return to menu..."
                            show_banner
                            continue
                        fi
                    else
                        log "ERROR" "Enterprise installation script not found: $enterprise_script"
                        echo
                        read -p "Press Enter to return to menu..."
                        show_banner
                        continue
                    fi
                else
                    show_banner
                    continue
                fi
                ;;
            9)
                # Fixes & Patches Submenu
                show_fixes_menu
                ;;
            0)
                echo
                log "INFO" "Installation cancelled by user"
                exit 0
                ;;
            *)
                echo
                echo -e "${RED}Invalid option. Please select 0-9.${NC}"
                sleep 2
                show_banner
                ;;
        esac
    done
}

# Display installation summary
show_installation_plan() {
    # In auto mode, skip showing the plan and prompt entirely
    if [[ "$AUTO_MODE" == true ]]; then
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
    
    if [[ "$SETUP_NGINX" == true ]] && [[ "$SKIP_NGINX_SETUP" == false ]]; then
        echo -e "${GREEN}✓${NC} Nginx Reverse Proxy: SSL/TLS setup for $NGINX_DOMAIN"
    elif [[ "$SKIP_NGINX_SETUP" == true ]]; then
        echo -e "${YELLOW}⚠${NC} Nginx Setup: ${YELLOW}SKIPPED${NC}"
    else
        echo -e "${BLUE}ℹ${NC} Nginx Setup: Not configured (can be added later)"
    fi
    
    if [[ "$INSTALL_ENTERPRISE" == true ]]; then
        echo -e "${GREEN}✓${NC} Odoo Enterprise: Will be installed to $ENTERPRISE_PATH"
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
    
    # Skip this prompt if user already made selection in interactive menu
    # (Menu sets SKIP flags or SETUP flags)
    if [[ "$AUTO_MODE" != true ]]; then
        # If any skip/setup flag is set, user already chose from menu - skip this prompt
        if [[ "$SKIP_SYSTEM_UPDATE" == true ]] || [[ "$SKIP_ODOO_INSTALL" == true ]] || \
           [[ "$SKIP_CRON_SETUP" == true ]] || [[ "$SKIP_NGINX_SETUP" == true ]] || \
           [[ "$SETUP_NGINX" == true ]] || [[ "$INSTALL_ENTERPRISE" == true ]]; then
            log "INFO" "Using menu selection - skipping existing installation prompt"
            return 0
        fi
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

# Install Odoo Enterprise edition
install_enterprise() {
    if [[ "$INSTALL_ENTERPRISE" != true ]]; then
        log "INFO" "Enterprise edition not requested - skipping"
        return 0
    fi
    
    log "INFO" "Installing Odoo Enterprise edition..."
    
    # Check if odoo user exists
    if ! id -u odoo &>/dev/null; then
        log "ERROR" "User 'odoo' does not exist. Please install Odoo first."
        return 1
    fi
    
    # Check if Git is available
    if ! command -v git &> /dev/null; then
        log "ERROR" "Git is not installed. Cannot clone Enterprise repository."
        return 1
    fi
    
    # Check SSH access to Odoo Enterprise repository as odoo user
    log "INFO" "Verifying SSH access to Odoo Enterprise repository as odoo user..."
    if sudo -u odoo ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
        log "SUCCESS" "SSH authentication verified for odoo user"
    else
        log "WARN" "SSH key may not be configured for odoo user"
        log "WARN" "Attempting to clone anyway - may require manual SSH key setup"
        log "INFO" "Setup SSH key with: sudo -u odoo ssh-keygen -t ed25519 -C 'odoo@yourserver.com'"
    fi
    
    # Create parent directory if not exists
    local parent_dir="$(dirname "$ENTERPRISE_PATH")"
    if [[ ! -d "$parent_dir" ]]; then
        log "INFO" "Creating parent directory: $parent_dir"
        mkdir -p "$parent_dir"
        chown odoo:odoo "$parent_dir"
    fi
    
    # Backup existing enterprise installation if exists
    if [[ -d "$ENTERPRISE_PATH/.git" ]]; then
        log "INFO" "Existing Enterprise installation found - backing up..."
        mv "$ENTERPRISE_PATH" "$ENTERPRISE_PATH.backup.$(date +%Y%m%d-%H%M%S)"
    fi
    
    # Remove directory if it exists but is not a git repo
    if [[ -d "$ENTERPRISE_PATH" ]] && [[ ! -d "$ENTERPRISE_PATH/.git" ]]; then
        log "WARN" "Removing non-git Enterprise directory"
        rm -rf "$ENTERPRISE_PATH"
    fi
    
    # Clone Enterprise repository
    log "INFO" "Cloning Odoo Enterprise from git@github.com:odoo/enterprise.git (branch 19.0)..."
    log "INFO" "Target directory: $ENTERPRISE_PATH"
    
    if sudo -u odoo git clone --depth 1 --branch 19.0 git@github.com:odoo/enterprise.git "$ENTERPRISE_PATH" 2>&1 | tee -a "$LOG_FILE"; then
        log "SUCCESS" "Enterprise repository cloned successfully"
        
        # Set permissions
        chown -R odoo:odoo "$ENTERPRISE_PATH"
        chmod -R 755 "$ENTERPRISE_PATH"
        log "SUCCESS" "Enterprise directory permissions set"
        
        # Verify clone was successful by checking for .git directory
        if [[ ! -d "$ENTERPRISE_PATH/.git" ]]; then
            echo ""
            echo "╔════════════════════════════════════════════════════════════════════════════╗"
            echo "║                                                                            ║"
            echo "║  ❌ ENTERPRISE VALIDATION FAILED - INCOMPLETE CLONE ❌                     ║"
            echo "║                                                                            ║"
            echo "╚════════════════════════════════════════════════════════════════════════════╝"
            echo ""
            log "ERROR" "Enterprise clone verification failed"
            log "ERROR" "Missing .git directory in: $ENTERPRISE_PATH"
            log "ERROR" "The repository appears to be incomplete or corrupted"
            echo ""
            log "ERROR" "TROUBLESHOOTING:"
            log "ERROR" "  • Check disk space: df -h"
            log "ERROR" "  • Check permissions: ls -la $(dirname $ENTERPRISE_PATH)"
            log "ERROR" "  • Try manual clone: sudo -u odoo git clone --depth 1 --branch 19.0 git@github.com:odoo/enterprise.git $ENTERPRISE_PATH"
            echo ""
            log "WARN" "⚠️  Enterprise will NOT be added to Odoo configuration"
            echo ""
            echo "📋 Full log details: $LOG_FILE"
            echo ""
            return 1
        fi
        
    else
        echo ""
        echo "╔════════════════════════════════════════════════════════════════════════════╗"
        echo "║                                                                            ║"
        echo "║  ❌ ENTERPRISE INSTALLATION FAILED - REPOSITORY CLONE ERROR ❌             ║"
        echo "║                                                                            ║"
        echo "╚════════════════════════════════════════════════════════════════════════════╝"
        echo ""
        log "ERROR" "Failed to clone Odoo Enterprise repository from GitHub"
        log "ERROR" "Target: git@github.com:odoo/enterprise.git (branch 19.0)"
        log "ERROR" "Destination: $ENTERPRISE_PATH"
        echo ""
        log "ERROR" "REQUIRED ACTIONS:"
        log "ERROR" "  1️⃣  Verify you have valid Odoo Enterprise Partner access"
        log "ERROR" "  2️⃣  Generate SSH key for odoo user:"
        log "ERROR" "      sudo -u odoo ssh-keygen -t ed25519 -C 'odoo@yourserver.com'"
        log "ERROR" "  3️⃣  Display public key:"
        log "ERROR" "      sudo -u odoo cat /var/lib/odoo/.ssh/id_ed25519.pub"
        log "ERROR" "  4️⃣  Add public key to GitHub: https://github.com/settings/keys"
        log "ERROR" "  5️⃣  Test SSH connection:"
        log "ERROR" "      sudo -u odoo ssh -T git@github.com"
        echo ""
        log "WARN" "⚠️  Enterprise will NOT be added to Odoo configuration"
        echo ""
        echo "📋 Full log details: $LOG_FILE"
        echo ""
        return 1
    fi
    
    # Update Odoo configuration to include enterprise addons
    # CRITICAL: Only update config if Enterprise directory exists and is valid
    if [[ ! -d "$ENTERPRISE_PATH" ]] || [[ ! -d "$ENTERPRISE_PATH/.git" ]]; then
        echo ""
        echo "╔════════════════════════════════════════════════════════════════════════════╗"
        echo "║                                                                            ║"
        echo "║  ❌ CONFIGURATION UPDATE FAILED - INVALID ENTERPRISE DIRECTORY ❌          ║"
        echo "║                                                                            ║"
        echo "╚════════════════════════════════════════════════════════════════════════════╝"
        echo ""
        log "ERROR" "Cannot update Odoo configuration - Enterprise directory not valid"
        log "ERROR" "Directory path: $ENTERPRISE_PATH"
        log "ERROR" "Directory exists: $([ -d "$ENTERPRISE_PATH" ] && echo 'YES' || echo 'NO')"
        log "ERROR" "Git repository: $([ -d "$ENTERPRISE_PATH/.git" ] && echo 'YES' || echo 'NO')"
        echo ""
        log "ERROR" "REASON: Enterprise installation failed or incomplete"
        log "WARN" "⚠️  Enterprise will NOT be added to Odoo configuration"
        log "WARN" "⚠️  Odoo will start WITHOUT Enterprise modules"
        echo ""
        echo "📋 Full log details: $LOG_FILE"
        echo ""
        return 1
    fi
    
    log "INFO" "Updating Odoo configuration to include Enterprise addons..."
    local odoo_config="/etc/odoo/odoo.conf"
    
    if [[ -f "$odoo_config" ]]; then
        # Backup config before modification
        cp "$odoo_config" "${odoo_config}.backup.$(date +%Y%m%d_%H%M%S)" || {
            echo ""
            echo "╔════════════════════════════════════════════════════════════════════════════╗"
            echo "║                                                                            ║"
            echo "║  ❌ CONFIGURATION BACKUP FAILED ❌                                         ║"
            echo "║                                                                            ║"
            echo "╚════════════════════════════════════════════════════════════════════════════╝"
            echo ""
            log "ERROR" "Failed to create backup of configuration file"
            log "ERROR" "Config file: $odoo_config"
            log "ERROR" "Backup destination: ${odoo_config}.backup.$(date +%Y%m%d_%H%M%S)"
            log "ERROR" "ABORTING: Cannot modify config without backup"
            echo ""
            echo "📋 Full log details: $LOG_FILE"
            echo ""
            return 1
        }
        
        # Check if enterprise path is already in addons_path
        if grep -q "addons_path.*$ENTERPRISE_PATH" "$odoo_config"; then
            log "INFO" "Enterprise path already in addons_path"
        else
            # Get current addons_path
            local current_addons=$(grep "^addons_path" "$odoo_config" | cut -d'=' -f2- | tr -d ' ')
            
            if [[ -z "$current_addons" ]]; then
                echo ""
                echo "╔════════════════════════════════════════════════════════════════════════════╗"
                echo "║                                                                            ║"
                echo "║  ❌ CONFIGURATION ERROR - NO ADDONS_PATH FOUND ❌                          ║"
                echo "║                                                                            ║"
                echo "╚════════════════════════════════════════════════════════════════════════════╝"
                echo ""
                log "ERROR" "No existing addons_path found in configuration"
                log "ERROR" "Config file: $odoo_config"
                log "ERROR" "Cannot add Enterprise without existing addons_path"
                echo ""
                log "ERROR" "SOLUTION: Run 'Full Installation' to create proper configuration"
                echo ""
                echo "📋 Full log details: $LOG_FILE"
                echo ""
                return 1
            fi
            
            # Build new addons_path with enterprise first (highest priority), then existing paths
            local new_addons="$ENTERPRISE_PATH,$current_addons"
            
            # Update configuration
            sed -i "s|^addons_path.*|addons_path = $new_addons|" "$odoo_config" || {
                echo ""
                echo "╔════════════════════════════════════════════════════════════════════════════╗"
                echo "║                                                                            ║"
                echo "║  ❌ CONFIGURATION UPDATE FAILED - SED COMMAND ERROR ❌                     ║"
                echo "║                                                                            ║"
                echo "╚════════════════════════════════════════════════════════════════════════════╝"
                echo ""
                log "ERROR" "Failed to update addons_path in configuration file"
                log "ERROR" "Config file: $odoo_config"
                log "ERROR" "Attempted update: addons_path = $new_addons"
                echo ""
                log "WARN" "⚠️  Restoring configuration backup..."
                # Restore backup
                cp "${odoo_config}.backup."* "$odoo_config" 2>/dev/null && log "SUCCESS" "Backup restored" || log "ERROR" "Backup restore failed!"
                echo ""
                echo "📋 Full log details: $LOG_FILE"
                echo ""
                return 1
            }
            log "SUCCESS" "Enterprise path added to addons_path: $new_addons"
        fi
    else
        echo ""
        echo "╔════════════════════════════════════════════════════════════════════════════╗"
        echo "║                                                                            ║"
        echo "║  ❌ CONFIGURATION FILE NOT FOUND ❌                                        ║"
        echo "║                                                                            ║"
        echo "╚════════════════════════════════════════════════════════════════════════════╝"
        echo ""
        log "ERROR" "Odoo configuration file not found"
        log "ERROR" "Expected location: $odoo_config"
        log "ERROR" "Cannot add Enterprise without configuration file"
        echo ""
        log "ERROR" "SOLUTION: Run 'Full Installation' to create Odoo configuration"
        echo ""
        echo "📋 Full log details: $LOG_FILE"
        echo ""
        return 1
    fi
    
    # Restart Odoo to load enterprise modules
    if systemctl is-active --quiet odoo 2>/dev/null; then
        log "INFO" "Restarting Odoo to load Enterprise modules..."
        systemctl restart odoo
        sleep 5
        
        if systemctl is-active --quiet odoo; then
            log "SUCCESS" "Odoo Enterprise installation completed successfully"
            log "INFO" "Enterprise modules are now available in Odoo"
            return 0
        else
            log "ERROR" "Odoo failed to start after Enterprise installation"
            log "INFO" "Check logs: sudo journalctl -u odoo -f"
            echo ""
            echo "╔════════════════════════════════════════════════════════════════════════════╗"
            echo "║                                                                            ║"
            echo "║  ❌ ODOO SERVICE FAILED TO START AFTER ENTERPRISE INSTALLATION ❌          ║"
            echo "║                                                                            ║"
            echo "╚════════════════════════════════════════════════════════════════════════════╝"
            echo ""
            log "ERROR" "Odoo service is not active after Enterprise installation"
            log "ERROR" "Enterprise was added to configuration but Odoo won't start"
            echo ""
            log "ERROR" "TROUBLESHOOTING COMMANDS:"
            log "ERROR" "  • Check service status: sudo systemctl status odoo"
            log "ERROR" "  • View live logs: sudo journalctl -u odoo -f"
            log "ERROR" "  • View recent errors: sudo journalctl -u odoo -n 50"
            log "ERROR" "  • Test configuration: odoo -c /etc/odoo/odoo.conf --test-enable"
            echo ""
            log "WARN" "⚠️  You may need to run: Fix Enterprise Installation (Fixes & Patches menu)"
            echo ""
            echo "📋 Full log details: $LOG_FILE"
            echo ""
            return 1
        fi
    else
        log "WARN" "Odoo service is not running - skipping restart"
        log "INFO" "Enterprise modules will be available after starting Odoo"
        return 0
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

# Run Nginx setup
run_nginx_setup() {
    if [[ "$SKIP_NGINX_SETUP" == true ]]; then
        log "INFO" "Nginx setup skipped as requested"
        return 0
    fi
    
    if [[ "$SETUP_NGINX" != true ]] || [[ -z "$NGINX_DOMAIN" ]]; then
        log "INFO" "Nginx setup not configured - skipping"
        return 0
    fi
    
    log "INFO" "Setting up Nginx reverse proxy with SSL/TLS..."
    
    # Check if Apache is installed and remove it (conflicts with Nginx)
    if command -v apache2 &> /dev/null || systemctl list-units --full -all | grep -q apache2.service; then
        log "WARN" "Apache2 detected - removing to avoid port conflicts with Nginx..."
        systemctl stop apache2 2>/dev/null || true
        systemctl disable apache2 2>/dev/null || true
        apt-get remove -y apache2 apache2-utils apache2-bin apache2.2-common 2>/dev/null || true
        apt-get purge -y apache2 apache2-utils apache2-bin apache2.2-common 2>/dev/null || true
        apt-get autoremove -y 2>/dev/null || true
        log "SUCCESS" "Apache2 removed"
    fi
    
    # Check if Nginx is installed, install if missing
    if ! command -v nginx &> /dev/null; then
        log "WARN" "Nginx not found - installing Nginx..."
        if apt-get update -qq && apt-get install -y nginx; then
            log "SUCCESS" "Nginx installed successfully"
            systemctl enable nginx
            systemctl start nginx
        else
            log "ERROR" "Failed to install Nginx"
            return 1
        fi
    else
        log "INFO" "Nginx is already installed"
        # Ensure Nginx is running
        if ! systemctl is-active --quiet nginx; then
            log "INFO" "Starting Nginx..."
            systemctl start nginx
        fi
    fi
    
    local nginx_script="$PROJECT_ROOT/scripts/setup-odoo-nginx.sh"
    
    if [[ ! -f "$nginx_script" ]]; then
        log "ERROR" "Nginx setup script not found: $nginx_script"
        return 1
    fi
    
    # Make script executable
    chmod +x "$nginx_script"
    
    # Build command with optional email
    local nginx_cmd="$nginx_script $NGINX_DOMAIN"
    [[ -n "$NGINX_EMAIL" ]] && nginx_cmd="$nginx_cmd $NGINX_EMAIL"
    
    if $nginx_cmd 2>&1 | tee -a "$LOG_FILE"; then
        log "SUCCESS" "Nginx reverse proxy setup completed successfully"
        log "INFO" "Odoo is now accessible at: https://$NGINX_DOMAIN"
        return 0
    else
        log "ERROR" "Nginx setup failed"
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
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
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
    
    if [[ "$SETUP_NGINX" == true ]] && [[ -n "$NGINX_DOMAIN" ]]; then
        echo -e "${GREEN}🌐 Web Interface (HTTPS):${NC} https://$NGINX_DOMAIN"
        echo -e "${GREEN}🌐 Direct Access:${NC} http://localhost:8069 (local only)"
    else
        echo -e "${GREEN}🌐 Web Interface:${NC} http://localhost:8069"
        echo -e "${GREEN}🌐 External Access:${NC} http://your-server-ip:8069"
        echo -e "${YELLOW}💡 Tip:${NC} Set up SSL/TLS with: sudo $PROJECT_ROOT/scripts/setup-odoo-nginx.sh <domain> <email>"
    fi
    
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
    
    if [[ "$SETUP_NGINX" == true ]] && [[ -n "$NGINX_DOMAIN" ]]; then
        echo -e "${YELLOW}1.${NC} Access Odoo at https://$NGINX_DOMAIN"
    else
        echo -e "${YELLOW}1.${NC} Access Odoo at http://your-server-ip:8069"
    fi
    
    echo -e "${YELLOW}2.${NC} Create your first database"
    echo -e "${YELLOW}3.${NC} Configure your Odoo instance"
    echo -e "${YELLOW}4.${NC} Review configuration file: /etc/odoo/odoo.conf"
    
    if [[ "$SETUP_NGINX" != true ]]; then
        echo -e "${YELLOW}5.${NC} (Optional) Set up SSL/TLS: sudo $PROJECT_ROOT/scripts/setup-odoo-nginx.sh <domain> <email>"
    fi
    
    # Check if pgvector is installed
    if sudo -u postgres psql -c "SELECT extversion FROM pg_extension WHERE extname='vector';" 2>/dev/null | grep -q "[0-9]"; then
        local pgvector_version=$(sudo -u postgres psql -t -c "SELECT extversion FROM pg_extension WHERE extname='vector';" 2>/dev/null | xargs)
        echo
        echo -e "${BLUE}${BOLD}AI/RAG Support:${NC}"
        echo -e "${BLUE}===============${NC}"
        echo -e "${GREEN}🤖 pgvector Extension:${NC} Installed (v$pgvector_version)"
        echo -e "${GREEN}💡 Enable in database:${NC} CREATE EXTENSION vector;"
        echo -e "${GREEN}📚 Documentation:${NC} https://github.com/pgvector/pgvector"
    fi
    
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
    echo -e "${GREEN}📖 Full Documentation:${NC} ${BOLD}https://github.com/Hammdie/odoo-upgrade-cron${NC}"
    echo -e "${GREEN}📋 Installation Log:${NC} $LOG_FILE"
    echo -e "${GREEN}🐛 Report Issues:${NC} https://github.com/Hammdie/odoo-upgrade-cron/issues"
    echo -e "${GREEN}💬 Discussions:${NC} https://github.com/Hammdie/odoo-upgrade-cron/discussions"
    echo
    echo -e "${YELLOW}💡 Tip:${NC} Click or copy the links above to access documentation"
    echo
    
    log "INFO" "Installation log saved to: $LOG_FILE"
    log "INFO" "Documentation: https://github.com/Hammdie/odoo-upgrade-cron"
    log "INFO" "Thank you for using the Odoo 19.0 Upgrade System!"
}

# Error handler
handle_error() {
    local exit_code=$?
    local line_number=$1
    
    log "ERROR" "Installation failed at line $line_number with exit code $exit_code"
    
    echo
    echo -e "${RED}${BOLD}❌ Installation Failed!${NC}"
    echo -e "${YELLOW}Error occurred at line $line_number (exit code: $exit_code)${NC}"
    echo -e "${YELLOW}Check the log file for details: ${BOLD}$LOG_FILE${NC}"
    echo
    echo -e "${BLUE}${BOLD}Common solutions:${NC}"
    echo -e "${YELLOW}•${NC} Check internet connectivity"
    echo -e "${YELLOW}•${NC} Ensure sufficient disk space (20GB+)"
    echo -e "${YELLOW}•${NC} Verify system requirements"
    echo -e "${YELLOW}•${NC} Run with sudo privileges"
    echo
    echo -e "${BLUE}${BOLD}Need help?${NC}"
    echo -e "${GREEN}📖 Documentation:${NC} ${BOLD}https://github.com/Hammdie/odoo-upgrade-cron${NC}"
    echo -e "${GREEN}🐛 Report Issue:${NC} ${BOLD}https://github.com/Hammdie/odoo-upgrade-cron/issues${NC}"
    echo -e "${GREEN}💬 Get Support:${NC} ${BOLD}https://github.com/Hammdie/odoo-upgrade-cron/discussions${NC}"
    echo
    echo -e "${YELLOW}💡 Tip:${NC} Click the links above to access help resources"
    echo
    
    log "ERROR" "Installation failed - See https://github.com/Hammdie/odoo-upgrade-cron for help"
    
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
    log "INFO" "Documentation: https://github.com/Hammdie/odoo-upgrade-cron"
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
    
    # Show interactive menu FIRST (only in interactive mode)
    # This allows user to choose what to do before handling existing installation
    show_interactive_menu
    
    # Handle existing installation based on menu selection
    handle_existing_installation
    
    # Show installation plan (after menu selection)
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
    
    # Install pgvector extension for AI/RAG support
    log "INFO" "Installing PostgreSQL pgvector extension for AI/RAG support..."
    if [[ -f "$PROJECT_ROOT/scripts/install-pgvector.sh" ]]; then
        if bash "$PROJECT_ROOT/scripts/install-pgvector.sh" 2>&1 | tee -a "$LOG_FILE"; then
            log "SUCCESS" "pgvector extension installed successfully"
        else
            log "WARN" "pgvector installation failed - continuing without AI/RAG support"
            log "INFO" "You can install it later from Fixes & Patches menu (Option 11)"
        fi
    else
        log "WARN" "pgvector installation script not found - skipping"
        log "INFO" "Script location: $PROJECT_ROOT/scripts/install-pgvector.sh"
    fi
    
    if ! run_cron_setup; then
        log "ERROR" "Cron setup failed"
        exit 1
    fi
    
    # Install Enterprise edition if requested
    if ! install_enterprise; then
        log "WARN" "Enterprise installation failed - continuing without Enterprise edition"
    fi
    
    # Verify installation BEFORE Nginx setup (Odoo must be running first!)
    if ! verify_installation; then
        log "ERROR" "Installation verification failed - aborting Nginx setup"
        log "INFO" "Please check Odoo service status and logs:"
        log "INFO" "  sudo systemctl status odoo"
        log "INFO" "  sudo journalctl -u odoo -n 50"
        log "INFO" "You can run Nginx setup later manually:"
        log "INFO" "  sudo $PROJECT_ROOT/scripts/setup-odoo-nginx.sh"
    else
        # Run Nginx setup only if verification passed
        if ! run_nginx_setup; then
            log "WARN" "Nginx setup failed - Odoo is still accessible via HTTP on port 8069"
        fi
    fi
    
    # Show final summary
    show_final_summary
    
    log "SUCCESS" "Odoo 19.0 Upgrade System installation completed successfully!"
}

# Run main function
main "$@"
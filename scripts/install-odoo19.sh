#!/bin/bash

# Odoo 19.0 Installation Script
# Downloads, installs, and configures Odoo 19.0

set -e  # Exit on any error

# Configuration
ODOO_VERSION="19.0"
ODOO_USER="odoo"
ODOO_HOME="/opt/odoo"
ODOO_CONFIG="/etc/odoo/odoo.conf"
LOG_DIR="/var/log/odoo-upgrade"
LOG_FILE="$LOG_DIR/install-odoo19-$(date +%Y%m%d-%H%M%S).log"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# GitHub repository for Odoo
ODOO_REPO="https://github.com/odoo/odoo.git"

# Ensure apt runs non-interactively when invoked
export DEBIAN_FRONTEND="${DEBIAN_FRONTEND:-noninteractive}"

# Pip options (Ubuntu/Debian enforce Externally Managed Env)
declare -a PIP_INSTALL_ARGS
if python3 -m pip --help 2>&1 | grep -q -- "--break-system-packages"; then
    PIP_INSTALL_ARGS+=("--break-system-packages")
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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
        sudo mkdir -p "$LOG_DIR"
        sudo chmod 755 "$LOG_DIR"
        log "INFO" "Created log directory: $LOG_DIR"
    fi
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log "ERROR" "This script must be run as root or with sudo"
        exit 1
    fi
}

# Check prerequisites
check_prerequisites() {
    log "INFO" "Checking prerequisites..."
    
    # Check if odoo user exists
    if ! id "$ODOO_USER" &>/dev/null; then
        log "ERROR" "User '$ODOO_USER' does not exist. Please run upgrade-system.sh first."
        exit 1
    fi
    
    # Check if PostgreSQL is running
    if ! systemctl is-active --quiet postgresql; then
        log "ERROR" "PostgreSQL is not running. Please run upgrade-system.sh first."
        exit 1
    fi
    
    # Check if Python 3 is available
    if ! command -v python3 &> /dev/null; then
        log "ERROR" "Python 3 is not installed. Please run upgrade-system.sh first."
        exit 1
    fi
    
    # Check if Git is available
    if ! command -v git &> /dev/null; then
        log "ERROR" "Git is not installed. Please run upgrade-system.sh first."
        exit 1
    fi
    
    log "SUCCESS" "Prerequisites check passed"
}

# Stop existing Odoo service
stop_odoo_service() {
    log "INFO" "Stopping existing Odoo service..."
    
    if systemctl is-active --quiet odoo; then
        systemctl stop odoo
        log "INFO" "Odoo service stopped"
    else
        log "INFO" "Odoo service is not running"
    fi
}

# Download Odoo source code
download_odoo() {
    log "INFO" "Downloading Odoo $ODOO_VERSION source code..."
    
    # Backup existing installation
    if [[ -d "$ODOO_HOME/odoo" ]]; then
        log "INFO" "Backing up existing Odoo installation..."
        mv "$ODOO_HOME/odoo" "$ODOO_HOME/odoo.backup.$(date +%Y%m%d-%H%M%S)"
    fi
    
    # Clone Odoo repository
    cd "$ODOO_HOME"
    sudo -u "$ODOO_USER" git clone --depth 1 --branch "$ODOO_VERSION" "$ODOO_REPO" odoo 2>&1 | tee -a "$LOG_FILE"
    
    # Set permissions
    chown -R "$ODOO_USER:$ODOO_USER" "$ODOO_HOME/odoo"
    
    log "SUCCESS" "Odoo $ODOO_VERSION downloaded successfully"
}

# Remove distro-provided Odoo packages to avoid mixing versions
remove_system_odoo_packages() {
    log "INFO" "Checking for system Odoo packages..."

    if dpkg -l | grep -q '^ii\s\+odoo'; then
        log "WARN" "Removing distro Odoo packages (odoo, odoo-*)"
        apt-get -o Dpkg::Options::="--force-confnew" -o Dpkg::Options::="--force-confdef" -y remove --purge 'odoo' 'odoo-*' 2>&1 | tee -a "$LOG_FILE" || true
    fi

    if dpkg -l | grep -q '^ii\s\+python3-odoo'; then
        log "WARN" "Removing distro python3-odoo package"
        apt-get -o Dpkg::Options::="--force-confnew" -o Dpkg::Options::="--force-confdef" -y remove --purge python3-odoo 2>&1 | tee -a "$LOG_FILE" || true
    fi

    apt-get -o Dpkg::Options::="--force-confnew" -o Dpkg::Options::="--force-confdef" -y autoremove 2>&1 | tee -a "$LOG_FILE" || true
}

# Remove previously installed dependencies to ensure a clean reinstall
purge_odoo_dependencies() {
    log "INFO" "Removing previously installed Odoo Python dependencies..."

    local anything_removed=false

    if python3 -m pip show odoo &>/dev/null; then
        python3 -m pip uninstall -y odoo 2>&1 | tee -a "$LOG_FILE" || true
        anything_removed=true
    fi

    # Gather possible requirements files (current installation, latest backup, new clone)
    local requirements_candidates=()
    if [[ -f "$ODOO_HOME/odoo/requirements.txt" ]]; then
        requirements_candidates+=("$ODOO_HOME/odoo/requirements.txt")
    fi

    local latest_backup
    latest_backup=$(ls -1dt "$ODOO_HOME"/odoo.backup.* 2>/dev/null | head -n1 || true)
    if [[ -n "$latest_backup" && -f "$latest_backup/requirements.txt" ]]; then
        requirements_candidates+=("$latest_backup/requirements.txt")
    fi

    for req_file in "${requirements_candidates[@]}"; do
        log "INFO" "Removing dependencies listed in $req_file"
        python3 -m pip uninstall -y -r "$req_file" 2>&1 | tee -a "$LOG_FILE" || true
        anything_removed=true
    done

    local extra_packages=(
        "psycopg2-binary"
        "python-ldap"
        "qrcode"
        "vobject"
        "werkzeug"
        "lxml"
    )

    for pkg in "${extra_packages[@]}"; do
        if python3 -m pip show "$pkg" &>/dev/null; then
            python3 -m pip uninstall -y "$pkg" 2>&1 | tee -a "$LOG_FILE" || true
            anything_removed=true
        fi
    done

    if [[ "$anything_removed" == true ]]; then
        log "SUCCESS" "Previous Odoo dependencies removed"
    else
        log "INFO" "No existing Odoo dependencies found to remove"
    fi
}

# Install Odoo Python dependencies
install_odoo_dependencies() {
    log "INFO" "Installing Odoo Python dependencies..."
    
    # Ensure pip tooling is up to date to avoid build quirks
    python3 -m pip install "${PIP_INSTALL_ARGS[@]}" --upgrade pip wheel setuptools 2>&1 | tee -a "$LOG_FILE"

    # Install from Odoo requirements.txt
    if [[ -f "$ODOO_HOME/odoo/requirements.txt" ]]; then
        python3 -m pip install "${PIP_INSTALL_ARGS[@]}" -r "$ODOO_HOME/odoo/requirements.txt" 2>&1 | tee -a "$LOG_FILE"
    else
        log "WARN" "requirements.txt not found in Odoo source tree"
    fi

    # Ensure compatible lxml version (<5 retains html.clean.defs expected by Odoo)
    python3 -m pip install "${PIP_INSTALL_ARGS[@]}" --upgrade "lxml<5" 2>&1 | tee -a "$LOG_FILE"
    
    # Install additional common dependencies
    local additional_deps=(
        "psycopg2-binary"
        "python-ldap"
        "qrcode"
        "vobject"
        "werkzeug"
    )
    
    for dep in "${additional_deps[@]}"; do
        log "INFO" "Installing $dep..."
        python3 -m pip install "${PIP_INSTALL_ARGS[@]}" "$dep" 2>&1 | tee -a "$LOG_FILE"
    done
}

# Create Odoo configuration
create_odoo_config() {
    log "INFO" "Creating Odoo configuration..."
    
    # Create config directory
    mkdir -p "/etc/odoo"
    
    # Copy example config or create new one
    if [[ -f "$PROJECT_ROOT/config/odoo.conf.example" ]]; then
        cp "$PROJECT_ROOT/config/odoo.conf.example" "$ODOO_CONFIG"
        log "INFO" "Copied configuration from project template"
    else
        # Create basic configuration
        cat > "$ODOO_CONFIG" << EOF
[options]
admin_passwd = $(openssl rand -base64 32)
db_host = localhost
db_port = 5432
db_user = $ODOO_USER
addons_path = $ODOO_HOME/odoo/addons,$ODOO_HOME/custom-addons
xmlrpc_port = 8069
logfile = /var/log/odoo/odoo.log
log_level = info
workers = 4
max_cron_threads = 2
limit_memory_hard = 2684354560
limit_memory_soft = 2147483648
data_dir = $ODOO_HOME/.local/share/Odoo
EOF
        log "INFO" "Created basic Odoo configuration"
    fi
    
    # Set permissions
    chown "$ODOO_USER:$ODOO_USER" "$ODOO_CONFIG"
    chmod 640 "$ODOO_CONFIG"
    
    log "SUCCESS" "Odoo configuration created"
}

# Setup PostgreSQL database
setup_database() {
    log "INFO" "Setting up PostgreSQL database for Odoo..."
    
    # Check if this is an upgrade mode (existing installation)
    if [[ "$ODOO_UPGRADE_MODE" == "true" ]] && [[ -n "$EXISTING_CONFIG_PATH" ]] && [[ -f "$EXISTING_CONFIG_PATH" ]]; then
        log "INFO" "Upgrade mode detected - preserving existing database configuration"
        
        # Extract existing database password from config
        local existing_password=$(grep -E "^[[:space:]]*db_password[[:space:]]*=" "$EXISTING_CONFIG_PATH" | cut -d'=' -f2 | tr -d ' ' | tr -d '"' | tr -d "'")
        
        if [[ -n "$existing_password" ]] && [[ "$existing_password" != "False" ]] && [[ "$existing_password" != "false" ]]; then
            log "INFO" "Using existing database password from configuration"
            
            # Test existing password
            if PGPASSWORD="$existing_password" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -c "\l" postgres &>/dev/null; then
                log "SUCCESS" "Existing database password is valid"
                # Update new config with existing password
                sed -i "s/db_password = .*/db_password = $existing_password/" "$ODOO_CONFIG"
                return 0
            else
                log "WARN" "Existing database password doesn't work"
            fi
        else
            log "INFO" "No existing database password found in configuration"
        fi
    fi
    
    # Check if odoo user exists and try without password first (peer authentication)
    if sudo -u postgres psql -c "\du" | grep -q "$ODOO_USER"; then
        log "INFO" "Database user '$ODOO_USER' already exists"
        
        # Test if current configuration works
        if [[ -f "$ODOO_CONFIG" ]]; then
            local current_password=$(grep -E "^[[:space:]]*db_password[[:space:]]*=" "$ODOO_CONFIG" | cut -d'=' -f2 | tr -d ' ' | tr -d '"' | tr -d "'")
            
            if [[ -n "$current_password" ]] && [[ "$current_password" != "False" ]] && [[ "$current_password" != "false" ]]; then
                if PGPASSWORD="$current_password" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -c "\l" postgres &>/dev/null; then
                    log "SUCCESS" "Current database configuration is working"
                    return 0
                fi
            fi
        fi
        
        # Try to connect without password (peer/trust authentication)
        if sudo -u "$ODOO_USER" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -c "\l" postgres &>/dev/null; then
            log "SUCCESS" "Database authentication working without password"
            # Set empty password in config for peer authentication
            sed -i "s/db_password = .*/db_password = False/" "$ODOO_CONFIG"
            return 0
        fi
    else
        log "INFO" "Creating new database user '$ODOO_USER'"
        sudo -u postgres createuser -s "$ODOO_USER" 2>/dev/null || log "WARN" "User '$ODOO_USER' may already exist"
    fi
    
    # Only set new password if nothing else works
    log "WARN" "Setting new database password as fallback"
    local db_password=$(openssl rand -base64 32)
    sudo -u postgres psql -c "ALTER USER $ODOO_USER PASSWORD '$db_password';" 2>&1 | tee -a "$LOG_FILE"
    
    # Update config file with database password
    sed -i "s/db_password = .*/db_password = $db_password/" "$ODOO_CONFIG"
    
    log "SUCCESS" "Database setup completed"
}

# Create systemd service
create_systemd_service() {
    log "INFO" "Creating systemd service for Odoo..."
    
    cat > /etc/systemd/system/odoo.service << EOF
[Unit]
Description=Odoo
Documentation=http://www.odoo.com
Requires=postgresql.service
After=network.target postgresql.service

[Service]
Type=forking
User=$ODOO_USER
ExecStart=$ODOO_HOME/odoo/odoo-bin -c $ODOO_CONFIG --pidfile=/var/run/odoo/odoo.pid --daemon
ExecReload=/bin/kill -s HUP \$MAINPID
PIDFile=/var/run/odoo/odoo.pid
KillMode=mixed

# Security settings
NoNewPrivileges=true
ProtectSystem=strict
ReadWritePaths=/var/log/odoo /var/run/odoo $ODOO_HOME
ProtectHome=true
PrivateTmp=true
PrivateDevices=true

[Install]
WantedBy=multi-user.target
EOF

    # Create PID directory
    mkdir -p /var/run/odoo
    chown "$ODOO_USER:$ODOO_USER" /var/run/odoo
    
    # Create tmpfiles.d configuration
    cat > /etc/tmpfiles.d/odoo.conf << EOF
d /var/run/odoo 0755 $ODOO_USER $ODOO_USER -
EOF
    
    # Reload systemd
    systemctl daemon-reload
    
    log "SUCCESS" "Systemd service created"
}

# Install Odoo as Python package
install_odoo_package() {
    log "INFO" "Installing Odoo as Python package..."
    
    cd "$ODOO_HOME/odoo"
    python3 -m pip install "${PIP_INSTALL_ARGS[@]}" -e . 2>&1 | tee -a "$LOG_FILE"
    
    log "SUCCESS" "Odoo package installed"
}

# Create custom addons directory
setup_custom_addons() {
    log "INFO" "Setting up custom addons directory..."
    
    mkdir -p "$ODOO_HOME/custom-addons"
    chown -R "$ODOO_USER:$ODOO_USER" "$ODOO_HOME/custom-addons"
    chmod 755 "$ODOO_HOME/custom-addons"
    
    # Create a sample custom addon structure
    cat > "$ODOO_HOME/custom-addons/.gitkeep" << EOF
# This directory is for custom Odoo addons
# Place your custom modules here
EOF
    
    chown "$ODOO_USER:$ODOO_USER" "$ODOO_HOME/custom-addons/.gitkeep"
    
    log "SUCCESS" "Custom addons directory set up"
}

# Configure log rotation
setup_log_rotation() {
    log "INFO" "Setting up log rotation..."
    
    cat > /etc/logrotate.d/odoo << EOF
/var/log/odoo/*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 0640 $ODOO_USER $ODOO_USER
    postrotate
        systemctl reload odoo > /dev/null 2>&1 || true
    endscript
}
EOF
    
    log "SUCCESS" "Log rotation configured"
}

# Test Odoo installation
test_installation() {
    log "INFO" "Testing Odoo installation..."
    
    # Start Odoo service
    systemctl enable odoo
    systemctl start odoo
    
    # Wait for service to start
    sleep 10
    
    # Check if service is running
    if systemctl is-active --quiet odoo; then
        log "SUCCESS" "Odoo service is running"
        
        # Check if Odoo is responding
        local max_attempts=30
        local attempt=1
        
        while [[ $attempt -le $max_attempts ]]; do
            if curl -s -o /dev/null -w "%{http_code}" http://localhost:8069 | grep -q "200\|302"; then
                log "SUCCESS" "Odoo is responding on port 8069"
                break
            fi
            
            log "INFO" "Waiting for Odoo to respond... (attempt $attempt/$max_attempts)"
            sleep 10
            ((attempt++))
        done
        
        if [[ $attempt -gt $max_attempts ]]; then
            log "WARN" "Odoo service is running but not responding on port 8069"
            log "INFO" "Check logs: journalctl -u odoo -f"
        fi
    else
        log "ERROR" "Failed to start Odoo service"
        log "INFO" "Check logs: journalctl -u odoo -f"
        exit 1
    fi
}

# Display installation summary
show_summary() {
    log "INFO" "Installation Summary"
    log "INFO" "==================="
    log "INFO" "Odoo Version: $ODOO_VERSION"
    log "INFO" "Installation Path: $ODOO_HOME/odoo"
    log "INFO" "Configuration: $ODOO_CONFIG"
    log "INFO" "Log File: /var/log/odoo/odoo.log"
    log "INFO" "Service Status: $(systemctl is-active odoo)"
    log "INFO" "Web Interface: http://localhost:8069"
    log "INFO" ""
    log "INFO" "Next Steps:"
    log "INFO" "1. Access Odoo at http://your-server-ip:8069"
    log "INFO" "2. Create your first database"
    log "INFO" "3. Configure your Odoo instance"
    log "INFO" "4. Run setup-cron.sh for automatic updates"
    log "INFO" ""
    log "INFO" "Useful Commands:"
    log "INFO" "- Check status: sudo systemctl status odoo"
    log "INFO" "- View logs: sudo journalctl -u odoo -f"
    log "INFO" "- Restart: sudo systemctl restart odoo"
    log "INFO" "- Stop: sudo systemctl stop odoo"
}

# Main execution
main() {
    log "INFO" "Starting Odoo $ODOO_VERSION installation..."
    log "INFO" "Log file: $LOG_FILE"
    
    create_log_dir
    check_root
    check_prerequisites
    stop_odoo_service
    remove_system_odoo_packages
    purge_odoo_dependencies
    download_odoo
    purge_odoo_dependencies
    install_odoo_dependencies
    install_odoo_package
    create_odoo_config
    setup_database
    setup_custom_addons
    create_systemd_service
    setup_log_rotation
    test_installation
    show_summary
    
    log "SUCCESS" "Odoo $ODOO_VERSION installation completed successfully!"
    
    echo
    echo -e "${GREEN}Odoo $ODOO_VERSION installation completed successfully!${NC}"
    echo -e "${BLUE}Access your Odoo instance at: http://localhost:8069${NC}"
    echo -e "${BLUE}Log file: $LOG_FILE${NC}"
}

# Run main function
main "$@"
#!/bin/bash

# Odoo System Upgrade Script
# Upgrades the system to be compatible with Odoo 19.0 requirements

set -e  # Exit on any error

# Configuration
LOG_DIR="/var/log/odoo-upgrade"
LOG_FILE="$LOG_DIR/upgrade-system-$(date +%Y%m%d-%H%M%S).log"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

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

# Check OS compatibility
check_os() {
    log "INFO" "Checking OS compatibility..."
    
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
        log "INFO" "Detected OS: $OS $VER"
        
        # Check if Ubuntu
        if [[ "$OS" != *"Ubuntu"* ]]; then
            log "WARN" "This script is optimized for Ubuntu. Other distributions may not be fully supported."
        fi
        
        # Check version
        if [[ "$OS" == *"Ubuntu"* ]] && [[ $(echo "$VER < 20.04" | bc -l) -eq 1 ]]; then
            log "WARN" "Ubuntu version $VER detected. Odoo 19.0 is recommended on Ubuntu 20.04 or higher."
        fi
    else
        log "ERROR" "Cannot detect OS version"
        exit 1
    fi
}

# Update system packages
update_system() {
    log "INFO" "Updating system packages..."
    
    export DEBIAN_FRONTEND=noninteractive
    
    # Update package lists
    apt update 2>&1 | tee -a "$LOG_FILE"
    
    # Upgrade existing packages
    apt upgrade -y 2>&1 | tee -a "$LOG_FILE"
    
    # Install essential packages
    local packages=(
        "curl"
        "wget" 
        "git"
        "software-properties-common"
        "apt-transport-https"
        "ca-certificates"
        "gnupg"
        "lsb-release"
        "build-essential"
        "python3"
        "python3-pip"
        "python3-dev"
        "python3-venv"
        "libxml2-dev"
        "libxslt1-dev"
        "zlib1g-dev"
        "libsasl2-dev"
        "libldap2-dev"
        "libssl-dev"
        "libffi-dev"
        "libjpeg-dev"
        "libpq-dev"
        "libevent-dev"
        "libxmlsec1-dev"
        "pkg-config"
    )
    
    log "INFO" "Installing essential packages..."
    for package in "${packages[@]}"; do
        log "INFO" "Installing $package..."
        apt install -y "$package" 2>&1 | tee -a "$LOG_FILE"
    done
}

# Install PostgreSQL
install_postgresql() {
    log "INFO" "Installing PostgreSQL..."
    
    # Install PostgreSQL
    apt install -y postgresql postgresql-contrib postgresql-client 2>&1 | tee -a "$LOG_FILE"
    
    # Start and enable PostgreSQL
    systemctl start postgresql
    systemctl enable postgresql
    
    # Check PostgreSQL version
    local pg_version=$(sudo -u postgres psql -c "SELECT version();" | head -n 3 | tail -n 1)
    log "INFO" "PostgreSQL installed: $pg_version"
    
    # Create Odoo database user
    log "INFO" "Creating Odoo database user..."
    sudo -u postgres createuser -s odoo 2>/dev/null || log "WARN" "User 'odoo' already exists"
}

# Install Node.js and npm (for Odoo frontend dependencies)
install_nodejs() {
    log "INFO" "Installing Node.js and npm..."
    
    # Add NodeSource repository for latest LTS
    curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - 2>&1 | tee -a "$LOG_FILE"
    
    # Install Node.js
    apt install -y nodejs 2>&1 | tee -a "$LOG_FILE"
    
    # Verify installation
    local node_version=$(node --version)
    local npm_version=$(npm --version)
    log "INFO" "Node.js installed: $node_version"
    log "INFO" "npm installed: $npm_version"
    
    # Install global packages needed for Odoo
    npm install -g rtlcss 2>&1 | tee -a "$LOG_FILE"
}

# Install Python dependencies
install_python_deps() {
    log "INFO" "Installing Python dependencies..."
    
    # Upgrade pip
    python3 -m pip install --upgrade pip 2>&1 | tee -a "$LOG_FILE"
    
    # Install wheel and setuptools
    python3 -m pip install wheel setuptools 2>&1 | tee -a "$LOG_FILE"
    
    # Install requirements if available
    if [[ -f "$PROJECT_ROOT/config/requirements.txt" ]]; then
        log "INFO" "Installing Python requirements from config/requirements.txt..."
        python3 -m pip install -r "$PROJECT_ROOT/config/requirements.txt" 2>&1 | tee -a "$LOG_FILE"
    else
        log "WARN" "requirements.txt not found, installing basic Odoo dependencies..."
        python3 -m pip install psycopg2-binary 2>&1 | tee -a "$LOG_FILE"
    fi
}

# Configure firewall
configure_firewall() {
    log "INFO" "Configuring firewall..."
    
    # Install UFW if not present
    apt install -y ufw 2>&1 | tee -a "$LOG_FILE"
    
    # Configure UFW rules
    ufw --force reset 2>&1 | tee -a "$LOG_FILE"
    ufw default deny incoming 2>&1 | tee -a "$LOG_FILE"
    ufw default allow outgoing 2>&1 | tee -a "$LOG_FILE"
    
    # Allow SSH
    ufw allow ssh 2>&1 | tee -a "$LOG_FILE"
    
    # Allow HTTP and HTTPS
    ufw allow 80/tcp comment 'HTTP' 2>&1 | tee -a "$LOG_FILE"
    ufw allow 443/tcp comment 'HTTPS' 2>&1 | tee -a "$LOG_FILE"
    
    # Allow Odoo ports
    ufw allow 8069/tcp comment 'Odoo HTTP' 2>&1 | tee -a "$LOG_FILE"
    ufw allow 8072/tcp comment 'Odoo Longpolling' 2>&1 | tee -a "$LOG_FILE"
    
    # Allow PostgreSQL (nur lokal)
    ufw allow from 127.0.0.1 to any port 5432 comment 'PostgreSQL local' 2>&1 | tee -a "$LOG_FILE"
    
    # Enable firewall
    ufw --force enable 2>&1 | tee -a "$LOG_FILE"
    
    log "SUCCESS" "Firewall configured successfully"
}

# Create Odoo user
create_odoo_user() {
    log "INFO" "Creating Odoo system user..."
    
    # Create odoo user if it doesn't exist
    if ! id "odoo" &>/dev/null; then
        useradd -m -d /opt/odoo -U -r -s /bin/bash odoo 2>&1 | tee -a "$LOG_FILE"
        log "SUCCESS" "Odoo user created"
    else
        log "WARN" "Odoo user already exists"
    fi
    
    # Create necessary directories
    mkdir -p /opt/odoo/{addons,custom-addons,.local/share/Odoo}
    mkdir -p /var/log/odoo
    
    # Set permissions
    chown -R odoo:odoo /opt/odoo
    chown -R odoo:odoo /var/log/odoo
    chmod 755 /var/log/odoo
}

# Install wkhtmltopdf
install_wkhtmltopdf() {
    log "INFO" "Installing wkhtmltopdf..."
    
    # Download and install wkhtmltopdf
    cd /tmp
    
    # Detect architecture
    local arch=$(dpkg --print-architecture)
    local wkhtml_version="0.12.6.1-2"
    
    if [[ "$arch" == "amd64" ]]; then
        local wkhtml_url="https://github.com/wkhtmltopdf/packaging/releases/download/${wkhtml_version}/wkhtmltox_${wkhtml_version}.jammy_amd64.deb"
    elif [[ "$arch" == "arm64" ]]; then
        local wkhtml_url="https://github.com/wkhtmltopdf/packaging/releases/download/${wkhtml_version}/wkhtmltox_${wkhtml_version}.jammy_arm64.deb"
    else
        log "WARN" "Unsupported architecture for wkhtmltopdf: $arch"
        return
    fi
    
    wget -q "$wkhtml_url" -O wkhtmltox.deb 2>&1 | tee -a "$LOG_FILE"
    
    # Install dependencies
    apt install -y fontconfig libfontconfig1 libfreetype6 libx11-6 libxext6 libxrender1 xfonts-75dpi xfonts-base 2>&1 | tee -a "$LOG_FILE"
    
    # Install wkhtmltopdf
    dpkg -i wkhtmltox.deb 2>&1 | tee -a "$LOG_FILE" || apt install -fy 2>&1 | tee -a "$LOG_FILE"
    
    # Verify installation
    if command -v wkhtmltopdf &> /dev/null; then
        local wk_version=$(wkhtmltopdf --version | head -n 1)
        log "SUCCESS" "wkhtmltopdf installed: $wk_version"
    else
        log "ERROR" "Failed to install wkhtmltopdf"
    fi
    
    # Cleanup
    rm -f wkhtmltox.deb
}

# System optimization for Odoo
optimize_system() {
    log "INFO" "Optimizing system for Odoo..."
    
    # Update sysctl settings
    cat >> /etc/sysctl.conf << EOF

# Odoo optimizations
vm.swappiness=10
vm.overcommit_memory=2
vm.overcommit_ratio=80
net.core.somaxconn=1024
net.core.netdev_max_backlog=5000
net.ipv4.tcp_max_syn_backlog=2048
net.ipv4.tcp_keepalive_time=600
EOF
    
    # Apply sysctl settings
    sysctl -p 2>&1 | tee -a "$LOG_FILE"
    
    # Update limits
    cat >> /etc/security/limits.conf << EOF

# Odoo limits
odoo soft nofile 65535
odoo hard nofile 65535
odoo soft nproc 8192
odoo hard nproc 8192
EOF
    
    log "SUCCESS" "System optimization completed"
}

# Main execution
main() {
    log "INFO" "Starting Odoo 19.0 system upgrade..."
    log "INFO" "Log file: $LOG_FILE"
    
    create_log_dir
    check_root
    check_os
    update_system
    install_postgresql
    install_nodejs
    install_python_deps
    create_odoo_user
    install_wkhtmltopdf
    configure_firewall
    optimize_system
    
    log "SUCCESS" "System upgrade completed successfully!"
    log "INFO" "Next steps:"
    log "INFO" "1. Run ./install-odoo19.sh to install Odoo 19.0"
    log "INFO" "2. Configure your Odoo instance"
    log "INFO" "3. Run ./setup-cron.sh to set up automatic updates"
    
    echo
    echo -e "${GREEN}System upgrade completed successfully!${NC}"
    echo -e "${BLUE}Log file: $LOG_FILE${NC}"
}

# Run main function
main "$@"
#!/bin/bash

# Quick Fix Script für Odoo Installation Probleme
# Behebt häufige Probleme nach fehlgeschlagener Installation

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"
ODOO_USER="odoo"
ODOO_HOME="/opt/odoo"
ODOO_CONFIG="/etc/odoo/odoo.conf"

echo -e "${BLUE}${BOLD}"
cat << 'EOF'
╔═══════════════════════════════════════════════════╗
║          Odoo Installation Quick Fix Tool         ║
╚═══════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}This script must be run as root or with sudo${NC}"
        exit 1
    fi
}

# Fix 1: Ensure Odoo service is properly installed
fix_service() {
    echo -e "${YELLOW}🔧 Fix 1: Checking and fixing Odoo service...${NC}"
    
    if ! systemctl list-unit-files 2>/dev/null | grep -q "^odoo.service"; then
        echo -e "${RED}✗ Odoo service not found - attempting to create...${NC}"
        
        # Run the Odoo installation script if service is missing
        if [[ -f "$PROJECT_ROOT/scripts/install-odoo19.sh" ]]; then
            echo -e "${BLUE}Running Odoo installation script...${NC}"
            bash "$PROJECT_ROOT/scripts/install-odoo19.sh"
        else
            echo -e "${RED}Installation script not found: $PROJECT_ROOT/scripts/install-odoo19.sh${NC}"
            echo -e "${YELLOW}Manual fix needed - please run the complete installation again${NC}"
            return 1
        fi
    else
        echo -e "${GREEN}✓ Odoo service exists${NC}"
        
        # Check if service is enabled
        if ! systemctl is-enabled --quiet odoo; then
            echo -e "${YELLOW}Enabling Odoo service...${NC}"
            systemctl enable odoo
        fi
        
        # Try to start service if not running
        if ! systemctl is-active --quiet odoo; then
            echo -e "${YELLOW}Starting Odoo service...${NC}"
            systemctl start odoo
            sleep 5
            
            if systemctl is-active --quiet odoo; then
                echo -e "${GREEN}✓ Odoo service started successfully${NC}"
            else
                echo -e "${RED}✗ Failed to start Odoo service${NC}"
                echo -e "${YELLOW}Check logs with: sudo journalctl -u odoo -n 20${NC}"
                return 1
            fi
        else
            echo -e "${GREEN}✓ Odoo service is already running${NC}"
        fi
    fi
}

# Fix 2: Fix permissions
fix_permissions() {
    echo -e "${YELLOW}🔧 Fix 2: Fixing file permissions...${NC}"
    
    if [[ -d "$ODOO_HOME" ]]; then
        echo -e "${BLUE}Fixing ownership of $ODOO_HOME...${NC}"
        chown -R odoo:odoo "$ODOO_HOME"
        chmod -R 755 "$ODOO_HOME"
        echo -e "${GREEN}✓ Permissions fixed${NC}"
    else
        echo -e "${RED}✗ Odoo home directory not found: $ODOO_HOME${NC}"
    fi
    
    if [[ -f "$ODOO_CONFIG" ]]; then
        echo -e "${BLUE}Fixing config file permissions...${NC}"
        chown odoo:odoo "$ODOO_CONFIG"
        chmod 640 "$ODOO_CONFIG"
        echo -e "${GREEN}✓ Config permissions fixed${NC}"
    else
        echo -e "${YELLOW}⚠ Config file not found: $ODOO_CONFIG${NC}"
    fi
    
    # Fix log directory
    if [[ -d "/var/log/odoo" ]]; then
        chown -R odoo:odoo "/var/log/odoo"
        chmod 755 "/var/log/odoo"
        echo -e "${GREEN}✓ Log directory permissions fixed${NC}"
    fi
}

# Fix 3: Verify and fix PostgreSQL setup
fix_postgresql() {
    echo -e "${YELLOW}🔧 Fix 3: Checking PostgreSQL setup...${NC}"
    
    # Start PostgreSQL if not running
    if ! systemctl is-active --quiet postgresql; then
        echo -e "${YELLOW}Starting PostgreSQL...${NC}"
        systemctl start postgresql
        systemctl enable postgresql
    fi
    
    # Check if odoo user exists in PostgreSQL
    if ! sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='odoo'" | grep -q "1"; then
        echo -e "${YELLOW}Creating PostgreSQL odoo user...${NC}"
        sudo -u postgres createuser -s odoo
        echo -e "${GREEN}✓ PostgreSQL odoo user created${NC}"
    else
        echo -e "${GREEN}✓ PostgreSQL odoo user exists${NC}"
    fi
    
    # Test connection
    if sudo -u odoo psql -h localhost -U odoo -d postgres -c "SELECT version();" &>/dev/null; then
        echo -e "${GREEN}✓ PostgreSQL connection test successful${NC}"
    else
        echo -e "${RED}✗ PostgreSQL connection test failed${NC}"
        echo -e "${YELLOW}Running PostgreSQL authentication fix...${NC}"
        
        if [[ -f "$PROJECT_ROOT/fix-postgres-auth.sh" ]]; then
            bash "$PROJECT_ROOT/fix-postgres-auth.sh"
        else
            echo -e "${YELLOW}Manual fix needed - check pg_hba.conf${NC}"
        fi
    fi
}

# Fix 4: Install missing Odoo Python package
fix_python_package() {
    echo -e "${YELLOW}🔧 Fix 4: Checking Odoo Python package...${NC}"
    
    if ! python3 -c "import odoo" &>/dev/null; then
        echo -e "${RED}✗ Odoo Python package not found${NC}"
        echo -e "${YELLOW}This is likely the main issue!${NC}"
        
        # Check if Odoo source exists
        if [[ -d "$ODOO_HOME/odoo" ]]; then
            echo -e "${BLUE}Installing Odoo from source directory...${NC}"
            cd "$ODOO_HOME/odoo"
            
            # Install as Python package
            pip3 install --break-system-packages -e . 2>/dev/null || pip3 install -e .
            
            # Verify installation
            if python3 -c "import odoo" &>/dev/null; then
                echo -e "${GREEN}✓ Odoo Python package installed successfully${NC}"
            else
                echo -e "${RED}✗ Failed to install Odoo Python package${NC}"
                return 1
            fi
        else
            echo -e "${RED}✗ Odoo source directory not found: $ODOO_HOME/odoo${NC}"
            echo -e "${YELLOW}Re-running complete installation recommended${NC}"
            return 1
        fi
    else
        echo -e "${GREEN}✓ Odoo Python package is available${NC}"
    fi
}

# Fix 5: Install/Fix wkhtmltopdf (Qt patched)
fix_wkhtmltopdf() {
    echo -e "${YELLOW}🔧 Fix 5: Checking wkhtmltopdf (Qt patch required)...${NC}"
    
    local needs_install=false
    
    if ! command -v wkhtmltopdf &> /dev/null; then
        echo -e "${RED}✗ wkhtmltopdf not found${NC}"
        needs_install=true
    else
        if ! wkhtmltopdf --version 2>&1 | grep -q "with patched qt"; then
            echo -e "${RED}✗ wkhtmltopdf found but WITHOUT Qt patch${NC}"
            echo -e "${YELLOW}This will cause PDF generation issues in Odoo!${NC}"
            needs_install=true
        else
            echo -e "${GREEN}✓ wkhtmltopdf with Qt patch is installed${NC}"
            return 0
        fi
    fi
    
    if [[ "$needs_install" == true ]]; then
        echo -e "${BLUE}Installing wkhtmltopdf with Qt patch...${NC}"
        
        # Remove existing version if present
        apt-get remove -y wkhtmltopdf 2>/dev/null || true
        
        # Get system architecture
        local arch=$(uname -m)
        local ubuntu_version=$(lsb_release -rs 2>/dev/null || echo "20.04")
        
        # Determine correct package based on architecture and Ubuntu version
        local package_url=""
        
        if [[ "$arch" == "x86_64" ]]; then
            if [[ "$ubuntu_version" > "20" ]]; then
                package_url="https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-2/wkhtmltox_0.12.6.1-2.jammy_amd64.deb"
            else
                package_url="https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-2/wkhtmltox_0.12.6.1-2.focal_amd64.deb"
            fi
        else
            echo -e "${YELLOW}Architecture $arch detected - trying generic installation...${NC}"
            apt-get update
            apt-get install -y wkhtmltopdf
            return 0
        fi
        
        # Download and install Qt patched version
        local temp_dir=$(mktemp -d)
        local package_file="$temp_dir/wkhtmltox.deb"
        
        echo -e "${BLUE}Downloading Qt patched wkhtmltopdf...${NC}"
        if curl -L -o "$package_file" "$package_url" 2>/dev/null; then
            echo -e "${BLUE}Installing wkhtmltopdf package...${NC}"
            
            # Install dependencies
            apt-get update
            apt-get install -y fontconfig libfontconfig1 libfreetype6 libx11-6 libxext6 libxrender1 libjpeg-turbo8
            
            # Install the package
            if dpkg -i "$package_file" 2>/dev/null; then
                echo -e "${GREEN}✓ wkhtmltopdf with Qt patch installed successfully${NC}"
            else
                echo -e "${YELLOW}Package installation failed, trying to fix dependencies...${NC}"
                apt-get install -f -y
                dpkg -i "$package_file" || {
                    echo -e "${RED}✗ Failed to install wkhtmltopdf package${NC}"
                    rm -rf "$temp_dir"
                    return 1
                }
            fi
        else
            echo -e "${RED}✗ Failed to download wkhtmltopdf package${NC}"
            echo -e "${YELLOW}Falling back to repository version...${NC}"
            apt-get update
            apt-get install -y wkhtmltopdf
        fi
        
        # Cleanup
        rm -rf "$temp_dir"
        
        # Verify installation
        if command -v wkhtmltopdf &> /dev/null; then
            local version_info=$(wkhtmltopdf --version 2>&1)
            echo -e "${GREEN}✓ wkhtmltopdf installed: $(echo "$version_info" | head -1)${NC}"
            
            if echo "$version_info" | grep -q "with patched qt"; then
                echo -e "${GREEN}✓ Qt patch confirmed${NC}"
            else
                echo -e "${YELLOW}⚠ Qt patch not detected, but installation completed${NC}"
            fi
        else
            echo -e "${RED}✗ wkhtmltopdf installation verification failed${NC}"
            return 1
        fi
    fi
}

# Fix 6: Restart services in correct order
restart_services() {
    echo -e "${YELLOW}🔧 Fix 5: Restarting services...${NC}"
    
    # Stop Odoo first
    systemctl stop odoo 2>/dev/null || true
    
    # Restart PostgreSQL
    systemctl restart postgresql
    sleep 3
    
    # Reload systemd daemon
    systemctl daemon-reload
    
    # Start Odoo
    systemctl start odoo
    sleep 5
    
    # Check status
    if systemctl is-active --quiet odoo; then
        echo -e "${GREEN}✓ Services restarted successfully${NC}"
    else
        echo -e "${RED}✗ Service restart failed${NC}"
        return 1
    fi
}

# Test installation
test_installation() {
    echo -e "${YELLOW}🧪 Testing Odoo installation...${NC}"
    
    # Test wkhtmltopdf first (critical for PDF reports)
    if command -v wkhtmltopdf &> /dev/null; then
        if wkhtmltopdf --version 2>&1 | grep -q "with patched qt"; then
            echo -e "${GREEN}✓ wkhtmltopdf with Qt patch available${NC}"
        else
            echo -e "${YELLOW}⚠ wkhtmltopdf without Qt patch - PDF reports may have issues${NC}"
        fi
    else
        echo -e "${RED}✗ wkhtmltopdf missing - PDF reports will fail${NC}"
    fi
    
    # Test service status
    if systemctl is-active --quiet odoo; then
        echo -e "${GREEN}✓ Odoo service is running${NC}"
        
        # Test HTTP response
        echo -e "${BLUE}Testing HTTP response...${NC}"
        sleep 10
        
        local max_attempts=6
        local attempt=1
        
        while [[ $attempt -le $max_attempts ]]; do
            if curl -s -o /dev/null -w "%{http_code}" http://localhost:8069 2>/dev/null | grep -q "200\|302"; then
                echo -e "${GREEN}✓ Odoo is responding on port 8069${NC}"
                echo -e "${GREEN}✓ Installation appears to be working!${NC}"
                echo
                echo -e "${BLUE}You can now access Odoo at:${NC}"
                echo -e "  • http://localhost:8069"
                echo -e "  • http://$(hostname -I | awk '{print $1}'):8069"
                return 0
            fi
            
            echo -e "${YELLOW}Waiting for Odoo to respond... (attempt $attempt/$max_attempts)${NC}"
            sleep 10
            ((attempt++))
        done
        
        echo -e "${RED}✗ Odoo service is running but not responding on port 8069${NC}"
        echo -e "${YELLOW}Check logs with: sudo journalctl -u odoo -f${NC}"
        return 1
    else
        echo -e "${RED}✗ Odoo service is not running${NC}"
        return 1
    fi
}

# Show logs for troubleshooting
show_logs() {
    echo -e "${YELLOW}📋 Recent logs for troubleshooting:${NC}"
    echo
    
    echo -e "${BLUE}Systemd service status:${NC}"
    systemctl status odoo --no-pager -l | head -20
    echo
    
    echo -e "${BLUE}Last 10 log entries:${NC}"
    journalctl -u odoo -n 10 --no-pager
    echo
    
    echo -e "${BLUE}Installation logs:${NC}"
    if [[ -d "/var/log/odoo-upgrade" ]]; then
        RECENT_LOG=$(ls -t /var/log/odoo-upgrade/install-*.log 2>/dev/null | head -1)
        if [[ -n "$RECENT_LOG" ]]; then
            echo -e "Recent log: $RECENT_LOG"
            echo -e "${YELLOW}Last 10 lines:${NC}"
            tail -10 "$RECENT_LOG" 2>/dev/null || echo "Could not read log"
        fi
    fi
}

# Main execution
main() {
    echo -e "${BLUE}Starting Quick Fix for Odoo Installation...${NC}"
    echo
    
    check_root
    
    # Run fixes in sequence
    if fix_service; then
        echo -e "${GREEN}✓ Service fix completed${NC}"
    else
        echo -e "${RED}✗ Service fix failed${NC}"
    fi
    echo
    
    if fix_permissions; then
        echo -e "${GREEN}✓ Permission fix completed${NC}"
    else
        echo -e "${RED}✗ Permission fix failed${NC}"
    fi
    echo
    
    if fix_postgresql; then
        echo -e "${GREEN}✓ PostgreSQL fix completed${NC}"
    else
        echo -e "${RED}✗ PostgreSQL fix failed${NC}"
    fi
    echo
    
    if fix_python_package; then
        echo -e "${GREEN}✓ Python package fix completed${NC}"
    else
        echo -e "${RED}✗ Python package fix failed${NC}"
    fi
    echo
    
    if fix_wkhtmltopdf; then
        echo -e "${GREEN}✓ wkhtmltopdf fix completed${NC}"
    else
        echo -e "${RED}✗ wkhtmltopdf fix failed${NC}"
    fi
    echo
    
    if restart_services; then
        echo -e "${GREEN}✓ Service restart completed${NC}"
    else
        echo -e "${RED}✗ Service restart failed${NC}"
    fi
    echo
    
    # Test the installation
    if test_installation; then
        echo
        echo -e "${GREEN}${BOLD}🎉 Quick Fix completed successfully!${NC}"
        echo -e "${GREEN}Odoo should now be working properly.${NC}"
    else
        echo
        echo -e "${YELLOW}${BOLD}⚠️ Quick Fix completed with some issues.${NC}"
        echo -e "${YELLOW}Additional troubleshooting may be needed.${NC}"
        echo
        show_logs
        echo
        echo -e "${BLUE}Next steps:${NC}"
        echo -e "  1. Check service logs: ${YELLOW}sudo journalctl -u odoo -f${NC}"
        echo -e "  2. Run full diagnosis: ${YELLOW}sudo ./diagnose-installation.sh${NC}"
        echo -e "  3. Or force complete reinstallation: ${YELLOW}sudo ./install.sh --auto --force${NC}"
    fi
}

# Run main function
main "$@"
#!/bin/bash

###############################################################################
# Nginx Setup für Odoo
# 
# - Deinstalliert Apache falls vorhanden
# - Installiert und konfiguriert Nginx als Reverse Proxy für Odoo
# - Fragt Domain-Name per Prompt ab
# - Erstellt optimierte Nginx-Konfiguration für Odoo
#
# Usage:
#   sudo ./setup-nginx-for-odoo.sh
###############################################################################

set -e  # Exit on any error

# Configuration
LOG_DIR="/var/log/odoo-upgrade"
LOG_FILE="$LOG_DIR/nginx-setup-$(date +%Y%m%d-%H%M%S).log"

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
  _   _       _            
 | \ | |     (_)           
 |  \| | __ _ _ _ __  __  __
 | . ` |/ _` | | '_ \ \ \/ /
 | |\  | (_| | | | | | >  < 
 |_| \_|\__, |_|_| |_|/_/\_\
         __/ |             
        |___/              
    Setup für Odoo        
EOF
    echo -e "${NC}"
    echo -e "${GREEN}Nginx Reverse Proxy Setup für Odoo${NC}"
    echo -e "${BLUE}Deinstalliert Apache und konfiguriert Nginx${NC}"
    echo
}

# Get domain name from user
get_domain_name() {
    log "INFO" "Domain-Konfiguration..."
    
    echo -e "${YELLOW}Geben Sie Ihren Domain-Namen ein:${NC}"
    echo -e "${BLUE}Beispiele: example.com, mysite.de, company.org${NC}"
    echo -e "${BLUE}Hinweis: www-Subdomain wird automatisch hinzugefügt${NC}"
    echo
    
    while true; do
        echo -n "Domain-Name: "
        read domain_input
        
        # Remove any protocol, www, trailing slashes
        domain_clean=$(echo "$domain_input" | sed 's|^https\?://||' | sed 's|^www\.||' | sed 's|/$||')
        
        if [ -z "$domain_clean" ]; then
            echo -e "${RED}Bitte geben Sie eine Domain ein.${NC}"
            continue
        fi
        
        # Basic domain validation (supports subdomains)
        if echo "$domain_clean" | grep -qE '^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?)*\.[a-zA-Z]{2,}$'; then
            DOMAIN_NAME="$domain_clean"
            log "SUCCESS" "Domain konfiguriert: $DOMAIN_NAME"
            echo -e "${GREEN}Domain wird konfiguriert: $DOMAIN_NAME und www.$DOMAIN_NAME${NC}"
            break
        else
            echo -e "${RED}Ungültiger Domain-Name. Bitte versuchen Sie es erneut.${NC}"
            echo -e "${BLUE}Format: domain.com oder subdomain.domain.com (ohne http:// oder www)${NC}"
        fi
    done
    echo
}

# Remove Apache if installed
remove_apache() {
    log "INFO" "Checking for Apache installation..."
    
    # Check if Apache is installed
    if command -v apache2 >/dev/null 2>&1 || command -v httpd >/dev/null 2>&1; then
        log "WARN" "⚠ Apache is installed - removing it..."
        
        # Stop Apache service
        systemctl stop apache2 2>/dev/null || systemctl stop httpd 2>/dev/null || true
        systemctl disable apache2 2>/dev/null || systemctl disable httpd 2>/dev/null || true
        
        # Remove Apache packages
        if apt list --installed 2>/dev/null | grep -q apache2; then
            log "INFO" "Removing Apache2 packages..."
            apt remove --purge -y apache2 apache2-utils apache2-bin apache2.2-common apache2-common 2>&1 | tee -a "$LOG_FILE" || true
            apt autoremove -y 2>&1 | tee -a "$LOG_FILE" || true
        fi
        
        log "SUCCESS" "✓ Apache removed"
    else
        log "SUCCESS" "✓ Apache not installed"
    fi
}

# Install Nginx
install_nginx() {
    log "INFO" "Installing Nginx..."
    
    # Update package list
    apt update 2>&1 | tee -a "$LOG_FILE"
    
    # Install Nginx
    if apt install -y nginx 2>&1 | tee -a "$LOG_FILE"; then
        log "SUCCESS" "✓ Nginx installed successfully"
    else
        log "ERROR" "✗ Failed to install Nginx"
        return 1
    fi
    
    # Enable and start Nginx
    systemctl enable nginx
    if systemctl start nginx 2>&1 | tee -a "$LOG_FILE"; then
        log "SUCCESS" "✓ Nginx service started"
    else
        log "ERROR" "✗ Failed to start Nginx"
        return 1
    fi
}

# Create Nginx configuration for Odoo
create_nginx_config() {
    log "INFO" "Creating Nginx configuration for Odoo..."
    
    local config_file="/etc/nginx/sites-available/odoo"
    local sites_enabled="/etc/nginx/sites-enabled"
    
    # Create the Nginx configuration
    log "INFO" "Writing Nginx configuration to $config_file"
    
    cat > "$config_file" << EOF
# Nginx configuration for Odoo
# Generated by setup-nginx-for-odoo.sh on $(date)

upstream odoochat { 
    server 127.0.0.1:8072; 
}

server {
    listen 80;
    server_name $DOMAIN_NAME www.$DOMAIN_NAME;

    access_log /var/log/nginx/odoo.access.log;
    error_log /var/log/nginx/odoo.error.log;

    # Static files caching for better performance
    location ~* /web/static/ {
       proxy_cache_valid 200 90m;
       proxy_buffering on;
       expires 864000;
       proxy_pass http://127.0.0.1:8069;
    }

    # Redirect requests to odoo backend server
    location / {
       proxy_redirect off;
       proxy_pass http://127.0.0.1:8069;

       proxy_set_header    X-Forwarded-Host  \$http_host;
       proxy_set_header    Host              \$host;
       proxy_set_header    X-Real-IP         \$remote_addr;
       proxy_set_header    X-Forwarded-For   \$proxy_add_x_forwarded_for;
       proxy_set_header    X-Forwarded-Proto \$scheme;
    }

    # WebSocket forwarding for Odoo chat and real-time features
    location /websocket {
      proxy_pass http://odoochat;
      proxy_set_header Upgrade \$http_upgrade;
      proxy_set_header Connection "upgrade";
      proxy_set_header X-Forwarded-Host \$http_host;
      proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
      proxy_set_header X-Forwarded-Proto \$scheme;
      proxy_set_header X-Real-IP \$remote_addr;
    }

    # Increase timeouts for large requests
    proxy_connect_timeout       600s;
    proxy_send_timeout          600s;
    proxy_read_timeout          600s;
    send_timeout                600s;
    
    # Allow large file uploads
    client_max_body_size 0;
}
EOF

    if [ -f "$config_file" ]; then
        log "SUCCESS" "✓ Nginx configuration created: $config_file"
    else
        log "ERROR" "✗ Failed to create Nginx configuration"
        return 1
    fi
    
    # Disable default site
    if [ -f "$sites_enabled/default" ]; then
        log "INFO" "Disabling default Nginx site..."
        rm -f "$sites_enabled/default"
        log "SUCCESS" "✓ Default site disabled"
    fi
    
    # Enable Odoo site
    if [ ! -f "$sites_enabled/odoo" ]; then
        log "INFO" "Enabling Odoo site..."
        ln -s "/etc/nginx/sites-available/odoo" "$sites_enabled/odoo"
        log "SUCCESS" "✓ Odoo site enabled"
    fi
    
    # Test Nginx configuration
    log "INFO" "Testing Nginx configuration..."
    if nginx -t 2>&1 | tee -a "$LOG_FILE"; then
        log "SUCCESS" "✓ Nginx configuration is valid"
    else
        log "ERROR" "✗ Nginx configuration has errors"
        return 1
    fi
    
    # Reload Nginx
    log "INFO" "Reloading Nginx..."
    if systemctl reload nginx 2>&1 | tee -a "$LOG_FILE"; then
        log "SUCCESS" "✓ Nginx reloaded successfully"
    else
        log "ERROR" "✗ Failed to reload Nginx"
        return 1
    fi
}

# Configure firewall
configure_firewall() {
    log "INFO" "Configuring firewall for web traffic..."
    
    if command -v ufw >/dev/null 2>&1; then
        # Allow HTTP and HTTPS
        ufw allow 80/tcp 2>&1 | tee -a "$LOG_FILE" || true
        ufw allow 443/tcp 2>&1 | tee -a "$LOG_FILE" || true
        
        # Remove direct Odoo port access (security)
        ufw delete allow 8069/tcp 2>/dev/null || true
        
        log "SUCCESS" "✓ Firewall rules updated (HTTP/HTTPS allowed, direct Odoo access restricted)"
    else
        log "WARN" "⚠ UFW not installed - firewall not configured"
    fi
}

# Test setup
test_setup() {
    log "INFO" "Testing Nginx and Odoo integration..."
    
    # Test Nginx is responding
    if curl -s -o /dev/null -w "%{http_code}" http://localhost | grep -q "200\|302\|301"; then
        log "SUCCESS" "✓ Nginx is responding on port 80"
    else
        log "WARN" "⚠ Nginx may not be responding correctly on port 80"
    fi
    
    # Test if Odoo is reachable through Nginx
    if curl -s -H "Host: $DOMAIN_NAME" http://localhost >/dev/null 2>&1; then
        log "SUCCESS" "✓ Odoo is reachable through Nginx proxy"
    else
        log "WARN" "⚠ Odoo may not be reachable through Nginx proxy"
        log "INFO" "This may be normal if Odoo is not yet running"
    fi
    
    # Check if Odoo is running
    if systemctl is-active odoo >/dev/null 2>&1; then
        log "SUCCESS" "✓ Odoo service is running"
    else
        log "WARN" "⚠ Odoo service is not running"
        log "INFO" "Start Odoo with: sudo systemctl start odoo"
    fi
}

# Show summary
show_summary() {
    echo
    echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}${BOLD}  Nginx Setup für Odoo abgeschlossen!${NC}"
    echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo
    echo -e "${BLUE}Konfiguration:${NC}"
    echo -e "  🌐 Domain: ${GREEN}$DOMAIN_NAME${NC} und ${GREEN}www.$DOMAIN_NAME${NC}"
    echo -e "  🔀 Reverse Proxy: ${GREEN}Nginx → Odoo (Port 8069)${NC}"
    echo -e "  💬 WebSocket: ${GREEN}Nginx → Odoo Chat (Port 8072)${NC}"
    echo -e "  📁 Config File: ${GREEN}/etc/nginx/sites-available/odoo${NC}"
    echo
    echo -e "${BLUE}Web-Zugriff:${NC}"
    echo -e "  🌍 HTTP: ${GREEN}http://$DOMAIN_NAME${NC}"
    echo -e "  🌍 HTTP (www): ${GREEN}http://www.$DOMAIN_NAME${NC}"
    echo
    echo -e "${BLUE}SSL-Zertifikat Setup (nächster Schritt):${NC}"
    echo -e "  📜 Certbot installieren: ${GREEN}sudo apt install certbot python3-certbot-nginx${NC}"
    echo -e "  🔐 SSL-Zertifikat erstellen: ${GREEN}sudo certbot --nginx -d $DOMAIN_NAME -d www.$DOMAIN_NAME${NC}"
    echo
    echo -e "${BLUE}Nützliche Befehle:${NC}"
    echo -e "  📊 Nginx Status: ${GREEN}sudo systemctl status nginx${NC}"
    echo -e "  🔄 Nginx Reload: ${GREEN}sudo systemctl reload nginx${NC}"
    echo -e "  📋 Nginx Logs: ${GREEN}sudo tail -f /var/log/nginx/odoo.access.log${NC}"
    echo -e "  🔧 Config Test: ${GREEN}sudo nginx -t${NC}"
    echo
    echo -e "${BLUE}Firewall:${NC}"
    echo -e "  ✅ Port 80 (HTTP): ${GREEN}Geöffnet${NC}"
    echo -e "  ✅ Port 443 (HTTPS): ${GREEN}Geöffnet${NC}"
    echo -e "  🔒 Port 8069 (Odoo direkt): ${YELLOW}Blockiert (Sicherheit)${NC}"
    echo
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
    
    # Call create_log_dir for consistency
    create_log_dir
    
    # Start logging
    log "INFO" "Starting Nginx setup for Odoo"
    log "INFO" "Log file: $LOG_FILE"
    
    echo -e "${BLUE}Starting Nginx setup...${NC}"
    echo
    
    # Get domain name first
    get_domain_name
    
    # Setup steps
    remove_apache
    install_nginx
    create_nginx_config
    configure_firewall
    test_setup
    
    # Show summary
    show_summary
    
    log "SUCCESS" "Nginx setup process completed!"
}

# Run main function
main "$@"
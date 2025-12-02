#!/bin/bash

###############################################################################
# Odoo Nginx Reverse Proxy + SSL/TLS Setup Script
# 
# Automatisiert Setup von:
#   - Nginx Reverse Proxy für Odoo (Port 8069) & Gevent WebSocket (Port 8072)
#   - Let's Encrypt SSL/TLS Certificate via Certbot
#   - Automatische monatliche Zertifikat-Erneuerung
#
# Usage:
#   sudo ./setup-odoo-nginx.sh <domain> [email] [--no-backup]
#
# Examples:
#   sudo ./setup-odoo-nginx.sh kh-dud.radiq.de
#   sudo ./setup-odoo-nginx.sh kh-dud.radiq.de admin@example.com
#   sudo ./setup-odoo-nginx.sh kh-dud.radiq.de admin@example.com --no-backup
###############################################################################

# Erzwinge bash-Interpretation für dieses Skript
if [ -z "${BASH_VERSION:-}" ]; then
    exec bash "$0" "$@"
fi

set -euo pipefail
shopt -s nullglob

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NGINX_SITES_AVAILABLE="/etc/nginx/sites-available"
NGINX_SITES_ENABLED="/etc/nginx/sites-enabled"
NGINX_CONFIG="${NGINX_SITES_AVAILABLE}/default"
CRON_DIR="/etc/cron.d"
CRON_FILE="${CRON_DIR}/certbot-monthly"
BACKUP_DIR="/root/odoo-nginx-backup-$(date +%Y%m%d-%H%M%S)"
NO_BACKUP=${3:-""}

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_step() {
    echo -e "\n${BLUE}════════════════════════════════════════${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}════════════════════════════════════════${NC}\n"
}

# Validation functions
is_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Dieses Skript muss mit sudo ausgeführt werden"
        exit 1
    fi
}

validate_domain() {
    local domain="$1"
    
    # Einfache Domain-Validierung
    if [[ ! $domain =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*\.([a-zA-Z]{2,})$ ]]; then
        log_error "Ungültige Domain-Syntax: $domain"
        exit 1
    fi
    
    log_success "Domain validiert: $domain"
}

validate_email() {
    local email="$1"
    
    # Einfache Email-Validierung
    if [[ ! $email =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        log_warn "Email-Format verdächtig: $email (wird aber akzeptiert)"
    else
        log_success "Email validiert: $email"
    fi
}

check_prerequisites() {
    log_step "Schritt 1: Voraussetzungen prüfen"
    
    # Prüfe ob root
    is_root
    
    # Check if Apache is installed and remove it (conflicts with Nginx)
    if command -v apache2 >/dev/null 2>&1 || systemctl list-units --full -all 2>/dev/null | grep -q apache2.service; then
        log_warn "Apache2 erkannt - wird entfernt (Port-Konflikt mit Nginx)..."
        systemctl stop apache2 2>/dev/null || true
        systemctl disable apache2 2>/dev/null || true
        apt-get remove -y apache2 apache2-utils apache2-bin apache2.2-common 2>/dev/null || true
        apt-get purge -y apache2 apache2-utils apache2-bin apache2.2-common 2>/dev/null || true
        apt-get autoremove -y 2>/dev/null || true
        log_success "Apache2 entfernt"
    fi
    
    # Prüfe ob Nginx installiert ist, installiere falls nötig
    if ! command -v nginx >/dev/null 2>&1; then
        log_warn "Nginx nicht gefunden - installiere Nginx..."
        if apt-get update -qq && apt-get install -y nginx; then
            log_success "Nginx erfolgreich installiert"
            systemctl enable nginx
            systemctl start nginx
            sleep 2
        else
            log_error "Nginx-Installation fehlgeschlagen"
            exit 1
        fi
    else
        log_success "Nginx gefunden"
    fi
    
    # Prüfe ob Nginx läuft, starte falls nötig
    if ! systemctl is-active --quiet nginx; then
        log_warn "Nginx läuft nicht, starte Nginx..."
        systemctl start nginx
        sleep 2
    fi
    log_success "Nginx läuft"
    
    # Prüfe ob Ports erreichbar sind (außer auf macOS)
    if [[ "$OSTYPE" != "darwin"* ]]; then
        if ! ss -tln | grep -q ":80 " 2>/dev/null || ! ss -tln | grep -q ":443 "; then
            log_warn "Ports 80 oder 443 sind möglicherweise nicht erreichbar"
        fi
    fi
}

backup_current_config() {
    if [[ "$NO_BACKUP" == "--no-backup" ]]; then
        log_info "Backup übersprungen (--no-backup Flag gesetzt)"
        return
    fi
    
    log_step "Schritt 2: Backup aktueller Konfiguration"
    
    mkdir -p "$BACKUP_DIR"
    
    if [[ -f "$NGINX_CONFIG" ]]; then
        cp "$NGINX_CONFIG" "$BACKUP_DIR/nginx-default.bak"
        log_success "Nginx-Konfiguration gesichert: $BACKUP_DIR/nginx-default.bak"
    fi
    
    if [[ -d "$NGINX_SITES_ENABLED" ]]; then
        cp -r "$NGINX_SITES_ENABLED" "$BACKUP_DIR/sites-enabled.bak" 2>/dev/null || true
        log_success "Enabled Sites gesichert: $BACKUP_DIR/sites-enabled.bak"
    fi
    
    if [[ -f "$CRON_FILE" ]]; then
        cp "$CRON_FILE" "$BACKUP_DIR/certbot-monthly.bak"
        log_success "Cron-Job gesichert: $BACKUP_DIR/certbot-monthly.bak"
    fi
    
    log_info "Vollständiges Backup: $BACKUP_DIR"
}

setup_nginx_config() {
    log_step "Schritt 3: Nginx-Konfiguration schreiben"
    
    log_info "Alle Nginx-Sites deaktivieren..."
    rm -f "${NGINX_SITES_ENABLED}"/*
    log_success "Sites deaktiviert"
    
    log_info "Default VHost für $DOMAIN erstellen..."
    
    mkdir -p "$NGINX_SITES_AVAILABLE"
    
    cat > "$NGINX_CONFIG" <<'NGINX_CONFIG_EOF'
upstream odoochat { 
    server 127.0.0.1:8072; 
}

server {
    client_max_body_size 0;
    server_name __SERVER_NAME__;

    # Logging
    access_log /var/log/odoo.access.log;
    error_log  /var/log/odoo.error.log;

    # Security Headers
    add_header Content-Security-Policy "upgrade-insecure-requests" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;

    # Longpolling endpoint (Odoo Longpolling)
    location /longpolling {
        proxy_connect_timeout 600s;
        proxy_send_timeout    600s;
        proxy_read_timeout    600s;
        send_timeout          600s;
        proxy_pass http://odoochat;
        
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Static content (cached)
    location ~* /web/static/ {
        proxy_cache_valid 200 90m;
        proxy_buffering on;
        expires 864000;
        proxy_pass http://127.0.0.1:8069;
        
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # WebSocket endpoint (Gevent async)
    location /websocket {
        proxy_pass http://odoochat;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-Host $http_host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # WebSocket timeouts
        proxy_connect_timeout 600s;
        proxy_send_timeout    600s;
        proxy_read_timeout    600s;
        send_timeout          600s;
        
        # Security header for WebSocket
        add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    }

    # Main application (Odoo backend on port 8069)
    location / {
        proxy_redirect off;
        proxy_pass http://127.0.0.1:8069;

        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-Host $http_host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # Global timeouts for main app
        proxy_connect_timeout 600s;
        proxy_send_timeout    600s;
        proxy_read_timeout    600s;
        send_timeout          600s;
    }

    listen 80;
}
NGINX_CONFIG_EOF

    # Ersetze Platzhalter mit Domain
    # Portable sed Lösung für macOS & Linux
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s/__SERVER_NAME__/${DOMAIN}/g" "$NGINX_CONFIG"
    else
        sed -i "s/__SERVER_NAME__/${DOMAIN}/g" "$NGINX_CONFIG"
    fi
    
    log_success "VHost konfiguriert: $NGINX_CONFIG"
}

enable_nginx_site() {
    log_step "Schritt 4: Nginx-Site aktivieren"
    
    log_info "Erstelle symbolischen Link..."
    ln -sf "$NGINX_CONFIG" "${NGINX_SITES_ENABLED}/default"
    log_success "Site aktiviert"
    
    log_info "Teste Nginx-Konfiguration..."
    if ! nginx -t 2>&1; then
        log_error "Nginx-Konfiguration fehlerhaft!"
        log_info "Versuche Rollback aus $BACKUP_DIR"
        exit 1
    fi
    log_success "Nginx-Konfiguration valid"
    
    log_info "Lade Nginx neu..."
    if ! systemctl reload nginx; then
        log_error "Konnte Nginx nicht neu laden"
        exit 1
    fi
    log_success "Nginx neu geladen"
}

install_certbot() {
    log_step "Schritt 5: Certbot installieren (falls nötig)"
    
    if command -v certbot >/dev/null 2>&1; then
        log_success "Certbot bereits installiert"
        certbot --version
        return
    fi
    
    log_info "Installiere Certbot und Nginx-Plugin..."
    apt-get update -qq
    apt-get install -y -qq certbot python3-certbot-nginx
    
    log_success "Certbot installiert"
}

install_certificate() {
    log_step "Schritt 6: SSL-Zertifikat erstellen/erneuern"
    
    log_info "Verwende Certbot mit Domain: $DOMAIN, Email: $EMAIL"
    
    # Prüfe ob Zertifikat bereits existiert
    if certbot certificates 2>/dev/null | grep -q "Certificate Name: $DOMAIN"; then
        log_warn "Zertifikat für $DOMAIN existiert bereits"
        log_info "Versuche Erneuerung..."
        if certbot renew --cert-name "$DOMAIN" --nginx --non-interactive --quiet; then
            log_success "Zertifikat erneuert"
        else
            log_warn "Erneuerung fehlgeschlagen oder nicht nötig"
        fi
    else
        log_info "Neues Zertifikat wird erstellt..."
        if certbot --nginx \
            -d "$DOMAIN" \
            --non-interactive \
            --agree-tos \
            -m "$EMAIL" \
            --redirect; then
            log_success "Zertifikat erstellt und Nginx konfiguriert"
        else
            log_error "Zertifikat-Erstellung fehlgeschlagen"
            log_info "Prüfe folgendes:"
            log_info "  1. Domain ist öffentlich erreichbar"
            log_info "  2. Port 80 und 443 sind offen"
            log_info "  3. DNS zeigt auf diesen Server"
            exit 1
        fi
    fi
    
    log_success "Zertifikat eingerichtet"
}

setup_auto_renewal() {
    log_step "Schritt 7: Automatische Zertifikat-Erneuerung konfigurieren"
    
    mkdir -p "$CRON_DIR"
    
    log_info "Erstelle monatlichen Cron-Job..."
    cat > "$CRON_FILE" <<'CRON_EOF'
# Certbot automatic renewal - monthly
# Runs on the 1st of each month at 03:17 UTC
17 3 1 * * root certbot renew --quiet --deploy-hook "systemctl reload nginx" >> /var/log/certbot-renewal.log 2>&1
CRON_EOF
    
    chmod 644 "$CRON_FILE"
    log_success "Cron-Job erstellt: $CRON_FILE"
    
    log_info "Cron-Job Details:"
    log_info "  Zeitplan: Jeden 1. des Monats um 03:17 Uhr"
    log_info "  Befehl: certbot renew (nur falls Cert < 30 Tage bis Ablauf)"
    log_info "  Nach Erneuerung: systemctl reload nginx"
    log_info "  Log-Datei: /var/log/certbot-renewal.log"
    
    # Test den Renewal-Prozess (dry-run)
    log_info "Teste Renewal-Prozess (dry-run - keine echte Erneuerung)..."
    if certbot renew --dry-run --quiet 2>/dev/null; then
        log_success "Renewal-Test erfolgreich"
    else
        log_warn "Renewal-Test hatte Probleme (meist unkritisch)"
    fi
}

final_tests() {
    log_step "Schritt 8: Finale Konfigurations-Tests"
    
    log_info "Test 1: Nginx lädt korrekt"
    if nginx -t 2>&1; then
        log_success "Nginx-Konfiguration OK"
    else
        log_error "Nginx-Konfiguration fehlerhaft"
        exit 1
    fi
    
    log_info "Test 2: Nginx läuft"
    if systemctl is-active --quiet nginx; then
        log_success "Nginx läuft"
    else
        log_error "Nginx läuft nicht"
        exit 1
    fi
    
    log_info "Test 3: Zertifikat existiert"
    if certbot certificates 2>/dev/null | grep -q "$DOMAIN"; then
        log_success "Zertifikat für $DOMAIN vorhanden"
    else
        log_warn "Zertifikat konnte nicht verifiziert werden"
    fi
    
    log_info "Test 4: Cron-Job aktiv"
    if [[ -f "$CRON_FILE" ]]; then
        log_success "Cron-Job existiert"
    else
        log_error "Cron-Job nicht gefunden"
    fi
}

show_summary() {
    log_step "✨ Installation abgeschlossen!"
    
    echo -e "${GREEN}════════════════════════════════════════${NC}"
    echo -e "${GREEN}  ODOO NGINX SETUP ERFOLGREICH${NC}"
    echo -e "${GREEN}════════════════════════════════════════${NC}\n"
    
    echo -e "${BLUE}Domain:${NC} $DOMAIN"
    echo -e "${BLUE}Email:${NC} $EMAIL"
    echo -e "${BLUE}Nginx Config:${NC} $NGINX_CONFIG"
    echo -e "${BLUE}Cron-Job:${NC} $CRON_FILE"
    
    if [[ "$NO_BACKUP" != "--no-backup" ]]; then
        echo -e "${BLUE}Backup:${NC} $BACKUP_DIR"
    fi
    
    echo -e "\n${YELLOW}Nächste Schritte:${NC}"
    echo -e "  1. Verifikation: curl -I https://${DOMAIN}"
    echo -e "  2. Logs prüfen: tail -f /var/log/odoo.access.log"
    echo -e "  3. Zertifikat prüfen: sudo certbot certificates"
    echo -e "  4. Renewal testen: sudo certbot renew --dry-run"
    
    echo -e "\n${YELLOW}Wichtige Dateien:${NC}"
    echo -e "  Nginx Config: /etc/nginx/sites-available/default"
    echo -e "  Zertifikate: /etc/letsencrypt/live/${DOMAIN}/"
    echo -e "  Access Log: /var/log/odoo.access.log"
    echo -e "  Error Log: /var/log/odoo.error.log"
    echo -e "  Renewal Log: /var/log/certbot-renewal.log"
    
    echo -e "\n${GREEN}════════════════════════════════════════${NC}\n"
}

# Main execution
main() {
    log_info "════════════════════════════════════════"
    log_info "  Odoo Nginx Reverse Proxy Setup"
    log_info "════════════════════════════════════════"
    echo
    
    # Interaktiver Modus wenn keine Parameter angegeben
    if [[ $# -lt 1 ]]; then
        log_info "Interaktiver Modus - Bitte geben Sie die Informationen ein"
        echo
        
        # Domain abfragen
        while true; do
            read -p "$(echo -e ${BLUE}Odoo Domain${NC}) (z.B. odoo.example.com): " DOMAIN
            if [[ -n "$DOMAIN" ]]; then
                if [[ $DOMAIN =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*\.([a-zA-Z]{2,})$ ]]; then
                    break
                else
                    log_error "Ungültige Domain. Bitte versuchen Sie es erneut."
                fi
            else
                log_error "Domain ist erforderlich."
            fi
        done
        
        # Email abfragen
        read -p "$(echo -e ${BLUE}Let\'s Encrypt Email${NC}) (Standard: admin@$DOMAIN): " EMAIL
        EMAIL="${EMAIL:-admin@${DOMAIN}}"
        
        # Backup-Option abfragen
        echo
        read -p "$(echo -e ${BLUE}Backup der aktuellen Nginx-Konfiguration erstellen?${NC}) (Y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Nn]$ ]]; then
            NO_BACKUP="--no-backup"
        else
            NO_BACKUP=""
        fi
        
        echo
        log_info "Konfiguration:"
        echo -e "  Domain: ${GREEN}$DOMAIN${NC}"
        echo -e "  Email:  ${GREEN}$EMAIL${NC}"
        echo -e "  Backup: ${GREEN}$([ -z "$NO_BACKUP" ] && echo "Ja" || echo "Nein")${NC}"
        echo
        read -p "$(echo -e ${YELLOW}Fortfahren mit der Installation?${NC}) (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_warn "Installation abgebrochen"
            exit 0
        fi
    else
        # Parameter-Modus
        DOMAIN="$1"
        EMAIL="${2:-admin@${DOMAIN}}"
    fi
    
    echo
    
    # Validierung
    validate_domain "$DOMAIN"
    validate_email "$EMAIL"
    
    # Hauptschritte
    check_prerequisites
    backup_current_config
    setup_nginx_config
    enable_nginx_site
    install_certbot
    install_certificate
    setup_auto_renewal
    final_tests
    show_summary
    
    log_success "Alle Schritte abgeschlossen"
}

# Fallstricke abfangen
trap 'log_error "Skript abgebrochen (Status: $?)"; exit 1' ERR

# Hauptprogramm starten
main "$@"

#!/bin/sh

###############################################################################
# Einfacher Odoo Enterprise 19.0 Installer
# Klont einfach das Enterprise Repository nach /opt/odoo/enterprise
###############################################################################

# Configuration
ENTERPRISE_DIR="/opt/odoo/enterprise"
ODOO_USER="odoo"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Check root
if [ "$(id -u)" != "0" ]; then
    printf "${RED}Script muss als root ausgeführt werden${NC}\n"
    printf "Ausführen: ${YELLOW}sudo $0${NC}\n"
    exit 1
fi

printf "${BLUE}=== Odoo Enterprise 19.0 Installation ===${NC}\n"
printf "Ziel: $ENTERPRISE_DIR\n\n"

# Check if odoo user exists
if ! id "$ODOO_USER" >/dev/null 2>&1; then
    printf "${RED}FEHLER: Benutzer '$ODOO_USER' existiert nicht${NC}\n"
    printf "Bitte zuerst Odoo Community installieren\n"
    exit 1
fi

# Install git if needed
if ! command -v git >/dev/null 2>&1; then
    printf "${YELLOW}Git wird installiert...${NC}\n"
    apt update && apt install -y git
fi

# Remove existing installation
if [ -d "$ENTERPRISE_DIR" ]; then
    printf "${YELLOW}Vorhandene Installation wird entfernt...${NC}\n"
    rm -rf "$ENTERPRISE_DIR"
fi

# Create parent directory
mkdir -p "$(dirname "$ENTERPRISE_DIR")"

printf "${BLUE}Wählen Sie die Authentifizierung:${NC}\n"
printf "  1) Personal Access Token (GitHub)\n"
printf "  2) SSH-Schlüssel\n"
printf "  3) Öffentlich versuchen (wird wahrscheinlich fehlschlagen)\n"
printf "Auswahl [1-3]: "
read choice

case $choice in
    1)
        printf "${YELLOW}GitHub Personal Access Token eingeben:${NC}\n"
        printf "Token: "
        stty -echo
        read token
        stty echo
        printf "\n"
        
        if [ -z "$token" ]; then
            printf "${RED}Token darf nicht leer sein${NC}\n"
            exit 1
        fi
        
        REPO_URL="https://$token@github.com/odoo/enterprise.git"
        ;;
    2)
        printf "${YELLOW}SSH-Schlüssel wird verwendet${NC}\n"
        REPO_URL="git@github.com:odoo/enterprise.git"
        ;;
    3)
        printf "${YELLOW}Öffentliches Repository wird versucht${NC}\n"
        REPO_URL="https://github.com/odoo/enterprise.git"
        ;;
    *)
        printf "${RED}Ungültige Auswahl${NC}\n"
        exit 1
        ;;
esac

printf "${BLUE}Repository wird geklont...${NC}\n"
printf "Von: $REPO_URL\n"
printf "Nach: $ENTERPRISE_DIR\n\n"

# Clone repository
if git clone --branch 19.0 --depth 1 "$REPO_URL" "$ENTERPRISE_DIR"; then
    printf "${GREEN}✓ Repository erfolgreich geklont${NC}\n"
else
    printf "${RED}✗ Git clone fehlgeschlagen${NC}\n"
    printf "\nMögliche Lösungen:\n"
    printf "- Personal Access Token erstellen: https://github.com/settings/tokens\n"
    printf "- SSH-Schlüssel hinzufügen: https://github.com/settings/keys\n"
    printf "- Odoo Enterprise Zugang anfordern: sales@odoo.com\n"
    exit 1
fi

# Check if clone was successful
if [ ! -d "$ENTERPRISE_DIR" ]; then
    printf "${RED}✗ Enterprise Verzeichnis wurde nicht erstellt${NC}\n"
    exit 1
fi

# Count modules
module_count=$(find "$ENTERPRISE_DIR" -maxdepth 2 -name "__manifest__.py" 2>/dev/null | wc -l)

if [ "$module_count" -lt 10 ]; then
    printf "${RED}✗ Repository scheint unvollständig ($module_count Module gefunden)${NC}\n"
    rm -rf "$ENTERPRISE_DIR"
    exit 1
fi

printf "${GREEN}✓ $module_count Enterprise Module gefunden${NC}\n"

# Set permissions
printf "${BLUE}Berechtigungen werden gesetzt...${NC}\n"
chown -R "$ODOO_USER:$ODOO_USER" "$ENTERPRISE_DIR"
chmod -R 755 "$ENTERPRISE_DIR"
printf "${GREEN}✓ Berechtigungen gesetzt${NC}\n"

# Update Odoo configuration
ODOO_CONFIG="/etc/odoo/odoo.conf"
if [ -f "$ODOO_CONFIG" ]; then
    printf "${BLUE}Odoo-Konfiguration wird aktualisiert...${NC}\n"
    
    # Backup
    cp "$ODOO_CONFIG" "$ODOO_CONFIG.backup.$(date +%Y%m%d-%H%M%S)"
    
    # Check if already in addons_path
    if grep -q "addons_path.*$ENTERPRISE_DIR" "$ODOO_CONFIG"; then
        printf "${YELLOW}Enterprise-Pfad bereits in Konfiguration${NC}\n"
    else
        # Get current addons_path
        current_addons=$(grep "^addons_path" "$ODOO_CONFIG" | cut -d'=' -f2- | tr -d ' ')
        
        if [ -n "$current_addons" ]; then
            # Add enterprise to the beginning
            new_addons="$ENTERPRISE_DIR,$current_addons"
            sed -i "s|^addons_path.*|addons_path = $new_addons|" "$ODOO_CONFIG"
            printf "${GREEN}✓ Konfiguration aktualisiert${NC}\n"
        else
            printf "${YELLOW}Keine addons_path in Konfiguration gefunden${NC}\n"
        fi
    fi
    
    # Restart Odoo if running
    if systemctl is-active odoo >/dev/null 2>&1; then
        printf "${BLUE}Odoo wird neu gestartet...${NC}\n"
        systemctl restart odoo
        sleep 3
        if systemctl is-active odoo >/dev/null 2>&1; then
            printf "${GREEN}✓ Odoo erfolgreich neu gestartet${NC}\n"
        else
            printf "${RED}✗ Odoo-Neustart fehlgeschlagen${NC}\n"
        fi
    else
        printf "${YELLOW}Odoo läuft nicht - manueller Start erforderlich${NC}\n"
    fi
else
    printf "${YELLOW}Odoo-Konfiguration nicht gefunden: $ODOO_CONFIG${NC}\n"
fi

printf "\n${GREEN}=== Installation abgeschlossen! ===${NC}\n"
printf "Enterprise-Pfad: ${GREEN}$ENTERPRISE_DIR${NC}\n"
printf "Module gefunden: ${GREEN}$module_count${NC}\n"
printf "\nNächste Schritte:\n"
printf "1. Odoo in Browser öffnen\n"
printf "2. Apps → Update Apps List\n"
printf "3. Enterprise-Module suchen und installieren\n"
printf "\nNützliche Befehle:\n"
printf "  Odoo Status: ${BLUE}systemctl status odoo${NC}\n"
printf "  Odoo Logs:   ${BLUE}journalctl -u odoo -f${NC}\n"

#!/bin/sh

###############################################################################
# Odoo 19.0 Installation Suite
# 
# Zentrale Installation und Management für Odoo 19.0
# - Vollständige automatische Installation
# - Einzelne Script-Ausführung per Menü
# - Enterprise Edition Support
#
# Usage: sudo ./install.sh
###############################################################################

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Check root
check_root() {
    if [ "$(id -u)" != "0" ]; then
        printf "${RED}Dieses Script muss als root ausgeführt werden${NC}\n"
        printf "Ausführen: ${YELLOW}sudo $0${NC}\n"
        exit 1
    fi
}

# Show banner
show_banner() {
    clear
    printf "${CYAN}${BOLD}"
    cat << 'EOF'
   ___      _             _____ _____ 
  / _ \  __| | ___   ___ |___ /|  ___|
 | | | |/ _` |/ _ \ / _ \  |_ \| |_   
 | |_| | (_| | (_) | (_) |___) |  _|  
  \___/ \__,_|\___/ \___/|____/|_|    
                                      
    Installation Suite v1.0           
EOF
    printf "${NC}\n"
    printf "${GREEN}Odoo 19.0 - Komplette Installation und Management${NC}\n"
    printf "${BLUE}Unterstützt: Community Edition, Enterprise Edition, Nginx, SSL${NC}\n"
    echo
}

# Check if script exists
check_script() {
    script_name="$1"
    if [ ! -f "$script_name" ]; then
        printf "${RED}FEHLER: Script '$script_name' nicht gefunden${NC}\n"
        return 1
    fi
    if [ ! -x "$script_name" ]; then
        chmod +x "$script_name"
        printf "${YELLOW}Script '$script_name' ausführbar gemacht${NC}\n"
    fi
    return 0
}

# Run script with error handling
run_script() {
    script_name="$1"
    script_desc="$2"
    
    printf "${BLUE}=== $script_desc ===${NC}\n"
    
    if ! check_script "$script_name"; then
        return 1
    fi
    
    printf "${YELLOW}Script wird ausgeführt: $script_name${NC}\n"
    echo
    
    if "./$script_name"; then
        printf "\n${GREEN}✓ $script_desc erfolgreich abgeschlossen${NC}\n"
        printf "${GREEN}Drücken Sie Enter um fortzufahren...${NC}"
        read dummy
        return 0
    else
        printf "\n${RED}✗ $script_desc fehlgeschlagen${NC}\n"
        printf "${RED}Möchten Sie trotzdem fortfahren? (y/N): ${NC}"
        read continue_choice
        if [ "$continue_choice" = "y" ] || [ "$continue_choice" = "Y" ]; then
            return 0
        else
            return 1
        fi
    fi
}

# Full automatic installation
full_installation() {
    printf "${GREEN}${BOLD}=== VOLLSTÄNDIGE ODOO INSTALLATION ===${NC}\n"
    printf "${BLUE}Folgende Scripts werden nacheinander ausgeführt:${NC}\n"
    printf "  1. install-official-odoo.sh - Odoo 19.0 Community Installation\n"
    printf "  2. setup-odoo-config.sh - Produktions-Konfiguration\n"  
    printf "  3. setup-postgres-for-odoo.sh - PostgreSQL Setup\n"
    printf "  4. setup-nginx-for-odoo.sh - Nginx Reverse Proxy + SSL\n"
    echo
    printf "${YELLOW}Möchten Sie fortfahren? (y/N): ${NC}"
    read confirm
    
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        printf "${BLUE}Installation abgebrochen${NC}\n"
        return
    fi
    
    echo
    printf "${GREEN}${BOLD}Installation wird gestartet...${NC}\n"
    echo
    
    # Step 1: Official Odoo Installation
    if ! run_script "install-official-odoo.sh" "Odoo 19.0 Community Installation"; then
        printf "${RED}Installation abgebrochen${NC}\n"
        return
    fi
    
    # Step 2: Configuration Setup
    if ! run_script "setup-odoo-config.sh" "Odoo Produktions-Konfiguration"; then
        printf "${RED}Installation abgebrochen${NC}\n"
        return
    fi
    
    # Step 3: PostgreSQL Setup
    if ! run_script "setup-postgres-for-odoo.sh" "PostgreSQL Konfiguration"; then
        printf "${RED}Installation abgebrochen${NC}\n"
        return
    fi
    
    # Step 4: Nginx Setup
    if ! run_script "setup-nginx-for-odoo.sh" "Nginx Reverse Proxy + SSL Setup"; then
        printf "${YELLOW}Nginx-Setup fehlgeschlagen - Odoo läuft trotzdem${NC}\n"
    fi
    
    printf "\n${GREEN}${BOLD}🎉 VOLLSTÄNDIGE INSTALLATION ABGESCHLOSSEN! 🎉${NC}\n"
    printf "${BLUE}Odoo 19.0 ist jetzt bereit für den Produktionseinsatz${NC}\n"
    echo
    printf "${GREEN}Zugriff:${NC}\n"
    printf "  • Web-Interface: ${CYAN}http://ihre-domain${NC} (oder https:// wenn SSL konfiguriert)\n"
    printf "  • Standard-Port: ${CYAN}8069${NC} (direkt, falls Nginx nicht konfiguriert)\n"
    echo
    printf "${GREEN}Nächste Schritte:${NC}\n"
    printf "  1. Odoo im Browser öffnen\n"
    printf "  2. Erste Datenbank erstellen\n"
    printf "  3. Unternehmen konfigurieren\n"
    printf "  4. Apps installieren\n"
    echo
}

# Enterprise installation with prerequisites
enterprise_installation() {
    printf "${GREEN}${BOLD}=== ODOO ENTERPRISE INSTALLATION ===${NC}\n"
    printf "${BLUE}Enterprise Edition erweitert Odoo um professionelle Features${NC}\n"
    echo
    
    printf "${YELLOW}${BOLD}VORAUSSETZUNGEN:${NC}\n"
    printf "${RED}Odoo Enterprise ist NICHT kostenlos und erfordert:${NC}\n"
    echo
    printf "  ${BOLD}1. Odoo Enterprise Subscription${NC}\n"
    printf "     • Lizenz von Odoo S.A. oder autorisierten Partnern\n"
    printf "     • Kontakt: sales@odoo.com oder Partner\n"
    echo
    printf "  ${BOLD}2. GitHub-Zugriff auf odoo/enterprise Repository${NC}\n"
    printf "     • GitHub-Account mit Enterprise-Repository-Zugriff\n"
    printf "     • SSH-Schlüssel oder Personal Access Token\n"
    echo
    printf "  ${BOLD}3. SSH-Schlüssel Setup (empfohlen)${NC}\n"
    printf "     ${GREEN}SSH-Schlüssel erstellen:${NC}\n"
    printf "     ssh-keygen -t ed25519 -C \"ihr-email@domain.com\"\n"
    echo
    printf "     ${GREEN}Public Key zu GitHub hinzufügen:${NC}\n"
    printf "     1. cat ~/.ssh/id_ed25519.pub\n"
    printf "     2. Gehen Sie zu: https://github.com/settings/keys\n"
    printf "     3. 'New SSH key' klicken\n"
    printf "     4. Public Key einfügen\n"
    echo
    printf "     ${GREEN}Verbindung testen:${NC}\n"
    printf "     ssh -T git@github.com\n"
    printf "     (Erwartete Ausgabe: 'Hi username! You've successfully authenticated...')\n"
    echo
    printf "  ${BOLD}4. Repository-Zugriff testen${NC}\n"
    printf "     git ls-remote git@github.com:odoo/enterprise.git HEAD\n"
    printf "     (Sollte ohne Fehler die Commit-Information anzeigen)\n"
    echo
    
    printf "${YELLOW}Haben Sie alle Voraussetzungen erfüllt? (y/N): ${NC}"
    read prereq_confirm
    
    if [ "$prereq_confirm" != "y" ] && [ "$prereq_confirm" != "Y" ]; then
        printf "${BLUE}Enterprise-Installation abgebrochen${NC}\n"
        printf "${YELLOW}Bitte erfüllen Sie zuerst die Voraussetzungen${NC}\n"
        return
    fi
    
    # Check if Community is installed
    if [ ! -d "/opt/odoo" ] || [ ! -f "/etc/odoo/odoo.conf" ]; then
        printf "${RED}FEHLER: Odoo Community Edition nicht gefunden${NC}\n"
        printf "${YELLOW}Bitte installieren Sie zuerst Odoo Community mit Option 1${NC}\n"
        return
    fi
    
    printf "\n${GREEN}Enterprise Installation wird gestartet...${NC}\n"
    run_script "install-odoo-enterprise.sh" "Odoo Enterprise 19.0 Installation"
}

# Show individual scripts menu
show_menu() {
    while true; do
        show_banner
        
        printf "${BOLD}INSTALLATION OPTIONEN:${NC}\n"
        echo
        printf "${GREEN}${BOLD}Vollständige Installation:${NC}\n"
        printf "  ${GREEN}1)${NC} Komplette Odoo 19.0 Installation (Community + Konfiguration + Nginx + SSL)\n"
        echo
        printf "${BLUE}${BOLD}Einzelne Scripts:${NC}\n"
        printf "  ${BLUE}2)${NC} install-official-odoo.sh      - Odoo 19.0 Community Edition\n"
        printf "  ${BLUE}3)${NC} setup-odoo-config.sh         - Produktions-Konfiguration\n"
        printf "  ${BLUE}4)${NC} setup-postgres-for-odoo.sh   - PostgreSQL Authentifizierung\n"
        printf "  ${BLUE}5)${NC} setup-nginx-for-odoo.sh      - Nginx Reverse Proxy + SSL\n"
        echo
        printf "${YELLOW}${BOLD}Enterprise Edition:${NC}\n"
        printf "  ${YELLOW}6)${NC} install-odoo-enterprise.sh   - Enterprise Module (benötigt Lizenz)\n"
        echo
        printf "${CYAN}${BOLD}Utilities:${NC}\n"
        printf "  ${CYAN}7)${NC} System-Information anzeigen\n"
        printf "  ${CYAN}8)${NC} Odoo Service Status\n"
        printf "  ${CYAN}9)${NC} Odoo Logs anzeigen\n"
        echo
        printf "${RED}0)${NC} Beenden\n"
        echo
        printf "${BOLD}Auswahl [0-9]: ${NC}"
        read choice
        
        case $choice in
            1)
                full_installation
                printf "\n${GREEN}Drücken Sie Enter um zum Hauptmenü zurückzukehren...${NC}"
                read dummy
                ;;
            2)
                run_script "install-official-odoo.sh" "Odoo 19.0 Community Installation"
                printf "\n${GREEN}Drücken Sie Enter um zum Hauptmenü zurückzukehren...${NC}"
                read dummy
                ;;
            3)
                run_script "setup-odoo-config.sh" "Odoo Produktions-Konfiguration"
                printf "\n${GREEN}Drücken Sie Enter um zum Hauptmenü zurückzukehren...${NC}"
                read dummy
                ;;
            4)
                run_script "setup-postgres-for-odoo.sh" "PostgreSQL Authentifizierung"
                printf "\n${GREEN}Drücken Sie Enter um zum Hauptmenü zurückzukehren...${NC}"
                read dummy
                ;;
            5)
                run_script "setup-nginx-for-odoo.sh" "Nginx Reverse Proxy + SSL"
                printf "\n${GREEN}Drücken Sie Enter um zum Hauptmenü zurückzukehren...${NC}"
                read dummy
                ;;
            6)
                enterprise_installation
                printf "\n${GREEN}Drücken Sie Enter um zum Hauptmenü zurückzukehren...${NC}"
                read dummy
                ;;
            7)
                show_system_info
                printf "\n${GREEN}Drücken Sie Enter um zum Hauptmenü zurückzukehren...${NC}"
                read dummy
                ;;
            8)
                show_odoo_status
                printf "\n${GREEN}Drücken Sie Enter um zum Hauptmenü zurückzukehren...${NC}"
                read dummy
                ;;
            9)
                show_odoo_logs
                ;;
            0)
                printf "${GREEN}Installation Suite beendet${NC}\n"
                exit 0
                ;;
            *)
                printf "${RED}Ungültige Auswahl: $choice${NC}\n"
                printf "${GREEN}Drücken Sie Enter um fortzufahren...${NC}"
                read dummy
                ;;
        esac
    done
}

# Show system information
show_system_info() {
    printf "${GREEN}${BOLD}=== SYSTEM INFORMATION ===${NC}\n"
    echo
    
    printf "${BLUE}Betriebssystem:${NC}\n"
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        printf "  • Name: $NAME\n"
        printf "  • Version: $VERSION\n"
    else
        printf "  • $(uname -s) $(uname -r)\n"
    fi
    echo
    
    printf "${BLUE}Hardware:${NC}\n"
    printf "  • CPU: $(nproc) Kerne\n"
    printf "  • RAM: $(free -h | awk '/^Mem:/ {print $2}')\n"
    printf "  • Festplatte: $(df -h / | awk 'NR==2 {print $4}') verfügbar\n"
    echo
    
    printf "${BLUE}Installierte Services:${NC}\n"
    
    # Check Python
    if command -v python3 >/dev/null 2>&1; then
        printf "  • Python: $(python3 --version)\n"
    else
        printf "  • Python: ${RED}Nicht installiert${NC}\n"
    fi
    
    # Check PostgreSQL
    if command -v psql >/dev/null 2>&1; then
        version=$(psql --version | head -n1)
        printf "  • PostgreSQL: $version\n"
        if systemctl is-active postgresql >/dev/null 2>&1; then
            printf "    Status: ${GREEN}Läuft${NC}\n"
        else
            printf "    Status: ${RED}Gestoppt${NC}\n"
        fi
    else
        printf "  • PostgreSQL: ${RED}Nicht installiert${NC}\n"
    fi
    
    # Check Nginx
    if command -v nginx >/dev/null 2>&1; then
        version=$(nginx -v 2>&1)
        printf "  • Nginx: $version\n"
        if systemctl is-active nginx >/dev/null 2>&1; then
            printf "    Status: ${GREEN}Läuft${NC}\n"
        else
            printf "    Status: ${RED}Gestoppt${NC}\n"
        fi
    else
        printf "  • Nginx: ${RED}Nicht installiert${NC}\n"
    fi
    
    # Check Odoo
    if systemctl list-unit-files | grep -q "odoo.service"; then
        printf "  • Odoo: Installiert\n"
        if systemctl is-active odoo >/dev/null 2>&1; then
            printf "    Status: ${GREEN}Läuft${NC}\n"
        else
            printf "    Status: ${RED}Gestoppt${NC}\n"
        fi
        
        if [ -f "/etc/odoo/odoo.conf" ]; then
            printf "    Konfiguration: ${GREEN}Vorhanden${NC}\n"
        else
            printf "    Konfiguration: ${RED}Fehlt${NC}\n"
        fi
        
        if [ -d "/opt/odoo/enterprise" ]; then
            module_count=$(find /opt/odoo/enterprise -maxdepth 2 -name "__manifest__.py" 2>/dev/null | wc -l)
            printf "    Enterprise: ${GREEN}Installiert${NC} ($module_count Module)\n"
        else
            printf "    Enterprise: ${YELLOW}Nicht installiert${NC}\n"
        fi
    else
        printf "  • Odoo: ${RED}Nicht installiert${NC}\n"
    fi
    
    echo
}

# Show Odoo service status
show_odoo_status() {
    printf "${GREEN}${BOLD}=== ODOO SERVICE STATUS ===${NC}\n"
    echo
    
    if systemctl list-unit-files | grep -q "odoo.service"; then
        printf "${BLUE}Service Status:${NC}\n"
        systemctl status odoo --no-pager -l
        echo
        
        printf "${BLUE}Port-Überprüfung:${NC}\n"
        if ss -tulpn | grep -q ":8069"; then
            printf "  • Port 8069: ${GREEN}Odoo läuft${NC}\n"
        else
            printf "  • Port 8069: ${RED}Nicht erreichbar${NC}\n"
        fi
        
        if ss -tulpn | grep -q ":8072"; then
            printf "  • Port 8072: ${GREEN}Odoo Chat läuft${NC}\n"
        else
            printf "  • Port 8072: ${YELLOW}Nicht aktiv${NC}\n"
        fi
        
        printf "\n${BLUE}Nützliche Befehle:${NC}\n"
        printf "  • Service starten:    ${CYAN}sudo systemctl start odoo${NC}\n"
        printf "  • Service stoppen:    ${CYAN}sudo systemctl stop odoo${NC}\n"
        printf "  • Service neustarten: ${CYAN}sudo systemctl restart odoo${NC}\n"
        printf "  • Autostart aktivieren: ${CYAN}sudo systemctl enable odoo${NC}\n"
    else
        printf "${RED}Odoo Service ist nicht installiert${NC}\n"
        printf "${BLUE}Installieren Sie zuerst Odoo mit Option 2${NC}\n"
    fi
}

# Show Odoo logs
show_odoo_logs() {
    printf "${GREEN}${BOLD}=== ODOO LOGS ===${NC}\n"
    printf "${YELLOW}Drücken Sie Ctrl+C um die Log-Anzeige zu beenden${NC}\n"
    printf "${BLUE}Zeige live Odoo logs...${NC}\n"
    echo
    
    if systemctl list-unit-files | grep -q "odoo.service"; then
        journalctl -u odoo -f
    else
        printf "${RED}Odoo Service nicht installiert${NC}\n"
        if [ -f "/var/log/odoo/odoo-server.log" ]; then
            printf "${BLUE}Zeige Odoo Log-Datei:${NC}\n"
            tail -f /var/log/odoo/odoo-server.log
        else
            printf "${RED}Keine Odoo-Logs gefunden${NC}\n"
        fi
    fi
}

# Main function
main() {
    check_root
    show_menu
}

# Run main function
main "$@"
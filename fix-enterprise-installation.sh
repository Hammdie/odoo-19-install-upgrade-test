#!/bin/bash

###############################################################################
# Fix Enterprise Installation Script
# 
# Repariert fehlgeschlagene Enterprise-Installation
# - Entfernt Enterprise aus addons_path wenn nicht installiert
# - Bietet Neuinstallation an
###############################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Configuration
ODOO_CONFIG="/etc/odoo/odoo.conf"
ENTERPRISE_PATH="/opt/odoo/enterprise"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${BLUE}${BOLD}"
echo "╔════════════════════════════════════════════════════════════╗"
echo "║          Enterprise Installation Repair Tool              ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}This script must be run as root or with sudo${NC}"
    exit 1
fi

# Check current status
echo -e "${CYAN}${BOLD}🔍 Checking Enterprise Installation Status...${NC}"
echo

ENTERPRISE_EXISTS=false
ENTERPRISE_IN_CONFIG=false

# Check if Enterprise directory exists
if [[ -d "$ENTERPRISE_PATH" ]]; then
    ENTERPRISE_EXISTS=true
    echo -e "${GREEN}✓${NC} Enterprise directory exists: $ENTERPRISE_PATH"
    
    # Check if it's a git repository
    if [[ -d "$ENTERPRISE_PATH/.git" ]]; then
        echo -e "${GREEN}✓${NC} Valid Git repository"
    else
        echo -e "${YELLOW}⚠${NC} Directory exists but is not a Git repository"
        ENTERPRISE_EXISTS=false
    fi
else
    echo -e "${RED}✗${NC} Enterprise directory not found: $ENTERPRISE_PATH"
fi

# Check if Enterprise is in config
if [[ -f "$ODOO_CONFIG" ]]; then
    if grep -q "addons_path.*enterprise" "$ODOO_CONFIG"; then
        ENTERPRISE_IN_CONFIG=true
        echo -e "${GREEN}✓${NC} Enterprise is referenced in config"
    else
        echo -e "${CYAN}ℹ${NC}  Enterprise is not in addons_path"
    fi
else
    echo -e "${RED}✗${NC} Odoo config not found: $ODOO_CONFIG"
    exit 1
fi

echo

# Determine action needed
if [[ "$ENTERPRISE_EXISTS" == false ]] && [[ "$ENTERPRISE_IN_CONFIG" == true ]]; then
    echo -e "${YELLOW}${BOLD}⚠ Problem detected:${NC}"
    echo -e "${YELLOW}Enterprise is referenced in config but not installed!${NC}"
    echo
    echo -e "This can cause Odoo to fail to start or show errors."
    echo
    echo -e "${BOLD}Options:${NC}"
    echo -e "  ${GREEN}1)${NC} Remove Enterprise from config (recommended if not using Enterprise)"
    echo -e "  ${GREEN}2)${NC} Install Enterprise edition (requires GitHub SSH access)"
    echo -e "  ${RED}0)${NC} Cancel"
    echo
    
    read -p "Enter your choice [0-2]: " choice
    
    case $choice in
        1)
            echo
            echo -e "${CYAN}Removing Enterprise from addons_path...${NC}"
            
            # Backup config
            cp "$ODOO_CONFIG" "${ODOO_CONFIG}.backup.$(date +%Y%m%d-%H%M%S)"
            echo -e "${GREEN}✓${NC} Config backed up"
            
            # Remove /opt/odoo/enterprise from addons_path
            sed -i 's|,/opt/odoo/enterprise||g' "$ODOO_CONFIG"
            sed -i 's|/opt/odoo/enterprise,||g' "$ODOO_CONFIG"
            sed -i 's|/opt/odoo/enterprise||g' "$ODOO_CONFIG"
            
            echo -e "${GREEN}✓${NC} Enterprise removed from config"
            
            # Restart Odoo
            echo
            read -p "Restart Odoo service now? (Y/n): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Nn]$ ]]; then
                systemctl restart odoo
                echo -e "${GREEN}✓${NC} Odoo service restarted"
            fi
            
            echo
            echo -e "${GREEN}${BOLD}✓ Repair completed!${NC}"
            echo -e "Enterprise has been removed from the configuration."
            ;;
        2)
            echo
            echo -e "${CYAN}Starting Enterprise installation...${NC}"
            
            if [[ -f "$SCRIPT_DIR/scripts/install-enterprise.sh" ]]; then
                bash "$SCRIPT_DIR/scripts/install-enterprise.sh"
            else
                echo -e "${RED}Error: install-enterprise.sh not found${NC}"
                echo
                echo -e "${YELLOW}Manual installation steps:${NC}"
                echo -e "1. Generate SSH key:"
                echo -e "   ${GREEN}sudo -u odoo ssh-keygen -t ed25519 -C \"odoo@\$(hostname)\"${NC}"
                echo
                echo -e "2. Add public key to GitHub:"
                echo -e "   ${GREEN}sudo cat /var/lib/odoo/.ssh/id_ed25519.pub${NC}"
                echo -e "   Add to: ${BLUE}https://github.com/settings/keys${NC}"
                echo
                echo -e "3. Clone Enterprise:"
                echo -e "   ${GREEN}sudo -u odoo git clone --depth 1 --branch 19.0 git@github.com:odoo/enterprise.git /opt/odoo/enterprise${NC}"
                echo
                echo -e "4. Restart Odoo:"
                echo -e "   ${GREEN}sudo systemctl restart odoo${NC}"
            fi
            ;;
        0)
            echo
            echo -e "${YELLOW}Cancelled${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid option${NC}"
            exit 1
            ;;
    esac
    
elif [[ "$ENTERPRISE_EXISTS" == true ]] && [[ "$ENTERPRISE_IN_CONFIG" == false ]]; then
    echo -e "${YELLOW}${BOLD}⚠ Notice:${NC}"
    echo -e "${YELLOW}Enterprise is installed but not enabled in config!${NC}"
    echo
    
    read -p "Add Enterprise to addons_path? (Y/n): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        # Backup config
        cp "$ODOO_CONFIG" "${ODOO_CONFIG}.backup.$(date +%Y%m%d-%H%M%S)"
        echo -e "${GREEN}✓${NC} Config backed up"
        
        # Get current addons_path
        CURRENT_ADDONS=$(grep "^addons_path" "$ODOO_CONFIG" | cut -d'=' -f2 | xargs)
        
        # Add Enterprise if not already there
        if [[ ! "$CURRENT_ADDONS" =~ "enterprise" ]]; then
            NEW_ADDONS="$CURRENT_ADDONS,/opt/odoo/enterprise"
            sed -i "s|^addons_path.*|addons_path = $NEW_ADDONS|" "$ODOO_CONFIG"
            echo -e "${GREEN}✓${NC} Enterprise added to addons_path"
            
            # Restart Odoo
            echo
            read -p "Restart Odoo service now? (Y/n): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Nn]$ ]]; then
                systemctl restart odoo
                echo -e "${GREEN}✓${NC} Odoo service restarted"
            fi
            
            echo
            echo -e "${GREEN}${BOLD}✓ Enterprise enabled!${NC}"
        else
            echo -e "${YELLOW}Enterprise already in addons_path${NC}"
        fi
    fi
    
elif [[ "$ENTERPRISE_EXISTS" == false ]] && [[ "$ENTERPRISE_IN_CONFIG" == false ]]; then
    echo -e "${CYAN}${BOLD}ℹ  Enterprise is not installed${NC}"
    echo
    
    read -p "Do you want to install Enterprise edition? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if [[ -f "$SCRIPT_DIR/scripts/install-enterprise.sh" ]]; then
            bash "$SCRIPT_DIR/scripts/install-enterprise.sh"
        else
            echo -e "${RED}Error: install-enterprise.sh not found${NC}"
        fi
    else
        echo -e "${YELLOW}Installation cancelled${NC}"
    fi
    
else
    echo -e "${GREEN}${BOLD}✓ Enterprise installation is correct!${NC}"
    echo -e "Enterprise is properly installed and configured."
    
    # Show some stats
    if [[ -d "$ENTERPRISE_PATH/.git" ]]; then
        cd "$ENTERPRISE_PATH"
        BRANCH=$(git branch --show-current 2>/dev/null || echo "Unknown")
        COMMIT=$(git log -1 --format="%h - %s" 2>/dev/null || echo "Unknown")
        MODULE_COUNT=$(find "$ENTERPRISE_PATH" -maxdepth 2 -name "__manifest__.py" 2>/dev/null | wc -l)
        
        echo
        echo -e "${CYAN}Branch: $BRANCH${NC}"
        echo -e "${CYAN}Latest Commit: $COMMIT${NC}"
        echo -e "${CYAN}Modules: $MODULE_COUNT${NC}"
        cd - > /dev/null
    fi
fi

echo
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo

exit 0

#!/bin/bash

###############################################################################
# Odoo Version Check Script
# 
# Zeigt die installierte Odoo-Version und Enterprise-Status an
###############################################################################

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Configuration
ODOO_CONFIG="/etc/odoo/odoo.conf"
ODOO_BIN="/opt/odoo/odoo/odoo-bin"
ENTERPRISE_PATH="/opt/odoo/enterprise"

echo -e "${BLUE}${BOLD}"
echo "╔════════════════════════════════════════════════════════════╗"
echo "║              Odoo Version & Status Check                   ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo

# Check if Odoo is installed
if [[ ! -f "$ODOO_BIN" ]] && [[ ! -f "/usr/bin/odoo" ]]; then
    echo -e "${RED}❌ Odoo ist nicht installiert${NC}"
    echo
    exit 1
fi

echo -e "${CYAN}${BOLD}📦 Odoo Installation:${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━${NC}"

# Get Odoo version from odoo-bin
if [[ -f "$ODOO_BIN" ]]; then
    echo -e "${GREEN}✓${NC} Odoo Binary: ${BOLD}$ODOO_BIN${NC}"
    
    # Try to get version from odoo-bin
    if command -v python3 &> /dev/null; then
        ODOO_VERSION=$(python3 -c "import sys; sys.path.insert(0, '/opt/odoo/odoo'); import odoo; print(odoo.release.version)" 2>/dev/null || echo "Unknown")
        ODOO_VERSION_INFO=$(python3 -c "import sys; sys.path.insert(0, '/opt/odoo/odoo'); import odoo; print(odoo.release.version_info)" 2>/dev/null || echo "Unknown")
        ODOO_SERIES=$(python3 -c "import sys; sys.path.insert(0, '/opt/odoo/odoo'); import odoo; print(odoo.release.series)" 2>/dev/null || echo "Unknown")
        
        echo -e "${GREEN}✓${NC} Version: ${BOLD}${GREEN}$ODOO_VERSION${NC}"
        
        if [[ "$ODOO_VERSION_INFO" != "Unknown" ]]; then
            echo -e "${CYAN}  Version Info: $ODOO_VERSION_INFO${NC}"
        fi
        
        if [[ "$ODOO_SERIES" != "Unknown" ]]; then
            echo -e "${CYAN}  Series: $ODOO_SERIES${NC}"
        fi
    else
        echo -e "${YELLOW}⚠${NC} Python3 nicht gefunden - Version kann nicht ermittelt werden"
    fi
else
    echo -e "${YELLOW}⚠${NC} Odoo Binary nicht gefunden unter $ODOO_BIN"
fi

echo

# Check Odoo service status
echo -e "${CYAN}${BOLD}🔧 Service Status:${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━${NC}"

if systemctl is-active --quiet odoo 2>/dev/null; then
    echo -e "${GREEN}✓${NC} Odoo Service: ${GREEN}${BOLD}Running${NC}"
    
    # Get service uptime
    UPTIME=$(systemctl show odoo --property=ActiveEnterTimestamp --value 2>/dev/null)
    if [[ -n "$UPTIME" ]]; then
        echo -e "${CYAN}  Started: $UPTIME${NC}"
    fi
else
    echo -e "${RED}✗${NC} Odoo Service: ${RED}${BOLD}Stopped${NC}"
fi

# Check if service exists
if systemctl list-unit-files | grep -q "^odoo.service"; then
    echo -e "${GREEN}✓${NC} Service Unit: ${BOLD}Installed${NC}"
else
    echo -e "${YELLOW}⚠${NC} Service Unit: ${YELLOW}Not found${NC}"
fi

echo

# Check Enterprise Edition
echo -e "${CYAN}${BOLD}🏢 Enterprise Edition:${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━${NC}"

if [[ -d "$ENTERPRISE_PATH" ]]; then
    echo -e "${GREEN}✓${NC} Enterprise Path: ${BOLD}$ENTERPRISE_PATH${NC}"
    
    # Check if it's a git repository
    if [[ -d "$ENTERPRISE_PATH/.git" ]]; then
        echo -e "${GREEN}✓${NC} Git Repository: ${GREEN}Yes${NC}"
        
        # Get current branch
        cd "$ENTERPRISE_PATH"
        ENTERPRISE_BRANCH=$(git branch --show-current 2>/dev/null || echo "Unknown")
        echo -e "${CYAN}  Branch: $ENTERPRISE_BRANCH${NC}"
        
        # Get latest commit
        ENTERPRISE_COMMIT=$(git log -1 --format="%h - %s (%ar)" 2>/dev/null || echo "Unknown")
        echo -e "${CYAN}  Latest Commit: $ENTERPRISE_COMMIT${NC}"
        
        # Check for updates
        if git fetch --dry-run 2>&1 | grep -q "up to date" || git fetch --dry-run 2>&1 | grep -q "From"; then
            BEHIND=$(git rev-list HEAD..origin/$ENTERPRISE_BRANCH --count 2>/dev/null || echo "0")
            if [[ "$BEHIND" -gt 0 ]]; then
                echo -e "${YELLOW}  Updates available: $BEHIND commits behind${NC}"
            else
                echo -e "${GREEN}  Up to date${NC}"
            fi
        fi
        
        cd - > /dev/null
    else
        echo -e "${YELLOW}⚠${NC} Not a Git repository"
    fi
    
    # Count modules
    MODULE_COUNT=$(find "$ENTERPRISE_PATH" -maxdepth 2 -name "__manifest__.py" 2>/dev/null | wc -l)
    echo -e "${CYAN}  Modules: $MODULE_COUNT${NC}"
    
    # Check if Enterprise is in addons_path
    if [[ -f "$ODOO_CONFIG" ]]; then
        if grep -q "addons_path.*enterprise" "$ODOO_CONFIG"; then
            echo -e "${GREEN}✓${NC} Status: ${GREEN}${BOLD}Enabled in config${NC}"
        else
            echo -e "${YELLOW}⚠${NC} Status: ${YELLOW}Not in addons_path${NC}"
        fi
    fi
    
else
    echo -e "${RED}✗${NC} Enterprise: ${RED}${BOLD}Not Installed${NC}"
    echo -e "${CYAN}  Path not found: $ENTERPRISE_PATH${NC}"
fi

echo

# Check Configuration
echo -e "${CYAN}${BOLD}⚙️  Configuration:${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━${NC}"

if [[ -f "$ODOO_CONFIG" ]]; then
    echo -e "${GREEN}✓${NC} Config File: ${BOLD}$ODOO_CONFIG${NC}"
    
    # Extract key settings
    DB_HOST=$(grep "^db_host" "$ODOO_CONFIG" | cut -d'=' -f2 | xargs 2>/dev/null || echo "Not set")
    DB_PORT=$(grep "^db_port" "$ODOO_CONFIG" | cut -d'=' -f2 | xargs 2>/dev/null || echo "Not set")
    DB_USER=$(grep "^db_user" "$ODOO_CONFIG" | cut -d'=' -f2 | xargs 2>/dev/null || echo "Not set")
    XMLRPC_PORT=$(grep "^xmlrpc_port" "$ODOO_CONFIG" | cut -d'=' -f2 | xargs 2>/dev/null || echo "8069")
    LONGPOLLING_PORT=$(grep "^longpolling_port" "$ODOO_CONFIG" | cut -d'=' -f2 | xargs 2>/dev/null || echo "8072")
    WORKERS=$(grep "^workers" "$ODOO_CONFIG" | cut -d'=' -f2 | xargs 2>/dev/null || echo "0")
    PROXY_MODE=$(grep "^proxy_mode" "$ODOO_CONFIG" | cut -d'=' -f2 | xargs 2>/dev/null || echo "False")
    
    echo -e "${CYAN}  Database Host: $DB_HOST${NC}"
    echo -e "${CYAN}  Database Port: $DB_PORT${NC}"
    echo -e "${CYAN}  Database User: $DB_USER${NC}"
    echo -e "${CYAN}  HTTP Port: $XMLRPC_PORT${NC}"
    echo -e "${CYAN}  Longpolling Port: $LONGPOLLING_PORT${NC}"
    echo -e "${CYAN}  Workers: $WORKERS${NC}"
    echo -e "${CYAN}  Proxy Mode: $PROXY_MODE${NC}"
    
    # Extract addons_path
    echo
    echo -e "${CYAN}  Addons Paths:${NC}"
    ADDONS_PATH=$(grep "^addons_path" "$ODOO_CONFIG" | cut -d'=' -f2 | tr ',' '\n' | xargs -I {} echo "    • {}")
    if [[ -n "$ADDONS_PATH" ]]; then
        echo -e "${CYAN}$ADDONS_PATH${NC}"
    else
        echo -e "${YELLOW}    Not configured${NC}"
    fi
else
    echo -e "${RED}✗${NC} Config File: ${RED}Not found${NC}"
fi

echo

# Check PostgreSQL
echo -e "${CYAN}${BOLD}🗄️  Database:${NC}"
echo -e "${BLUE}━━━━━━━━━━━${NC}"

if systemctl is-active --quiet postgresql 2>/dev/null; then
    echo -e "${GREEN}✓${NC} PostgreSQL: ${GREEN}${BOLD}Running${NC}"
    
    # Try to list databases
    if command -v psql &> /dev/null; then
        DB_COUNT=$(sudo -u postgres psql -t -c "SELECT count(*) FROM pg_database WHERE datname NOT IN ('postgres', 'template0', 'template1');" 2>/dev/null | xargs || echo "0")
        echo -e "${CYAN}  Odoo Databases: $DB_COUNT${NC}"
        
        # List database names
        echo -e "${CYAN}  Database Names:${NC}"
        sudo -u postgres psql -t -c "SELECT datname FROM pg_database WHERE datname NOT IN ('postgres', 'template0', 'template1') ORDER BY datname;" 2>/dev/null | while read -r dbname; do
            if [[ -n "$dbname" ]]; then
                echo -e "${CYAN}    • $(echo $dbname | xargs)${NC}"
            fi
        done
    fi
else
    echo -e "${RED}✗${NC} PostgreSQL: ${RED}Stopped${NC}"
fi

echo

# Check Nginx (if installed)
echo -e "${CYAN}${BOLD}🌐 Web Server:${NC}"
echo -e "${BLUE}━━━━━━━━━━━━${NC}"

if command -v nginx &> /dev/null; then
    if systemctl is-active --quiet nginx 2>/dev/null; then
        echo -e "${GREEN}✓${NC} Nginx: ${GREEN}${BOLD}Running${NC}"
        
        # Check if Odoo is configured
        if [[ -f "/etc/nginx/sites-enabled/default" ]]; then
            if grep -q "8069" "/etc/nginx/sites-enabled/default" 2>/dev/null; then
                echo -e "${GREEN}✓${NC} Odoo Proxy: ${GREEN}Configured${NC}"
                
                # Extract server_name
                SERVER_NAME=$(grep "server_name" "/etc/nginx/sites-enabled/default" | head -n1 | sed 's/.*server_name //;s/;//' | xargs 2>/dev/null || echo "localhost")
                echo -e "${CYAN}  Domain: $SERVER_NAME${NC}"
                
                # Check SSL
                if grep -q "ssl_certificate" "/etc/nginx/sites-enabled/default" 2>/dev/null; then
                    echo -e "${GREEN}✓${NC} SSL: ${GREEN}Enabled${NC}"
                else
                    echo -e "${YELLOW}⚠${NC} SSL: ${YELLOW}Not configured${NC}"
                fi
            else
                echo -e "${YELLOW}⚠${NC} Odoo Proxy: ${YELLOW}Not configured${NC}"
            fi
        fi
    else
        echo -e "${YELLOW}⚠${NC} Nginx: ${YELLOW}Installed but not running${NC}"
    fi
else
    echo -e "${CYAN}ℹ${NC}  Nginx: Not installed"
fi

echo

# Summary
echo -e "${BLUE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}${BOLD}Summary:${NC}"

if [[ "$ODOO_VERSION" != "Unknown" ]]; then
    echo -e "  Odoo Version: ${GREEN}${BOLD}$ODOO_VERSION${NC}"
else
    echo -e "  Odoo Version: ${YELLOW}Could not be determined${NC}"
fi

if [[ -d "$ENTERPRISE_PATH" ]]; then
    echo -e "  Enterprise: ${GREEN}${BOLD}Installed${NC} (Branch: $ENTERPRISE_BRANCH)"
else
    echo -e "  Enterprise: ${RED}Not installed${NC}"
fi

if systemctl is-active --quiet odoo 2>/dev/null; then
    echo -e "  Service: ${GREEN}${BOLD}Running${NC}"
else
    echo -e "  Service: ${RED}Stopped${NC}"
fi

echo -e "${BLUE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo

exit 0

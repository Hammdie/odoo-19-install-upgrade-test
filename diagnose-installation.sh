#!/bin/bash

# Odoo Installation Diagnose Script
# Analysiert häufige Installationsprobleme und zeigt Lösungen

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

echo -e "${BLUE}${BOLD}"
cat << 'EOF'
╔═══════════════════════════════════════════════════╗
║          Odoo Installation Diagnose Tool          ║
╚═══════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo -e "${YELLOW}Diagnosing Odoo Installation Issues...${NC}"
echo

# 1. Check if Odoo service exists
echo -e "${BOLD}1. Checking Odoo Service Status:${NC}"
if systemctl list-unit-files 2>/dev/null | grep -q "^odoo.service"; then
    echo -e "${GREEN}✓ Odoo service file exists${NC}"
    
    # Check service status
    if systemctl is-active --quiet odoo; then
        echo -e "${GREEN}✓ Odoo service is running${NC}"
    else
        echo -e "${RED}✗ Odoo service is not running${NC}"
        echo -e "  Status: $(systemctl is-active odoo 2>/dev/null || echo 'unknown')"
        
        # Get service status details
        echo -e "${YELLOW}  Service Status Details:${NC}"
        systemctl status odoo --no-pager -l | grep -E "(Active:|Main PID:|since|ago)" | sed 's/^/    /'
    fi
else
    echo -e "${RED}✗ Odoo service file does not exist${NC}"
    echo -e "  Expected location: /etc/systemd/system/odoo.service"
fi

echo

# 2. Check if Odoo user exists
echo -e "${BOLD}2. Checking Odoo User:${NC}"
if id odoo &>/dev/null; then
    echo -e "${GREEN}✓ Odoo user exists${NC}"
    echo -e "  User info: $(id odoo)"
    echo -e "  Home: $(getent passwd odoo | cut -d: -f6)"
else
    echo -e "${RED}✗ Odoo user does not exist${NC}"
    echo -e "  ${YELLOW}Solution: Create user with: sudo useradd -m -d /opt/odoo -r -s /bin/bash odoo${NC}"
fi

echo

# 3. Check Odoo installation directory
echo -e "${BOLD}3. Checking Odoo Installation:${NC}"
ODOO_HOME="/opt/odoo"
if [[ -d "$ODOO_HOME" ]]; then
    echo -e "${GREEN}✓ Odoo home directory exists: $ODOO_HOME${NC}"
    
    # Check for Odoo binary
    if [[ -d "$ODOO_HOME/odoo" ]]; then
        echo -e "${GREEN}✓ Odoo source directory exists: $ODOO_HOME/odoo${NC}"
        
        # Check for odoo-bin or odoo.py
        if [[ -f "$ODOO_HOME/odoo/odoo-bin" ]]; then
            echo -e "${GREEN}✓ Odoo binary found: $ODOO_HOME/odoo/odoo-bin${NC}"
        elif [[ -f "$ODOO_HOME/odoo/odoo.py" ]]; then
            echo -e "${GREEN}✓ Odoo binary found: $ODOO_HOME/odoo/odoo.py${NC}"
        else
            echo -e "${RED}✗ Odoo binary not found${NC}"
            echo -e "  ${YELLOW}Expected: $ODOO_HOME/odoo/odoo-bin or $ODOO_HOME/odoo/odoo.py${NC}"
        fi
        
        # Check ownership
        OWNER=$(stat -c '%U' "$ODOO_HOME/odoo" 2>/dev/null || echo "unknown")
        if [[ "$OWNER" == "odoo" ]]; then
            echo -e "${GREEN}✓ Correct ownership (odoo)${NC}"
        else
            echo -e "${YELLOW}⚠ Ownership issue - Current owner: $OWNER${NC}"
            echo -e "  ${YELLOW}Solution: sudo chown -R odoo:odoo $ODOO_HOME${NC}"
        fi
    else
        echo -e "${RED}✗ Odoo source directory not found: $ODOO_HOME/odoo${NC}"
    fi
else
    echo -e "${RED}✗ Odoo home directory does not exist: $ODOO_HOME${NC}"
fi

echo

# 4. Check Odoo configuration
echo -e "${BOLD}4. Checking Odoo Configuration:${NC}"
ODOO_CONFIG="/etc/odoo/odoo.conf"
if [[ -f "$ODOO_CONFIG" ]]; then
    echo -e "${GREEN}✓ Configuration file exists: $ODOO_CONFIG${NC}"
    
    # Check ownership
    CONFIG_OWNER=$(stat -c '%U' "$ODOO_CONFIG" 2>/dev/null || echo "unknown")
    if [[ "$CONFIG_OWNER" == "odoo" ]] || [[ "$CONFIG_OWNER" == "root" ]]; then
        echo -e "${GREEN}✓ Configuration ownership OK ($CONFIG_OWNER)${NC}"
    else
        echo -e "${YELLOW}⚠ Configuration ownership issue - Current owner: $CONFIG_OWNER${NC}"
    fi
    
    # Check for critical settings
    echo -e "${BLUE}  Configuration overview:${NC}"
    if grep -q "addons_path" "$ODOO_CONFIG"; then
        ADDONS_PATH=$(grep "addons_path" "$ODOO_CONFIG" | cut -d'=' -f2- | xargs)
        echo -e "    Addons path: $ADDONS_PATH"
    fi
    
    if grep -q "db_host" "$ODOO_CONFIG"; then
        DB_HOST=$(grep "db_host" "$ODOO_CONFIG" | cut -d'=' -f2- | xargs)
        echo -e "    DB host: $DB_HOST"
    fi
    
    if grep -q "db_user" "$ODOO_CONFIG"; then
        DB_USER=$(grep "db_user" "$ODOO_CONFIG" | cut -d'=' -f2- | xargs)
        echo -e "    DB user: $DB_USER"
    fi
else
    echo -e "${RED}✗ Configuration file not found: $ODOO_CONFIG${NC}"
fi

echo

# 5. Check PostgreSQL
echo -e "${BOLD}5. Checking PostgreSQL:${NC}"
if systemctl is-active --quiet postgresql; then
    echo -e "${GREEN}✓ PostgreSQL service is running${NC}"
    
    # Check if odoo user exists in PostgreSQL
    if sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='odoo'" | grep -q "1"; then
        echo -e "${GREEN}✓ PostgreSQL odoo user exists${NC}"
    else
        echo -e "${RED}✗ PostgreSQL odoo user does not exist${NC}"
        echo -e "  ${YELLOW}Solution: sudo -u postgres createuser -s odoo${NC}"
    fi
    
    # Test connection with default password
    if PGPASSWORD="odoo" psql -h localhost -U odoo -d postgres -c "SELECT version();" &>/dev/null; then
        echo -e "${GREEN}✓ PostgreSQL connection test successful${NC}"
    else
        echo -e "${RED}✗ PostgreSQL connection test failed${NC}"
        echo -e "  ${YELLOW}Check pg_hba.conf authentication settings${NC}"
    fi
else
    echo -e "${RED}✗ PostgreSQL service is not running${NC}"
    echo -e "  ${YELLOW}Solution: sudo systemctl start postgresql${NC}"
fi

echo

# 6. Check wkhtmltopdf (Qt patched version)
echo -e "${BOLD}6. Checking wkhtmltopdf (Qt Patch):${NC}"
if command -v wkhtmltopdf &> /dev/null; then
    WKHTML_VERSION=$(wkhtmltopdf --version 2>&1)
    echo -e "${GREEN}✓ wkhtmltopdf found${NC}"
    
    if echo "$WKHTML_VERSION" | grep -q "with patched qt"; then
        echo -e "${GREEN}✓ Qt patched version detected${NC}"
        echo -e "  Version: $(echo "$WKHTML_VERSION" | head -1)"
    else
        echo -e "${RED}✗ Qt patch NOT detected${NC}"
        echo -e "  ${YELLOW}This will cause PDF generation issues in Odoo!${NC}"
        echo -e "  Version: $(echo "$WKHTML_VERSION" | head -1)"
        echo -e "  ${YELLOW}Solution: Install Qt patched version${NC}"
    fi
    
    # Test basic functionality
    if echo "<html><body><h1>Test</h1></body></html>" | wkhtmltopdf - /tmp/test.pdf 2>/dev/null; then
        echo -e "${GREEN}✓ Basic PDF generation test successful${NC}"
        rm -f /tmp/test.pdf
    else
        echo -e "${RED}✗ PDF generation test failed${NC}"
    fi
else
    echo -e "${RED}✗ wkhtmltopdf not found${NC}"
    echo -e "  ${YELLOW}This is CRITICAL for Odoo PDF reports!${NC}"
    echo -e "  ${YELLOW}Solution: Install wkhtmltopdf with Qt patch${NC}"
fi

echo

# 7. Check Python environment
echo -e "${BOLD}7. Checking Python Environment:${NC}"
if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version | cut -d' ' -f2)
    echo -e "${GREEN}✓ Python3 available: $PYTHON_VERSION${NC}"
    
    # Check if Odoo is installed as Python package
    if python3 -c "import odoo; print(odoo.__version__)" &>/dev/null; then
        ODOO_VERSION=$(python3 -c "import odoo; print(odoo.__version__)" 2>/dev/null || echo "unknown")
        echo -e "${GREEN}✓ Odoo Python package installed: $ODOO_VERSION${NC}"
    else
        echo -e "${RED}✗ Odoo Python package not installed${NC}"
        echo -e "  ${YELLOW}This might be the main issue!${NC}"
    fi
else
    echo -e "${RED}✗ Python3 not found${NC}"
    echo -e "  ${YELLOW}Solution: sudo apt update && sudo apt install python3${NC}"
fi

echo

# 8. Check recent logs
echo -e "${BOLD}8. Checking Recent Logs:${NC}"

# Installation logs
echo -e "${BLUE}Recent installation logs:${NC}"
if [[ -d "/var/log/odoo-upgrade" ]]; then
    RECENT_LOG=$(ls -t /var/log/odoo-upgrade/install-*.log 2>/dev/null | head -1)
    if [[ -n "$RECENT_LOG" ]]; then
        echo -e "  Most recent: $RECENT_LOG"
        echo -e "  ${YELLOW}Last few lines:${NC}"
        tail -5 "$RECENT_LOG" 2>/dev/null | sed 's/^/    /' || echo "    (Could not read log)"
    else
        echo -e "  ${YELLOW}No installation logs found${NC}"
    fi
else
    echo -e "  ${YELLOW}Log directory not found: /var/log/odoo-upgrade${NC}"
fi

# Service logs
echo -e "${BLUE}Odoo service logs (last 5 lines):${NC}"
if systemctl list-unit-files 2>/dev/null | grep -q "^odoo.service"; then
    journalctl -u odoo -n 5 --no-pager 2>/dev/null | sed 's/^/  /' || echo "  (No service logs available)"
else
    echo -e "  ${YELLOW}No odoo service to check${NC}"
fi

echo

# 9. Quick fix recommendations
echo -e "${BOLD}9. Quick Fix Recommendations:${NC}"
echo

# Check for wkhtmltopdf issues first
if ! command -v wkhtmltopdf &> /dev/null; then
    echo -e "${YELLOW}🔧 CRITICAL: wkhtmltopdf missing${NC}"
    echo -e "   ${GREEN}1. Install wkhtmltopdf: sudo ./fix-installation.sh${NC}"
    echo -e "   ${GREEN}2. Or install manually: sudo apt update && sudo apt install -y wkhtmltopdf${NC}"
    echo
elif ! wkhtmltopdf --version 2>&1 | grep -q "with patched qt"; then
    echo -e "${YELLOW}🔧 WARNING: wkhtmltopdf without Qt patch${NC}"
    echo -e "   ${GREEN}1. Install Qt patched version: sudo ./fix-installation.sh${NC}"
    echo -e "   ${GREEN}2. Download from: https://github.com/wkhtmltopdf/packaging/releases${NC}"
    echo
fi
echo

if ! systemctl list-unit-files 2>/dev/null | grep -q "^odoo.service"; then
    echo -e "${YELLOW}🔧 Main Issue: Odoo service not installed${NC}"
    echo -e "   ${GREEN}1. Re-run installation: sudo ./install.sh --auto --force${NC}"
    echo -e "   ${GREEN}2. Or run Odoo installation only: sudo ./scripts/install-odoo19.sh${NC}"
    echo
elif ! systemctl is-active --quiet odoo; then
    echo -e "${YELLOW}🔧 Main Issue: Odoo service installed but not running${NC}"
    echo -e "   ${GREEN}1. Start service: sudo systemctl start odoo${NC}"
    echo -e "   ${GREEN}2. Enable auto-start: sudo systemctl enable odoo${NC}"
    echo -e "   ${GREEN}3. Check logs: sudo journalctl -u odoo -f${NC}"
    echo
fi

# Common fixes
echo -e "${BLUE}📋 Common Fixes:${NC}"
echo -e "   ${GREEN}• Fix permissions: sudo chown -R odoo:odoo /opt/odoo${NC}"
echo -e "   ${GREEN}• Check config: sudo nano /etc/odoo/odoo.conf${NC}"
echo -e "   ${GREEN}• Restart PostgreSQL: sudo systemctl restart postgresql${NC}"
echo -e "   ${GREEN}• View live logs: sudo journalctl -u odoo -f${NC}"
echo -e "   ${GREEN}• Test Odoo manually: sudo -u odoo python3 -m odoo --config=/etc/odoo/odoo.conf --stop-after-init${NC}"

echo
echo -e "${BOLD}Diagnosis completed!${NC}"
echo -e "${BLUE}For more help, check: https://github.com/Hammdie/odoo-upgrade-cron${NC}"
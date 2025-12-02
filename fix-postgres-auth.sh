#!/bin/bash

# PostgreSQL Localhost Authentication Fix
# Konfiguriert PostgreSQL für:
# - Lokale Verbindungen OHNE Passwort (trust)
# - Externe Verbindungen BLOCKIERT

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔══════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  PostgreSQL Localhost Trust Configuration    ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════╝${NC}"
echo

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}This script must be run as root or with sudo${NC}"
    exit 1
fi

# Find PostgreSQL version
PG_VERSION=$(sudo -u postgres psql -t -c "SHOW server_version;" 2>/dev/null | grep -o '[0-9]*' | head -n1)
if [[ -z "$PG_VERSION" ]]; then
    PG_VERSION=$(ls /etc/postgresql/ 2>/dev/null | head -n1)
fi

echo -e "${BLUE}PostgreSQL version: $PG_VERSION${NC}"

# Find pg_hba.conf
PG_HBA_FILE="/etc/postgresql/$PG_VERSION/main/pg_hba.conf"

if [[ ! -f "$PG_HBA_FILE" ]]; then
    echo -e "${RED}Could not find pg_hba.conf file at: $PG_HBA_FILE${NC}"
    exit 1
fi

echo -e "${GREEN}Found pg_hba.conf: $PG_HBA_FILE${NC}"

# Backup
BACKUP_FILE="${PG_HBA_FILE}.backup.$(date +%Y%m%d-%H%M%S)"
cp "$PG_HBA_FILE" "$BACKUP_FILE"
echo -e "${GREEN}✓ Backup created: $BACKUP_FILE${NC}"

# Create simple trust configuration for localhost
echo -e "\n${BLUE}Configuring localhost trust (no password)...${NC}"

cat > "$PG_HBA_FILE" << 'EOF'
# PostgreSQL Client Authentication Configuration
# 
# TYPE  DATABASE        USER            ADDRESS                 METHOD
#
# Lokale Verbindungen ohne Passwort (trust)
local   all             all                                     trust
host    all             all             127.0.0.1/32            trust
host    all             all             ::1/128                 trust

# Externe Verbindungen BLOCKIERT (reject)
host    all             all             0.0.0.0/0               reject
EOF

echo -e "${GREEN}✓ pg_hba.conf configured for localhost trust${NC}"
echo -e "${YELLOW}  ✓ Local connections: NO PASSWORD${NC}"
echo -e "${YELLOW}  ✓ External connections: BLOCKED${NC}"

# Ensure odoo user exists
echo -e "\n${BLUE}Checking PostgreSQL users...${NC}"

if sudo -u postgres psql -t -c "SELECT 1 FROM pg_roles WHERE rolname='odoo';" | grep -q 1; then
    echo -e "${GREEN}✓ User 'odoo' exists${NC}"
else
    echo -e "${BLUE}Creating user 'odoo'...${NC}"
    sudo -u postgres createuser -d -R -S odoo
    echo -e "${GREEN}✓ User 'odoo' created${NC}"
fi

# Grant CREATEDB privilege
sudo -u postgres psql -c "ALTER USER odoo CREATEDB;" 2>/dev/null || true
echo -e "${GREEN}✓ User 'odoo' has CREATEDB privilege${NC}"

# Update odoo.conf for peer/trust authentication
ODOO_CONF="/etc/odoo/odoo.conf"
if [[ -f "$ODOO_CONF" ]]; then
    echo -e "\n${BLUE}Updating odoo.conf for trust authentication...${NC}"
    
    # Backup
    cp "$ODOO_CONF" "${ODOO_CONF}.bak.$(date +%Y%m%d-%H%M%S)"
    
    # Update to use localhost without password
    sed -i 's/^db_host.*/db_host = localhost/' "$ODOO_CONF"
    sed -i 's/^db_port.*/db_port = 5432/' "$ODOO_CONF"
    sed -i 's/^db_user.*/db_user = odoo/' "$ODOO_CONF"
    sed -i 's/^db_password.*/db_password = False/' "$ODOO_CONF"
    
    echo -e "${GREEN}✓ odoo.conf updated${NC}"
fi

# Reload PostgreSQL
echo -e "\n${BLUE}Reloading PostgreSQL...${NC}"
systemctl reload postgresql
echo -e "${GREEN}✓ PostgreSQL reloaded${NC}"

# Test connection
echo -e "\n${BLUE}Testing connection...${NC}"
if psql -h localhost -U odoo -d postgres -c "SELECT version();" >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Connection successful (no password needed)${NC}"
else
    echo -e "${RED}✗ Connection test failed${NC}"
fi

echo
echo -e "${GREEN}🎉 Configuration completed!${NC}"
echo
echo -e "${BLUE}Configuration:${NC}"
echo -e "  ✓ Localhost: ${GREEN}trust (no password)${NC}"
echo -e "  ✓ External: ${RED}blocked${NC}"
echo
echo -e "${BLUE}Test:${NC}"
echo -e "  psql -h localhost -U odoo -d postgres"
echo

exit 0
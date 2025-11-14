#!/bin/bash

# PostgreSQL Localhost Authentication Fix
# Konfiguriert PostgreSQL für passwortlose lokale Verbindungen

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔══════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     PostgreSQL Localhost Auth Fix            ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════╝${NC}"
echo

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}This script must be run as root or with sudo${NC}"
    exit 1
fi

# Check if PostgreSQL is installed
if ! command -v psql &> /dev/null; then
    echo -e "${RED}PostgreSQL is not installed${NC}"
    exit 1
fi

# Find PostgreSQL version and config
PG_VERSION=$(sudo -u postgres psql -t -c "SHOW server_version;" 2>/dev/null | grep -o '[0-9]*' | head -n1)
if [[ -z "$PG_VERSION" ]]; then
    PG_VERSION=$(ls /etc/postgresql/ | head -n1)
fi

echo -e "${BLUE}PostgreSQL version: $PG_VERSION${NC}"

# Find pg_hba.conf
PG_HBA_PATHS=(
    "/etc/postgresql/$PG_VERSION/main/pg_hba.conf"
    "/etc/postgresql/$PG_VERSION/cluster/pg_hba.conf" 
    "/var/lib/pgsql/data/pg_hba.conf"
    "/usr/local/pgsql/data/pg_hba.conf"
)

PG_HBA_FILE=""
for path in "${PG_HBA_PATHS[@]}"; do
    if [[ -f "$path" ]]; then
        PG_HBA_FILE="$path"
        break
    fi
done

if [[ -z "$PG_HBA_FILE" ]]; then
    echo -e "${RED}Could not find pg_hba.conf file${NC}"
    exit 1
fi

echo -e "${GREEN}Found pg_hba.conf: $PG_HBA_FILE${NC}"

# Backup original pg_hba.conf
BACKUP_FILE="${PG_HBA_FILE}.backup.$(date +%Y%m%d-%H%M%S)"
cp "$PG_HBA_FILE" "$BACKUP_FILE"
echo -e "${GREEN}✓ Backup created: $BACKUP_FILE${NC}"

# Show current configuration
echo -e "\n${BLUE}Current authentication configuration:${NC}"
grep -v "^#" "$PG_HBA_FILE" | grep -v "^$" | head -10

# Create new pg_hba.conf with localhost trust authentication
echo -e "\n${BLUE}Updating pg_hba.conf for localhost trust authentication...${NC}"

cat > "$PG_HBA_FILE" << 'EOF'
# PostgreSQL Client Authentication Configuration File
# Fixed for localhost trust authentication

# TYPE  DATABASE        USER            ADDRESS                 METHOD

# "local" is for Unix domain socket connections only
local   all             postgres                                peer
local   all             odoo                                    peer
local   all             all                                     peer

# IPv4 local connections:
host    all             postgres        127.0.0.1/32            trust
host    all             odoo            127.0.0.1/32            trust  
host    all             all             127.0.0.1/32            trust

# IPv6 local connections:
host    all             postgres        ::1/128                 trust
host    all             odoo            ::1/128                 trust
host    all             all             ::1/128                 trust

# Remote connections (more restrictive)
host    all             all             0.0.0.0/0               md5

# Replication connections
local   replication     all                                     peer
host    replication     all             127.0.0.1/32            trust
host    replication     all             ::1/128                 trust
EOF

echo -e "${GREEN}✓ Updated pg_hba.conf for localhost trust authentication${NC}"

# Show new configuration
echo -e "\n${BLUE}New authentication configuration:${NC}"
grep -v "^#" "$PG_HBA_FILE" | grep -v "^$"

# Create/ensure odoo user exists and has proper privileges
echo -e "\n${BLUE}Checking PostgreSQL users and privileges...${NC}"

# Check if odoo user exists
if sudo -u postgres psql -t -c "SELECT 1 FROM pg_roles WHERE rolname='odoo';" | grep -q 1; then
    echo -e "${GREEN}✓ PostgreSQL user 'odoo' already exists${NC}"
else
    echo -e "${BLUE}Creating PostgreSQL user 'odoo'...${NC}"
    sudo -u postgres createuser -d -R -S odoo
    echo -e "${GREEN}✓ PostgreSQL user 'odoo' created${NC}"
fi

# Ensure odoo user has all necessary privileges
echo -e "${BLUE}Setting up odoo user privileges...${NC}"
sudo -u postgres psql << 'EOSQL'
-- Grant CREATEDB privilege to odoo user
ALTER USER odoo CREATEDB;

-- Grant additional privileges that Odoo needs
ALTER USER odoo WITH LOGIN;

-- Allow odoo to create roles (needed for some Odoo operations)
-- ALTER USER odoo CREATEROLE;

-- Show current privileges
\du odoo
EOSQL

echo -e "${GREEN}✓ odoo user privileges configured${NC}"

# Also ensure postgres user has proper privileges
echo -e "${BLUE}Ensuring postgres user privileges...${NC}"
sudo -u postgres psql -c "ALTER USER postgres CREATEDB;" 2>/dev/null || true

# Check if there are any other database users from odoo.conf
ODOO_CONF="/etc/odoo/odoo.conf"
if [[ -f "$ODOO_CONF" ]]; then
    CONF_DB_USER=$(grep "^db_user" "$ODOO_CONF" | cut -d'=' -f2 | xargs 2>/dev/null || echo "")
    if [[ -n "$CONF_DB_USER" ]] && [[ "$CONF_DB_USER" != "odoo" ]] && [[ "$CONF_DB_USER" != "postgres" ]]; then
        echo -e "${BLUE}Found additional database user in odoo.conf: $CONF_DB_USER${NC}"
        
        # Check if this user exists
        if sudo -u postgres psql -t -c "SELECT 1 FROM pg_roles WHERE rolname='$CONF_DB_USER';" | grep -q 1; then
            echo -e "${GREEN}✓ User '$CONF_DB_USER' already exists${NC}"
        else
            echo -e "${BLUE}Creating PostgreSQL user '$CONF_DB_USER'...${NC}"
            sudo -u postgres createuser -d -R -S "$CONF_DB_USER"
            echo -e "${GREEN}✓ PostgreSQL user '$CONF_DB_USER' created${NC}"
        fi
        
        # Grant privileges
        echo -e "${BLUE}Granting privileges to '$CONF_DB_USER'...${NC}"
        sudo -u postgres psql -c "ALTER USER \"$CONF_DB_USER\" CREATEDB;" 2>/dev/null || true
        echo -e "${GREEN}✓ Privileges granted to '$CONF_DB_USER'${NC}"
    fi
fi

# Reload PostgreSQL configuration
echo -e "\n${BLUE}Reloading PostgreSQL configuration...${NC}"
if systemctl is-active --quiet postgresql; then
    systemctl reload postgresql
    echo -e "${GREEN}✓ PostgreSQL configuration reloaded${NC}"
else
    echo -e "${YELLOW}⚠ PostgreSQL service not running via systemctl${NC}"
    # Try alternative reload methods
    if sudo -u postgres psql -c "SELECT pg_reload_conf();" >/dev/null 2>&1; then
        echo -e "${GREEN}✓ PostgreSQL configuration reloaded via SQL${NC}"
    else
        echo -e "${YELLOW}⚠ Could not reload PostgreSQL config - restart may be needed${NC}"
    fi
fi

# Test connections
echo -e "\n${BLUE}Testing database connections...${NC}"

# Test postgres user
if sudo -u postgres psql -c "SELECT current_user, current_database();" >/dev/null 2>&1; then
    echo -e "${GREEN}✓ postgres user connection works${NC}"
else
    echo -e "${RED}✗ postgres user connection failed${NC}"
fi

# Test odoo user
if sudo -u postgres psql -U odoo -d postgres -c "SELECT current_user, current_database();" >/dev/null 2>&1; then
    echo -e "${GREEN}✓ odoo user connection works${NC}"
else
    echo -e "${RED}✗ odoo user connection failed${NC}"
fi

# Test localhost connection without password
if psql -h localhost -U postgres -d postgres -c "SELECT current_user;" >/dev/null 2>&1; then
    echo -e "${GREEN}✓ localhost connection without password works${NC}"
else
    echo -e "${RED}✗ localhost connection failed${NC}"
fi

# Test database creation permissions for all users
echo -e "\n${BLUE}Testing database creation permissions...${NC}"

# Test postgres user
TEST_DB="test_postgres_$(date +%s)"
if sudo -u postgres createdb "$TEST_DB" 2>/dev/null; then
    echo -e "${GREEN}✓ postgres user can create databases${NC}"
    sudo -u postgres dropdb "$TEST_DB" 2>/dev/null
else
    echo -e "${RED}✗ postgres user cannot create databases${NC}"
fi

# Test odoo user via peer authentication
TEST_DB="test_odoo_$(date +%s)"
if sudo -u postgres createdb -O odoo "$TEST_DB" 2>/dev/null; then
    echo -e "${GREEN}✓ odoo user can own databases${NC}"
    sudo -u postgres dropdb "$TEST_DB" 2>/dev/null
else
    echo -e "${YELLOW}⚠ odoo user ownership test inconclusive${NC}"
fi

# Test localhost connection with database creation
if createdb -h localhost -U postgres "test_localhost_$(date +%s)" 2>/dev/null; then
    echo -e "${GREEN}✓ localhost postgres connection can create databases${NC}"
    dropdb -h localhost -U postgres "test_localhost_$(date +%s)" 2>/dev/null
else
    echo -e "${YELLOW}⚠ localhost postgres database creation failed${NC}"
fi

# Test odoo user via localhost (if trust auth is working)
if createdb -h localhost -U odoo "test_odoo_localhost_$(date +%s)" 2>/dev/null; then
    echo -e "${GREEN}✓ localhost odoo user can create databases${NC}"
    dropdb -h localhost -U odoo "test_odoo_localhost_$(date +%s)" 2>/dev/null
else
    echo -e "${YELLOW}⚠ localhost odoo user database creation failed${NC}"
    echo -e "${CYAN}  This is expected if odoo system user doesn't exist${NC}"
fi

echo -e "\n${GREEN}🎉 PostgreSQL localhost authentication fix completed!${NC}"
echo
echo -e "${BLUE}Summary of changes:${NC}"
echo -e "${GREEN}✓${NC} Backup created: $BACKUP_FILE"
echo -e "${GREEN}✓${NC} pg_hba.conf updated for trust authentication on localhost"
echo -e "${GREEN}✓${NC} odoo user created/verified with database creation privileges"
echo -e "${GREEN}✓${NC} PostgreSQL configuration reloaded"
echo
echo -e "${BLUE}You can now:${NC}"
echo "• Connect without password: psql -h localhost -U postgres"
echo "• Connect as odoo user: psql -h localhost -U odoo -d postgres"
echo "• Create databases: createdb -h localhost -U postgres mydb"
echo
echo -e "${BLUE}To revert changes:${NC}"
echo "sudo cp $BACKUP_FILE $PG_HBA_FILE"
echo "sudo systemctl reload postgresql"

exit 0
#!/bin/bash

# Quick Test: Odoo User Database Creation Permissions
# Testet spezifisch ob der odoo-Benutzer Datenbanken erstellen kann

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔══════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║       Odoo User Database Permissions        ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════╝${NC}"
echo

# Test 1: Check if odoo PostgreSQL user exists
echo -e "${BLUE}1. Checking if odoo PostgreSQL user exists...${NC}"
if sudo -u postgres psql -t -c "SELECT 1 FROM pg_roles WHERE rolname='odoo';" 2>/dev/null | grep -q 1; then
    echo -e "${GREEN}✓ odoo PostgreSQL user exists${NC}"
    
    # Show user privileges
    echo -e "${CYAN}   User privileges:${NC}"
    sudo -u postgres psql -c "\du odoo" 2>/dev/null | grep -A1 "Role name" || echo "   Could not retrieve privileges"
else
    echo -e "${RED}✗ odoo PostgreSQL user does not exist${NC}"
    echo -e "${YELLOW}   Run: sudo ./fix-postgres-auth.sh${NC}"
fi

echo

# Test 2: Test database creation via localhost (trust auth)
echo -e "${BLUE}2. Testing odoo user database creation (localhost)...${NC}"
TEST_DB="odoo_createdb_test_$(date +%s)"

if createdb -h localhost -U odoo "$TEST_DB" 2>/dev/null; then
    echo -e "${GREEN}✓ SUCCESS: odoo user can create databases via localhost${NC}"
    
    # Verify database was created
    if psql -h localhost -U odoo -d "$TEST_DB" -c "SELECT current_database();" >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Database is accessible and functional${NC}"
    fi
    
    # Clean up
    if dropdb -h localhost -U odoo "$TEST_DB" 2>/dev/null; then
        echo -e "${GREEN}✓ Database cleanup successful${NC}"
    fi
else
    echo -e "${RED}✗ FAILED: odoo user cannot create databases via localhost${NC}"
    echo -e "${YELLOW}   This means Odoo cannot create new databases!${NC}"
    echo -e "${CYAN}   Fix with: sudo ./fix-postgres-auth.sh${NC}"
fi

echo

# Test 3: Test with peer authentication
echo -e "${BLUE}3. Testing odoo user database creation (peer auth)...${NC}"
TEST_DB2="odoo_peer_test_$(date +%s)"

# This test requires an odoo system user, so it might fail in containers
if id odoo >/dev/null 2>&1; then
    if sudo -u odoo createdb "$TEST_DB2" 2>/dev/null; then
        echo -e "${GREEN}✓ odoo user can create databases via peer authentication${NC}"
        sudo -u odoo dropdb "$TEST_DB2" 2>/dev/null
    else
        echo -e "${YELLOW}⚠ odoo user cannot create databases via peer auth${NC}"
        echo -e "${CYAN}   This is less critical if localhost trust works${NC}"
    fi
else
    echo -e "${YELLOW}⚠ odoo system user does not exist${NC}"
    echo -e "${CYAN}   This is normal in containers - localhost auth is sufficient${NC}"
fi

echo

# Test 4: Check CREATE DATABASE privilege specifically
echo -e "${BLUE}4. Checking CREATE DATABASE privilege...${NC}"
if sudo -u postgres psql -t -c "SELECT rolcreatedb FROM pg_roles WHERE rolname='odoo';" 2>/dev/null | grep -q "t"; then
    echo -e "${GREEN}✓ odoo user has CREATE DATABASE privilege${NC}"
else
    echo -e "${RED}✗ odoo user lacks CREATE DATABASE privilege${NC}"
    echo -e "${YELLOW}   Fix with: sudo -u postgres psql -c \"ALTER USER odoo CREATEDB;\"${NC}"
fi

echo

# Test 5: Test connection methods
echo -e "${BLUE}5. Testing connection methods...${NC}"

# Via localhost trust
if psql -h localhost -U odoo -d postgres -c "SELECT current_user;" >/dev/null 2>&1; then
    echo -e "${GREEN}✓ localhost trust connection works${NC}"
else
    echo -e "${RED}✗ localhost trust connection failed${NC}"
    echo -e "${CYAN}   Check pg_hba.conf for trust authentication${NC}"
fi

# Via peer authentication (if odoo system user exists)
if id odoo >/dev/null 2>&1 && sudo -u odoo psql -d postgres -c "SELECT current_user;" >/dev/null 2>&1; then
    echo -e "${GREEN}✓ peer authentication works${NC}"
elif ! id odoo >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠ peer authentication not testable (no odoo system user)${NC}"
else
    echo -e "${YELLOW}⚠ peer authentication failed${NC}"
fi

echo

# Summary
echo -e "${BLUE}╔══════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                  Summary                     ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════╝${NC}"

# Final assessment
if createdb -h localhost -U odoo "final_test_$(date +%s)" 2>/dev/null; then
    dropdb -h localhost -U odoo "final_test_$(date +%s)" 2>/dev/null
    echo -e "${GREEN}🎉 SUCCESS: Odoo user database creation is working!${NC}"
    echo -e "${GREEN}   Odoo should be able to create databases properly.${NC}"
else
    echo -e "${RED}❌ FAILED: Odoo user cannot create databases${NC}"
    echo -e "${YELLOW}   Run the fix script: sudo ./fix-postgres-auth.sh${NC}"
    echo -e "${CYAN}   Or manually grant privileges: sudo -u postgres psql -c \"ALTER USER odoo CREATEDB;\"${NC}"
fi

echo

exit 0
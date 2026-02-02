#!/bin/bash
# PostgreSQL User Password Setup Script
# This script sets a password for the odoo PostgreSQL user

set -e  # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔐 PostgreSQL User Password Setup${NC}"
echo "=================================================="

# Function to generate random password
generate_password() {
    openssl rand -base64 12 | tr -d "=+/" | cut -c1-12
}

# Check if PostgreSQL is running
if ! systemctl is-active --quiet postgresql; then
    echo -e "${RED}❌ PostgreSQL is not running${NC}"
    echo "Starting PostgreSQL..."
    sudo systemctl start postgresql
fi

# Check if odoo user exists
if sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='odoo'" | grep -q 1; then
    echo -e "${GREEN}✓${NC} PostgreSQL user 'odoo' exists"
else
    echo -e "${YELLOW}⚠${NC} Creating PostgreSQL user 'odoo'..."
    sudo -u postgres createuser -d -R -S odoo
fi

# Ask for password or generate one
read -p "Enter password for odoo user (press Enter to generate random password): " USER_PASSWORD

if [[ -z "$USER_PASSWORD" ]]; then
    USER_PASSWORD=$(generate_password)
    echo -e "${YELLOW}Generated password:${NC} $USER_PASSWORD"
    echo -e "${BLUE}💡 Make sure to save this password!${NC}"
fi

# Set the password
echo -e "${BLUE}Setting password for odoo user...${NC}"
sudo -u postgres psql -c "ALTER USER odoo PASSWORD '$USER_PASSWORD';"

# Update odoo.conf if it exists
ODOO_CONF="/etc/odoo/odoo.conf"
if [[ -f "$ODOO_CONF" ]]; then
    echo -e "${BLUE}Updating odoo.conf with new password...${NC}"
    
    # Backup original config
    sudo cp "$ODOO_CONF" "${ODOO_CONF}.bak.$(date +%Y%m%d_%H%M%S)"
    
    # Update database configuration
    if grep -q "^db_password" "$ODOO_CONF"; then
        sudo sed -i "s|^db_password.*|db_password = $USER_PASSWORD|" "$ODOO_CONF"
    else
        echo "db_password = $USER_PASSWORD" | sudo tee -a "$ODOO_CONF"
    fi
    
    # Ensure database connection settings are correct for localhost
    if ! grep -q "^db_host" "$ODOO_CONF"; then
        echo "db_host = localhost" | sudo tee -a "$ODOO_CONF"
    fi
    
    if ! grep -q "^db_port" "$ODOO_CONF"; then
        echo "db_port = 5432" | sudo tee -a "$ODOO_CONF"
    fi
    
    if ! grep -q "^db_user" "$ODOO_CONF"; then
        echo "db_user = odoo" | sudo tee -a "$ODOO_CONF"
    fi
    
    echo -e "${GREEN}✓${NC} Updated $ODOO_CONF"
fi

# Test connection
echo -e "${BLUE}Testing database connection...${NC}"
if PGPASSWORD="$USER_PASSWORD" psql -h localhost -U odoo -d postgres -c "SELECT version();" > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Database connection successful"
else
    echo -e "${RED}❌ Database connection failed${NC}"
    echo "You may need to adjust pg_hba.conf for network connections"
fi

echo
echo -e "${GREEN}🎉 Password setup completed!${NC}"
echo
echo -e "${BLUE}Database Connection Details:${NC}"
echo "Host: localhost"
echo "Port: 5432"
echo "User: odoo"
echo "Password: $USER_PASSWORD"
echo
echo -e "${BLUE}Test manually:${NC}"
echo "PGPASSWORD='$USER_PASSWORD' psql -h localhost -U odoo -d postgres"
echo
echo -e "${YELLOW}⚠${NC} Save the password securely!"
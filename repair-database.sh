#!/bin/bash

# Odoo Database Connection Repair Script
# Repariert Datenbankverbindungsprobleme nach fehlgeschlagener Installation

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}Odoo Database Connection Repair${NC}"
echo -e "${BLUE}===============================${NC}"
echo

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}This script must be run as root or with sudo${NC}"
    exit 1
fi

# Find Odoo configuration file
CONFIG_LOCATIONS=(
    "/etc/odoo/odoo.conf"
    "/etc/odoo.conf"
    "/opt/odoo/odoo.conf"
)

ODOO_CONFIG=""
for config in "${CONFIG_LOCATIONS[@]}"; do
    if [[ -f "$config" ]]; then
        ODOO_CONFIG="$config"
        echo -e "${GREEN}Found Odoo config:${NC} $config"
        break
    fi
done

if [[ -z "$ODOO_CONFIG" ]]; then
    echo -e "${RED}No Odoo configuration file found!${NC}"
    exit 1
fi

# Stop Odoo service
echo -e "${BLUE}Stopping Odoo service...${NC}"
systemctl stop odoo 2>/dev/null || true

# Find backup configurations
echo -e "${BLUE}Looking for backup configurations...${NC}"
BACKUP_CONFIGS=$(find /etc/odoo/ /opt/ -name "odoo.conf.*backup*" -o -name "odoo.conf.*pre-upgrade*" 2>/dev/null | sort -r)

if [[ -n "$BACKUP_CONFIGS" ]]; then
    echo -e "${GREEN}Found backup configurations:${NC}"
    echo "$BACKUP_CONFIGS" | nl
    echo
    
    read -p "Restore from backup? (1-$(echo "$BACKUP_CONFIGS" | wc -l) or 'n' to manually fix): " choice
    
    if [[ "$choice" =~ ^[0-9]+$ ]]; then
        SELECTED_BACKUP=$(echo "$BACKUP_CONFIGS" | sed -n "${choice}p")
        if [[ -f "$SELECTED_BACKUP" ]]; then
            echo -e "${BLUE}Restoring configuration from:${NC} $SELECTED_BACKUP"
            cp "$SELECTED_BACKUP" "$ODOO_CONFIG"
            echo -e "${GREEN}Configuration restored!${NC}"
            
            # Start Odoo service
            echo -e "${BLUE}Starting Odoo service...${NC}"
            systemctl start odoo
            sleep 5
            
            if systemctl is-active --quiet odoo; then
                echo -e "${GREEN}✓ Odoo service is running${NC}"
                
                # Test connection
                if curl -s -o /dev/null -w "%{http_code}" http://localhost:8069 | grep -q "200\|302"; then
                    echo -e "${GREEN}✓ Odoo is responding on http://localhost:8069${NC}"
                    echo -e "${GREEN}🎉 Repair completed successfully!${NC}"
                    exit 0
                else
                    echo -e "${YELLOW}⚠ Odoo started but may not be fully responsive yet${NC}"
                    echo -e "${BLUE}Check logs: journalctl -u odoo -f${NC}"
                fi
            else
                echo -e "${YELLOW}⚠ Odoo service may not have started correctly${NC}"
            fi
        fi
    fi
fi

echo -e "${BLUE}Manual repair process...${NC}"

# Get database user from config
DB_USER=$(grep -E "^[[:space:]]*db_user[[:space:]]*=" "$ODOO_CONFIG" | cut -d'=' -f2 | tr -d ' ' | tr -d '"' | tr -d "'")
if [[ -z "$DB_USER" ]]; then
    DB_USER="odoo"
fi

echo -e "${BLUE}Database user:${NC} $DB_USER"

# Option 1: Try peer authentication (no password)
echo -e "${BLUE}Option 1: Trying peer authentication...${NC}"
if sudo -u postgres psql -c "ALTER USER $DB_USER PASSWORD NULL;" 2>/dev/null; then
    echo -e "${GREEN}✓ Removed password for database user${NC}"
    
    # Update config for peer authentication
    sed -i "s/db_password = .*/db_password = False/" "$ODOO_CONFIG"
    sed -i "s/db_host = .*/db_host = /" "$ODOO_CONFIG"
    
    echo -e "${GREEN}✓ Updated configuration for peer authentication${NC}"
    
    # Test connection
    if sudo -u "$DB_USER" psql -c "\l" postgres &>/dev/null; then
        echo -e "${GREEN}✓ Database connection working!${NC}"
        
        # Start Odoo
        systemctl start odoo
        sleep 5
        
        if systemctl is-active --quiet odoo; then
            echo -e "${GREEN}✓ Odoo service started successfully${NC}"
            echo -e "${GREEN}🎉 Repair completed with peer authentication!${NC}"
            exit 0
        fi
    fi
fi

# Option 2: Set new password and update config
echo -e "${BLUE}Option 2: Setting new password...${NC}"

# Generate new password
NEW_PASSWORD=$(openssl rand -base64 32)

# Set new password
if sudo -u postgres psql -c "ALTER USER $DB_USER PASSWORD '$NEW_PASSWORD';" 2>/dev/null; then
    echo -e "${GREEN}✓ Set new database password${NC}"
    
    # Update config
    sed -i "s/db_password = .*/db_password = $NEW_PASSWORD/" "$ODOO_CONFIG"
    sed -i "s/db_host = .*/db_host = localhost/" "$ODOO_CONFIG"
    
    echo -e "${GREEN}✓ Updated configuration with new password${NC}"
    
    # Test connection
    if PGPASSWORD="$NEW_PASSWORD" psql -h localhost -U "$DB_USER" -c "\l" postgres &>/dev/null; then
        echo -e "${GREEN}✓ Database connection working!${NC}"
        
        # Start Odoo
        systemctl start odoo
        sleep 5
        
        if systemctl is-active --quiet odoo; then
            echo -e "${GREEN}✓ Odoo service started successfully${NC}"
            echo -e "${GREEN}🎉 Repair completed with new password!${NC}"
            exit 0
        fi
    fi
fi

# Option 3: Manual intervention required
echo -e "${RED}❌ Automatic repair failed${NC}"
echo -e "${YELLOW}Manual intervention required:${NC}"
echo
echo -e "${BLUE}1. Check PostgreSQL status:${NC}"
echo "   sudo systemctl status postgresql"
echo
echo -e "${BLUE}2. Check database users:${NC}"
echo "   sudo -u postgres psql -c \"\\du\""
echo
echo -e "${BLUE}3. Reset database password:${NC}"
echo "   sudo -u postgres psql"
echo "   ALTER USER $DB_USER PASSWORD 'your_password';"
echo "   \\q"
echo
echo -e "${BLUE}4. Update Odoo config:${NC}"
echo "   sudo nano $ODOO_CONFIG"
echo "   # Set db_password = your_password"
echo
echo -e "${BLUE}5. Start Odoo:${NC}"
echo "   sudo systemctl start odoo"
echo
echo -e "${BLUE}Current config file:${NC} $ODOO_CONFIG"
echo -e "${BLUE}Check Odoo logs:${NC} sudo journalctl -u odoo -f"
echo

exit 1
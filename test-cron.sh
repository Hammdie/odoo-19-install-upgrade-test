#!/bin/bash

# Test Cron Installation Script
# Überprüft und repariert die Cron-Konfiguration

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PROJECT_ROOT="/workspaces/odoo-upgrade-cron"
CRON_CONFIG="$PROJECT_ROOT/config/crontab"

echo -e "${BLUE}Cron Installation Test & Repair${NC}"
echo -e "${BLUE}===============================${NC}"
echo

# Check if running as root or with sudo for cron operations
if [[ $EUID -ne 0 ]]; then
    echo -e "${YELLOW}Note: Some cron operations may require sudo${NC}"
fi

# 1. Check if cron service is running
echo -e "${BLUE}1. Checking cron service status...${NC}"
if systemctl is-active --quiet cron 2>/dev/null || systemctl is-active --quiet crond 2>/dev/null; then
    echo -e "${GREEN}✓ Cron service is running${NC}"
else
    echo -e "${RED}✗ Cron service is not running${NC}"
    echo "  Starting cron service..."
    if command -v systemctl &> /dev/null; then
        sudo systemctl start cron 2>/dev/null || sudo systemctl start crond 2>/dev/null
        echo -e "${GREEN}✓ Cron service started${NC}"
    fi
fi

# 2. Check crontab configuration file
echo -e "\n${BLUE}2. Checking crontab configuration...${NC}"
if [[ -f "$CRON_CONFIG" ]]; then
    echo -e "${GREEN}✓ Crontab config file exists${NC}"
    
    # Check if file ends with newline
    if [[ -n $(tail -c1 "$CRON_CONFIG") ]]; then
        echo -e "${YELLOW}⚠ Crontab file missing final newline - fixing...${NC}"
        echo "" >> "$CRON_CONFIG"
        echo -e "${GREEN}✓ Added missing newline${NC}"
    else
        echo -e "${GREEN}✓ Crontab file properly formatted${NC}"
    fi
else
    echo -e "${RED}✗ Crontab config file missing${NC}"
    echo "  Creating default crontab..."
    mkdir -p "$(dirname "$CRON_CONFIG")"
    
    cat > "$CRON_CONFIG" << 'EOF'
# Odoo Upgrade Cron Jobs
# These cron jobs handle automatic updates and maintenance

# Daily system maintenance at 2:00 AM
0 2 * * * /workspaces/odoo-upgrade-cron/scripts/daily-maintenance.sh >> /var/log/odoo-upgrade/daily.log 2>&1

# Weekly Odoo updates on Sunday at 3:00 AM
0 3 * * 0 /workspaces/odoo-upgrade-cron/scripts/weekly-odoo-update.sh >> /var/log/odoo-upgrade/weekly.log 2>&1

# Database backup every day at 1:30 AM
30 1 * * * /workspaces/odoo-upgrade-cron/scripts/backup-odoo.sh --auto >> /var/log/odoo-upgrade/backup.log 2>&1

# System monitoring every hour
0 * * * * /workspaces/odoo-upgrade-cron/scripts/monitor-system.sh >> /var/log/odoo-upgrade/monitor.log 2>&1

# Clean old log files every month on the 1st at midnight
0 0 1 * * find /var/log/odoo-upgrade -name "*.log" -mtime +30 -delete

# Clean old backup files every week (keep 4 weeks)
0 4 * * 0 find /workspaces/odoo-upgrade-cron/backups -name "*.sql" -mtime +28 -delete

EOF
    echo -e "${GREEN}✓ Default crontab created${NC}"
fi

# 3. Test crontab installation
echo -e "\n${BLUE}3. Testing crontab installation...${NC}"

# Create temp crontab with proper formatting
temp_crontab="/tmp/test-crontab-$(date +%s)"
cp "$CRON_CONFIG" "$temp_crontab"

# Ensure it ends with newline
echo "" >> "$temp_crontab"

# Test installation
if crontab "$temp_crontab" 2>/dev/null; then
    echo -e "${GREEN}✓ Crontab installation successful${NC}"
else
    echo -e "${RED}✗ Crontab installation failed${NC}"
    echo "  Checking crontab syntax..."
    crontab -l > /dev/null 2>&1 || echo -e "${YELLOW}  No existing crontab found${NC}"
fi

# Clean up
rm -f "$temp_crontab"

# 4. Verify current crontab
echo -e "\n${BLUE}4. Current crontab status...${NC}"
if crontab -l > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Crontab is installed${NC}"
    echo -e "${BLUE}Active cron jobs:${NC}"
    crontab -l | grep -v "^#" | grep -v "^$" | while read line; do
        echo "  • $line"
    done
else
    echo -e "${RED}✗ No crontab installed${NC}"
fi

# 5. Check log directories
echo -e "\n${BLUE}5. Checking log directories...${NC}"
if [[ -d "/var/log/odoo-upgrade" ]]; then
    echo -e "${GREEN}✓ Log directory exists${NC}"
else
    echo -e "${YELLOW}⚠ Log directory missing - creating...${NC}"
    sudo mkdir -p /var/log/odoo-upgrade
    sudo chown $(whoami):$(whoami) /var/log/odoo-upgrade
    echo -e "${GREEN}✓ Log directory created${NC}"
fi

# 6. Check script permissions
echo -e "\n${BLUE}6. Checking script permissions...${NC}"
for script in daily-maintenance.sh weekly-odoo-update.sh backup-odoo.sh monitor-system.sh; do
    script_path="$PROJECT_ROOT/scripts/$script"
    if [[ -f "$script_path" ]]; then
        if [[ -x "$script_path" ]]; then
            echo -e "${GREEN}✓ $script is executable${NC}"
        else
            echo -e "${YELLOW}⚠ $script not executable - fixing...${NC}"
            chmod +x "$script_path"
            echo -e "${GREEN}✓ Made $script executable${NC}"
        fi
    else
        echo -e "${RED}✗ $script missing${NC}"
    fi
done

echo
echo -e "${GREEN}🎉 Cron setup verification completed!${NC}"
echo
echo -e "${BLUE}To manually install the crontab:${NC}"
echo "sudo $PROJECT_ROOT/scripts/setup-cron.sh"
echo
echo -e "${BLUE}To check cron logs:${NC}"
echo "sudo tail -f /var/log/syslog | grep CRON"
echo "ls -la /var/log/odoo-upgrade/"

exit 0
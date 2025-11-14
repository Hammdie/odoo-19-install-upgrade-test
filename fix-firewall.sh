#!/bin/bash

# Quick Firewall Fix Script
# Öffnet HTTP/HTTPS Ports die möglicherweise blockiert wurden

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}Firewall Quick Fix${NC}"
echo -e "${BLUE}=================${NC}"
echo

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}This script must be run as root or with sudo${NC}"
    exit 1
fi

# Check if UFW is installed and active
if ! command -v ufw &> /dev/null; then
    echo -e "${YELLOW}UFW not installed - no firewall changes needed${NC}"
    exit 0
fi

# Check UFW status
if ! ufw status | grep -q "Status: active"; then
    echo -e "${YELLOW}UFW is not active - no firewall changes needed${NC}"
    exit 0
fi

echo -e "${BLUE}Current UFW status:${NC}"
ufw status numbered
echo

# Add missing HTTP/HTTPS rules
echo -e "${BLUE}Adding HTTP and HTTPS ports...${NC}"

# Allow HTTP (port 80)
if ! ufw status | grep -q "80/tcp"; then
    ufw allow 80/tcp comment 'HTTP'
    echo -e "${GREEN}✓ Added HTTP (port 80)${NC}"
else
    echo -e "${YELLOW}⚠ HTTP (port 80) already allowed${NC}"
fi

# Allow HTTPS (port 443)
if ! ufw status | grep -q "443/tcp"; then
    ufw allow 443/tcp comment 'HTTPS'
    echo -e "${GREEN}✓ Added HTTPS (port 443)${NC}"
else
    echo -e "${YELLOW}⚠ HTTPS (port 443) already allowed${NC}"
fi

# Ensure SSH is allowed
if ! ufw status | grep -q "22/tcp\|OpenSSH\|ssh"; then
    ufw allow ssh
    echo -e "${GREEN}✓ Added SSH access${NC}"
else
    echo -e "${GREEN}✓ SSH access already allowed${NC}"
fi

# Ensure Odoo ports are allowed
if ! ufw status | grep -q "8069"; then
    ufw allow 8069/tcp comment 'Odoo HTTP'
    echo -e "${GREEN}✓ Added Odoo HTTP (port 8069)${NC}"
else
    echo -e "${GREEN}✓ Odoo HTTP (port 8069) already allowed${NC}"
fi

if ! ufw status | grep -q "8072"; then
    ufw allow 8072/tcp comment 'Odoo Longpolling'
    echo -e "${GREEN}✓ Added Odoo Longpolling (port 8072)${NC}"
else
    echo -e "${GREEN}✓ Odoo Longpolling (port 8072) already allowed${NC}"
fi

echo
echo -e "${BLUE}Updated UFW status:${NC}"
ufw status numbered

echo
echo -e "${GREEN}🎉 Firewall configuration updated!${NC}"
echo
echo -e "${BLUE}Open ports:${NC}"
echo -e "• ${GREEN}Port 22${NC}   - SSH"
echo -e "• ${GREEN}Port 80${NC}   - HTTP"
echo -e "• ${GREEN}Port 443${NC}  - HTTPS"
echo -e "• ${GREEN}Port 8069${NC} - Odoo Web Interface"
echo -e "• ${GREEN}Port 8072${NC} - Odoo Longpolling"
echo

# Test connectivity
echo -e "${BLUE}Testing connectivity...${NC}"

# Test if ports are listening
if netstat -tuln 2>/dev/null | grep -q ":80 "; then
    echo -e "${GREEN}✓ HTTP service listening on port 80${NC}"
elif ss -tuln 2>/dev/null | grep -q ":80 "; then
    echo -e "${GREEN}✓ HTTP service listening on port 80${NC}"
else
    echo -e "${YELLOW}⚠ No service listening on port 80${NC}"
fi

if netstat -tuln 2>/dev/null | grep -q ":443 "; then
    echo -e "${GREEN}✓ HTTPS service listening on port 443${NC}"
elif ss -tuln 2>/dev/null | grep -q ":443 "; then
    echo -e "${GREEN}✓ HTTPS service listening on port 443${NC}"
else
    echo -e "${YELLOW}⚠ No service listening on port 443${NC}"
fi

if netstat -tuln 2>/dev/null | grep -q ":8069 "; then
    echo -e "${GREEN}✓ Odoo service listening on port 8069${NC}"
elif ss -tuln 2>/dev/null | grep -q ":8069 "; then
    echo -e "${GREEN}✓ Odoo service listening on port 8069${NC}"
else
    echo -e "${YELLOW}⚠ No service listening on port 8069 (Odoo may not be running)${NC}"
fi

echo
echo -e "${BLUE}If you're still having connectivity issues:${NC}"
echo -e "${YELLOW}1.${NC} Check if services are running:"
echo "   sudo systemctl status nginx    # for HTTP/HTTPS"
echo "   sudo systemctl status odoo     # for Odoo"
echo
echo -e "${YELLOW}2.${NC} Check service logs:"
echo "   sudo journalctl -u nginx -f"
echo "   sudo journalctl -u odoo -f"
echo
echo -e "${YELLOW}3.${NC} Test local connectivity:"
echo "   curl -I http://localhost"
echo "   curl -I http://localhost:8069"
echo

exit 0
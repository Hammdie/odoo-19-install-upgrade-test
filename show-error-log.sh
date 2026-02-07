#!/bin/bash

# Error Log Viewer Script
# Zeigt die neueste Error-Log Datei für Support-Zwecke

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

LOG_DIR="/var/log/odoo-upgrade"

echo -e "${BLUE}${BOLD}"
cat << 'EOF'
╔═══════════════════════════════════════════════════╗
║            Error Log Viewer for Support          ║
╚═══════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

if [[ ! -d "$LOG_DIR" ]]; then
    echo -e "${RED}❌ Log directory not found: $LOG_DIR${NC}"
    exit 1
fi

# Find latest error log
LATEST_ERROR_LOG=$(ls -t "$LOG_DIR"/error-*.log 2>/dev/null | head -1)

if [[ -z "$LATEST_ERROR_LOG" ]]; then
    echo -e "${YELLOW}ℹ️  No error logs found${NC}"
    echo -e "${BLUE}Looking for installation logs instead...${NC}"
    
    LATEST_INSTALL_LOG=$(ls -t "$LOG_DIR"/install-*.log 2>/dev/null | head -1)
    if [[ -n "$LATEST_INSTALL_LOG" ]]; then
        echo -e "${GREEN}📄 Latest installation log:${NC} $LATEST_INSTALL_LOG"
        echo -e "${YELLOW}Last 50 lines:${NC}"
        echo "----------------------------------------"
        tail -50 "$LATEST_INSTALL_LOG"
    else
        echo -e "${YELLOW}ℹ️  No logs found at all${NC}"
    fi
    exit 0
fi

echo -e "${GREEN}📄 Latest error log:${NC} $LATEST_ERROR_LOG"
echo -e "${BLUE}File size:${NC} $(du -h "$LATEST_ERROR_LOG" | cut -f1)"
echo -e "${BLUE}Created:${NC} $(ls -la "$LATEST_ERROR_LOG" | awk '{print $6, $7, $8}')"

echo
echo -e "${YELLOW}${BOLD}ERROR LOG CONTENT:${NC}"
echo "======================================================="

if [[ -s "$LATEST_ERROR_LOG" ]]; then
    cat "$LATEST_ERROR_LOG"
else
    echo -e "${YELLOW}(Error log is empty)${NC}"
fi

echo "======================================================="
echo
echo -e "${BLUE}${BOLD}📋 SUPPORT INFORMATION:${NC}"
echo -e "${GREEN}1. Send this file to support: ${BOLD}$LATEST_ERROR_LOG${NC}"
echo -e "${GREEN}2. System info: ${NC}$(uname -a)"
echo -e "${GREEN}3. Available logs:${NC}"
ls -la "$LOG_DIR"/ | tail -n +2

echo
echo -e "${YELLOW}💡 To copy error log:${NC}"
echo -e "${BLUE}  cat $LATEST_ERROR_LOG${NC}"
echo
echo -e "${YELLOW}💡 To send via email/chat:${NC}"
echo -e "${BLUE}  Copy the content above and include system information${NC}"
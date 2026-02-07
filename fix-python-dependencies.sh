#!/bin/bash

# Quick fix for missing Python dependencies in Odoo installation
# This script addresses the common zope.event and other dependency issues

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# Logging
log() {
    local level=$1
    shift
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case $level in
        "ERROR")
            echo -e "${RED}[ERROR]${NC} $message" >&2
            ;;
        "WARN")
            echo -e "${YELLOW}[WARN]${NC} $message"
            ;;
        "INFO")
            echo -e "${BLUE}[INFO]${NC} $message"
            ;;
        "SUCCESS")
            echo -e "${GREEN}[SUCCESS]${NC} $message"
            ;;
    esac
}

echo -e "${BLUE}${BOLD}"
cat << 'EOF'
═══════════════════════════════════════════════════════
   Odoo Dependencies Quick Fix
═══════════════════════════════════════════════════════
EOF
echo -e "${NC}"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    log "ERROR" "This script must be run as root or with sudo"
    echo -e "${RED}Please run: sudo $0${NC}"
    exit 1
fi

# Force install critical dependencies
log "INFO" "Installing critical Odoo dependencies with --break-system-packages..."

# Critical dependencies that often fail
critical_deps=(
    "zope.event"
    "zope.interface"
    "passlib"
    "psycopg2-binary"
    "lxml<5"
    "werkzeug"
    "Pillow"
    "babel"
    "gevent"
    "greenlet"
    "python-dateutil"
    "requests"
    "setuptools"
    "wheel"
    "pip"
)

# Update pip first
log "INFO" "Updating pip..."
python3 -m pip install --break-system-packages --upgrade pip

# Install each dependency with force
for dep in "${critical_deps[@]}"; do
    log "INFO" "Force installing: $dep"
    if python3 -m pip install --break-system-packages --force-reinstall "$dep"; then
        log "SUCCESS" "✓ $dep installed successfully"
    else
        log "ERROR" "✗ Failed to install: $dep"
    fi
done

# Verify installations
log "INFO" "Verifying dependency installations..."
verification_failed=false

declare -A import_names=(
    ["zope.event"]="zope.event"
    ["zope.interface"]="zope.interface"
    ["passlib"]="passlib"
    ["psycopg2-binary"]="psycopg2"
    ["lxml"]="lxml"
    ["werkzeug"]="werkzeug"
    ["Pillow"]="PIL"
    ["babel"]="babel"
    ["gevent"]="gevent"
    ["greenlet"]="greenlet"
    ["python-dateutil"]="dateutil"
    ["requests"]="requests"
)

for dep in "${!import_names[@]}"; do
    import_name="${import_names[$dep]}"
    if python3 -c "import $import_name" 2>/dev/null; then
        log "SUCCESS" "✓ $dep verified (import: $import_name)"
    else
        log "ERROR" "✗ $dep verification failed (import: $import_name)"
        verification_failed=true
    fi
done

# Install from Odoo requirements if available
if [[ -f "/opt/odoo/odoo/requirements.txt" ]]; then
    log "INFO" "Installing from Odoo requirements.txt..."
    python3 -m pip install --break-system-packages -r /opt/odoo/odoo/requirements.txt || log "WARN" "Some requirements may have failed"
fi

# Final status
echo
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
if [[ "$verification_failed" == "true" ]]; then
    echo -e "${RED}${BOLD}❌ Some dependencies still missing!${NC}"
    echo -e "${YELLOW}Try running the full installation again:${NC}"
    echo -e "${GREEN}  sudo ./install.sh --auto --force${NC}"
else
    echo -e "${GREEN}${BOLD}✅ All critical dependencies installed successfully!${NC}"
    echo -e "${YELLOW}You can now retry the Odoo installation:${NC}"
    echo -e "${GREEN}  sudo ./install.sh --auto${NC}"
fi
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
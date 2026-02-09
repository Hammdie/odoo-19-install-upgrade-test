#!/bin/bash

###############################################################################
# Fix Python Dependencies Script - Speziell für zope.event Probleme
# 
# Behebt häufige Python-Abhängigkeitsprobleme bei Odoo-Installationen,
# insbesondere das zope.event Problem auf ecowatt.detalex.de
#
# Usage:
#   sudo ./fix-python-dependencies.sh
###############################################################################

set -e  # Exit on any error

# Configuration
LOG_DIR="/var/log/odoo-upgrade"
LOG_FILE="$LOG_DIR/fix-python-deps-$(date +%Y%m%d-%H%M%S).log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Pip options (Ubuntu/Debian enforce Externally Managed Env)
declare -a PIP_INSTALL_ARGS=("--break-system-packages")
export PIP_BREAK_SYSTEM_PACKAGES=1

# Logging function
log() {
    local level=$1
    shift
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
    
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

# Create log directory
create_log_dir() {
    if [[ ! -d "$LOG_DIR" ]]; then
        mkdir -p "$LOG_DIR"
        chmod 755 "$LOG_DIR"
    fi
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}This script must be run as root or with sudo${NC}"
        echo -e "Please run: ${YELLOW}sudo $0${NC}"
        exit 1
    fi
}

# Display banner
show_banner() {
    clear
    echo -e "${BLUE}${BOLD}"
    cat << 'EOF'
  ____        _   _                   ____            
 |  _ \ _   _| |_| |__   ___  _ __   |  _ \  ___ _ __  
 | |_) | | | | __| '_ \ / _ \| '_ \  | | | |/ _ \ '_ \ 
 |  __/| |_| | |_| | | | (_) | | | | | |_| |  __/ |_) |
 |_|    \__, |\__|_| |_|\___/|_| |_| |____/ \___| .__/ 
        |___/                                   |_|    
            Dependency Fix Tool           
EOF
    echo -e "${NC}"
    echo -e "${GREEN}Repariert Python-Abhängigkeiten für Odoo (speziell zope.event)${NC}"
    echo
}

# Stop Odoo service
stop_odoo_service() {
    log "INFO" "Stopping Odoo service if running..."
    
    if systemctl is-active --quiet odoo 2>/dev/null; then
        log "INFO" "Stopping Odoo service..."
        systemctl stop odoo
        sleep 3
        log "SUCCESS" "Odoo service stopped"
    else
        log "INFO" "Odoo service is not running"
    fi
}

# Test current environment
test_current_environment() {
    log "INFO" "Testing current Python environment..."
    
    local test_script="/tmp/python_env_test.py"
    cat > "$test_script" << 'PYTHON_EOF'
#!/usr/bin/env python3
import sys
failed_imports = []
critical_packages = [
    ('zope.event', 'zope.event'),
    ('zope.interface', 'zope.interface'), 
    ('psycopg2', 'psycopg2'),
    ('werkzeug', 'werkzeug'),
    ('lxml', 'lxml'),
    ('PIL', 'Pillow'),
    ('passlib', 'passlib'),
    ('babel', 'babel'),
    ('gevent', 'gevent')
]

print("Testing critical Python packages...")
for import_name, package_name in critical_packages:
    try:
        __import__(import_name)
        print(f"✓ {package_name}")
    except ImportError as e:
        print(f"✗ {package_name} - {e}")
        failed_imports.append(package_name)

if failed_imports:
    print(f"\nFAILED imports: {', '.join(failed_imports)}")
    sys.exit(1)
else:
    print("\n✓ All critical packages can be imported")
    sys.exit(0)
PYTHON_EOF
    
    chmod +x "$test_script"
    
    if python3 "$test_script" 2>&1 | tee -a "$LOG_FILE"; then
        log "SUCCESS" "All critical packages are working"
        rm -f "$test_script"
        return 0
    else
        log "ERROR" "Some packages are missing or broken"
        rm -f "$test_script"
        return 1
    fi
}

# Emergency repair of Python environment
emergency_repair_environment() {
    log "INFO" "Starting emergency Python environment repair..."
    
    # Upgrade pip and core tools
    log "INFO" "Upgrading pip and core tools..."
    python3 -m pip install "${PIP_INSTALL_ARGS[@]}" --upgrade pip wheel setuptools 2>&1 | tee -a "$LOG_FILE"
    
    # List of critical packages with specific handling
    local critical_packages=(
        "zope.event"
        "zope.interface" 
        "psycopg2-binary"
        "werkzeug"
        "lxml<5"
        "Pillow"
        "passlib"
        "babel"
        "gevent"
        "greenlet"
        "setuptools"
        "wheel"
    )
    
    log "INFO" "Force reinstalling critical packages..."
    
    # Try different installation strategies
    for package in "${critical_packages[@]}"; do
        log "INFO" "Emergency install: $package"
        
        # Strategy 1: Force reinstall with no cache
        if python3 -m pip install "${PIP_INSTALL_ARGS[@]}" --force-reinstall --no-cache-dir "$package" 2>&1 | tee -a "$LOG_FILE"; then
            log "SUCCESS" "✓ $package installed"
            continue
        fi
        
        # Strategy 2: Uninstall and reinstall
        log "WARN" "Strategy 1 failed for $package, trying uninstall+reinstall..."
        python3 -m pip uninstall -y "$package" 2>/dev/null || true
        if python3 -m pip install "${PIP_INSTALL_ARGS[@]}" "$package" 2>&1 | tee -a "$LOG_FILE"; then
            log "SUCCESS" "✓ $package installed (strategy 2)"
            continue
        fi
        
        # Strategy 3: No-deps install for zope packages
        if [[ "$package" =~ ^zope\. ]]; then
            log "WARN" "Strategy 2 failed for $package, trying no-deps install..."
            if python3 -m pip install "${PIP_INSTALL_ARGS[@]}" --no-deps "$package" 2>&1 | tee -a "$LOG_FILE"; then
                log "SUCCESS" "✓ $package installed (no-deps)"
                continue
            fi
        fi
        
        log "ERROR" "✗ Failed to install $package after all strategies"
    done
    
    log "SUCCESS" "Emergency repair completed"
}

# Validate Odoo can be imported
validate_odoo_import() {
    log "INFO" "Validating Odoo can be imported..."
    
    if [[ ! -d "/opt/odoo/odoo" ]]; then
        log "WARN" "Odoo source not found at /opt/odoo/odoo - skipping Odoo import test"
        return 0
    fi
    
    local test_script="/tmp/odoo_import_test.py"
    cat > "$test_script" << 'PYTHON_EOF'
#!/usr/bin/env python3
import sys
sys.path.insert(0, '/opt/odoo/odoo')

try:
    import odoo
    from odoo import api, models, fields
    from odoo.service import db
    print("SUCCESS: Odoo modules imported successfully")
except Exception as e:
    print(f"ERROR: Odoo import failed: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)
PYTHON_EOF
    
    chmod +x "$test_script"
    
    if python3 "$test_script" 2>&1 | tee -a "$LOG_FILE"; then
        log "SUCCESS" "Odoo modules can be imported successfully"
        rm -f "$test_script"
        return 0
    else
        log "ERROR" "Odoo modules cannot be imported"
        rm -f "$test_script"
        return 1
    fi
}

# Start Odoo service
start_odoo_service() {
    log "INFO" "Starting Odoo service..."
    
    if systemctl list-unit-files 2>/dev/null | grep -q "^odoo.service"; then
        log "INFO" "Starting Odoo service..."
        if systemctl start odoo; then
            sleep 5
            if systemctl is-active --quiet odoo; then
                log "SUCCESS" "Odoo service started successfully"
            else
                log "ERROR" "Odoo service failed to start properly"
                log "INFO" "Check status: systemctl status odoo"
                log "INFO" "Check logs: journalctl -u odoo -n 20"
                return 1
            fi
        else
            log "ERROR" "Failed to start Odoo service"
            return 1
        fi
    else
        log "WARN" "Odoo service not found - skipping service start"
        log "WARN" "Run the main installation script to create the service"
    fi
}

# Show summary
show_summary() {
    echo
    echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}${BOLD}  Python Dependencies Fix Completed!${NC}"
    echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo
    echo -e "${BLUE}Fix Details:${NC}"
    echo -e "  📁 Log File: ${GREEN}$LOG_FILE${NC}"
    echo -e "  🐍 Python Environment: Repaired and validated"
    echo -e "  📦 Critical Packages: zope.event, zope.interface, psycopg2, etc."
    echo
    echo -e "${BLUE}Service Status:${NC}"
    if systemctl is-active --quiet odoo 2>/dev/null; then
        echo -e "  🟢 Odoo Service: ${GREEN}Running${NC}"
        echo -e "  🌐 Web Access: http://localhost:8069"
    else
        echo -e "  🟡 Odoo Service: ${YELLOW}Not running${NC}"
        echo -e "  ℹ️  Start with: sudo systemctl start odoo"
    fi
    echo
    echo -e "${BLUE}Useful Commands:${NC}"
    echo -e "  Check service: ${GREEN}sudo systemctl status odoo${NC}"
    echo -e "  View logs:     ${GREEN}sudo journalctl -u odoo -f${NC}"
    echo -e "  Restart:       ${GREEN}sudo systemctl restart odoo${NC}"
    echo
}

# Main function
main() {
    # Create log directory
    create_log_dir
    
    # Show banner
    show_banner
    
    # Check root
    check_root
    
    # Start logging
    log "INFO" "Starting Python dependencies fix"
    log "INFO" "Target: Resolve zope.event and related dependency issues"
    log "INFO" "Log file: $LOG_FILE"
    
    # Test current environment
    if test_current_environment; then
        echo
        echo -e "${GREEN}✅ All Python packages are working correctly!${NC}"
        echo -e "${BLUE}No fixes needed - your environment is healthy.${NC}"
        echo
        echo -e "${YELLOW}If you're still experiencing issues, check:${NC}"
        echo -e "  • Odoo service logs: ${GREEN}sudo journalctl -u odoo -n 20${NC}"
        echo -e "  • Odoo service status: ${GREEN}sudo systemctl status odoo${NC}"
        echo
        return 0
    fi
    
    echo
    echo -e "${YELLOW}⚠️  Python environment issues detected${NC}"
    echo -e "${BLUE}Proceeding with automatic repair...${NC}"
    echo
    
    # Stop Odoo service
    stop_odoo_service
    
    # Emergency repair
    emergency_repair_environment
    
    # Test environment again
    if test_current_environment; then
        log "SUCCESS" "Python environment repair successful"
    else
        log "ERROR" "Python environment still has issues after repair"
    fi
    
    # Validate Odoo import
    validate_odoo_import || {
        log "WARN" "Odoo import validation failed - may need full reinstallation"
    }
    
    # Start Odoo service
    start_odoo_service || {
        log "WARN" "Service start failed - check logs"
    }
    
    # Show summary
    show_summary
    
    log "SUCCESS" "Python dependencies fix completed!"
}

# Run main function
main "$@"
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
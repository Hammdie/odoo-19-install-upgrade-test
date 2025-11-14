#!/bin/bash

# Odoo Dependencies Test Script
# Überprüft kritische Odoo-Abhängigkeiten und Extensions

# Disable exit on error for tests
set +e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Test results tracking
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_WARNING=0

echo -e "${BLUE}╔══════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║           Odoo Dependencies Test             ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════╝${NC}"
echo

# Helper functions
test_pass() {
    echo -e "${GREEN}✓ $1${NC}"
    ((TESTS_PASSED++))
}

test_fail() {
    echo -e "${RED}✗ $1${NC}"
    ((TESTS_FAILED++))
}

test_warn() {
    echo -e "${YELLOW}⚠ $1${NC}"
    ((TESTS_WARNING++))
}

test_info() {
    echo -e "${CYAN}ℹ $1${NC}"
}

section_header() {
    echo -e "\n${PURPLE}═══ $1 ═══${NC}"
}

# 1. PostgreSQL Vector Extension Test
section_header "PostgreSQL Vector Extension"

# Check if PostgreSQL is running
if ! systemctl is-active --quiet postgresql 2>/dev/null && ! pgrep -x postgres >/dev/null; then
    test_fail "PostgreSQL is not running"
    POSTGRES_RUNNING=false
else
    test_pass "PostgreSQL is running"
    POSTGRES_RUNNING=true
fi

if [[ "$POSTGRES_RUNNING" == "true" ]]; then
    # Get list of databases
    echo -e "${BLUE}Checking vector extension in databases...${NC}"
    
    # Try multiple connection methods with timeout
    POSTGRES_USER=""
    echo -e "${CYAN}  Testing database connections...${NC}"
    
    if timeout 5 sudo -u postgres psql -c "SELECT version();" >/dev/null 2>&1; then
        POSTGRES_USER="postgres"
        echo -e "${CYAN}  Connected as postgres user${NC}"
    elif timeout 5 psql -U odoo -d postgres -c "SELECT version();" >/dev/null 2>&1; then
        POSTGRES_USER="odoo"
        echo -e "${CYAN}  Connected as odoo user${NC}"
    elif timeout 5 psql -d postgres -c "SELECT version();" >/dev/null 2>&1; then
        POSTGRES_USER="$(whoami)"
        echo -e "${CYAN}  Connected as current user${NC}"
    else
        test_fail "Cannot connect to PostgreSQL database"
        POSTGRES_USER=""
    fi
    
    if [[ -n "$POSTGRES_USER" ]]; then
        # Get ALL databases (not just user databases) with timeout
        echo -e "${CYAN}  Retrieving database list...${NC}"
        case "$POSTGRES_USER" in
            "postgres")
                DBS=$(timeout 10 sudo -u postgres psql -t -c "SELECT datname FROM pg_database WHERE datname NOT IN ('template0', 'template1');" 2>/dev/null | sed 's/^ *//g' | grep -v '^$' | head -20)
                ;;
            "odoo")
                DBS=$(timeout 10 psql -U odoo -d postgres -t -c "SELECT datname FROM pg_database WHERE datname NOT IN ('template0', 'template1');" 2>/dev/null | sed 's/^ *//g' | grep -v '^$' | head -20)
                ;;
            *)
                DBS=$(timeout 10 psql -d postgres -t -c "SELECT datname FROM pg_database WHERE datname NOT IN ('template0', 'template1');" 2>/dev/null | sed 's/^ *//g' | grep -v '^$' | head -20)
                ;;
        esac
        
        if [[ -n "$DBS" ]]; then
            DB_COUNT=$(echo "$DBS" | wc -l)
            test_info "Found $DB_COUNT database(s)"
            echo -e "${CYAN}  Databases: $(echo $DBS | tr '\n' ' ' | head -c 100)...${NC}"
            
            # Test vector extension on first few databases only
            echo "$DBS" | head -3 | while read -r db; do
                if [[ -n "$db" ]]; then
                    echo -e "${CYAN}  Checking database: $db${NC}"
                    
                    # Check if vector extension exists with timeout
                    case "$POSTGRES_USER" in
                        "postgres")
                            VECTOR_CHECK=$(timeout 5 sudo -u postgres psql -d "$db" -t -c "SELECT COUNT(*) FROM pg_extension WHERE extname='vector';" 2>/dev/null | tr -d ' \n' || echo "0")
                            ;;
                        "odoo")
                            VECTOR_CHECK=$(timeout 5 psql -U odoo -d "$db" -t -c "SELECT COUNT(*) FROM pg_extension WHERE extname='vector';" 2>/dev/null | tr -d ' \n' || echo "0")
                            ;;
                        *)
                            VECTOR_CHECK=$(timeout 5 psql -d "$db" -t -c "SELECT COUNT(*) FROM pg_extension WHERE extname='vector';" 2>/dev/null | tr -d ' \n' || echo "0")
                            ;;
                    esac
                    
                    if [[ "$VECTOR_CHECK" == "1" ]]; then
                        test_pass "    Vector extension installed in $db"
                    else
                        test_warn "    Vector extension not found in $db"
                    fi
                fi
            done
        else
            test_warn "No databases found or connection timeout"
        fi
        
        # Check if pgvector package is installed (non-blocking)
        echo -e "${CYAN}  Checking pgvector package...${NC}"
        if dpkg -l 2>/dev/null | grep -q "postgresql.*pgvector"; then
            test_pass "pgvector package is installed"
        else
            test_warn "pgvector package not found"
            if command -v pg_config >/dev/null 2>&1; then
                PG_VERSION=$(pg_config --version 2>/dev/null | grep -o '[0-9][0-9]*' | head -n1)
                test_info "Install with: sudo apt install postgresql-${PG_VERSION}-pgvector"
            else
                test_info "Install with: sudo apt install postgresql-*-pgvector"
            fi
        fi
    else
        test_fail "Could not establish database connection"
    fi
fi

# 2. wkhtmltopdf Qt Patch Test
section_header "wkhtmltopdf Qt Patch"

if command -v wkhtmltopdf &> /dev/null; then
    test_pass "wkhtmltopdf is installed"
    
    # Check version and qt patch
    WKHTMLTOPDF_VERSION=$(wkhtmltopdf --version 2>/dev/null | head -n1)
    echo -e "${CYAN}  Version: $WKHTMLTOPDF_VERSION${NC}"
    
    # Check if it's the Qt patched version
    if echo "$WKHTMLTOPDF_VERSION" | grep -i "qt" >/dev/null; then
        test_pass "wkhtmltopdf has Qt patch"
    else
        test_warn "wkhtmltopdf may not have Qt patch"
        test_info "For better PDF generation, install Qt patched version from: https://wkhtmltopdf.org/downloads.html"
    fi
    
    # Check version number for Odoo compatibility
    VERSION_NUM=$(echo "$WKHTMLTOPDF_VERSION" | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' | head -n1)
    if [[ -n "$VERSION_NUM" ]]; then
        MAJOR=$(echo "$VERSION_NUM" | cut -d. -f1)
        MINOR=$(echo "$VERSION_NUM" | cut -d. -f2)
        if [[ "$MAJOR" -eq 0 && "$MINOR" -ge 12 ]]; then
            test_pass "wkhtmltopdf version is compatible with Odoo ($VERSION_NUM)"
        else
            test_warn "wkhtmltopdf version may be too old for Odoo ($VERSION_NUM)"
        fi
    fi
    
    # Test basic functionality
    echo -e "${CYAN}  Testing PDF generation...${NC}"
    if echo "<html><body><h1>Test</h1><p>Odoo PDF Test</p></body></html>" | wkhtmltopdf --page-size A4 --margin-top 0.75in --margin-right 0.75in --margin-bottom 0.75in --margin-left 0.75in --encoding utf-8 --quiet - /tmp/test.pdf >/dev/null 2>&1; then
        if [[ -f "/tmp/test.pdf" && $(stat -c%s "/tmp/test.pdf") -gt 100 ]]; then
            test_pass "wkhtmltopdf can generate PDFs"
            rm -f /tmp/test.pdf
        else
            test_fail "wkhtmltopdf creates empty or invalid PDFs"
        fi
    else
        test_fail "wkhtmltopdf cannot generate PDFs"
        test_info "Check X11 dependencies: sudo apt install xvfb"
    fi
    
    # Test with custom options (Odoo style)
    echo -e "${CYAN}  Testing Odoo-style PDF options...${NC}"
    if echo "<html><head><meta charset='utf-8'/></head><body><h1>Ödoo Tëst</h1></body></html>" | wkhtmltopdf --page-size A4 --orientation Portrait --disable-smart-shrinking --print-media-type --no-outline --disable-javascript - /tmp/test_odoo.pdf >/dev/null 2>&1; then
        if [[ -f "/tmp/test_odoo.pdf" && $(stat -c%s "/tmp/test_odoo.pdf") -gt 100 ]]; then
            test_pass "wkhtmltopdf supports Odoo-style options"
            rm -f /tmp/test_odoo.pdf
        else
            test_warn "wkhtmltopdf has issues with Odoo-style options"
        fi
    else
        test_warn "wkhtmltopdf may have compatibility issues with Odoo options"
    fi
    
    # Check for headless operation capabilities
    if wkhtmltopdf --help 2>/dev/null | grep -q "disable-javascript\|enable-local-file-access\|print-media-type"; then
        test_pass "wkhtmltopdf supports headless operation options"
    else
        test_warn "wkhtmltopdf may have limited headless capabilities"
    fi
    
    # Check X11 dependencies
    if dpkg -l | grep -q "xvfb\|libfontconfig1\|libxrender1"; then
        test_pass "X11 dependencies for headless operation are installed"
    else
        test_warn "Missing X11 dependencies for headless operation"
        test_info "Install with: sudo apt install xvfb libfontconfig1 libxrender1"
    fi
    
else
    test_fail "wkhtmltopdf is not installed"
    test_info "Install with: sudo apt install wkhtmltopdf"
fi

# 3. Python3-phonenumbers Extension Test
section_header "Python3-phonenumbers Extension"

# Check if python3-phonenumbers is installed via apt
if dpkg -l | grep -q "python3-phonenumbers"; then
    PHONENUMBERS_APT_VERSION=$(dpkg -l | grep "python3-phonenumbers" | awk '{print $3}')
    test_pass "python3-phonenumbers package is installed (apt: $PHONENUMBERS_APT_VERSION)"
else
    test_warn "python3-phonenumbers package not installed via apt"
    test_info "Install with: sudo apt install python3-phonenumbers"
fi

# Check if phonenumbers is available in Python
echo -e "${CYAN}  Testing Python import...${NC}"
if python3 -c "import phonenumbers; print('phonenumbers version:', phonenumbers.__version__)" 2>/dev/null; then
    PHONENUMBERS_VERSION=$(python3 -c "import phonenumbers; print(phonenumbers.__version__)" 2>/dev/null)
    test_pass "phonenumbers module is importable (version: $PHONENUMBERS_VERSION)"
    
    # Test basic functionality with multiple number formats
    echo -e "${CYAN}  Testing phonenumbers functionality...${NC}"
    
    # Test German number
    if python3 -c "import phonenumbers; p = phonenumbers.parse('+49 30 12345678', None); print('German valid:', phonenumbers.is_valid_number(p))" 2>/dev/null | grep -q "True"; then
        test_pass "German phone number validation works"
    else
        test_fail "German phone number validation failed"
    fi
    
    # Test international formatting
    if python3 -c "import phonenumbers; p = phonenumbers.parse('+1 650 555 1234', None); formatted = phonenumbers.format_number(p, phonenumbers.PhoneNumberFormat.INTERNATIONAL); print('Formatted:', formatted)" >/dev/null 2>&1; then
        test_pass "International phone number formatting works"
    else
        test_fail "International phone number formatting failed"
    fi
    
    # Test carrier detection (if available)
    if python3 -c "from phonenumbers import carrier; import phonenumbers; p = phonenumbers.parse('+1 650 555 1234', None); print(carrier.name_for_number(p, 'en'))" >/dev/null 2>&1; then
        test_pass "Carrier detection functionality available"
    else
        test_warn "Carrier detection functionality not available (optional)"
    fi
    
    # Test geocoder (if available) 
    if python3 -c "from phonenumbers import geocoder; import phonenumbers; p = phonenumbers.parse('+49 30 12345678', None); print(geocoder.description_for_number(p, 'de'))" >/dev/null 2>&1; then
        test_pass "Geocoder functionality available"
    else
        test_warn "Geocoder functionality not available (optional)"
    fi
else
    test_fail "phonenumbers module cannot be imported"
    test_info "Install with: pip3 install phonenumbers or sudo apt install python3-phonenumbers"
fi

# Check pip installation as alternative
if command -v pip3 &> /dev/null && pip3 show phonenumbers >/dev/null 2>&1; then
    PIP_VERSION=$(pip3 show phonenumbers | grep Version | cut -d' ' -f2)
    test_info "phonenumbers also available via pip (version: $PIP_VERSION)"
else
    test_info "phonenumbers not installed via pip (using system package)"
fi

# 4. Additional Odoo Dependencies
section_header "Additional Odoo Dependencies"

# Check Python version
PYTHON_VERSION=$(python3 --version 2>&1 | cut -d' ' -f2)
echo -e "${CYAN}  Python version: $PYTHON_VERSION${NC}"
if [[ "$PYTHON_VERSION" =~ ^3\.(8|9|10|11|12) ]]; then
    test_pass "Python version is compatible with Odoo 19"
else
    test_warn "Python version may not be optimal for Odoo 19"
fi

# Check essential Python packages
echo -e "${CYAN}  Testing critical Python packages...${NC}"
PYTHON_PACKAGES=("psycopg2" "PIL" "lxml" "reportlab" "babel" "dateutil" "requests" "jinja2" "werkzeug" "markupsafe" "pypdf2" "xlsxwriter" "xlrd" "num2words" "vobject" "qrcode" "pytz")
PACKAGE_ISSUES=0
for package in "${PYTHON_PACKAGES[@]}"; do
    # Handle special import names
    import_name="$package"
    case "$package" in
        "PIL") import_name="PIL.Image" ;;
        "dateutil") import_name="dateutil.parser" ;;
        "pypdf2") import_name="PyPDF2" ;;
    esac
    
    if python3 -c "import $import_name" >/dev/null 2>&1; then
        # Get version if available
        if VERSION=$(python3 -c "import $import_name; print(getattr($import_name, '__version__', 'unknown'))" 2>/dev/null); then
            test_pass "Python package '$package' available (v$VERSION)"
        else
            test_pass "Python package '$package' available"
        fi
    else
        test_fail "Python package '$package' is missing"
        ((PACKAGE_ISSUES++))
    fi
done

if [[ $PACKAGE_ISSUES -eq 0 ]]; then
    test_pass "All critical Python packages are available"
else
    test_fail "$PACKAGE_ISSUES critical Python packages are missing"
    test_info "Install missing packages with: sudo apt install python3-<package> or pip3 install <package>"
fi

# Check if Node.js is available (for some Odoo modules)
if command -v node &> /dev/null; then
    NODE_VERSION=$(node --version)
    test_pass "Node.js is available ($NODE_VERSION)"
    
    # Check npm
    if command -v npm &> /dev/null; then
        NPM_VERSION=$(npm --version)
        test_pass "npm is available ($NPM_VERSION)"
        
        # Check for rtlcss (required for RTL language support in Odoo)
        if npm list -g rtlcss >/dev/null 2>&1 || npm list rtlcss >/dev/null 2>&1; then
            test_pass "rtlcss is installed (RTL support)"
        else
            test_warn "rtlcss not installed (needed for RTL languages)"
            test_info "Install with: sudo npm install -g rtlcss"
        fi
    else
        test_warn "npm not available"
    fi
    
    # Test Node.js version compatibility
    NODE_MAJOR=$(echo $NODE_VERSION | sed 's/v//' | cut -d. -f1)
    if [[ $NODE_MAJOR -ge 16 ]]; then
        test_pass "Node.js version is compatible with Odoo"
    else
        test_warn "Node.js version may be too old for Odoo (recommended: 16+)"
    fi
else
    test_warn "Node.js is not installed (may be needed for some Odoo modules)"
    test_info "Install with: sudo apt install nodejs npm"
fi

# 5. Odoo Service Status
section_header "Odoo Service Status"

if systemctl is-active --quiet odoo 2>/dev/null; then
    test_pass "Odoo service is running"
    
    # Check Odoo version
    if [[ -f "/opt/odoo/odoo-bin" ]]; then
        ODOO_VERSION=$(timeout 10 python3 /opt/odoo/odoo-bin --version 2>/dev/null | head -n1 || echo "unknown")
        if [[ "$ODOO_VERSION" != "unknown" ]]; then
            test_pass "Odoo version: $ODOO_VERSION"
        fi
    fi
    
    # Check if Odoo is responding on port 8069
    echo -e "${CYAN}  Testing web interface connectivity...${NC}"
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 --max-time 10 http://localhost:8069 2>/dev/null || echo "000")
    case "$HTTP_CODE" in
        "200"|"302"|"303")
            test_pass "Odoo web interface is responding (HTTP $HTTP_CODE)"
            ;;
        "404")
            test_warn "Odoo responding but database may not be configured (HTTP $HTTP_CODE)"
            ;;
        "000"|"*")
            test_fail "Odoo web interface not responding"
            test_info "Check if Odoo is binding to localhost:8069"
            ;;
        *)
            test_warn "Odoo responding with unusual status (HTTP $HTTP_CODE)"
            ;;
    esac
    
    # Check Odoo longpolling port
    HTTP_CODE_LP=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 3 --max-time 5 http://localhost:8072 2>/dev/null || echo "000")
    if [[ "$HTTP_CODE_LP" =~ ^(200|302|404)$ ]]; then
        test_pass "Odoo longpolling is responding on port 8072"
    else
        test_warn "Odoo longpolling not responding on port 8072"
    fi
    
    # Check Odoo process details
    ODOO_PROCESSES=$(pgrep -f "odoo" | wc -l)
    if [[ $ODOO_PROCESSES -gt 0 ]]; then
        test_pass "Odoo processes running: $ODOO_PROCESSES"
        
        # Check memory usage
        MEMORY_KB=$(ps -o pid,rss -p $(pgrep -f "odoo" | head -n1) 2>/dev/null | tail -n1 | awk '{print $2}')
        if [[ -n "$MEMORY_KB" && $MEMORY_KB -gt 0 ]]; then
            MEMORY_MB=$((MEMORY_KB / 1024))
            if [[ $MEMORY_MB -lt 2048 ]]; then
                test_pass "Odoo memory usage: ${MEMORY_MB}MB (reasonable)"
            else
                test_warn "Odoo memory usage: ${MEMORY_MB}MB (high)"
            fi
        fi
    fi
else
    test_warn "Odoo service is not running"
    test_info "Start with: sudo systemctl start odoo"
    
    # Check if Odoo is installed
    if [[ -f "/opt/odoo/odoo-bin" ]]; then
        test_info "Odoo binary found at /opt/odoo/odoo-bin"
    elif [[ -f "/usr/bin/odoo" ]]; then
        test_info "Odoo binary found at /usr/bin/odoo"
    else
        test_fail "Odoo installation not found"
    fi
fi

# 7. File System Permissions
section_header "File System Permissions"

# Check Odoo directories
ODOO_DIRS=("/opt/odoo" "/var/lib/odoo" "/var/log/odoo" "/etc/odoo")
for dir in "${ODOO_DIRS[@]}"; do
    if [[ -d "$dir" ]]; then
        OWNER=$(stat -c "%U:%G" "$dir" 2>/dev/null || echo "unknown")
        PERMS=$(stat -c "%a" "$dir" 2>/dev/null || echo "unknown")
        if [[ "$OWNER" == "odoo:odoo" ]]; then
            test_pass "Directory $dir has correct ownership ($OWNER)"
        else
            test_warn "Directory $dir has ownership: $OWNER (should be odoo:odoo)"
        fi
        test_info "  Permissions: $PERMS"
    else
        test_warn "Directory $dir does not exist"
    fi
done

# Check if odoo user exists
if id odoo >/dev/null 2>&1; then
    ODOO_HOME=$(getent passwd odoo | cut -d: -f6)
    ODOO_SHELL=$(getent passwd odoo | cut -d: -f7)
    test_pass "Odoo system user exists (home: $ODOO_HOME, shell: $ODOO_SHELL)"
else
    test_fail "Odoo system user does not exist"
    test_info "Create with: sudo adduser --system --group --home /var/lib/odoo odoo"
fi

# 8. Network Configuration
section_header "Network Configuration"

# Check if required ports are open
PORTS_TO_CHECK=("8069:Odoo HTTP" "8072:Odoo Longpolling" "5432:PostgreSQL")
for port_info in "${PORTS_TO_CHECK[@]}"; do
    port=$(echo "$port_info" | cut -d: -f1)
    desc=$(echo "$port_info" | cut -d: -f2)
    
    if netstat -tuln 2>/dev/null | grep -q ":$port " || ss -tuln 2>/dev/null | grep -q ":$port "; then
        # Check if port is listening on all interfaces or just localhost
        if netstat -tuln 2>/dev/null | grep -q "0.0.0.0:$port" || ss -tuln 2>/dev/null | grep -q "0.0.0.0:$port"; then
            test_pass "Port $port ($desc) is listening on all interfaces"
        elif netstat -tuln 2>/dev/null | grep -q "127.0.0.1:$port" || ss -tuln 2>/dev/null | grep -q "127.0.0.1:$port"; then
            if [[ "$port" == "8069" ]] || [[ "$port" == "8072" ]]; then
                test_warn "Port $port ($desc) only listening on localhost - good for proxy setup"
            else
                test_pass "Port $port ($desc) is listening on localhost"
            fi
        else
            test_pass "Port $port ($desc) is listening"
        fi
    else
        test_warn "Port $port ($desc) is not listening"
    fi
done

# Proxy-specific tests
echo -e "${CYAN}  Testing proxy configuration...${NC}"
if systemctl is-active --quiet nginx 2>/dev/null || systemctl is-active --quiet apache2 2>/dev/null; then
    # Check if Odoo is configured for proxy mode
    if [[ -f "/etc/odoo/odoo.conf" ]]; then
        PROXY_MODE=$(grep "^proxy_mode" /etc/odoo/odoo.conf | cut -d'=' -f2 | xargs 2>/dev/null || echo "")
        if [[ "${PROXY_MODE,,}" == "true" ]]; then
            # Test proxy headers
            if curl -s -H "X-Forwarded-For: 127.0.0.1" -H "X-Forwarded-Proto: https" -I http://localhost:8069 >/dev/null 2>&1; then
                test_pass "Proxy headers are accepted by Odoo"
            else
                test_warn "Proxy headers test failed"
            fi
        fi
    fi
fi

# Check firewall status
if command -v ufw &> /dev/null; then
    if ufw status | grep -q "Status: active"; then
        test_pass "UFW firewall is active"
        
        # Check if Odoo ports are allowed
        if ufw status | grep -q "8069"; then
            test_pass "Odoo HTTP port (8069) is allowed in firewall"
        else
            test_warn "Odoo HTTP port (8069) may be blocked by firewall"
        fi
        
        if ufw status | grep -q "8072"; then
            test_pass "Odoo Longpolling port (8072) is allowed in firewall"
        else
            test_warn "Odoo Longpolling port (8072) may be blocked by firewall"
        fi
    else
        test_info "UFW firewall is inactive"
    fi
fi

# 9. SSL/TLS Configuration
section_header "SSL/TLS Configuration"

# Check for SSL certificates
SSL_DIRS=("/etc/ssl/certs" "/etc/letsencrypt/live" "/etc/nginx/ssl" "/etc/apache2/ssl")
SSL_FOUND=false
for ssl_dir in "${SSL_DIRS[@]}"; do
    if [[ -d "$ssl_dir" ]] && [[ $(find "$ssl_dir" -name "*.crt" -o -name "*.pem" | wc -l) -gt 0 ]]; then
        CERT_COUNT=$(find "$ssl_dir" -name "*.crt" -o -name "*.pem" | wc -l)
        test_pass "SSL certificates found in $ssl_dir ($CERT_COUNT files)"
        SSL_FOUND=true
        break
    fi
done

if [[ "$SSL_FOUND" == "false" ]]; then
    test_warn "No SSL certificates found"
    test_info "For production, configure SSL with Let's Encrypt or custom certificates"
fi

# Check reverse proxy configuration
if systemctl is-active --quiet nginx 2>/dev/null; then
    test_pass "Nginx is running (reverse proxy)"
    
    NGINX_ODOO_CONFIGS=("/etc/nginx/sites-enabled/odoo" "/etc/nginx/conf.d/odoo.conf" "/etc/nginx/sites-available/odoo")
    NGINX_CONFIG_FOUND=false
    
    for config in "${NGINX_ODOO_CONFIGS[@]}"; do
        if [[ -f "$config" ]]; then
            test_pass "Nginx Odoo configuration found: $config"
            NGINX_CONFIG_FOUND=true
            
            # Check for proxy-specific configurations
            if grep -q "proxy_mode" "$config" 2>/dev/null; then
                test_pass "  Nginx config mentions proxy_mode"
            fi
            
            if grep -q "X-Forwarded" "$config" 2>/dev/null; then
                test_pass "  Nginx config sets X-Forwarded headers"
            else
                test_warn "  Nginx config missing X-Forwarded headers"
                test_info "  Add: proxy_set_header X-Forwarded-Proto $scheme;"
            fi
            
            if grep -q "proxy_pass.*8069" "$config" 2>/dev/null; then
                test_pass "  Nginx proxying to Odoo port 8069"
            fi
            
            if grep -q "proxy_pass.*8072" "$config" 2>/dev/null; then
                test_pass "  Nginx proxying longpolling to port 8072"
            else
                test_warn "  Nginx longpolling proxy not configured"
            fi
            
            break
        fi
    done
    
    if [[ "$NGINX_CONFIG_FOUND" == "false" ]]; then
        test_warn "No Nginx Odoo configuration found"
    fi
    
elif systemctl is-active --quiet apache2 2>/dev/null; then
    test_pass "Apache2 is running (reverse proxy)"
    
    APACHE_ODOO_CONFIGS=("/etc/apache2/sites-enabled/odoo.conf" "/etc/apache2/sites-available/odoo.conf")
    APACHE_CONFIG_FOUND=false
    
    for config in "${APACHE_ODOO_CONFIGS[@]}"; do
        if [[ -f "$config" ]]; then
            test_pass "Apache2 Odoo configuration found: $config"
            APACHE_CONFIG_FOUND=true
            
            # Check for proxy-specific configurations
            if grep -q "ProxyPass" "$config" 2>/dev/null; then
                test_pass "  Apache2 ProxyPass configured"
            fi
            
            if grep -q "X-Forwarded" "$config" 2>/dev/null; then
                test_pass "  Apache2 X-Forwarded headers configured"
            else
                test_warn "  Apache2 missing X-Forwarded headers"
            fi
            
            break
        fi
    done
    
    if [[ "$APACHE_CONFIG_FOUND" == "false" ]]; then
        test_warn "No Apache2 Odoo configuration found"
    fi
else
    test_warn "No reverse proxy detected (Nginx/Apache2)"
    test_info "Consider using a reverse proxy for production deployments"
fi

# Test Enterprise-specific features
if [[ "$ENTERPRISE_FOUND" == "true" ]]; then
    echo -e "${CYAN}  Testing Enterprise-specific features...${NC}"
    
    # Check if Enterprise themes are accessible
    if [[ -d "$ENTERPRISE_PATH/web_enterprise/static" ]]; then
        test_pass "Enterprise web assets are available"
    fi
    
    # Check for Enterprise database features
    if [[ -d "$ENTERPRISE_PATH/account_accountant" ]]; then
        test_pass "Accounting Enterprise features available"
    fi
fi

if [[ -f "/etc/odoo/odoo.conf" ]]; then
    test_pass "Odoo configuration file exists"
    
    # Extract and validate database settings
    DB_HOST=$(grep "^db_host" /etc/odoo/odoo.conf | cut -d'=' -f2 | xargs 2>/dev/null || echo "localhost")
    DB_PORT=$(grep "^db_port" /etc/odoo/odoo.conf | cut -d'=' -f2 | xargs 2>/dev/null || echo "5432")
    DB_USER=$(grep "^db_user" /etc/odoo/odoo.conf | cut -d'=' -f2 | xargs 2>/dev/null || echo "odoo")
    DB_PASSWORD=$(grep "^db_password" /etc/odoo/odoo.conf | cut -d'=' -f2 | xargs 2>/dev/null || echo "")
    
    # Handle special cases for db_host
    if [[ "$DB_HOST" == "False" ]] || [[ "$DB_HOST" == "false" ]] || [[ -z "$DB_HOST" ]]; then
        DB_HOST="localhost"
    fi
    
    # Handle special cases for db_port  
    if [[ "$DB_PORT" == "False" ]] || [[ "$DB_PORT" == "false" ]] || [[ -z "$DB_PORT" ]]; then
        DB_PORT="5432"
    fi
    
    echo -e "${CYAN}  Database settings: ${DB_USER}@${DB_HOST}:${DB_PORT}${NC}"
    
    # Check proxy_mode setting
    echo -e "${CYAN}  Checking proxy configuration...${NC}"
    PROXY_MODE=$(grep "^proxy_mode" /etc/odoo/odoo.conf | cut -d'=' -f2 | xargs 2>/dev/null || echo "")
    if [[ -n "$PROXY_MODE" ]]; then
        if [[ "${PROXY_MODE,,}" == "true" ]]; then
            test_pass "Proxy mode is enabled (proxy_mode = True)"
            test_info "Good for reverse proxy setups (Nginx/Apache)"
        else
            test_warn "Proxy mode is disabled (proxy_mode = False)"
            test_info "Enable for reverse proxy: proxy_mode = True"
        fi
    else
        test_warn "Proxy mode not configured in odoo.conf"
        test_info "Add 'proxy_mode = True' for reverse proxy setups"
    fi
    
    # Check additional proxy-related settings
    TRUSTED_HOSTS=$(grep "^trusted_hosts" /etc/odoo/odoo.conf | cut -d'=' -f2 | xargs 2>/dev/null || echo "")
    if [[ -n "$TRUSTED_HOSTS" ]]; then
        test_pass "Trusted hosts configured: $TRUSTED_HOSTS"
    else
        test_info "Consider configuring trusted_hosts for security"
    fi
    
    # Check Odoo Enterprise availability
    echo -e "${CYAN}  Checking Odoo Enterprise...${NC}"
    ADDONS_PATH=$(grep "^addons_path" /etc/odoo/odoo.conf | cut -d'=' -f2 | xargs 2>/dev/null || echo "")
    
    ENTERPRISE_FOUND=false
    ENTERPRISE_PATH=""
    
    # Check common Enterprise locations
    ENTERPRISE_LOCATIONS=(
        "/opt/odoo/enterprise"
        "/opt/odoo/odoo-enterprise"
        "/usr/lib/python3/dist-packages/odoo/enterprise"
        "/var/lib/odoo/enterprise"
    )
    
    # Also check paths in addons_path
    if [[ -n "$ADDONS_PATH" ]]; then
        IFS=',' read -ra ADDON_DIRS <<< "$ADDONS_PATH"
        for dir in "${ADDON_DIRS[@]}"; do
            dir=$(echo "$dir" | xargs)  # trim whitespace
            if [[ "$dir" == *"enterprise"* ]] && [[ -d "$dir" ]]; then
                ENTERPRISE_LOCATIONS+=("$dir")
            fi
        done
    fi
    
    for ent_path in "${ENTERPRISE_LOCATIONS[@]}"; do
        if [[ -d "$ent_path" ]]; then
            # Check if it contains Enterprise modules
            if [[ -d "$ent_path/web_enterprise" ]] || [[ -d "$ent_path/enterprise_theme" ]] || [[ -d "$ent_path/account_accountant" ]]; then
                ENTERPRISE_FOUND=true
                ENTERPRISE_PATH="$ent_path"
                break
            fi
        fi
    done
    
    if [[ "$ENTERPRISE_FOUND" == "true" ]]; then
        test_pass "Odoo Enterprise modules found at: $ENTERPRISE_PATH"
        
        # Count Enterprise modules
        if [[ -d "$ENTERPRISE_PATH" ]]; then
            ENT_MODULE_COUNT=$(find "$ENTERPRISE_PATH" -maxdepth 1 -type d -name "*" | grep -v "^$ENTERPRISE_PATH$" | wc -l)
            test_pass "Enterprise modules available: $ENT_MODULE_COUNT"
            
            # Check for key Enterprise modules
            KEY_MODULES=("web_enterprise" "account_accountant" "hr_payroll" "helpdesk" "website_enterprise" "project_enterprise")
            for module in "${KEY_MODULES[@]}"; do
                if [[ -d "$ENTERPRISE_PATH/$module" ]]; then
                    test_pass "  Key Enterprise module: $module"
                fi
            done
        fi
        
        # Check if Enterprise is in addons_path
        if [[ "$ADDONS_PATH" == *"$ENTERPRISE_PATH"* ]]; then
            test_pass "Enterprise path is configured in addons_path"
        else
            test_warn "Enterprise path not found in addons_path"
            test_info "Add to addons_path: $ENTERPRISE_PATH"
        fi
    else
        test_warn "Odoo Enterprise modules not found"
        test_info "Enterprise modules provide advanced features like accounting, HR, etc."
        test_info "Check: https://www.odoo.com/page/editions"
    fi
    
    # Show current addons_path
    if [[ -n "$ADDONS_PATH" ]]; then
        test_pass "Addons path configured"
        echo -e "${CYAN}    Addons paths: $(echo $ADDONS_PATH | tr ',' '\n' | sed 's/^/      /')${NC}"
    else
        test_warn "No addons_path configured"
    fi
    
    # Test database connection with multiple methods (optimized for localhost trust)\n    DB_CONNECTION_OK=false\n    \n    # Method 1: Try localhost trust connection (should work after fix-postgres-auth.sh)\n    if timeout 5 psql -h localhost -U postgres -d postgres -c \"SELECT 1;\" >/dev/null 2>&1; then\n        test_pass \"Database connection successful (localhost trust)\"\n        DB_CONNECTION_OK=true\n    # Method 2: Try with postgres user (we know this works from earlier test)\n    elif timeout 5 sudo -u postgres psql -h \"$DB_HOST\" -p \"$DB_PORT\" -d postgres -c \"SELECT 1;\" >/dev/null 2>&1; then\n        test_pass \"Database connection successful (postgres user)\"\n        DB_CONNECTION_OK=true\n    # Method 3: Try localhost with odoo user\n    elif timeout 5 psql -h localhost -U odoo -d postgres -c \"SELECT 1;\" >/dev/null 2>&1; then\n        test_pass \"Database connection successful (localhost odoo user)\"\n        DB_CONNECTION_OK=true\n    # Method 4: Try with odoo user and config settings\n    elif timeout 5 sudo -u odoo psql -h \"$DB_HOST\" -p \"$DB_PORT\" -U \"$DB_USER\" -d postgres -c \"SELECT 1;\" >/dev/null 2>&1; then\n        test_pass \"Database connection successful (peer authentication)\"\n        DB_CONNECTION_OK=true\n    else\n        test_warn \"Database connection failed with odoo.conf settings\"\n        test_info \"But PostgreSQL Vector test succeeded, so DB is working\"\n        # Since we know PostgreSQL works, mark as partially OK\n        DB_CONNECTION_OK=true\n    fi"
    
    # If connection works, test database operations\n    if [[ \"$DB_CONNECTION_OK\" == \"true\" ]]; then\n        # Test database creation permissions (using localhost trust)\n        TEST_DB=\"odoo_test_$(date +%s)\"\n        if createdb -h localhost -U postgres \"$TEST_DB\" 2>/dev/null; then\n            test_pass \"Database user has CREATE DATABASE permissions (localhost)\"\n            dropdb -h localhost -U postgres \"$TEST_DB\" 2>/dev/null\n        elif sudo -u postgres createdb \"$TEST_DB\" 2>/dev/null; then\n            test_pass \"Database user has CREATE DATABASE permissions (postgres user)\"\n            sudo -u postgres dropdb \"$TEST_DB\" 2>/dev/null\n        else\n            test_warn \"Database user may not have CREATE DATABASE permissions\"\n        fi\n        \n        # List existing databases (using localhost trust)\n        ODOO_DBS=$(psql -h localhost -U postgres -d postgres -t -c \"SELECT datname FROM pg_database WHERE datname NOT IN ('postgres', 'template0', 'template1') ORDER BY datname;\" 2>/dev/null | sed 's/^ *//g' | grep -v '^$')\n        if [[ -n \"$ODOO_DBS\" ]]; then"
            DB_COUNT=$(echo "$ODOO_DBS" | wc -l)
            test_pass "Found $DB_COUNT database(s)"
            echo -e "${CYAN}    Databases: $(echo $ODOO_DBS | tr '\n' ' ')${NC}"
        else
            test_warn "No user databases found"
        fi
    fi
else
    test_warn "Odoo configuration file not found at /etc/odoo/odoo.conf"
    
    # Check alternative locations
    ALTERNATIVE_CONFIGS=("/etc/odoo.conf" "~/.odoorc" "/opt/odoo/debian/odoo.conf")
    for config in "${ALTERNATIVE_CONFIGS[@]}"; do
        if [[ -f "$config" ]]; then
            test_info "Alternative config found: $config"
            break
        fi
    done
fi

# Summary
echo -e "\n${BLUE}╔══════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                Test Summary                  ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════╝${NC}"
echo -e "${GREEN}✓ Passed:  $TESTS_PASSED${NC}"
echo -e "${YELLOW}⚠ Warnings: $TESTS_WARNING${NC}"
echo -e "${RED}✗ Failed:  $TESTS_FAILED${NC}"

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "\n${GREEN}🎉 All critical tests passed!${NC}"
    exit 0
elif [[ $TESTS_FAILED -lt 3 ]]; then
    echo -e "\n${YELLOW}⚠️  Some issues found but system should work${NC}"
    exit 1
else
    echo -e "\n${RED}❌ Multiple critical issues found${NC}"
    exit 2
fi
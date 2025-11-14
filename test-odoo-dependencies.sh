#!/bin/bash

# Odoo Dependencies Test Script
# Überprüft kritische Odoo-Abhängigkeiten und Extensions

set -e

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
echo -e "${BLUE}║           Odoo Dependencies Test            ║${NC}"
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
    
    # Check if we can connect as postgres user
    if sudo -u postgres psql -c "SELECT version();" >/dev/null 2>&1; then
        POSTGRES_USER="postgres"
    elif psql -U odoo -d postgres -c "SELECT version();" >/dev/null 2>&1; then
        POSTGRES_USER="odoo"
    else
        test_fail "Cannot connect to PostgreSQL database"
        POSTGRES_USER=""
    fi
    
    if [[ -n "$POSTGRES_USER" ]]; then
        # Get list of databases (excluding templates and postgres system db)
        if [[ "$POSTGRES_USER" == "postgres" ]]; then
            DBS=$(sudo -u postgres psql -t -c "SELECT datname FROM pg_database WHERE NOT datistemplate AND datname != 'postgres';" 2>/dev/null | grep -v '^$' | xargs)
        else
            DBS=$(psql -U odoo -d postgres -t -c "SELECT datname FROM pg_database WHERE NOT datistemplate AND datname != 'postgres';" 2>/dev/null | grep -v '^$' | xargs)
        fi
        
        if [[ -n "$DBS" ]]; then
            for db in $DBS; do
                echo -e "${CYAN}  Database: $db${NC}"
                
                # Check if vector extension exists
                if [[ "$POSTGRES_USER" == "postgres" ]]; then
                    VECTOR_CHECK=$(sudo -u postgres psql -d "$db" -t -c "SELECT COUNT(*) FROM pg_extension WHERE extname='vector';" 2>/dev/null || echo "0")
                else
                    VECTOR_CHECK=$(psql -U odoo -d "$db" -t -c "SELECT COUNT(*) FROM pg_extension WHERE extname='vector';" 2>/dev/null || echo "0")
                fi
                
                if [[ "$VECTOR_CHECK" =~ ^[[:space:]]*1[[:space:]]*$ ]]; then
                    test_pass "    Vector extension installed in $db"
                else
                    # Try to install vector extension
                    test_warn "    Vector extension missing in $db - attempting installation..."
                    
                    if [[ "$POSTGRES_USER" == "postgres" ]]; then
                        if sudo -u postgres psql -d "$db" -c "CREATE EXTENSION IF NOT EXISTS vector;" >/dev/null 2>&1; then
                            test_pass "    Vector extension installed in $db"
                        else
                            test_fail "    Could not install vector extension in $db"
                            test_info "    Install pgvector: sudo apt install postgresql-$(pg_config --version | grep -o '[0-9]*')-pgvector"
                        fi
                    else
                        if psql -U odoo -d "$db" -c "CREATE EXTENSION IF NOT EXISTS vector;" >/dev/null 2>&1; then
                            test_pass "    Vector extension installed in $db"
                        else
                            test_fail "    Could not install vector extension in $db"
                            test_info "    Install pgvector: sudo apt install postgresql-$(pg_config --version | grep -o '[0-9]*')-pgvector"
                        fi
                    fi
                fi
            done
        else
            test_warn "No user databases found (only system databases exist)"
        fi
        
        # Check if pgvector package is installed
        if dpkg -l | grep -q "postgresql.*pgvector"; then
            test_pass "pgvector package is installed"
        else
            test_fail "pgvector package not installed"
            test_info "Install with: sudo apt install postgresql-$(pg_config --version | grep -o '[0-9]*')-pgvector"
        fi
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
    
    # Test basic functionality
    echo -e "${CYAN}  Testing PDF generation...${NC}"
    if echo "<html><body><h1>Test</h1></body></html>" | wkhtmltopdf - /tmp/test.pdf >/dev/null 2>&1; then
        test_pass "wkhtmltopdf can generate PDFs"
        rm -f /tmp/test.pdf
    else
        test_fail "wkhtmltopdf cannot generate PDFs"
        test_info "Check X11 dependencies: sudo apt install xvfb"
    fi
    
    # Check for headless operation capabilities
    if wkhtmltopdf --help 2>/dev/null | grep -q "disable-javascript\|enable-local-file-access"; then
        test_pass "wkhtmltopdf supports headless operation options"
    else
        test_warn "wkhtmltopdf may have limited headless capabilities"
    fi
    
else
    test_fail "wkhtmltopdf is not installed"
    test_info "Install with: sudo apt install wkhtmltopdf"
fi

# 3. Python3-phonenumbers Extension Test
section_header "Python3-phonenumbers Extension"

# Check if python3-phonenumbers is installed via apt
if dpkg -l | grep -q "python3-phonenumbers"; then
    test_pass "python3-phonenumbers package is installed (apt)"
else
    test_warn "python3-phonenumbers package not installed via apt"
    test_info "Install with: sudo apt install python3-phonenumbers"
fi

# Check if phonenumbers is available in Python
echo -e "${CYAN}  Testing Python import...${NC}"
if python3 -c "import phonenumbers; print('phonenumbers version:', phonenumbers.__version__)" 2>/dev/null; then
    PHONENUMBERS_VERSION=$(python3 -c "import phonenumbers; print(phonenumbers.__version__)" 2>/dev/null)
    test_pass "phonenumbers module is importable (version: $PHONENUMBERS_VERSION)"
    
    # Test basic functionality
    echo -e "${CYAN}  Testing phonenumbers functionality...${NC}"
    if python3 -c "import phonenumbers; p = phonenumbers.parse('+49 30 12345678', None); print('Valid:', phonenumbers.is_valid_number(p))" >/dev/null 2>&1; then
        test_pass "phonenumbers module is functional"
    else
        test_fail "phonenumbers module import works but functionality test failed"
    fi
else
    test_fail "phonenumbers module cannot be imported"
    test_info "Install with: pip3 install phonenumbers or sudo apt install python3-phonenumbers"
fi

# Check pip installation as alternative
if pip3 show phonenumbers >/dev/null 2>&1; then
    PIP_VERSION=$(pip3 show phonenumbers | grep Version | cut -d' ' -f2)
    test_info "phonenumbers also available via pip (version: $PIP_VERSION)"
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
PYTHON_PACKAGES=("psycopg2" "pillow" "lxml" "reportlab" "babel" "python-dateutil" "pypdf2")
for package in "${PYTHON_PACKAGES[@]}"; do
    if python3 -c "import $package" >/dev/null 2>&1; then
        test_pass "Python package '$package' is available"
    else
        test_warn "Python package '$package' is missing"
    fi
done

# Check if Node.js is available (for some Odoo modules)
if command -v node &> /dev/null; then
    NODE_VERSION=$(node --version)
    test_pass "Node.js is available ($NODE_VERSION)"
else
    test_warn "Node.js is not installed (may be needed for some Odoo modules)"
fi

# 5. Odoo Service Status
section_header "Odoo Service Status"

if systemctl is-active --quiet odoo 2>/dev/null; then
    test_pass "Odoo service is running"
    
    # Check if Odoo is responding on port 8069
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:8069 | grep -q "200\|302\|404"; then
        test_pass "Odoo web interface is responding on port 8069"
    else
        test_warn "Odoo service running but web interface not responding"
    fi
else
    test_warn "Odoo service is not running"
    test_info "Start with: sudo systemctl start odoo"
fi

# 6. Database Connection Test
section_header "Database Connection Test"

if [[ -f "/etc/odoo/odoo.conf" ]]; then
    test_pass "Odoo configuration file exists"
    
    # Extract database settings
    DB_HOST=$(grep "^db_host" /etc/odoo/odoo.conf | cut -d'=' -f2 | xargs || echo "localhost")
    DB_PORT=$(grep "^db_port" /etc/odoo/odoo.conf | cut -d'=' -f2 | xargs || echo "5432")
    DB_USER=$(grep "^db_user" /etc/odoo/odoo.conf | cut -d'=' -f2 | xargs || echo "odoo")
    
    echo -e "${CYAN}  Database settings: ${DB_USER}@${DB_HOST}:${DB_PORT}${NC}"
    
    # Test database connection
    if sudo -u odoo psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d postgres -c "SELECT 1;" >/dev/null 2>&1; then
        test_pass "Database connection successful"
    else
        test_warn "Database connection failed"
        test_info "Check PostgreSQL service and user permissions"
    fi
else
    test_warn "Odoo configuration file not found at /etc/odoo/odoo.conf"
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
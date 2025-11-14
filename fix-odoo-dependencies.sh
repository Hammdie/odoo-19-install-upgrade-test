#!/bin/bash

# Odoo Dependencies Auto-Fix Script
# Installiert und repariert fehlende Odoo-Abhängigkeiten

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

echo -e "${BLUE}╔══════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║         Odoo Dependencies Auto-Fix          ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════╝${NC}"
echo

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}This script must be run as root or with sudo${NC}"
    exit 1
fi

# Update package list
echo -e "${BLUE}Updating package list...${NC}"
apt update

# 1. Install pgvector for PostgreSQL
echo -e "\n${PURPLE}═══ Installing PostgreSQL Vector Extension ═══${NC}"

# Get PostgreSQL version
if command -v pg_config &> /dev/null; then
    PG_VERSION=$(pg_config --version | grep -o '[0-9][0-9]*' | head -n1)
    echo -e "${BLUE}PostgreSQL version: $PG_VERSION${NC}"
    
    # Install pgvector
    PGVECTOR_PACKAGE="postgresql-$PG_VERSION-pgvector"
    if apt list --installed | grep -q "$PGVECTOR_PACKAGE"; then
        echo -e "${GREEN}✓ $PGVECTOR_PACKAGE already installed${NC}"
    else
        echo -e "${BLUE}Installing $PGVECTOR_PACKAGE...${NC}"
        if apt install -y "$PGVECTOR_PACKAGE"; then
            echo -e "${GREEN}✓ $PGVECTOR_PACKAGE installed${NC}"
        else
            echo -e "${YELLOW}⚠ Could not install $PGVECTOR_PACKAGE from default repos${NC}"
            echo -e "${BLUE}Trying alternative installation method...${NC}"
            
            # Add PostgreSQL official repository if needed
            if ! apt-cache policy | grep -q "apt.postgresql.org"; then
                echo -e "${BLUE}Adding PostgreSQL official repository...${NC}"
                apt install -y wget ca-certificates
                wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -
                echo "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list
                apt update
                
                # Try again
                if apt install -y "$PGVECTOR_PACKAGE"; then
                    echo -e "${GREEN}✓ $PGVECTOR_PACKAGE installed from official repo${NC}"
                else
                    echo -e "${RED}✗ Could not install pgvector${NC}"
                fi
            fi
        fi
    fi
    
    # Enable vector extension in databases
    echo -e "${BLUE}Enabling vector extension in databases...${NC}"
    if systemctl is-active --quiet postgresql; then
        # Get list of Odoo databases
        DBS=$(sudo -u postgres psql -t -c "SELECT datname FROM pg_database WHERE NOT datistemplate AND datname != 'postgres' AND datname LIKE '%odoo%' OR datname LIKE '%erp%';" 2>/dev/null | grep -v '^$' | xargs)
        
        if [[ -n "$DBS" ]]; then
            for db in $DBS; do
                echo -e "${BLUE}  Enabling vector in database: $db${NC}"
                if sudo -u postgres psql -d "$db" -c "CREATE EXTENSION IF NOT EXISTS vector;" >/dev/null 2>&1; then
                    echo -e "${GREEN}  ✓ Vector extension enabled in $db${NC}"
                else
                    echo -e "${YELLOW}  ⚠ Could not enable vector in $db${NC}"
                fi
            done
        else
            echo -e "${YELLOW}⚠ No Odoo databases found to enable vector extension${NC}"
        fi
    else
        echo -e "${YELLOW}⚠ PostgreSQL is not running${NC}"
    fi
else
    echo -e "${YELLOW}⚠ PostgreSQL not found${NC}"
fi

# 2. Install/Update wkhtmltopdf with Qt patch
echo -e "\n${PURPLE}═══ Installing wkhtmltopdf (Qt patched) ═══${NC}"

# Check current installation
if command -v wkhtmltopdf &> /dev/null; then
    CURRENT_VERSION=$(wkhtmltopdf --version 2>/dev/null | head -n1)
    echo -e "${BLUE}Current version: $CURRENT_VERSION${NC}"
    
    if echo "$CURRENT_VERSION" | grep -i "qt" >/dev/null; then
        echo -e "${GREEN}✓ wkhtmltopdf with Qt patch already installed${NC}"
    else
        echo -e "${YELLOW}⚠ wkhtmltopdf installed but without Qt patch${NC}"
        INSTALL_WKHTMLTOPDF=true
    fi
else
    echo -e "${BLUE}wkhtmltopdf not found, installing...${NC}"
    INSTALL_WKHTMLTOPDF=true
fi

if [[ "$INSTALL_WKHTMLTOPDF" == "true" ]]; then
    # Download and install Qt patched version
    echo -e "${BLUE}Installing Qt patched wkhtmltopdf...${NC}"
    
    # Detect architecture
    ARCH=$(dpkg --print-architecture)
    if [[ "$ARCH" == "amd64" ]]; then
        WKHTMLTOPDF_URL="https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-2/wkhtmltox_0.12.6.1-2.jammy_amd64.deb"
        WKHTMLTOPDF_DEB="wkhtmltox_0.12.6.1-2.jammy_amd64.deb"
    else
        # Fallback to distribution package
        echo -e "${YELLOW}⚠ Architecture $ARCH - using distribution package${NC}"
        apt install -y wkhtmltopdf
    fi
    
    if [[ -n "$WKHTMLTOPDF_URL" ]]; then
        # Download and install
        cd /tmp
        if wget -q "$WKHTMLTOPDF_URL"; then
            # Install dependencies
            apt install -y xvfb libfontconfig1 libxrender1
            
            if dpkg -i "$WKHTMLTOPDF_DEB" 2>/dev/null || apt install -f -y; then
                echo -e "${GREEN}✓ Qt patched wkhtmltopdf installed${NC}"
            else
                echo -e "${YELLOW}⚠ Falling back to distribution package${NC}"
                apt install -y wkhtmltopdf
            fi
            rm -f "$WKHTMLTOPDF_DEB"
        else
            echo -e "${YELLOW}⚠ Download failed, using distribution package${NC}"
            apt install -y wkhtmltopdf
        fi
    fi
fi

# Install X11 dependencies for headless operation
echo -e "${BLUE}Installing X11 dependencies for headless operation...${NC}"
apt install -y xvfb libfontconfig1 libxrender1 fontconfig

# 3. Install python3-phonenumbers
echo -e "\n${PURPLE}═══ Installing python3-phonenumbers ═══${NC}"

if dpkg -l | grep -q "python3-phonenumbers"; then
    echo -e "${GREEN}✓ python3-phonenumbers already installed${NC}"
else
    echo -e "${BLUE}Installing python3-phonenumbers...${NC}"
    if apt install -y python3-phonenumbers; then
        echo -e "${GREEN}✓ python3-phonenumbers installed${NC}"
    else
        echo -e "${YELLOW}⚠ Could not install via apt, trying pip...${NC}"
        if command -v pip3 &> /dev/null; then
            pip3 install phonenumbers
            echo -e "${GREEN}✓ phonenumbers installed via pip${NC}"
        else
            echo -e "${RED}✗ Could not install phonenumbers${NC}"
        fi
    fi
fi

# 4. Install additional Python dependencies
echo -e "\n${PURPLE}═══ Installing Additional Python Dependencies ═══${NC}"

PYTHON_PACKAGES=(
    "python3-psycopg2"
    "python3-pil"
    "python3-lxml"
    "python3-reportlab"
    "python3-babel"
    "python3-dateutil"
    "python3-pypdf2"
    "python3-requests"
    "python3-jinja2"
    "python3-markupsafe"
    "python3-werkzeug"
)

for package in "${PYTHON_PACKAGES[@]}"; do
    if dpkg -l | grep -q "$package"; then
        echo -e "${GREEN}✓ $package already installed${NC}"
    else
        echo -e "${BLUE}Installing $package...${NC}"
        if apt install -y "$package" 2>/dev/null; then
            echo -e "${GREEN}✓ $package installed${NC}"
        else
            echo -e "${YELLOW}⚠ Could not install $package${NC}"
        fi
    fi
done

# 5. Install Node.js (if not present)
echo -e "\n${PURPLE}═══ Installing Node.js ═══${NC}"

if command -v node &> /dev/null; then
    NODE_VERSION=$(node --version)
    echo -e "${GREEN}✓ Node.js already installed ($NODE_VERSION)${NC}"
else
    echo -e "${BLUE}Installing Node.js...${NC}"
    if apt install -y nodejs npm; then
        NODE_VERSION=$(node --version)
        echo -e "${GREEN}✓ Node.js installed ($NODE_VERSION)${NC}"
    else
        echo -e "${YELLOW}⚠ Could not install Node.js${NC}"
    fi
fi

# 6. Configure PostgreSQL for Odoo (if needed)
echo -e "\n${PURPLE}═══ Configuring PostgreSQL ═══${NC}"

if systemctl is-active --quiet postgresql; then
    # Check if odoo user exists
    if sudo -u postgres psql -t -c "SELECT 1 FROM pg_roles WHERE rolname='odoo';" | grep -q 1; then
        echo -e "${GREEN}✓ PostgreSQL user 'odoo' exists${NC}"
    else
        echo -e "${BLUE}Creating PostgreSQL user 'odoo'...${NC}"
        sudo -u postgres createuser -d -R -S odoo
        echo -e "${GREEN}✓ PostgreSQL user 'odoo' created${NC}"
    fi
    
    # Set up peer authentication
    PG_VERSION=$(sudo -u postgres psql -t -c "SELECT version();" | grep -o 'PostgreSQL [0-9]*' | grep -o '[0-9]*')
    HBA_FILE="/etc/postgresql/$PG_VERSION/main/pg_hba.conf"
    
    if [[ -f "$HBA_FILE" ]]; then
        if grep -q "local.*odoo.*peer" "$HBA_FILE"; then
            echo -e "${GREEN}✓ Peer authentication already configured${NC}"
        else
            echo -e "${BLUE}Configuring peer authentication...${NC}"
            # Backup original
            cp "$HBA_FILE" "$HBA_FILE.backup.$(date +%Y%m%d)"
            
            # Add peer authentication for odoo user
            sed -i '/^local.*all.*all.*peer/a local   all             odoo                                    peer' "$HBA_FILE"
            
            # Reload PostgreSQL
            systemctl reload postgresql
            echo -e "${GREEN}✓ Peer authentication configured${NC}"
        fi
    fi
else
    echo -e "${YELLOW}⚠ PostgreSQL is not running${NC}"
fi

# Summary
echo -e "\n${BLUE}╔══════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║            Installation Complete            ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════╝${NC}"

echo -e "\n${GREEN}🎉 Odoo dependencies installation completed!${NC}"
echo
echo -e "${BLUE}Next steps:${NC}"
echo -e "${YELLOW}1.${NC} Run the test script: ./test-odoo-dependencies.sh"
echo -e "${YELLOW}2.${NC} Restart Odoo service: systemctl restart odoo"
echo -e "${YELLOW}3.${NC} Check Odoo logs: journalctl -u odoo -f"

exit 0
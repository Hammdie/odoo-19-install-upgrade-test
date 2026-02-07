#!/bin/bash

# wkhtmltopdf Qt-Patch Installation Script
# Installiert wkhtmltopdf mit Qt-Patch für Odoo PDF-Generierung

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

echo -e "${BLUE}${BOLD}"
cat << 'EOF'
╔═══════════════════════════════════════════════════╗
║       wkhtmltopdf Qt-Patch Installation Tool     ║
╚═══════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}This script must be run as root or with sudo${NC}"
        exit 1
    fi
}

# Install wkhtmltopdf with Qt patch
install_wkhtmltopdf() {
    echo -e "${YELLOW}🔧 Installing wkhtmltopdf with Qt patch...${NC}"
    
    # Check current status
    if command -v wkhtmltopdf &> /dev/null; then
        local current_version=$(wkhtmltopdf --version 2>&1)
        echo -e "${BLUE}Current version found:${NC}"
        echo -e "  $current_version"
        
        if echo "$current_version" | grep -q "with patched qt"; then
            echo -e "${GREEN}✓ Qt patched version already installed${NC}"
            echo -e "${YELLOW}Do you want to reinstall anyway? (y/N):${NC}"
            read -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                echo -e "${GREEN}Installation skipped${NC}"
                return 0
            fi
        else
            echo -e "${RED}⚠️  Current version does NOT have Qt patch${NC}"
            echo -e "${YELLOW}This will cause PDF generation issues in Odoo!${NC}"
        fi
        
        # Remove existing version
        echo -e "${BLUE}Removing existing wkhtmltopdf...${NC}"
        apt-get remove -y wkhtmltopdf 2>/dev/null || true
    else
        echo -e "${BLUE}No existing wkhtmltopdf found${NC}"
    fi
    
    # Get system information
    local arch=$(uname -m)
    local ubuntu_version=$(lsb_release -rs 2>/dev/null || echo "20.04")
    
    echo -e "${BLUE}System information:${NC}"
    echo -e "  Architecture: $arch"
    echo -e "  Ubuntu version: $ubuntu_version"
    
    # Determine correct package URL
    local package_url=""
    local package_name=""
    
    if [[ "$arch" == "x86_64" ]]; then
        if [[ $(echo "$ubuntu_version >= 22.04" | bc 2>/dev/null || echo 0) -eq 1 ]]; then
            package_url="https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-2/wkhtmltox_0.12.6.1-2.jammy_amd64.deb"
            package_name="wkhtmltox_0.12.6.1-2.jammy_amd64.deb"
        else
            package_url="https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-2/wkhtmltox_0.12.6.1-2.focal_amd64.deb"
            package_name="wkhtmltox_0.12.6.1-2.focal_amd64.deb"
        fi
    elif [[ "$arch" == "aarch64" ]] || [[ "$arch" == "arm64" ]]; then
        if [[ $(echo "$ubuntu_version >= 22.04" | bc 2>/dev/null || echo 0) -eq 1 ]]; then
            package_url="https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-2/wkhtmltox_0.12.6.1-2.jammy_arm64.deb"
            package_name="wkhtmltox_0.12.6.1-2.jammy_arm64.deb"
        else
            package_url="https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-2/wkhtmltox_0.12.6.1-2.focal_arm64.deb"
            package_name="wkhtmltox_0.12.6.1-2.focal_arm64.deb"
        fi
    else
        echo -e "${YELLOW}⚠️  Unsupported architecture: $arch${NC}"
        echo -e "${YELLOW}Falling back to repository version (may not have Qt patch)${NC}"
        apt-get update
        apt-get install -y wkhtmltopdf
        return 0
    fi
    
    echo -e "${BLUE}Selected package: $package_name${NC}"
    
    # Create temporary directory
    local temp_dir=$(mktemp -d)
    local package_file="$temp_dir/$package_name"
    
    # Install dependencies first
    echo -e "${BLUE}Installing dependencies...${NC}"
    apt-get update
    apt-get install -y \
        fontconfig \
        libfontconfig1 \
        libfreetype6 \
        libx11-6 \
        libxext6 \
        libxrender1 \
        libjpeg-turbo8 \
        libpng16-16 \
        libssl3 \
        ca-certificates \
        curl \
        wget \
        xvfb
    
    # Download package
    echo -e "${BLUE}Downloading wkhtmltopdf Qt patched version...${NC}"
    echo -e "  URL: $package_url"
    
    if curl -L --fail -o "$package_file" "$package_url" 2>/dev/null; then
        echo -e "${GREEN}✓ Download successful${NC}"
    else
        echo -e "${RED}✗ Download failed${NC}"
        echo -e "${YELLOW}Trying alternative download method...${NC}"
        
        if wget -O "$package_file" "$package_url" 2>/dev/null; then
            echo -e "${GREEN}✓ Download successful (wget)${NC}"
        else
            echo -e "${RED}✗ All download methods failed${NC}"
            echo -e "${YELLOW}Falling back to repository version...${NC}"
            rm -rf "$temp_dir"
            apt-get install -y wkhtmltopdf
            return 1
        fi
    fi
    
    # Verify download
    if [[ ! -f "$package_file" ]] || [[ ! -s "$package_file" ]]; then
        echo -e "${RED}✗ Downloaded file is invalid${NC}"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Install package
    echo -e "${BLUE}Installing wkhtmltopdf package...${NC}"
    
    if dpkg -i "$package_file" 2>/dev/null; then
        echo -e "${GREEN}✓ Package installed successfully${NC}"
    else
        echo -e "${YELLOW}Package installation failed, fixing dependencies...${NC}"
        apt-get install -f -y
        
        if dpkg -i "$package_file" 2>/dev/null; then
            echo -e "${GREEN}✓ Package installed after dependency fix${NC}"
        else
            echo -e "${RED}✗ Package installation failed${NC}"
            rm -rf "$temp_dir"
            return 1
        fi
    fi
    
    # Cleanup
    rm -rf "$temp_dir"
    
    # Verify installation
    echo -e "${BLUE}Verifying installation...${NC}"
    
    if command -v wkhtmltopdf &> /dev/null; then
        local installed_version=$(wkhtmltopdf --version 2>&1)
        echo -e "${GREEN}✓ wkhtmltopdf installed successfully${NC}"
        echo -e "${BLUE}Version:${NC} $(echo "$installed_version" | head -1)"
        
        if echo "$installed_version" | grep -q "with patched qt"; then
            echo -e "${GREEN}✓ Qt patch confirmed${NC}"
        else
            echo -e "${YELLOW}⚠️  Qt patch not detected${NC}"
            return 1
        fi
        
        # Test PDF generation
        echo -e "${BLUE}Testing PDF generation...${NC}"
        
        if echo "<html><body><h1>Test PDF</h1><p>This is a test document.</p></body></html>" | wkhtmltopdf - /tmp/test.pdf 2>/dev/null; then
            echo -e "${GREEN}✓ PDF generation test successful${NC}"
            rm -f /tmp/test.pdf
        else
            echo -e "${YELLOW}⚠️  PDF generation test failed${NC}"
            echo -e "${YELLOW}This may indicate missing dependencies or X11 issues${NC}"
        fi
        
        return 0
    else
        echo -e "${RED}✗ Installation verification failed${NC}"
        return 1
    fi
}

# Main function
main() {
    echo -e "${BLUE}Starting wkhtmltopdf Qt-Patch installation...${NC}"
    echo
    
    check_root
    
    if install_wkhtmltopdf; then
        echo
        echo -e "${GREEN}${BOLD}🎉 wkhtmltopdf Qt-Patch installation completed successfully!${NC}"
        echo
        echo -e "${BLUE}Installation details:${NC}"
        echo -e "  • Binary location: $(which wkhtmltopdf)"
        echo -e "  • Version: $(wkhtmltopdf --version 2>&1 | head -1)"
        echo
        echo -e "${GREEN}✓ Odoo PDF reports should now work properly${NC}"
    else
        echo
        echo -e "${RED}${BOLD}❌ wkhtmltopdf installation failed${NC}"
        echo -e "${YELLOW}Troubleshooting:${NC}"
        echo -e "  • Check internet connection"
        echo -e "  • Verify system architecture compatibility"
        echo -e "  • Try manual installation from GitHub releases"
        echo -e "  • Check system logs for detailed error information"
    fi
}

# Run main function
main "$@"
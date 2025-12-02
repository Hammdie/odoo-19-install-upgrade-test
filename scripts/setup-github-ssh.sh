#!/bin/bash

###############################################################################
# GitHub SSH Key Setup Script
# 
# Erstellt und konfiguriert SSH-Schlüssel für GitHub-Zugriff
# Nützlich für Enterprise Repository oder eigene GitHub Repositories
#
# Usage:
#   sudo ./setup-github-ssh.sh
#   ./setup-github-ssh.sh  (ohne sudo für aktuellen Benutzer)
###############################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Banner
show_banner() {
    echo -e "${GREEN}${BOLD}"
    cat << "EOF"
   ____ _ _   _   _       _       ____ ____  _   _ 
  / ___(_) |_| | | |_   _| |__   / ___/ ___|| | | |
 | |  _| | __| |_| | | | | '_ \  \___ \___ \| |_| |
 | |_| | | |_|  _  | |_| | |_) |  ___) |__) |  _  |
  \____|_|\__|_| |_|\__,_|_.__/  |____/____/|_| |_|
                                                    
EOF
    echo -e "${NC}"
    echo -e "${BLUE}${BOLD}        SSH Key Setup für GitHub${NC}"
    echo
}

# Get current user
get_current_user() {
    if [[ -n "$SUDO_USER" ]]; then
        echo "$SUDO_USER"
    else
        echo "$USER"
    fi
}

# Test GitHub SSH connection
test_github_connection() {
    local user="$1"
    local test_output
    
    echo
    echo -e "${BLUE}${BOLD}Testing GitHub SSH Connection...${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    if [[ "$user" == "root" ]]; then
        test_output=$(ssh -T git@github.com 2>&1 || true)
    else
        test_output=$(su - "$user" -c "ssh -T git@github.com" 2>&1 || true)
    fi
    
    if echo "$test_output" | grep -q "successfully authenticated"; then
        echo -e "${GREEN}✓ GitHub Authentication: SUCCESS${NC}"
        
        # Test Enterprise repository access
        echo -e "${BLUE}Testing Enterprise Repository Access...${NC}"
        local repo_test
        if [[ "$user" == "root" ]]; then
            repo_test=$(git ls-remote git@github.com:odoo/enterprise.git HEAD 2>&1 || true)
        else
            repo_test=$(su - "$user" -c "git ls-remote git@github.com:odoo/enterprise.git HEAD" 2>&1 || true)
        fi
        
        if echo "$repo_test" | grep -q "refs/heads"; then
            echo -e "${GREEN}✓ Enterprise Repository Access: SUCCESS${NC}"
        else
            echo -e "${YELLOW}⚠ Enterprise Repository Access: DENIED${NC}"
            echo -e "${YELLOW}  (Normal if you don't have Odoo Partner access)${NC}"
        fi
    else
        echo -e "${RED}✗ GitHub Authentication: FAILED${NC}"
        echo
        echo -e "${YELLOW}Output from GitHub:${NC}"
        echo "$test_output" | head -5
    fi
    
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo
}

# Show public key
show_public_key() {
    local ssh_dir="$1"
    local key_type="$2"
    local key_file="$ssh_dir/id_$key_type"
    
    if [[ -f "$key_file.pub" ]]; then
        echo
        echo -e "${GREEN}${BOLD}Your ${key_type^^} Public SSH Key:${NC}"
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        cat "$key_file.pub"
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo
        echo -e "${YELLOW}Add this key to GitHub:${NC}"
        echo -e "  1. Go to: ${BLUE}https://github.com/settings/keys${NC}"
        echo -e "  2. Click ${GREEN}'New SSH key'${NC}"
        echo -e "  3. Title: ${GREEN}$(hostname) - $(date +%Y-%m-%d)${NC}"
        echo -e "  4. Key type: ${GREEN}Authentication Key${NC}"
        echo -e "  5. Paste the key above"
        echo -e "  6. Click ${GREEN}'Add SSH key'${NC}"
        echo
    else
        echo -e "${RED}Error: Key file not found: $key_file.pub${NC}"
    fi
}

# Generate SSH key
generate_ssh_key() {
    local user="$1"
    local user_home=$(eval echo ~$user)
    local ssh_dir="$user_home/.ssh"
    local key_type="$2"
    local key_file="$ssh_dir/id_$key_type"
    
    echo
    echo -e "${BLUE}Generating ${key_type^^} SSH key for user: ${GREEN}$user${NC}"
    
    # Create SSH directory if it doesn't exist
    if [[ "$user" == "root" ]]; then
        mkdir -p "$ssh_dir"
        chmod 700 "$ssh_dir"
    else
        su - "$user" -c "mkdir -p $ssh_dir && chmod 700 $ssh_dir"
    fi
    
    # Generate key
    if [[ -f "$key_file" ]]; then
        echo -e "${YELLOW}Key already exists: $key_file${NC}"
        read -p "Overwrite existing key? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${BLUE}Showing existing key instead...${NC}"
            show_public_key "$ssh_dir" "$key_type"
            return 0
        fi
    fi
    
    echo -e "${BLUE}Creating new SSH key...${NC}"
    if [[ "$user" == "root" ]]; then
        if [[ "$key_type" == "ed25519" ]]; then
            ssh-keygen -t ed25519 -C "$user@$(hostname)" -f "$key_file" -N ""
        else
            ssh-keygen -t rsa -b 4096 -C "$user@$(hostname)" -f "$key_file" -N ""
        fi
    else
        if [[ "$key_type" == "ed25519" ]]; then
            su - "$user" -c "ssh-keygen -t ed25519 -C '$user@$(hostname)' -f $key_file -N ''"
        else
            su - "$user" -c "ssh-keygen -t rsa -b 4096 -C '$user@$(hostname)' -f $key_file -N ''"
        fi
    fi
    
    echo -e "${GREEN}✓ SSH key generated successfully${NC}"
    show_public_key "$ssh_dir" "$key_type"
}

# Main menu
main_menu() {
    local user=$(get_current_user)
    local user_home=$(eval echo ~$user)
    local ssh_dir="$user_home/.ssh"
    
    # Check existing keys
    local has_ed25519=false
    local has_rsa=false
    
    [[ -f "$ssh_dir/id_ed25519" ]] && has_ed25519=true
    [[ -f "$ssh_dir/id_rsa" ]] && has_rsa=true
    
    while true; do
        echo
        echo -e "${BOLD}SSH Key Management for user: ${GREEN}$user${NC}"
        echo -e "${BOLD}SSH directory: ${GREEN}$ssh_dir${NC}"
        echo
        echo -e "${BOLD}Current Status:${NC}"
        if $has_ed25519; then
            echo -e "  ${GREEN}✓${NC} ED25519 key exists: $ssh_dir/id_ed25519"
        else
            echo -e "  ${RED}✗${NC} No ED25519 key"
        fi
        if $has_rsa; then
            echo -e "  ${GREEN}✓${NC} RSA key exists: $ssh_dir/id_rsa"
        else
            echo -e "  ${RED}✗${NC} No RSA key"
        fi
        echo
        echo -e "${BOLD}Choose an option:${NC}"
        echo -e "  ${GREEN}1)${NC} Test GitHub connection"
        echo -e "  ${GREEN}2)${NC} Show existing ED25519 public key"
        echo -e "  ${GREEN}3)${NC} Show existing RSA public key"
        echo -e "  ${GREEN}4)${NC} Generate new ED25519 SSH key (recommended)"
        echo -e "  ${GREEN}5)${NC} Generate new RSA 4096-bit SSH key"
        echo -e "  ${GREEN}6)${NC} GitHub SSH Keys Management (opens browser)"
        echo -e "  ${RED}0)${NC} Exit"
        echo
        
        read -p "Select option [0-6]: " choice
        
        case $choice in
            1)
                test_github_connection "$user"
                read -p "Press Enter to continue..."
                ;;
            2)
                if $has_ed25519; then
                    show_public_key "$ssh_dir" "ed25519"
                else
                    echo -e "${RED}No ED25519 key found. Generate one with option 4.${NC}"
                fi
                read -p "Press Enter to continue..."
                ;;
            3)
                if $has_rsa; then
                    show_public_key "$ssh_dir" "rsa"
                else
                    echo -e "${RED}No RSA key found. Generate one with option 5.${NC}"
                fi
                read -p "Press Enter to continue..."
                ;;
            4)
                generate_ssh_key "$user" "ed25519"
                has_ed25519=true
                read -p "Press Enter to continue..."
                ;;
            5)
                generate_ssh_key "$user" "rsa"
                has_rsa=true
                read -p "Press Enter to continue..."
                ;;
            6)
                echo
                echo -e "${BLUE}Opening GitHub SSH Keys page...${NC}"
                echo -e "${YELLOW}URL: ${BLUE}https://github.com/settings/keys${NC}"
                echo
                if command -v xdg-open &> /dev/null; then
                    xdg-open "https://github.com/settings/keys" 2>/dev/null || true
                elif command -v open &> /dev/null; then
                    open "https://github.com/settings/keys" 2>/dev/null || true
                else
                    echo -e "${YELLOW}Please manually open: https://github.com/settings/keys${NC}"
                fi
                read -p "Press Enter to continue..."
                ;;
            0)
                echo
                echo -e "${GREEN}Goodbye!${NC}"
                echo
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid option. Please select 0-6.${NC}"
                sleep 1
                ;;
        esac
    done
}

# Main
main() {
    show_banner
    
    echo -e "${BLUE}This script helps you manage SSH keys for GitHub access.${NC}"
    echo -e "${BLUE}Useful for: Odoo Enterprise, private repositories, or any GitHub access.${NC}"
    echo
    
    main_menu
}

main "$@"

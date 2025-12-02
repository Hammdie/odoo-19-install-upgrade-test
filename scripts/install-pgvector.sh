#!/bin/bash
################################################################################
# Script: install-pgvector.sh
# Description: Install PostgreSQL pgvector extension for RAG/AI support
# Usage: sudo ./install-pgvector.sh
# Documentation: https://github.com/pgvector/pgvector
################################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging
LOG_DIR="/var/log/odoo"
LOG_FILE="$LOG_DIR/pgvector-install_$(date +%Y%m%d_%H%M%S).log"

log() {
    local level=$1
    shift
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
    
    case $level in
        ERROR)
            echo -e "${RED}[ERROR]${NC} $message"
            ;;
        SUCCESS)
            echo -e "${GREEN}[SUCCESS]${NC} $message"
            ;;
        WARN)
            echo -e "${YELLOW}[WARN]${NC} $message"
            ;;
        INFO)
            echo -e "${BLUE}[INFO]${NC} $message"
            ;;
    esac
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}This script must be run as root${NC}"
        echo "Please run: sudo $0"
        exit 1
    fi
}

# Create log directory
create_log_dir() {
    mkdir -p "$LOG_DIR"
    chmod 755 "$LOG_DIR"
}

# Main installation function
install_pgvector() {
    log "INFO" "Starting pgvector installation..."
    log "INFO" "Documentation: https://github.com/pgvector/pgvector"
    
    # Find PostgreSQL version
    local pg_version=$(sudo -u postgres psql -t -c "SHOW server_version;" 2>/dev/null | grep -o '[0-9]*' | head -n1)
    if [[ -z "$pg_version" ]]; then
        pg_version=$(ls /etc/postgresql/ 2>/dev/null | head -n1)
    fi
    
    if [[ -z "$pg_version" ]]; then
        echo ""
        echo "╔════════════════════════════════════════════════════════════════════════════╗"
        echo "║                                                                            ║"
        echo "║  ❌ POSTGRESQL NOT FOUND ❌                                                ║"
        echo "║                                                                            ║"
        echo "╚════════════════════════════════════════════════════════════════════════════╝"
        echo ""
        log "ERROR" "Could not detect PostgreSQL installation"
        log "ERROR" "Please install PostgreSQL first"
        echo ""
        echo "📋 Full log details: $LOG_FILE"
        echo ""
        exit 1
    fi
    
    log "INFO" "Detected PostgreSQL version: $pg_version"
    
    # Check if pgvector is already installed
    if sudo -u postgres psql -c "SELECT extversion FROM pg_extension WHERE extname='vector';" 2>/dev/null | grep -q "[0-9]"; then
        local current_version=$(sudo -u postgres psql -t -c "SELECT extversion FROM pg_extension WHERE extname='vector';" | xargs)
        log "INFO" "pgvector is already installed (version $current_version)"
        
        echo ""
        read -p "Do you want to reinstall/upgrade pgvector? (y/n): " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log "INFO" "Installation cancelled by user"
            exit 0
        fi
    fi
    
    # Install build dependencies
    log "INFO" "Installing build dependencies..."
    apt-get update 2>&1 | tee -a "$LOG_FILE"
    apt-get install -y \
        postgresql-server-dev-$pg_version \
        build-essential \
        git \
        make \
        gcc \
        postgresql-common 2>&1 | tee -a "$LOG_FILE" || {
        echo ""
        echo "╔════════════════════════════════════════════════════════════════════════════╗"
        echo "║                                                                            ║"
        echo "║  ❌ DEPENDENCY INSTALLATION FAILED ❌                                      ║"
        echo "║                                                                            ║"
        echo "╚════════════════════════════════════════════════════════════════════════════╝"
        echo ""
        log "ERROR" "Failed to install build dependencies"
        echo ""
        echo "📋 Full log details: $LOG_FILE"
        echo ""
        exit 1
    }
    
    log "SUCCESS" "Build dependencies installed"
    
    # Clone pgvector repository
    log "INFO" "Cloning pgvector from GitHub..."
    local pgvector_dir="/tmp/pgvector-$(date +%Y%m%d%H%M%S)"
    
    if git clone --depth 1 https://github.com/pgvector/pgvector.git "$pgvector_dir" 2>&1 | tee -a "$LOG_FILE"; then
        log "SUCCESS" "pgvector repository cloned to $pgvector_dir"
    else
        echo ""
        echo "╔════════════════════════════════════════════════════════════════════════════╗"
        echo "║                                                                            ║"
        echo "║  ❌ GIT CLONE FAILED ❌                                                    ║"
        echo "║                                                                            ║"
        echo "╚════════════════════════════════════════════════════════════════════════════╝"
        echo ""
        log "ERROR" "Failed to clone pgvector repository"
        log "ERROR" "URL: https://github.com/pgvector/pgvector.git"
        echo ""
        echo "📋 Full log details: $LOG_FILE"
        echo ""
        exit 1
    fi
    
    # Build and install
    log "INFO" "Building pgvector..."
    cd "$pgvector_dir" || exit 1
    
    if make 2>&1 | tee -a "$LOG_FILE"; then
        log "SUCCESS" "pgvector compiled successfully"
    else
        echo ""
        echo "╔════════════════════════════════════════════════════════════════════════════╗"
        echo "║                                                                            ║"
        echo "║  ❌ COMPILATION FAILED ❌                                                  ║"
        echo "║                                                                            ║"
        echo "╚════════════════════════════════════════════════════════════════════════════╝"
        echo ""
        log "ERROR" "Failed to compile pgvector"
        cd /
        rm -rf "$pgvector_dir"
        echo ""
        echo "📋 Full log details: $LOG_FILE"
        echo ""
        exit 1
    fi
    
    log "INFO" "Installing pgvector..."
    if make install 2>&1 | tee -a "$LOG_FILE"; then
        log "SUCCESS" "pgvector installed successfully"
    else
        echo ""
        echo "╔════════════════════════════════════════════════════════════════════════════╗"
        echo "║                                                                            ║"
        echo "║  ❌ INSTALLATION FAILED ❌                                                 ║"
        echo "║                                                                            ║"
        echo "╚════════════════════════════════════════════════════════════════════════════╝"
        echo ""
        log "ERROR" "Failed to install pgvector"
        cd /
        rm -rf "$pgvector_dir"
        echo ""
        echo "📋 Full log details: $LOG_FILE"
        echo ""
        exit 1
    fi
    
    # Enable extension in default database
    log "INFO" "Enabling pgvector extension in PostgreSQL..."
    if sudo -u postgres psql -c "CREATE EXTENSION IF NOT EXISTS vector;" 2>&1 | tee -a "$LOG_FILE"; then
        log "SUCCESS" "pgvector extension enabled in default database"
    else
        log "WARN" "Could not enable vector extension in default database"
        log "INFO" "You can enable it manually per database with: CREATE EXTENSION vector;"
    fi
    
    # Verify installation
    if sudo -u postgres psql -c "SELECT extversion FROM pg_extension WHERE extname='vector';" 2>/dev/null | grep -q "[0-9]"; then
        local vector_version=$(sudo -u postgres psql -t -c "SELECT extversion FROM pg_extension WHERE extname='vector';" | xargs)
        
        echo ""
        echo "╔════════════════════════════════════════════════════════════════════════════╗"
        echo "║                                                                            ║"
        echo "║  ✅ PGVECTOR INSTALLATION SUCCESSFUL ✅                                    ║"
        echo "║                                                                            ║"
        echo "╚════════════════════════════════════════════════════════════════════════════╝"
        echo ""
        log "SUCCESS" "pgvector version $vector_version installed and verified"
        log "INFO" "Vector similarity search is now available in PostgreSQL"
        log "INFO" "RAG capabilities enabled for Odoo AI agents"
        echo ""
        echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║                                                              ║${NC}"
        echo -e "${GREEN}║  USAGE INSTRUCTIONS                                          ║${NC}"
        echo -e "${GREEN}║                                                              ║${NC}"
        echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo "1️⃣  Enable in your Odoo database:"
        echo "    psql -U odoo -d your_database_name -c 'CREATE EXTENSION vector;'"
        echo ""
        echo "2️⃣  Verify installation:"
        echo "    psql -U odoo -d your_database_name -c 'SELECT extversion FROM pg_extension WHERE extname=\\'vector\\';'"
        echo ""
        echo "3️⃣  Example vector operations:"
        echo "    CREATE TABLE items (id bigserial PRIMARY KEY, embedding vector(3));"
        echo "    INSERT INTO items (embedding) VALUES ('[1,2,3]'), ('[4,5,6]');"
        echo "    SELECT * FROM items ORDER BY embedding <-> '[3,1,2]' LIMIT 5;"
        echo ""
        echo "4️⃣  Documentation:"
        echo "    https://github.com/pgvector/pgvector"
        echo ""
    else
        log "WARN" "pgvector installed but not enabled"
        log "INFO" "Enable per database with: CREATE EXTENSION vector;"
    fi
    
    # Cleanup
    cd /
    rm -rf "$pgvector_dir"
    log "INFO" "Build directory cleaned up"
    
    echo ""
    echo "📋 Full log: $LOG_FILE"
    echo ""
}

# Main execution
main() {
    create_log_dir
    check_root
    
    echo ""
    echo "╔════════════════════════════════════════════════════════════════════════════╗"
    echo "║                                                                            ║"
    echo "║  PostgreSQL pgvector Extension Installer                                   ║"
    echo "║  Enable vector similarity search for RAG/AI                                ║"
    echo "║                                                                            ║"
    echo "╚════════════════════════════════════════════════════════════════════════════╝"
    echo ""
    
    install_pgvector
}

main "$@"

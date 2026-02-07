#!/bin/bash

# SSH Remote Execution Script for Odoo Installation Repair
# Run this script locally to execute commands on office.hecker24.net

SERVER="office.hecker24.net"
USER="root"

echo "🚀 Executing Odoo repair installation on $SERVER..."

# Execute commands on remote server
ssh $USER@$SERVER << 'EOF'
    set -e
    
    echo "📁 Navigating to project directory..."
    cd /var/odoo-upgrade-cron || { echo "❌ Project directory not found"; exit 1; }
    
    echo "📥 Pulling latest changes..."
    git pull origin main || echo "⚠️  Git pull failed - continuing with local files"
    
    echo "🔧 Making scripts executable..."
    chmod +x *.sh
    chmod +x scripts/*.sh
    
    echo "🛑 Stopping existing Odoo service..."
    systemctl stop odoo 2>/dev/null || true
    
    echo "🔥 Starting FORCE installation with repaired scripts..."
    ./install.sh --auto --force --nginx-domain office.hecker24.net --nginx-email admin@detalex.de
    
    echo "✅ Installation completed!"
    
    echo "🔍 Checking service status..."
    systemctl status odoo --no-pager
    
    echo "🌐 Testing web access..."
    curl -I http://localhost:8069 || echo "⚠️  Web access test failed"
    
EOF

echo "🏁 Remote execution completed!"
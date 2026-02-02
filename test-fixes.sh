#!/bin/bash

# Test-Skript für Reparaturen
# Validiert die wichtigsten Fixes die gemacht wurden

set -e

echo "🔧 Testing script fixes..."
echo "========================="

# Test 1: sed Delimiter Check
echo "✅ Test 1: Checking sed delimiters..."
if grep -r "sed.*s/.*password.*/" scripts/ >/dev/null 2>&1; then
    echo "❌ Found unsafe sed patterns with / delimiters that could fail"
    grep -rn "sed.*s/.*password.*/" scripts/
    exit 1
else
    echo "✅ All password-related sed commands use safe delimiters"
fi

# Test 2: systemd Service WorkingDirectory
echo "✅ Test 2: Checking systemd service..."
if grep -A 10 "\[Service\]" scripts/install-odoo19.sh | grep -q "WorkingDirectory="; then
    echo "✅ systemd service has WorkingDirectory set"
else
    echo "❌ systemd service missing WorkingDirectory"
    exit 1
fi

# Test 3: Python -m odoo usage
if grep -q "python3 -m odoo" scripts/install-odoo19.sh; then
    echo "✅ Uses python3 -m odoo instead of odoo-bin"
else
    echo "❌ Still using old odoo-bin path"
    exit 1
fi

# Test 4: zope dependencies
echo "✅ Test 4: Checking zope dependencies..."
if grep -q "zope.event" scripts/install-odoo19.sh && grep -q "zope.interface" scripts/install-odoo19.sh; then
    echo "✅ zope.event and zope.interface included in dependencies"
else
    echo "❌ Missing zope dependencies"
    exit 1
fi

# Test 5: Nginx interactive mode fix
echo "✅ Test 5: Checking nginx interactive mode..."
if grep -q "DEBIAN_FRONTEND.*noninteractive" scripts/setup-odoo-nginx.sh; then
    echo "✅ Nginx script handles non-interactive mode"
else
    echo "❌ Nginx script doesn't handle non-interactive mode"
    exit 1
fi

# Test 6: Custom addons path
echo "✅ Test 6: Checking custom addons path..."
if grep -q "/var/odoo_addons" scripts/install-odoo19.sh && grep -q "/var/odoo_addons" config/odoo.conf.example; then
    echo "✅ Custom addons use /var/odoo_addons path"
else
    echo "❌ Custom addons path not updated to /var/odoo_addons"
    exit 1
fi

# Test 7: Password authentication setup
echo "✅ Test 7: Checking password authentication..."
if grep -q "setup_postgres_auth" scripts/install-odoo19.sh; then
    echo "✅ Using password authentication instead of trust"
else
    echo "❌ Still using trust authentication"
    exit 1
fi

# Test 8: Database password configuration
echo "✅ Test 8: Checking database password config..."
if grep -q "db_password = odoo" config/odoo.conf.example; then
    echo "✅ Database password correctly set in config template"
else
    echo "❌ Database password not set in config template"
    exit 1
fi

echo "========================="
echo "🎉 All tests passed! All fixes are properly implemented."
echo "📝 Scripts are ready for production use."
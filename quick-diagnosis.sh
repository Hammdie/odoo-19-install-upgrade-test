#!/bin/bash

# Quick Diagnosis Script - Erstelle direkt auf dem Server
# Führe aus: sudo bash quick-diagnosis.sh

echo "=== ODOO INSTALLATION DIAGNOSE ==="
echo "Datum: $(date)"
echo "System: $(uname -a)"
echo

# 1. Service Status
echo "=== 1. ODOO SERVICE STATUS ==="
if systemctl list-unit-files | grep -q odoo; then
    echo "✓ Odoo service gefunden"
    systemctl status odoo --no-pager -l
else
    echo "❌ Odoo service NICHT GEFUNDEN"
fi
echo

# 2. Odoo User
echo "=== 2. ODOO USER ==="
if id odoo &>/dev/null; then
    echo "✓ Odoo user existiert: $(id odoo)"
else
    echo "❌ Odoo user NICHT GEFUNDEN"
fi
echo

# 3. Odoo Installation
echo "=== 3. ODOO INSTALLATION ==="
if [[ -d "/opt/odoo" ]]; then
    echo "✓ Odoo Verzeichnis gefunden: /opt/odoo"
    ls -la /opt/odoo/
else
    echo "❌ Odoo Verzeichnis NICHT GEFUNDEN: /opt/odoo"
fi

if [[ -f "/etc/odoo/odoo.conf" ]]; then
    echo "✓ Odoo Config gefunden: /etc/odoo/odoo.conf"
else
    echo "❌ Odoo Config NICHT GEFUNDEN: /etc/odoo/odoo.conf"
fi
echo

# 4. PostgreSQL
echo "=== 4. POSTGRESQL ==="
if systemctl is-active --quiet postgresql; then
    echo "✓ PostgreSQL läuft"
    if sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='odoo'" | grep -q "1"; then
        echo "✓ PostgreSQL odoo user existiert"
    else
        echo "❌ PostgreSQL odoo user NICHT GEFUNDEN"
    fi
else
    echo "❌ PostgreSQL läuft NICHT"
    systemctl status postgresql --no-pager -l
fi
echo

# 5. Python Odoo Paket
echo "=== 5. PYTHON ODOO PAKET ==="
if python3 -c "import odoo; print('Odoo Version:', odoo.__version__)" 2>/dev/null; then
    echo "✓ Odoo Python Paket OK"
else
    echo "❌ Odoo Python Paket FEHLT - DAS IST DAS HAUPTPROBLEM!"
fi
echo

# 6. wkhtmltopdf (KRITISCH für PDF)
echo "=== 6. WKHTMLTOPDF (KRITISCH!) ==="
if command -v wkhtmltopdf &>/dev/null; then
    version_info=$(wkhtmltopdf --version 2>&1)
    echo "✓ wkhtmltopdf gefunden"
    echo "Version: $(echo "$version_info" | head -1)"
    if echo "$version_info" | grep -q "with patched qt"; then
        echo "✓ Qt patch vorhanden"
    else
        echo "❌ Qt patch FEHLT - PDF Reports werden nicht funktionieren!"
    fi
else
    echo "❌ wkhtmltopdf NICHT GEFUNDEN - PDF Reports werden NICHT funktionieren!"
fi
echo

# 7. Logs
echo "=== 7. LOGS ==="
if [[ -d "/var/log/odoo-upgrade" ]]; then
    echo "✓ Log Verzeichnis gefunden"
    echo "Verfügbare Logs:"
    ls -la /var/log/odoo-upgrade/
    
    # Zeige neueste Error-Log
    latest_error=$(ls -t /var/log/odoo-upgrade/error-*.log 2>/dev/null | head -1)
    if [[ -n "$latest_error" ]]; then
        echo
        echo "=== NEUESTE ERROR-LOG ==="
        echo "File: $latest_error"
        echo "Content:"
        cat "$latest_error"
    fi
    
    # Zeige neuestes Install-Log (letzte 20 Zeilen)
    latest_install=$(ls -t /var/log/odoo-upgrade/install-*.log 2>/dev/null | head -1)
    if [[ -n "$latest_install" ]]; then
        echo
        echo "=== NEUESTES INSTALL-LOG (letzte 20 Zeilen) ==="
        echo "File: $latest_install"
        tail -20 "$latest_install"
    fi
else
    echo "❌ Log Verzeichnis nicht gefunden: /var/log/odoo-upgrade"
fi
echo

# 8. Zusammenfassung
echo "=== 8. DIAGNOSE ZUSAMMENFASSUNG ==="
echo "Häufigste Probleme und Lösungen:"
echo
if ! systemctl list-unit-files | grep -q odoo; then
    echo "🔥 HAUPTPROBLEM: Odoo Service nicht installiert"
    echo "   Lösung: Neuinstallation erforderlich"
fi

if ! python3 -c "import odoo" &>/dev/null; then
    echo "🔥 HAUPTPROBLEM: Odoo Python Paket fehlt"
    echo "   Lösung: pip3 install --break-system-packages -e /opt/odoo/odoo"
fi

if ! command -v wkhtmltopdf &>/dev/null; then
    echo "⚠️  PROBLEM: wkhtmltopdf fehlt"
    echo "   Lösung: apt install wkhtmltopdf oder Qt-Patch Version installieren"
fi

echo
echo "=== NÄCHSTE SCHRITTE ==="
echo "1. Force Reinstall: sudo ./install.sh --auto --force --nginx-domain office.hecker24.net --nginx-email admin@detalex.de"
echo "2. Oder manuell Python Paket installieren: cd /opt/odoo/odoo && pip3 install --break-system-packages -e ."
echo "3. Service Status prüfen: systemctl status odoo"
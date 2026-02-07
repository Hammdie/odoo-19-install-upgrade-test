#!/bin/bash

# Setup-Script für die verbesserten Diagnose- und Fix-Tools

echo "Setting up Odoo installation troubleshooting tools..."

# Aktuelle Verzeichnis
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Skripte ausführbar machen
chmod +x "$SCRIPT_DIR/diagnose-installation.sh"
chmod +x "$SCRIPT_DIR/fix-installation.sh"
chmod +x "$SCRIPT_DIR/fix-wkhtmltopdf.sh"
chmod +x "$SCRIPT_DIR/show-error-log.sh"
chmod +x "$SCRIPT_DIR/install.sh"

echo "✓ Scripts made executable"

# Überprüfung der wichtigsten Dateien
echo
echo "Checking created files:"

if [[ -f "$SCRIPT_DIR/diagnose-installation.sh" ]]; then
    echo "✓ diagnose-installation.sh - $(wc -l < "$SCRIPT_DIR/diagnose-installation.sh") lines"
else
    echo "✗ diagnose-installation.sh missing"
fi

if [[ -f "$SCRIPT_DIR/fix-installation.sh" ]]; then
    echo "✓ fix-installation.sh - $(wc -l < "$SCRIPT_DIR/fix-installation.sh") lines"
else
    echo "✗ fix-installation.sh missing"
fi

if [[ -f "$SCRIPT_DIR/fix-wkhtmltopdf.sh" ]]; then
    echo "✓ fix-wkhtmltopdf.sh - $(wc -l < "$SCRIPT_DIR/fix-wkhtmltopdf.sh") lines"
else
    echo "✗ fix-wkhtmltopdf.sh missing"
fi

if [[ -f "$SCRIPT_DIR/show-error-log.sh" ]]; then
    echo "✓ show-error-log.sh - $(wc -l < "$SCRIPT_DIR/show-error-log.sh") lines"
else
    echo "✗ show-error-log.sh missing"
fi

if [[ -f "$SCRIPT_DIR/TROUBLESHOOTING.md" ]]; then
    echo "✓ TROUBLESHOOTING.md - $(wc -l < "$SCRIPT_DIR/TROUBLESHOOTING.md") lines"
else
    echo "✗ TROUBLESHOOTING.md missing"
fi

echo
echo "=== WICHTIGE VERBESSERUNGEN ==="
echo
echo "1. ERROR LOGGING:"
echo "   • Separate error.log wird erstellt bei Fehlern"
echo "   • Pfad: /var/log/odoo-upgrade/error-DATUM.log"
echo
echo "2. KEINE SUCCESS-MELDUNG BEI FEHLERN:"
echo "   • Installation zeigt nur Success wenn wirklich erfolgreich"
echo "   • Bei Fehlern: Klare Fehlermeldung + Troubleshooting-Hinweise"
echo
echo "3. KEINE USER-PROMPTS IM AUTO-MODE:"
echo "   • --auto Mode wartet nie auf Benutzereingaben"
echo "   • Alle Prompts werden automatisch mit Defaults beantwortet"
echo
echo "4. WKHTMLTOPDF QT-PATCH ÜBERPRÜFUNG:"
echo "   • Kritische PDF-Generierung wird geprüft"
echo "   • Automatische Installation der Qt-Patch Version"
echo "   • Separate Fix-Tool: ./fix-wkhtmltopdf.sh"
echo
echo "5. NEUE DIAGNOSE-TOOLS:"
echo "   • ./diagnose-installation.sh - Vollständige Systemdiagnose"
echo "   • ./fix-installation.sh - Automatische Fehlerbehebung"
echo "   • ./fix-wkhtmltopdf.sh - wkhtmltopdf Qt-Patch Installation"
echo "   • ./show-error-log.sh - Error-Log für Support anzeigen"
echo
echo "=== NÄCHSTE SCHRITTE ==="
echo
echo "Nach fehlgeschlagener Installation ausführen:"
echo
echo "1. Diagnose:"
echo "   sudo ./diagnose-installation.sh"
echo
echo "2. Error-Log für Support anzeigen:"
echo "   sudo ./show-error-log.sh"
echo
echo "3. Automatische Reparatur:"
echo "   sudo ./fix-installation.sh"
echo
echo "4. wkhtmltopdf Qt-Patch prüfen/installieren:"
echo "   sudo ./fix-wkhtmltopdf.sh"
echo
echo "5. Wenn das nicht hilft - Force Reinstall:"
echo "   sudo ./install.sh --auto --force --nginx-domain office.hecker24.net --nginx-email admin@detalex.de"
echo
echo "=== LOG-DATEIEN ÜBERWACHEN ==="
echo
echo "Installation Logs:"
echo "   ls -la /var/log/odoo-upgrade/"
echo
echo "Error Logs ansehen:"
echo "   tail -f /var/log/odoo-upgrade/error-*.log"
echo
echo "Service Status prüfen:"
echo "   sudo systemctl status odoo"
echo "   sudo journalctl -u odoo -f"
echo
echo "Setup completed successfully!"
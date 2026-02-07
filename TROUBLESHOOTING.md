# Odoo Installation Problembehandlung

Nach der Ausführung von `./install.sh --auto --nginx-domain office.hecker24.net --nginx-email admin@detalex.de` ist der Odoo Service nicht installiert? Diese Tools helfen bei der Diagnose und Fehlerbehebung.

## 🚨 **WICHTIGE VERBESSERUNGEN**

Das Installationsskript wurde verbessert:
- ❌ **Keine Success-Meldung bei fehlgeschlagener Installation**
- 📝 **Separate Error-Log-Datei** (`/var/log/odoo-upgrade/error-*.log`)
- 🤖 **Keine User-Prompts im AUTO-MODE** (wartet nie auf Y/N Eingaben)
- 🔧 **Automatische Diagnose- und Fix-Tools**
- 📝 **wkhtmltopdf Qt-Patch Überprüfung** (kritisch für PDF-Reports)

## 🔍 Diagnose-Tools

### 1. Installation Diagnostizieren
```bash
sudo ./diagnose-installation.sh
```
**Zweck:** Umfassende Analyse des Installationsstatus
- Überprüft Odoo Service Status
- Verifiziert Benutzer und Verzeichnisse
- Testet PostgreSQL Verbindung
- Analysiert Python-Umgebung
- Zeigt aktuelle Logs

### 2. Schnelle Fehlerbehebung
```bash
sudo ./fix-installation.sh
```
**Zweck:** Automatische Behebung häufiger Probleme
- Repariert fehlende Services
- Korrigiert Dateiberechtigungen
- Behebt PostgreSQL-Probleme
- Installiert fehlende Python-Pakete
- Startet Services neu

### 3. Error-Log für Support anzeigen
```bash
sudo ./show-error-log.sh
```
**Zweck:** Zeigt die neueste Error-Log für Support-Zwecke
- Findet automatisch die neueste Error-Log
- Zeigt vollständigen Inhalt für Support
- Gibt Anweisungen zum Senden der Logs

## 🚨 Häufige Probleme und Lösungen

### Problem: "Odoo service ist nicht da"

**Ursachen:**
1. Installation wurde unterbrochen
2. Python-Paket nicht installiert
3. Service-Datei fehlt
4. Berechtigungsprobleme

**Lösungsschritte:**

#### Schritt 1: Diagnose ausführen
```bash
sudo ./diagnose-installation.sh
```

#### Schritt 2: Automatische Reparatur versuchen
```bash
sudo ./fix-installation.sh
```

#### Schritt 3: Manuelle Überprüfung
```bash
# Service Status prüfen
sudo systemctl status odoo

# Logs anzeigen
sudo journalctl -u odoo -n 20

# Python Paket testen
python3 -c "import odoo; print('OK')"

# wkhtmltopdf Qt-Patch prüfen (KRITISCH für PDF-Reports!)
wkhtmltopdf --version
```

#### Schritt 4: Komplette Neuinstallation (wenn nötig)
```bash
sudo ./install.sh --auto --force --nginx-domain office.hecker24.net --nginx-email admin@detalex.de
```

## 🔧 Erweiterte Fehlerbehebung

### Manueller Service-Neustart
```bash
sudo systemctl stop odoo
sudo systemctl start odoo
sudo systemctl status odoo
```

### PostgreSQL Verbindung testen
```bash
sudo -u odoo psql -h localhost -U odoo -d postgres -c "SELECT version();"
```

### Odoo manuell starten (Debug-Modus)
```bash
sudo -u odoo python3 -m odoo --config=/etc/odoo/odoo.conf --stop-after-init
```

### Berechtigungen zurücksetzen
```bash
sudo chown -R odoo:odoo /opt/odoo
sudo chown odoo:odoo /etc/odoo/odoo.conf
sudo chmod 640 /etc/odoo/odoo.conf
```

### wkhtmltopdf Qt-Patch installieren (KRITISCH!)
```bash
# Überprüfen ob Qt-Patch vorhanden ist
wkhtmltopdf --version | grep "with patched qt"

# Falls nicht vorhanden - Installation mit Qt-Patch
wget https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-2/wkhtmltox_0.12.6.1-2.focal_amd64.deb
sudo dpkg -i wkhtmltox_0.12.6.1-2.focal_amd64.deb
sudo apt-get install -f

# Oder automatisch mit Fix-Script
sudo ./fix-installation.sh
```

## 📁 Log-Dateien

### Installation Logs
```bash
# Neueste Installationslogs
ls -la /var/log/odoo-upgrade/

# Letztes Log anzeigen
tail -50 /var/log/odoo-upgrade/install-*.log | tail -1
```

### Service Logs
```bash
# Live Logs verfolgen
sudo journalctl -u odoo -f

# Letzte 50 Einträge
sudo journalctl -u odoo -n 50
```

### Odoo Application Logs
```bash
# Hauptlog-Datei
sudo tail -50 /var/log/odoo/odoo.log
```

## 🌐 Zugriff testen

Nach erfolgreicher Reparatur:

```bash
# Lokaler Zugriff
curl -I http://localhost:8069

# Web-Browser Zugriff
# http://office.hecker24.net (falls Nginx konfiguriert)
# http://SERVER-IP:8069 (direkter Zugriff)
```

## 📞 Weitere Hilfe

Wenn die automatischen Tools nicht helfen:

1. **GitHub Issues:** https://github.com/Hammdie/odoo-upgrade-cron/issues
2. **Support Email:** support@detelx.de
3. **Dokumentation:** https://github.com/Hammdie/odoo-upgrade-cron

## 💡 Tipps

- Führen Sie Diagnose-Tools immer als `root` oder mit `sudo` aus
- Überprüfen Sie die Logs für detaillierte Fehlermeldungen
- Bei Nginx-Problemen: Stellen Sie sicher, dass Odoo läuft BEVOR Nginx konfiguriert wird
- Für Production-Systeme: Erstellen Sie immer Backups vor Reparaturversuchen
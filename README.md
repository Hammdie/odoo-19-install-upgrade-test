# Odoo Upgrade Cron

Ein umfassendes Script-Repository für die automatisierte Aktualisierung und Wartung von Odoo 19.0 Installationen auf VM-Hosts.

## Übersicht

Dieses Repository enthält Shell-Scripts und Konfigurationsdateien für die automatisierte Aktualisierung von Odoo 19.0 Installationen. Das Hauptziel ist es, VM-Hosts so zu konfigurieren, dass sie den Anforderungen von Odoo 19.0 entsprechen und regelmäßige Updates automatisch durchführen.

## Features

- 🔄 Automatische Odoo 19.0 Updates via Cron-Jobs
- 🖥️ VM-Host Konfiguration für Odoo 19.0 Kompatibilität
- 🔧 System-Anforderungen Überprüfung und Installation
- 📝 Logging und Monitoring der Update-Prozesse
- 🛡️ Backup-Erstellung vor Updates
- ⚡ Performance-Optimierung für Odoo 19.0

## Voraussetzungen

### System-Anforderungen
- Ubuntu 20.04 LTS oder höher
- Python 3.8+
- PostgreSQL 12+
- Mindestens 4GB RAM
- 20GB freier Speicherplatz

### Berechtigungen
- Root oder sudo-Zugriff auf dem Ziel-Host
- SSH-Zugriff (falls Remote-Installation)

## Installation

### Schnellinstallation

```bash
# Repository klonen
git clone https://github.com/Hammdie/odoo-upgrade-cron.git
cd odoo-upgrade-cron

# Installationsscript ausführbar machen
chmod +x install.sh

# Installation starten
sudo ./install.sh
```

### Manuelle Installation

1. **Repository herunterladen:**
   ```bash
   git clone https://github.com/Hammdie/odoo-upgrade-cron.git
   cd odoo-upgrade-cron
   ```

2. **Abhängigkeiten installieren:**
   ```bash
   sudo apt update
   sudo apt install -y curl wget git python3 python3-pip postgresql
   ```

3. **Konfiguration anpassen:**
   ```bash
   cp config/odoo.conf.example config/odoo.conf
   nano config/odoo.conf
   ```

4. **Scripts ausführbar machen:**
   ```bash
   chmod +x scripts/*.sh
   ```

## Verwendung

### Grundlegende Verwendung

```bash
# Einmalige Systemaktualisierung
sudo ./scripts/upgrade-system.sh

# Odoo 19.0 Installation/Update
sudo ./scripts/install-odoo19.sh

# Cron-Job einrichten
sudo ./scripts/setup-cron.sh
```

### Konfiguration

#### Odoo-Konfiguration
Bearbeiten Sie `config/odoo.conf` entsprechend Ihrer Umgebung:

```ini
[options]
admin_passwd = your_admin_password
db_host = localhost
db_port = 5432
db_user = odoo
db_password = your_db_password
addons_path = /opt/odoo/addons
logfile = /var/log/odoo/odoo.log
```

#### Cron-Konfiguration
Die Cron-Jobs werden in `config/crontab` definiert:

```bash
# Täglich um 2:00 Uhr - System-Updates
0 2 * * * /path/to/odoo-upgrade-cron/scripts/daily-maintenance.sh

# Wöchentlich Sonntags um 3:00 Uhr - Odoo Updates
0 3 * * 0 /path/to/odoo-upgrade-cron/scripts/weekly-odoo-update.sh
```

### Verfügbare Scripts

| Script | Beschreibung |
|--------|-------------|
| `install.sh` | Hauptinstallationsscript |
| `scripts/upgrade-system.sh` | System-Pakete aktualisieren |
| `scripts/install-odoo19.sh` | Odoo 19.0 Installation |
| `scripts/setup-cron.sh` | Cron-Jobs einrichten |
| `scripts/backup-odoo.sh` | Odoo-Datenbank Backup |
| `scripts/restore-odoo.sh` | Odoo-Datenbank Wiederherstellung |
| `scripts/daily-maintenance.sh` | Tägliche Wartungsaufgaben |
| `scripts/weekly-odoo-update.sh` | Wöchentliche Odoo-Updates |

## Ordnerstruktur

```
odoo-upgrade-cron/
├── README.md
├── install.sh                 # Hauptinstallationsscript
├── config/
│   ├── odoo.conf.example      # Beispiel Odoo-Konfiguration
│   ├── crontab               # Cron-Job Definitionen
│   └── requirements.txt      # Python-Abhängigkeiten
├── scripts/
│   ├── upgrade-system.sh     # System-Update Script
│   ├── install-odoo19.sh     # Odoo 19.0 Installation
│   ├── setup-cron.sh         # Cron-Setup
│   ├── backup-odoo.sh        # Backup-Script
│   ├── restore-odoo.sh       # Restore-Script
│   ├── daily-maintenance.sh  # Tägliche Wartung
│   └── weekly-odoo-update.sh # Wöchentliche Updates
├── logs/
│   └── .gitkeep
└── backups/
    └── .gitkeep
```

## Logging

Alle Scripts erstellen Logs in verschiedenen Verzeichnissen:

- **System-Logs:** `/var/log/odoo-upgrade/`
- **Odoo-Logs:** `/var/log/odoo/`
- **Backup-Logs:** `./logs/`

### Log-Überwachung

```bash
# Aktuelle Logs anzeigen
tail -f /var/log/odoo-upgrade/upgrade.log

# Letzte Backup-Logs
tail -f ./logs/backup-$(date +%Y-%m-%d).log

# Odoo-Anwendungslogs
tail -f /var/log/odoo/odoo.log
```

## Backup und Wiederherstellung

### Automatisches Backup

```bash
# Backup vor jedem Update (automatisch)
./scripts/backup-odoo.sh

# Manuelles Backup
./scripts/backup-odoo.sh --manual
```

### Wiederherstellung

```bash
# Aus dem neuesten Backup wiederherstellen
./scripts/restore-odoo.sh --latest

# Aus spezifischem Backup wiederherstellen
./scripts/restore-odoo.sh --file backups/odoo-backup-2025-11-14.sql
```

## Überwachung und Wartung

### Status überprüfen

```bash
# Odoo-Service Status
systemctl status odoo

# PostgreSQL Status
systemctl status postgresql

# Cron-Jobs Status
crontab -l
```

### Fehlerbehandlung

```bash
# Logs auf Fehler überprüfen
grep -i error /var/log/odoo-upgrade/*.log

# Service-Neustart
sudo systemctl restart odoo
sudo systemctl restart postgresql
```

## Troubleshooting

### Häufige Probleme

1. **Odoo startet nicht:**
   ```bash
   sudo systemctl status odoo
   sudo journalctl -u odoo -f
   ```

2. **Datenbankverbindung fehlgeschlagen:**
   ```bash
   sudo -u postgres psql -l
   sudo systemctl status postgresql
   ```

3. **Unzureichende Berechtigungen:**
   ```bash
   sudo chown -R odoo:odoo /opt/odoo
   sudo chmod +x scripts/*.sh
   ```

### Debug-Modus

```bash
# Scripts mit Debug-Output ausführen
bash -x ./scripts/install-odoo19.sh

# Umgebungsvariable für Debug-Logs
export ODOO_UPGRADE_DEBUG=1
./scripts/upgrade-system.sh
```

## Sicherheit

### Empfohlene Sicherheitsmaßnahmen

1. **Firewall konfigurieren:**
   ```bash
   sudo ufw enable
   sudo ufw allow 8069/tcp  # Odoo Port
   sudo ufw allow ssh
   ```

2. **SSL/TLS einrichten:**
   ```bash
   # Nginx Reverse Proxy mit Let's Encrypt
   sudo apt install nginx certbot
   ```

3. **Datenbankzugriff beschränken:**
   ```bash
   # PostgreSQL nur lokal zugänglich machen
   sudo nano /etc/postgresql/*/main/pg_hba.conf
   ```

## Entwicklung und Beitrag

### Entwicklungsumgebung

```bash
# Repository forken und klonen
git clone https://github.com/YOURUSERNAME/odoo-upgrade-cron.git
cd odoo-upgrade-cron

# Entwicklungsbranch erstellen
git checkout -b feature/neue-funktion

# Änderungen committen
git add .
git commit -m "Beschreibung der Änderung"
git push origin feature/neue-funktion
```

### Code-Standards

- Verwenden Sie shellcheck für Script-Validierung
- Fügen Sie Kommentare für komplexe Logik hinzu
- Testen Sie Scripts in einer isolierten Umgebung
- Dokumentieren Sie neue Features in der README

## Support

### Community-Support
- GitHub Issues: https://github.com/Hammdie/odoo-upgrade-cron/issues
- Diskussionen: https://github.com/Hammdie/odoo-upgrade-cron/discussions

### Enterprise-Support
Für kommerzielle Unterstützung und angepasste Lösungen kontaktieren Sie:
- E-Mail: support@example.com
- Website: https://example.com

## Lizenz

Dieses Projekt steht unter der MIT-Lizenz. Siehe [LICENSE](LICENSE) für Details.

## Changelog

### Version 1.0.0 (2025-11-14)
- Initiale Version
- Odoo 19.0 Upgrade-Scripts
- Automatisierte Cron-Job Konfiguration
- Backup und Restore Funktionalität

## Roadmap

- [ ] Docker-Container Support
- [ ] Multi-Instanz Verwaltung
- [ ] Web-basierte Konfigurationsoberfläche
- [ ] Erweiterte Monitoring-Dashboards
- [ ] Cloud-Provider Integration (AWS, GCP, Azure)

## Autoren

- **Hammdie** - *Initial work* - [Hammdie](https://github.com/Hammdie)

Siehe auch die Liste der [Mitwirkenden](https://github.com/Hammdie/odoo-upgrade-cron/contributors), die an diesem Projekt beteiligt waren.

---

**Hinweis:** Dieses Repository wird aktiv gewartet. Bei Fragen oder Problemen erstellen Sie bitte ein Issue auf GitHub.

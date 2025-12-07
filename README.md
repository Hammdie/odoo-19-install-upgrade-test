# Ein umfassendes Script-Repository für die automatisierte Installation, Aktualisierung und Wartung von Odoo 19.0

## Übersicht

Dieses Repository enthält Shell-Scripts und Konfigurationsdateien für die vollautomatische Installation und Wartung von Odoo 19.0. Das Hauptziel ist es, frische Ubuntu-Server (20.04+) mit einem einzigen Befehl in eine produktionsbereite Odoo-Umgebung zu verwandeln.

## Features

- 🚀 **One-Command Installation** – Komplett automatisiert mit `./install.sh --auto`
- 🔄 Automatische Odoo 19.0 Updates via Cron-Jobs
- 🖥️ Intelligente Erkennung bestehender Odoo-Installationen (Upgrade oder Neuinstallation)
- 🔧 System-Anforderungen Überprüfung und Installation
- 📝 Umfassendes Logging und Monitoring der Update-Prozesse
- 🛡️ Automatische Backup-Erstellung vor Updates
- ⚡ Performance-Optimierung für Odoo 19.0
- 🔐 PostgreSQL Peer-Authentifizierung für Produktionsumgebungen
- 🔧 Automatische Reparatur-Scripts für beschädigte Installationen
- 🧪 Umfassende Dependency-Tests (Vector-Extension, wkhtmltopdf, Python-Pakete)
- 🔥 Automatische UFW-Firewall Konfiguration
- 👤 Automatische PostgreSQL-Benutzerberechtigungen
- ⚙️ Erkennung und Schonung vorhandener Odoo-Installationen
- 🐍 Kompatibel mit Ubuntu 22.04/24.04 „Externally Managed Environment" (pip --break-system-packages)

## Voraussetzungen

### System-Anforderungen
- Ubuntu 20.04 LTS oder höher
- Python 3.8+ (mit phonenumbers, lxml, requests)
- PostgreSQL 12+ mit pgvector-Extension für AI/RAG
- Node.js 16+ mit rtlcss für RTL-Sprachen
- wkhtmltopdf 0.12.6.1 mit Qt-Patch
- Mindestens 4GB RAM
- 20GB freier Speicherplatz

### Geprüfte Dependencies (automatisch getestet)
- **PostgreSQL pgvector Extension:** Für RAG (Retrieval-Augmented Generation) und AI Agents mit Vector-Similarity Search
- **wkhtmltopdf Qt-Patch:** Für PDF-Generierung mit korrekter Darstellung
- **Python phonenumbers:** Für internationale Telefonnummern-Validierung
- **Node.js rtlcss:** Für Right-to-Left Sprachen (Arabisch, Hebräisch)
- **UFW Firewall:** Für sichere HTTP/HTTPS-Verbindungen

### Berechtigungen
- Root oder sudo-Zugriff auf dem Ziel-Host
- SSH-Zugriff (falls Remote-Installation)

## Installation

### Schnellinstallation (empfohlen)

```bash
# Repository klonen
git clone https://github.com/Hammdie/odoo-upgrade-cron.git
cd odoo-upgrade-cron

# Installationsscript ausführbar machen
chmod +x install.sh

# Vollautomatische Installation starten (keine Prompts)
sudo ./install.sh --auto
```

Das war's! Odoo 19.0 ist nun unter `http://your-server-ip:8069` erreichbar.

### Installationsoptionen

```bash
# Interaktive Installation (mit Bestätigungen)
sudo ./install.sh

# Vollautomatisch ohne Prompts
sudo ./install.sh --auto

# Mit Nginx Reverse Proxy + SSL/TLS (Let's Encrypt)
sudo ./install.sh --auto --nginx-domain odoo.example.com --nginx-email admin@example.com

# Neuinstallation erzwingen (entfernt bestehende Installation)
sudo ./install.sh --auto --force

# Nur System-Update überspringen
sudo ./install.sh --auto --skip-system

# Nur Cron-Setup überspringen
sudo ./install.sh --auto --skip-cron

# Nginx-Setup überspringen
sudo ./install.sh --auto --skip-nginx

# Hilfe anzeigen
./install.sh --help
```

### Nginx Reverse Proxy + SSL/TLS

Das Repository enthält ein vollautomatisches Nginx-Setup-Script für Produktionsumgebungen:

**Während der Installation:**
```bash
sudo ./install.sh --auto --nginx-domain odoo.example.com --nginx-email admin@example.com
```

**Nach der Installation:**
```bash
sudo ./scripts/setup-odoo-nginx.sh odoo.example.com admin@example.com
```

**Features:**
- ✅ Nginx Reverse Proxy für Odoo (Port 8069)
- ✅ WebSocket-Unterstützung für Longpolling (Port 8072)
- ✅ Let's Encrypt SSL/TLS Zertifikat
- ✅ Automatische monatliche Zertifikat-Erneuerung
- ✅ HTTP zu HTTPS Weiterleitung
- ✅ Automatisches Backup der Nginx-Konfiguration

**Voraussetzungen für Nginx + SSL:**
- Domain muss auf Server-IP zeigen (DNS A-Record)
- Port 80 und 443 müssen erreichbar sein
- Gültige E-Mail-Adresse für Let's Encrypt

### Odoo Enterprise Edition

Das Repository unterstützt die optionale Installation der **Odoo Enterprise Edition**:

**Während der Installation:**
```bash
# Enterprise während der Hauptinstallation aktivieren
sudo ./install.sh --auto --enterprise
```

**Nach der Installation (nachträgliche Enterprise-Installation):**
```bash
# Interaktives Installationsscript mit SSH-Key Setup
sudo ./scripts/install-enterprise.sh
```

**SSH-Schlüssel für aktuellen Benutzer erstellen:**

Das Enterprise-Installationsscript verwendet automatisch den SSH-Schlüssel des **aktuell eingeloggten Benutzers** (der das Script mit `sudo` ausführt). Der SSH-Schlüssel muss NICHT für den odoo-Benutzer erstellt werden.

```bash
# SSH-Schlüssel wird automatisch erstellt, wenn Sie das Enterprise-Script ausführen
sudo ./scripts/install-enterprise.sh

# Das Script führt Sie durch 4 Optionen:
# 1. Testen der bestehenden SSH-Verbindung zu GitHub
# 2. Generieren eines neuen ED25519 SSH-Schlüssels (empfohlen)
# 3. SSH-Check überspringen und trotzdem klonen
# 4. Installation abbrechen

# Manuelle SSH-Schlüssel-Erstellung (falls gewünscht):
# ED25519 (empfohlen - modern und sicher):
ssh-keygen -t ed25519 -C "$(whoami)@$(hostname)" -f ~/.ssh/id_ed25519 -N ""

# ODER klassischer RSA-Schlüssel (falls ED25519 nicht unterstützt):
ssh-keygen -t rsa -b 4096 -C "$(whoami)@$(hostname)" -f ~/.ssh/id_rsa -N ""

# Öffentlichen Schlüssel anzeigen (zum Kopieren für GitHub):
cat ~/.ssh/id_ed25519.pub
# ODER bei RSA:
cat ~/.ssh/id_rsa.pub

# SSH-Schlüssel zu GitHub hinzufügen:
# 1. Gehe zu: https://github.com/settings/keys
# 2. Klicke "New SSH key"
# 3. Title: "Odoo Server - $(hostname)"
# 4. Key: Füge den öffentlichen Schlüssel ein (ssh-ed25519 AAAA... oder ssh-rsa AAAA...)
# 5. Klicke "Add SSH key"

# SSH-Verbindung zu GitHub testen:
ssh -T git@github.com
# Erwartete Ausgabe: "Hi <username>! You've successfully authenticated, but GitHub does not provide shell access."

# Jetzt Enterprise installieren:
sudo ./scripts/install-enterprise.sh
```

**Wichtig:** 
- Der SSH-Schlüssel wird für **Ihren aktuellen Benutzer** erstellt (nicht für odoo)
- Das Repository wird mit Ihrem SSH-Schlüssel geklont
- Die Dateien werden anschließend automatisch dem odoo-Benutzer zugewiesen
- Sie benötigen Odoo Partner-Zugang für das Enterprise Repository

**Hinweis zu SSH-Schlüssel-Typen:**
- **ED25519** (empfohlen): Moderner, sicherer, kleiner - wird von GitHub seit 2020 empfohlen
- **RSA 4096-bit**: Klassische Alternative, falls ED25519 nicht verfügbar ist
- Die Scripts unterstützen beide Typen automatisch

**Manuelle Installation (für Experten):**
```bash
cd /opt/odoo
sudo -u odoo git clone git@github.com:odoo/enterprise.git --depth 1 --branch 19.0
# Odoo-Konfiguration manuell anpassen
sudo nano /etc/odoo/odoo.conf
sudo systemctl restart odoo
```

**Features:**
- ✅ Automatischer Clone von `git@github.com:odoo/enterprise.git` (Branch 19.0)
- ✅ Installation nach `/opt/odoo/enterprise`
- ✅ Automatische Integration in `addons_path`
- ✅ Wöchentliche Auto-Updates via Cron (jeden Sonntag 3:00 Uhr)

**Voraussetzungen für Enterprise Edition:**
- **Odoo Partner Zugang:** Gültiger Odoo Enterprise Vertrag erforderlich
- **Odoo Enterprise GitHub-Zugriff:** Repository-Zugang muss von Odoo freigeschaltet werden
- **SSH-Schlüssel für GitHub:** Zugriff auf `git@github.com:odoo/enterprise.git`
  
  **SSH-Schlüssel Schritt-für-Schritt (für aktuellen Benutzer):**
  ```bash
  # Schritt 1: SSH-Schlüssel generieren (falls noch nicht vorhanden)
  ssh-keygen -t ed25519 -C "$(whoami)@$(hostname)" -f ~/.ssh/id_ed25519 -N ""
  
  # Schritt 2: Öffentlichen Schlüssel anzeigen und kopieren
  cat ~/.ssh/id_ed25519.pub
  # Ausgabe: ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAA... username@yourserver
  
  # Schritt 3: SSH-Schlüssel zu GitHub-Account hinzufügen
  # - Gehe zu: https://github.com/settings/keys
  # - Klicke "New SSH key"
  # - Title: "Odoo Server - $(hostname)"
  # - Key type: "Authentication Key" (Standard)
  # - Key: Füge den KOMPLETTEN öffentlichen Schlüssel ein (ssh-ed25519 AAAA...)
  # - Klicke "Add SSH key"
  
  # Schritt 4: SSH-Schlüssel für Odoo Enterprise Repository berechtigen
  # WICHTIG: Der GitHub-Account muss von Odoo für das Enterprise-Repository freigeschaltet sein!
  # Kontaktiere deinen Odoo Account Manager oder Partner, um Zugriff zu erhalten:
  # - E-Mail: sales@odoo.com oder dein Partner
  # - Benötigte Info: Dein GitHub-Benutzername
  # - Odoo fügt deinen Account zur "odoo/enterprise" Repository-Berechtigungsliste hinzu
  
  # Schritt 5: SSH-Verbindung zu GitHub testen
  ssh -T git@github.com
  # Erwartete Ausgabe: "Hi <username>! You've successfully authenticated, but GitHub does not provide shell access."
  
  # Schritt 6: Zugriff auf Enterprise Repository testen
  git ls-remote git@github.com:odoo/enterprise.git
  # Erwartete Ausgabe: Liste der Branches (19.0, 18.0, master, etc.)
  # FEHLER "Repository not found": Dein Account hat noch keinen Zugriff -> Kontaktiere Odoo
  
  # Schritt 7: Jetzt Enterprise installieren
  sudo ./scripts/install-enterprise.sh
  ```
  
  **Alternative mit RSA-Schlüssel (falls ED25519 nicht verfügbar):**
  
  **✅ Standard & korrekt (empfohlen):**
  ```bash
  # So erstellst du ~/.ssh/id_rsa.pub korrekt (inkl. privatem Key)
  ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa
  
  # 🔹 Ergebnis:
  # Privater Key: ~/.ssh/id_rsa
  # Public Key:   ~/.ssh/id_rsa.pub ✅
  
  # Öffentlichen Schlüssel anzeigen:
  cat ~/.ssh/id_rsa.pub
  ```

- **GitHub SSH-Verbindung testen:**
  ```bash
  ssh -T git@github.com
  # Erwartete Ausgabe: "Hi <username>! You've successfully authenticated..."
  ```

- **Enterprise Repository-Zugriff testen:**
  ```bash
  git ls-remote git@github.com:odoo/enterprise.git
  # Erwartete Ausgabe: Liste aller Branches
  # Fehler "Repository not found" = Kein Zugriff -> Odoo kontaktieren
  ```

**Manuelle Konfiguration:**
```bash
# Enterprise-Addons Path in Odoo-Konfiguration prüfen
sudo nano /etc/odoo/odoo.conf

# addons_path sollte enthalten:
# addons_path = /opt/odoo/enterprise,/opt/odoo/addons,/opt/odoo/custom-addons,/var/custom-addons

# Odoo neustarten nach Änderungen
sudo systemctl restart odoo
```

### Custom Addons Verzeichnisse

Das Repository erstellt automatisch **zwei Verzeichnisse** für eigene Custom Addons:

**1. Projekt-spezifische Custom Addons:** `/opt/odoo/custom-addons`
- Für Addons, die zum Odoo-Projekt gehören
- Werden mit dem odoo-Benutzer verwaltet
- Ideal für versionskontrollierte Module

**2. System-weite Custom Addons:** `/var/custom-addons`
- Für externe oder unabhängige Custom Addons
- Gemeinsam genutzt über mehrere Odoo-Instanzen (falls vorhanden)
- Ideal für gekaufte oder externe Module

**Custom Addon hinzufügen:**
```bash
# Addon nach /var/custom-addons kopieren
sudo cp -r /pfad/zu/deinem/custom_module /var/custom-addons/

# Berechtigungen setzen
sudo chown -R odoo:odoo /var/custom-addons/custom_module
sudo chmod -R 755 /var/custom-addons/custom_module

# Odoo neustarten
sudo systemctl restart odoo

# Im Odoo Web-Interface:
# 1. Apps Menü öffnen
# 2. "Apps aktualisieren" klicken
# 3. Nach "custom_module" suchen und installieren
```

**Addons-Pfad Priorität (von links nach rechts):**
1. `/opt/odoo/enterprise` - Enterprise Edition (höchste Priorität)
2. `/opt/odoo/addons` - Odoo Core Module
3. `/opt/odoo/custom-addons` - Projekt-spezifische Custom Addons
4. `/var/custom-addons` - System-weite Custom Addons

**Hinweis:** Module in Verzeichnissen mit höherer Priorität überschreiben Module mit gleichem Namen in nachfolgenden Verzeichnissen.

### Was passiert bei der Installation?

1. **System-Vorbereitung** – Updates, PostgreSQL, Node.js, Python-Dependencies
2. **Odoo 19.0 Download** – Klont das offizielle Odoo-Repository
3. **Custom Addons Verzeichnisse** – Erstellt `/opt/odoo/custom-addons` und `/var/custom-addons`
4. **Admin-Passwort Abfrage** – Interaktive Eingabe des Odoo Master-Passworts (min. 8 Zeichen)
5. **Python-Dependencies** – Installiert alle benötigten Pakete (inkl. lxml < 5.0, passlib, etc.)
6. **Datenbank-Setup** – Erstellt PostgreSQL-Benutzer und konfiguriert Authentifizierung
7. **Systemd-Service** – Erstellt und aktiviert den Odoo-Dienst (Type=simple für Odoo 19.0)
8. **Cron-Jobs** – Richtet automatische Wartung und Updates ein
9. **Firewall** – Konfiguriert UFW für Ports 8069, 80, 443
10. **Nginx + SSL** (optional) – Reverse Proxy mit Let's Encrypt Zertifikat
11. **Enterprise Edition** (optional) – Klont Enterprise-Addons nach `/opt/odoo/enterprise`

**Hinweis zur Passwort-Abfrage:**
- Im **interaktiven Modus**: Sie werden nach dem Odoo Master-Passwort gefragt
- Im **automatischen Modus** (`--auto`): Es wird ein zufälliges Passwort generiert und in `/etc/odoo/odoo.conf` gespeichert
- Das Master-Passwort wird für Datenbankverwaltungsoperationen benötigt

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

### Nach der Installation

```bash
# Odoo-Status prüfen
sudo systemctl status odoo

# Odoo-Logs in Echtzeit verfolgen
sudo journalctl -u odoo -f

# Odoo neustarten
sudo systemctl restart odoo

# Odoo stoppen
sudo systemctl stop odoo
```

### Web-Interface

Nach erfolgreicher Installation ist Odoo erreichbar unter:
- **Lokal:** http://localhost:8069
- **Extern:** http://your-server-ip:8069

Beim ersten Zugriff können Sie eine neue Datenbank erstellen.

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
Bearbeiten Sie `/etc/odoo/odoo.conf` entsprechend Ihrer Umgebung:

```ini
[options]
admin_passwd = your_admin_password
db_host = localhost
db_port = 5432
db_user = odoo
db_password = your_db_password

# Addons-Pfad (automatisch konfiguriert bei Installation)
# Enterprise (falls installiert), Core, Custom Addons
addons_path = /opt/odoo/enterprise,/opt/odoo/addons,/opt/odoo/custom-addons,/var/custom-addons

logfile = /var/log/odoo/odoo.log
workers = 4
max_cron_threads = 2
```

**Wichtig:** Die Reihenfolge in `addons_path` ist entscheidend! Module weiter links haben Vorrang bei Namenskonflikten.

#### Cron-Konfiguration
Die Cron-Jobs werden in `config/crontab` definiert:

```bash
# Täglich um 2:00 Uhr - System-Updates
0 2 * * * /path/to/odoo-upgrade-cron/scripts/daily-maintenance.sh

# Wöchentlich Sonntags um 3:00 Uhr - Odoo Updates
0 3 * * 0 /path/to/odoo-upgrade-cron/scripts/weekly-odoo-update.sh
```

### Verfügbare Scripts

| Script | Beschreibung | Version |
|--------|-------------|---------|
| `install.sh` | Hauptinstallationsscript mit Erkennung vorhandener Installationen | 1.2.0 |
| `scripts/upgrade-system.sh` | System-Pakete aktualisieren | 1.2.0 |
| `scripts/install-odoo19.sh` | Odoo 19.0 Installation | 1.2.0 |
| `scripts/setup-cron.sh` | Cron-Jobs einrichten | 1.1.0 |
| `scripts/setup-odoo-nginx.sh` | **Nginx Reverse Proxy + SSL/TLS Setup** | **1.2.0** |
| **`scripts/install-enterprise.sh`** | **Nachträgliche Enterprise Edition Installation** | **1.2.0** |
| `scripts/backup-odoo.sh` | Odoo-Datenbank Backup | 1.0.0 |
| `scripts/restore-odoo.sh` | Odoo-Datenbank Wiederherstellung | 1.0.0 |
| `scripts/daily-maintenance.sh` | Tägliche Wartungsaufgaben | 1.0.0 |
| `scripts/weekly-odoo-update.sh` | Wöchentliche Odoo-Updates (inkl. Enterprise) | 1.2.0 |
| **`repair-database.sh`** | **Repariert PostgreSQL-Authentifizierungsprobleme** | **1.1.0** |
| **`fix-firewall.sh`** | **Konfiguriert UFW-Firewall für Odoo** | **1.1.0** |
| **`test-odoo-dependencies.sh`** | **Testet alle Odoo-Abhängigkeiten umfassend** | **1.1.0** |
| **`fix-postgres-auth.sh`** | **Konfiguriert PostgreSQL für Peer-Authentifizierung** | **1.1.0** |
| **`test-odoo-user-permissions.sh`** | **Testet odoo-Benutzer Datenbankberechtigungen** | **1.1.0** |
| **`scripts/set-postgres-password.sh`** | **Setzt PostgreSQL-Passwort für odoo-Benutzer** | **1.1.0** |
| **`scripts/install-pgvector.sh`** | **Installiert pgvector Extension für AI/RAG** | **1.2.0** |
| **`fix-phonenumbers.sh`** | **Installiert python3-phonenumbers für account_peppol** | **1.2.0** |

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

2. **`lxml.html.clean` AttributeError:**
   ```bash
   # Distro-Pakete entfernen und lxml < 5 installieren
   sudo apt-get purge -y python3-lxml
   python3 -m pip install --break-system-packages --force-reinstall "lxml<5"
   sudo systemctl restart odoo
   ```

3. **Datenbankverbindung fehlgeschlagen:**
   ```bash
   # Teste PostgreSQL-Verbindung
   sudo -u postgres psql -l
   sudo systemctl status postgresql
   
   # Teste odoo-Benutzer Berechtigungen
   ./test-odoo-user-permissions.sh
   ```

4. **PostgreSQL Authentifizierungsfehler:**
   ```bash
   # Repariere Datenbank-Authentifizierung
   sudo ./repair-database.sh
   
   # Oder konfiguriere Peer-Authentifizierung neu
   sudo ./fix-postgres-auth.sh
   ```

5. **Firewall blockiert Odoo-Zugriff:**
   ```bash
   # Konfiguriere Firewall automatisch
   sudo ./fix-firewall.sh
   
   # Oder manuell
   sudo ufw allow 8069/tcp
   sudo ufw allow 80/tcp
   sudo ufw allow 443/tcp
   ```

6. **pip „externally-managed-environment" Fehler (Ubuntu 22.04/24.04):**
   ```bash
   # Die Scripts verwenden automatisch --break-system-packages
   # und setzen PIP_BREAK_SYSTEM_PACKAGES=1
   
   # Manuelle Installation falls nötig:
   python3 -m pip install --break-system-packages <paket>
   
   # Oder führe das Installationsscript erneut aus:
   sudo ./scripts/install-odoo19.sh
   ```
   
   **Hinweis:** Alle Scripts (`install-odoo19.sh`, `upgrade-system.sh`, `weekly-odoo-update.sh`) 
   sind bereits für Ubuntu 22.04/24.04 PEP 668 konfiguriert und verwenden automatisch 
   `--break-system-packages` sowie die Umgebungsvariable `PIP_BREAK_SYSTEM_PACKAGES=1`.

7. **Fehlende Dependencies:**
   ```bash
   # Teste alle Abhängigkeiten
   ./test-odoo-dependencies.sh
   
   # Installiere fehlende Pakete basierend auf Test-Output
   ```

8. **Unzureichende Berechtigungen:**
   ```bash
   sudo chown -R odoo:odoo /opt/odoo
   sudo chmod +x scripts/*.sh
   ```

9. **Modul-Installation fehlgeschlagen: "phonenumbers" fehlt:**
   ```bash
   # Fehler: "Es ist nicht möglich das Modul 'account_peppol' zu installieren,
   #          da eine Abhängigkeit nicht erfüllt ist: phonenumbers"
   
   # Schnelle Lösung:
   sudo apt install python3-phonenumbers
   sudo systemctl restart odoo
   
   # Oder über Fixes-Menü:
   sudo ./install.sh
   # → Option 5: Fixes & Patches
   # → Option 12: Fix phonenumbers Module
   
   # Oder direkt:
   sudo ./fix-phonenumbers.sh
   ```
   
   **Betroffene Module:** `account_peppol`, `phone_validation`, und andere Module 
   die internationale Telefonnummer-Validierung benötigen.

### Reparatur-Scripts für Produktionsumgebungen

```bash
# Komplette Systemreparatur nach fehlgeschlagener Installation
sudo ./repair-database.sh        # Repariert Datenbankprobleme
sudo ./fix-firewall.sh          # Repariert Firewall-Konfiguration
sudo ./fix-postgres-auth.sh     # Konfiguriert PostgreSQL-Authentifizierung

# Teste nach Reparatur
./test-odoo-dependencies.sh     # Teste alle Dependencies
./test-odoo-user-permissions.sh # Teste Datenbankberechtigungen
```

### PostgreSQL-Authentifizierung Konfiguration

**Für Produktionsumgebungen (empfohlen):**
```bash
# Verwende Peer-Authentifizierung (kein Passwort nötig)
sudo ./fix-postgres-auth.sh

# In /etc/odoo/odoo.conf:
# db_host = False
# db_port = False  
# db_user = odoo
# db_password =
```

**Für Netzwerk-Verbindungen:**
```bash
# Setze Passwort für odoo-Benutzer
sudo ./scripts/set-postgres-password.sh

# In /etc/odoo/odoo.conf:
# db_host = localhost
# db_port = 5432
# db_user = odoo
# db_password = your_password
```

### PostgreSQL pgvector Extension für AI/RAG

**Automatische Installation (bei Full Installation bereits integriert):**
```bash
# pgvector wird automatisch bei der Full Installation installiert
sudo ./install.sh
# Wähle Option 6: Full Installation

# Oder direkt über Fixes & Patches Menu:
# Wähle Option 5: Fixes & Patches
# Dann Option 11: Install pgvector for RAG/AI
```

**Manuelle Installation:**
```bash
# pgvector separat installieren
sudo ./scripts/install-pgvector.sh
```

**Was ist pgvector?**
- PostgreSQL Extension für **Vector Similarity Search**
- Ermöglicht **RAG (Retrieval-Augmented Generation)** für Odoo AI Agents
- Speichert und durchsucht hochdimensionale Vektoren effizient
- Essentiell für moderne KI-Features in Odoo 19.0

**Verwendung in Odoo:**
```sql
-- Extension in Datenbank aktivieren
psql -U odoo -d your_database_name -c 'CREATE EXTENSION vector;'

-- Verifikation
psql -U odoo -d your_database_name -c "SELECT extversion FROM pg_extension WHERE extname='vector';"

-- Beispiel: Tabelle mit Vektoren erstellen
CREATE TABLE embeddings (
    id SERIAL PRIMARY KEY,
    content TEXT,
    embedding vector(1536)  -- z.B. für OpenAI embeddings
);

-- Ähnlichkeitssuche (cosine distance)
SELECT content, embedding <=> '[0.1, 0.2, ...]'::vector AS distance
FROM embeddings
ORDER BY distance
LIMIT 5;
```

**Use Cases in Odoo:**
- 🤖 **AI-Chatbots** mit Kontext-basierter Antwortsuche
- 📚 **Knowledge Base** mit semantischer Suche
- 🔍 **Produktempfehlungen** basierend auf Vektorähnlichkeit
- 📝 **Dokumentenklassifizierung** mit Embeddings
- 💬 **Intelligente Kundenservice-Antworten**

**Weitere Informationen:**
- GitHub: https://github.com/pgvector/pgvector
- Dokumentation: https://github.com/pgvector/pgvector#getting-started

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
   sudo ufw allow 22/tcp    # SSH
   sudo ufw allow 80/tcp    # HTTP
   sudo ufw allow 443/tcp   # HTTPS
   # Port 8069 sollte NUR mit Nginx Reverse Proxy geöffnet werden
   ```

2. **SSL/TLS einrichten (automatisch mit Nginx-Script):**
   ```bash
   sudo ./scripts/setup-odoo-nginx.sh odoo.example.com admin@example.com
   ```
   
   **Oder manuell mit Nginx + Certbot:**
   ```bash
   sudo apt install nginx certbot python3-certbot-nginx
   sudo certbot --nginx -d odoo.example.com
   ```

3. **Datenbankzugriff beschränken:**
   ```bash
   # PostgreSQL nur lokal zugänglich machen
   sudo nano /etc/postgresql/*/main/pg_hba.conf
   # Verwende 'peer' oder 'md5' statt 'trust'
   ```

4. **Odoo Admin-Passwort ändern:**
   ```bash
   # Master-Passwort in Konfiguration ändern
   sudo nano /etc/odoo/odoo.conf
   # Ändere die Zeile: admin_passwd = <neues-starkes-passwort>
   sudo systemctl restart odoo
   ```
   
   **Wichtig:** Das `admin_passwd` ist das **Master-Passwort** für:
   - Datenbank-Management (Erstellen, Löschen, Backup, Restore)
   - Server-weite Einstellungen
   - Modul-Installation und Updates
   
   **Best Practices:**
   - Mindestens 16 Zeichen lang
   - Kombination aus Buchstaben, Zahlen und Sonderzeichen
   - Nicht das gleiche wie andere Passwörter
   - Regelmäßig ändern (z.B. alle 90 Tage)

5. **Regelmäßige Updates:**
   ```bash
   # Automatisch via Cron (bereits konfiguriert)
   # Oder manuell:
   sudo ./scripts/weekly-odoo-update.sh
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
Für kommerzielle Unterstützung und angepasste Lösungen kontaktieren Sie DETELX GmbH:
- E-Mail: support@detelx.de
- Website: https://www.detelx.de

**Verfügbare Services:**
- Professionelle Odoo-Installation & Konfiguration
- Monitoring & Wartung
- Custom Odoo-Module Entwicklung
- Migration & Upgrade-Services
- Schulungen & Consulting

## Lizenz

**Copyright © 2025 DETELX GmbH. Alle Rechte vorbehalten.**

Dieses Projekt steht unter der MIT-Lizenz. Siehe [LICENSE](LICENSE) für Details.

### Haftungsausschluss

⚠️ **VERWENDUNG AUF EIGENE GEFAHR - AS IS**

Diese Software wird "wie besehen" zur Verfügung gestellt, ohne jegliche ausdrückliche oder stillschweigende Gewährleistung. Die Autoren und DETELX GmbH übernehmen keine Haftung für Schäden jeglicher Art, die durch die Verwendung dieser Software entstehen könnten, einschließlich, aber nicht beschränkt auf:

- Datenverlust oder Beschädigung von Systemen
- Ausfallzeiten oder Betriebsunterbrechungen  
- Sicherheitsprobleme oder Datenlecks
- Finanzielle Verluste oder Geschäftsschäden

**Es wird dringend empfohlen:**
- Vollständige Backups vor der Verwendung zu erstellen
- Die Scripts in einer Testumgebung zu validieren
- Eigene Sicherheitsaudits durchzuführen
- Professionelle IT-Beratung einzuholen

Durch die Verwendung dieser Software akzeptieren Sie diese Bedingungen vollständig.

## Changelog

### Version 1.2.0 (2025-12-02)
- **Vollautomatische Installation:** `--auto` Flag für promptfreie Installation
- **Interaktive Admin-Passwort Abfrage:** Sichere Eingabe des Odoo Master-Passworts während Installation
- **Nginx Reverse Proxy Integration:** `--nginx-domain` und `--nginx-email` Flags für automatisches SSL/TLS Setup
- **Odoo Enterprise Edition Support:** `--enterprise` Flag für automatische Installation der Enterprise-Addons
- **Nachträgliche Enterprise-Installation:** Neues Script `install-enterprise.sh` für spätere Enterprise-Installation
- **Interaktives SSH-Key Setup:** Enterprise-Script bietet 4 Optionen für SSH-Konfiguration (Test, Generierung, Skip, Abbruch)
- **Custom Addons Verzeichnisse:** Automatische Erstellung von `/opt/odoo/custom-addons` und `/var/custom-addons`
- **Erweiterte Addons-Pfad Konfiguration:** Unterstützung für Enterprise, Core, Custom Addons mit Prioritätsreihenfolge
- **Odoo 19.0 Systemd-Anpassung:** `Type=simple` statt `Type=forking` (--daemon entfernt)
- **Ubuntu 24.04 Kompatibilität:** Automatische Erkennung und Verwendung von `--break-system-packages` für pip
- **lxml Kompatibilität:** Erzwingt lxml < 5.0 (behebt `AttributeError: module 'lxml.html.clean' has no attribute 'defs'`)
- **Robuste Dependency-Installation:** Retry-Mechanismus + Verifizierung kritischer Pakete (passlib, lxml, psycopg2, etc.)
- **Verbesserte DB-Konfiguration:** Fehlende `DB_HOST`, `DB_PORT`, `DB_USER` Variablen werden jetzt korrekt initialisiert
- **Cron-Setup Flexibilität:** Setup kann jetzt auch vor der Odoo-Installation ausgeführt werden
- **Distro-Paket-Entfernung:** Automatische Entfernung von System-Odoo-Paketen (`odoo`, `python3-odoo`) vor Installation
- **Dependency-Purge:** Vollständige Entfernung alter pip-Dependencies vor Neuinstallation
- **Nginx-Script:** Vollautomatisches Setup mit Let's Encrypt, Longpolling-Support, monatlicher Auto-Renewal
- **Enterprise Auto-Update:** Wöchentliche automatische Updates der Enterprise-Addons via Cron

### Neue Scripts in Version 1.2.0:
| Script | Beschreibung |
|--------|-------------|
| `scripts/setup-odoo-nginx.sh` | Nginx Reverse Proxy + SSL/TLS Setup mit Let's Encrypt |
| **`scripts/install-enterprise.sh`** | **Nachträgliche Enterprise Edition Installation mit interaktivem SSH-Key Setup** |

### Version 1.1.0 (2025-11-14)
- **Verbesserte PostgreSQL-Authentifizierung:** Peer-Authentication für Produktionsumgebungen
- **Database Repair Scripts:** Reparatur-Scripts für beschädigte Installationen
- **Erweiterte Dependency-Tests:** Umfassende Tests für alle Odoo-Abhängigkeiten
- **Firewall-Konfiguration:** Automatische UFW-Konfiguration mit HTTP/HTTPS-Ports
- **Benutzer-Berechtigungen:** Automatische Konfiguration der PostgreSQL-Datenbankberechtigungen
- **Produktions-optimierte Scripts:** Angepasst für echte Serverumgebungen ohne localhost-Trust

### Neue Scripts in Version 1.1.0:
| Script | Beschreibung |
|--------|-------------|
| `repair-database.sh` | Repariert PostgreSQL-Authentifizierungsprobleme |
| `fix-firewall.sh` | Konfiguriert UFW-Firewall für Odoo |
| `test-odoo-dependencies.sh` | Testet alle Odoo-Abhängigkeiten |
| `fix-postgres-auth.sh` | Konfiguriert PostgreSQL für Peer-Authentifizierung |
| `test-odoo-user-permissions.sh` | Testet odoo-Benutzer Datenbankberechtigungen |
| `scripts/set-postgres-password.sh` | Setzt PostgreSQL-Passwort für odoo-Benutzer |

## Server-Setup & Git-Konfiguration

### Problem: Git-Konflikte beim Update

Beim `git pull` auf dem Server erscheint häufig:
```
error: Your local changes to the following files would be overwritten by merge:
	scripts/install-enterprise.sh
Please commit your changes or stash them before you merge.
```

**Ursache:** Git erkennt Line-Ending-Änderungen (CRLF vs LF) oder Dateirechte-Änderungen (chmod), obwohl das Script sich nicht selbst ändert.

### Lösung: Einmalige Git-Konfiguration auf dem Server

```bash
# Auf dem Server ausführen
cd /var/odoo-upgrade-cron

# Line-Ending-Konvertierung deaktivieren
git config core.autocrlf false

# Dateirechte-Änderungen ignorieren
git config core.fileMode false

# Konfiguration prüfen
git config --list | grep -E "autocrlf|fileMode"
# Erwartete Ausgabe:
# core.autocrlf=false
# core.filemode=false
```

### Bestehende Änderungen verwerfen und Repository aktualisieren

```bash
cd /var/odoo-upgrade-cron

# Alle lokalen Änderungen verwerfen
git reset --hard origin/main

# Neueste Version holen
git pull

# Scripts ausführbar machen
chmod +x *.sh scripts/*.sh
```

### Schnell-Befehl (Copy & Paste für Server)

```bash
cd /var/odoo-upgrade-cron && \
git config core.autocrlf false && \
git config core.fileMode false && \
git reset --hard origin/main && \
git pull && \
chmod +x *.sh scripts/*.sh && \
echo "✓ Repository aktualisiert und bereit!"
```

### Bei jedem Update (wenn Installation abgebrochen wurde)

Wenn Sie das Enterprise-Script abbrechen (Ctrl+C) und dann updaten möchten:

```bash
cd /var/odoo-upgrade-cron

# Methode 1: Nur eine Datei zurücksetzen
git checkout scripts/install-enterprise.sh
git pull

# Methode 2: Alles zurücksetzen (empfohlen)
git reset --hard origin/main
git pull
```

### Git-Konfiguration global setzen (optional)

Falls Sie das für ALLE Repositories auf dem Server wollen:

```bash
git config --global core.autocrlf false
git config --global core.fileMode false
```

**Hinweis:** Dies beeinflusst alle Git-Repositories auf dem System.

### Troubleshooting

**Problem: "git pull" zeigt immer noch Änderungen**

```bash
# Prüfen was genau geändert wurde
git diff scripts/install-enterprise.sh

# Häufige Ursachen:
# - Line endings: ^M am Zeilenende
# - File mode: old mode 100644, new mode 100755

# Lösung: Hard reset
git reset --hard HEAD
git pull
```

**Problem: Script wird als "geändert" erkannt ohne Änderungen**

```bash
# Prüfen ob fileMode das Problem ist
git diff --summary

# Wenn "mode change" erscheint:
git config core.fileMode false
git reset --hard HEAD
```

### Version 1.0.0 (2025-11-14)
- Initiale Version
- Odoo 19.0 Upgrade-Scripts
- Automatisierte Cron-Job Konfiguration
- Backup und Restore Funktionalität

## Autoren & Mitwirkende

- **Dietmar Hamm** - *Hauptentwickler & Projektleitung* - [Hammdie](https://github.com/Hammdie)
- **DETELX GmbH** - *Projektsponsoring & Enterprise Support*

### Mitwirkende
Siehe auch die Liste der [Mitwirkenden](https://github.com/Hammdie/odoo-upgrade-cron/contributors), die an diesem Projekt beteiligt waren.

### Unternehmensinformationen
**DETALX GmbH**  
IT-Consulting & Solutions  
Website: [www.detalx.de](https://www.detalx.de)  
E-Mail: info@detalx.de

---

**Hinweis:** Dieses Repository wird aktiv gewartet. Bei Fragen oder Problemen erstellen Sie bitte ein Issue auf GitHub.

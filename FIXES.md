# Installation Script Fixes

Diese Datei dokumentiert die Reparaturen, die an den Installationsskripten vorgenommen wurden, um die Probleme zu beheben, die während der Odoo-Installation auf dem Server aufgetreten sind.

## 🐛 Behobene Probleme

### 1. sed-Delimiter Problem
**Problem:** `sed: -e expression #1, char 40: unknown option to 's'`

**Ursache:** Verwendung von `/` als sed-Delimiter in Passwörtern, die selbst `/` oder andere Sonderzeichen enthalten können.

**Lösung:** Verwendung von `|` als sed-Delimiter für sicheren String-Ersatz.

**Geänderte Dateien:**
- `scripts/install-odoo19.sh` - Zeilen mit `sed -i "s|...|...|"`
- `scripts/set-postgres-password.sh` - Password-Ersetzung

**Beispiel:**
```bash
# Vorher (unsicher)
sed -i "s/db_password = .*/db_password = $password/" "$config"

# Nachher (sicher)
sed -i "s|db_password = .*|db_password = $password|" "$config"
```

### 2. systemd Service Pfad-Problem
**Problem:** `pkg_resources.DistributionNotFound: The 'zope.interface' distribution was not found`

**Ursache:** 
- Falsche ExecStart-Pfad (`odoo-bin` vs `python3 -m odoo`)
- Fehlendes WorkingDirectory
- Mix aus verschiedenen Python-Paketsystemen

**Lösung:**
```systemd
[Service]
Type=simple
User=odoo
Group=odoo
WorkingDirectory=/opt/odoo/odoo
ExecStart=/usr/bin/python3 -m odoo --config=/etc/odoo/odoo.conf
```

### 3. zope Dependencies Problem
**Problem:** Gevent erfordert zope.event und zope.interface, die nicht automatisch installiert wurden.

**Lösung:** Explizite Installation der zope-Abhängigkeiten in der Dependencies-Liste:
```bash
local additional_deps=(
    # ... andere deps ...
    "gevent"
    "greenlet"
    "zope.event"      # Neu hinzugefügt
    "zope.interface"  # Neu hinzugefügt
    # ...
)
```

### 4. Nginx Interactive Mode Problem
**Problem:** Nginx-Setup hing in interaktivem Modus fest, auch in nicht-interaktiven Umgebungen.

**Lösung:** Prüfung auf TTY und DEBIAN_FRONTEND:
```bash
if [[ $# -lt 1 ]] && [[ -t 0 ]] && [[ "${DEBIAN_FRONTEND:-}" != "noninteractive" ]]; then
    # Interaktiver Modus
else
    # Nicht-interaktiver Modus oder Parameter übergeben
fi
```

### 5. Custom Addons Pfad-Problem
**Problem:** Custom addons wurden in `/var/custom-addons` erwartet, aber die Installation erstellte `/var/odoo_addons`.

**Ursache:** Inkonsistenz zwischen erwarteten und tatsächlich erstellten Verzeichnissen.

**Lösung:** Aktualisierung aller Skripte und Konfigurationen auf `/var/odoo_addons`:
- `scripts/install-odoo19.sh` - Verzeichniserstellung 
- `config/odoo.conf.example` - addons_path Konfiguration
- `README.md` - Dokumentation und Beispiele
- `install.sh` - Ausgabemeldungen

## 🧪 Validierung

Das `test-fixes.sh` Skript validiert alle Reparaturen:

```bash
./test-fixes.sh
```

**Tests:**
1. ✅ Keine unsicheren sed-Patterns mit `/` Delimitern
2. ✅ systemd Service hat WorkingDirectory gesetzt
3. ✅ Verwendung von `python3 -m odoo` statt `odoo-bin`
4. ✅ zope.event und zope.interface in Dependencies
5. ✅ Nginx-Setup behandelt nicht-interaktive Umgebungen
6. ✅ Custom addons verwenden korrekten `/var/odoo_addons` Pfad

## 🚀 Verbesserte Robustheit

**Vor den Fixes:**
- Installation konnte bei Passwörtern mit Sonderzeichen fehlschlagen
- Service startete nicht wegen falscher Pfade
- Dependencies-Konflikte mit zope-Paketen
- Skripte hingen in automatisierten Umgebungen fest
- Custom addons wurden im falschen Verzeichnis erwartet

**Nach den Fixes:**
- Sichere String-Behandlung in allen sed-Operationen
- Robuster systemd Service mit korrektem Python-Umgebung
- Vollständige Dependencies mit expliziten zope-Paketen
- Funktioniert sowohl interaktiv als auch automatisiert
- Custom addons im korrekten `/var/odoo_addons` Verzeichnis

## 🔄 Anwendung auf dem Server

Diese Fixes sind bereits im Repository verfügbar. Bei der nächsten Installation auf dem Server:

```bash
cd /var/odoo-upgrade-cron
git pull
sudo ./install.sh --auto
```

Die Installation sollte jetzt ohne die vorherigen Fehler durchlaufen.

## 📝 Weitere Verbesserungen

- Bessere Fehlerbehandlung für edge cases
- Automatische Erkennung von Python-Umgebungsproblemen
- Backup-Mechanismus vor kritischen Operationen
- Umfassendere Tests für verschiedene Systemkonfigurationen
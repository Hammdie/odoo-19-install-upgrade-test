# Odoo 19.0 Installation Suite

Complete automated installation suite for Odoo 19.0 Community and Enterprise editions with production-ready configuration, Nginx reverse proxy, and SSL certificate management.

## 🚀 Features

- **One-Click Installation**: Complete Odoo 19.0 setup with single command
- **Official Packages**: Uses official Odoo repositories for maximum compatibility
- **Production Ready**: Optimized configuration for production environments
- **SSL Automation**: Automatic SSL certificate generation with Let's Encrypt
- **Enterprise Support**: Optional Enterprise edition installation
- **Interactive Menu**: Easy-to-use menu system for individual component installation
- **Shell Compatible**: Works with sh, dash, and bash (POSIX compliant)

## 📋 Prerequisites

### System Requirements
- **OS**: Ubuntu 20.04 LTS, Ubuntu 22.04 LTS, or Debian 11/12
- **Memory**: Minimum 2GB RAM (4GB+ recommended)
- **Storage**: 10GB+ free disk space
- **Network**: Internet connection for package downloads

### Required Privileges
- Root access (scripts must be run with `sudo`)

### For Enterprise Installation
- **Odoo Enterprise License**: Valid subscription from Odoo S.A.
- **GitHub Access**: Account with access to `odoo/enterprise` repository
- **Authentication**: SSH key or Personal Access Token for GitHub

## ⚡ Quick Start

### Complete Installation (Recommended)

```bash
# Clone the repository
git clone https://github.com/your-repo/odoo-upgrade-cron.git
cd odoo-upgrade-cron

# Make scripts executable
chmod +x *.sh

# Run complete installation
sudo ./install.sh
```

Select option `1` for complete automatic installation including:
- Odoo 19.0 Community Edition
- Production configuration
- PostgreSQL setup
- Nginx reverse proxy with SSL

### Custom Installation

Use the interactive menu (`sudo ./install.sh`) to install individual components as needed.

## 📁 Script Overview

### 🎯 install.sh - Main Installation Suite
Central orchestration script with interactive menu system.

**Features:**
- Complete automated installation workflow
- Individual script execution options
- System information display
- Service status monitoring
- Odoo log viewing

**Usage:**
```bash
sudo ./install.sh
```

### 🔧 install-official-odoo.sh - Community Edition
Installs Odoo 19.0 Community Edition from official repositories.

**What it does:**
- Adds official Odoo APT repository
- Installs PostgreSQL and dependencies
- Creates `odoo` system user
- Configures systemd service
- Sets up basic configuration

**Usage:**
```bash
sudo ./install-official-odoo.sh
```

**Post-Installation:**
- Access Odoo at `http://your-server:8069`
- Default database: Create through web interface
- Service: Automatically started and enabled

### ⚙️ setup-odoo-config.sh - Production Configuration
Replaces default minimal configuration with production-optimized settings.

**Configuration includes:**
- Performance tuning (worker processes, memory limits)
- Security settings (proxy mode, database filtering)
- Logging configuration
- Email server setup (optional)
- Database connection optimization

**Usage:**
```bash
sudo ./setup-odoo-config.sh
```

**Interactive prompts for:**
- Master password (database management)
- Email server settings (optional)
- Custom database filters

### 🐘 setup-postgres-for-odoo.sh - PostgreSQL Authentication
Configures PostgreSQL authentication for seamless Odoo database operations.

**Resolves:**
- `psycopg2.OperationalError` authentication failures
- Password-based authentication setup
- Connection testing and validation

**What it does:**
- Creates `odoo` PostgreSQL user
- Configures `pg_hba.conf` for md5 authentication
- Sets database password
- Tests database connectivity

**Usage:**
```bash
sudo ./setup-postgres-for-odoo.sh
```

### 🌐 setup-nginx-for-odoo.sh - Reverse Proxy & SSL
Sets up Nginx as reverse proxy with automatic SSL certificate generation.

**Features:**
- Nginx installation and configuration
- Automatic SSL certificate generation (Let's Encrypt)
- HTTP to HTTPS redirect
- WebSocket support for live chat
- Security headers and optimizations

**Requirements:**
- Domain name pointing to server IP
- Open ports 80 and 443
- Valid email address for SSL certificates

**Usage:**
```bash
sudo ./setup-nginx-for-odoo.sh
```

**Interactive prompts for:**
- Domain name
- Email address for SSL certificates
- SSL certificate generation

### 🏢 install-odoo-enterprise.sh - Enterprise Edition
Installs Odoo Enterprise modules for licensed users.

**Prerequisites:**
- Odoo Community Edition already installed
- Valid Odoo Enterprise subscription
- GitHub account with enterprise repository access
- SSH key or Personal Access Token

**What it does:**
- Clones `odoo/enterprise` repository
- Sets proper permissions
- Updates Odoo configuration
- Restarts Odoo service

**Usage:**
```bash
sudo ./install-odoo-enterprise.sh
```

## 🏢 Enterprise Installation Guide

### Step 1: Obtain Enterprise License
Contact Odoo S.A. or authorized partners:
- **Sales**: sales@odoo.com
- **Partners**: https://www.odoo.com/partners

### Step 2: GitHub Repository Access
Your Odoo subscription includes access to the private `odoo/enterprise` repository.

### Step 3: SSH Key Setup (Recommended)
```bash
# Generate SSH key
ssh-keygen -t ed25519 -C "your-email@domain.com"

# Add to GitHub account
cat ~/.ssh/id_ed25519.pub
# Copy output and add to: https://github.com/settings/keys

# Test connection
ssh -T git@github.com
```

### Step 4: Verify Repository Access
```bash
git ls-remote git@github.com:odoo/enterprise.git HEAD
```

### Step 5: Run Installation
```bash
sudo ./install.sh
# Select option 6 for Enterprise installation
```

## 🔧 Configuration Files

### Odoo Configuration (`/etc/odoo/odoo.conf`)
```ini
[options]
addons_path = /opt/odoo/addons,/opt/odoo/enterprise
data_dir = /var/lib/odoo
logfile = /var/log/odoo/odoo-server.log
proxy_mode = True
workers = 4
max_cron_threads = 2
db_name = False
db_user = odoo
db_password = [generated]
admin_passwd = [your-master-password]
```

### Nginx Configuration (`/etc/nginx/sites-available/odoo`)
```nginx
upstream odoo {
    server 127.0.0.1:8069;
}

upstream odoochat {
    server 127.0.0.1:8072;
}

server {
    listen 80;
    server_name your-domain.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name your-domain.com;
    
    # SSL Configuration
    ssl_certificate /etc/letsencrypt/live/your-domain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/your-domain.com/privkey.pem;
    
    # Proxy Configuration
    location / {
        proxy_pass http://odoo;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    # WebSocket for live chat
    location /websocket {
        proxy_pass http://odoochat;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
```

## 🛠️ Troubleshooting

### Common Issues

#### Odoo Service Not Starting
```bash
# Check service status
sudo systemctl status odoo

# Check logs
sudo journalctl -u odoo -f

# Common fixes
sudo systemctl restart postgresql
sudo systemctl restart odoo
```

#### Database Connection Issues
```bash
# Test PostgreSQL connection
sudo -u odoo psql -d postgres

# Reset PostgreSQL configuration
sudo ./setup-postgres-for-odoo.sh
```

#### SSL Certificate Issues
```bash
# Check certificate status
sudo certbot certificates

# Renew certificates
sudo certbot renew

# Re-run Nginx setup
sudo ./setup-nginx-for-odoo.sh
```

#### Port Already in Use
```bash
# Check what's using port 8069
sudo ss -tulpn | grep :8069

# Stop conflicting services
sudo systemctl stop apache2  # if Apache is running
```

### Log Files

| Component | Log Location |
|-----------|-------------|
| Odoo | `/var/log/odoo/odoo-server.log` |
| Nginx | `/var/log/nginx/access.log`, `/var/log/nginx/error.log` |
| PostgreSQL | `/var/log/postgresql/` |
| System | `journalctl -u odoo` |

### Service Management

```bash
# Odoo service
sudo systemctl start|stop|restart|status odoo
sudo systemctl enable|disable odoo

# PostgreSQL service
sudo systemctl start|stop|restart|status postgresql

# Nginx service
sudo systemctl start|stop|restart|status nginx
```

## 🔐 Security Considerations

### Default Security Measures
- Odoo runs as non-privileged `odoo` user
- Database access restricted to local connections
- Nginx proxy mode enabled
- SSL/TLS encryption for web traffic
- Security headers configured

### Additional Security Recommendations
1. **Firewall**: Configure UFW to restrict access
   ```bash
   sudo ufw allow 22/tcp    # SSH
   sudo ufw allow 80/tcp    # HTTP
   sudo ufw allow 443/tcp   # HTTPS
   sudo ufw enable
   ```

2. **Database**: Restrict PostgreSQL access
   ```bash
   # Edit /etc/postgresql/*/main/postgresql.conf
   listen_addresses = 'localhost'
   ```

3. **Backup**: Regular database backups
   ```bash
   # Automated backups
   sudo -u odoo pg_dump your_db_name > backup.sql
   ```

## 📊 Performance Tuning

### Worker Configuration
Adjust based on server resources in `/etc/odoo/odoo.conf`:

```ini
# For 4GB RAM server
workers = 4
max_cron_threads = 2

# For 8GB RAM server  
workers = 8
max_cron_threads = 4
```

### Database Optimization
PostgreSQL tuning in `/etc/postgresql/*/main/postgresql.conf`:

```ini
shared_buffers = 256MB
effective_cache_size = 1GB
random_page_cost = 1.1
work_mem = 4MB
```

## 📁 Directory Structure

```
/opt/odoo/                    # Odoo installation
├── addons/                   # Community addons
└── enterprise/               # Enterprise addons (if installed)

/etc/odoo/                    # Configuration
└── odoo.conf                 # Main configuration file

/var/lib/odoo/                # Data directory
├── filestore/                # Uploaded files
└── sessions/                 # Session data

/var/log/odoo/                # Log files
└── odoo-server.log           # Main log file
```

## 🚀 Next Steps After Installation

1. **Access Odoo**: Open `https://your-domain.com` or `http://your-server:8069`

2. **Create Database**: Use the database manager to create your first database

3. **Install Apps**: Browse and install required applications

4. **Configure Company**: Set up your company information

5. **User Management**: Create users and assign permissions

6. **Backup Strategy**: Set up automated backups

7. **Monitor**: Set up monitoring for services and logs

## 📄 License

This installation suite is provided under the MIT License. See [LICENSE](LICENSE) file for details.

**Note**: Odoo itself is licensed under LGPL-3.0, and Odoo Enterprise requires a separate commercial license from Odoo S.A.

## 🤝 Support

### Community Support
- **Odoo Documentation**: https://www.odoo.com/documentation
- **Community Forum**: https://www.odoo.com/forum
- **GitHub Issues**: For script-related issues

### Enterprise Support
- **Odoo Support**: https://www.odoo.com/help
- **Professional Services**: Available through Odoo partners

## 📝 Changelog

### v1.0.0 - February 2026
- Initial release
- Complete Odoo 19.0 installation suite
- Nginx reverse proxy with SSL
- Enterprise edition support
- Interactive menu system
- POSIX shell compatibility

---

**Made with ❤️ for the Odoo Community**

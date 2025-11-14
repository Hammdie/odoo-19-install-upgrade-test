#!/bin/bash

# Odoo Backup Script
# Creates backups of Odoo databases and filestore

set -e  # Exit on any error

# Configuration
ODOO_USER="odoo"
ODOO_HOME="/opt/odoo"
BACKUP_DIR="$(dirname "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)")/backups"
LOG_DIR="/var/log/odoo-upgrade"
LOG_FILE="$LOG_DIR/backup-$(date +%Y%m%d-%H%M%S).log"

# Database configuration
DB_HOST="localhost"
DB_PORT="5432"
DB_USER="odoo"

# Backup retention (days)
RETENTION_DAYS=30

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Command line options
AUTO_MODE=false
TEST_MODE=false
DATABASE=""
COMPRESS=true

# Logging function
log() {
    local level=$1
    shift
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
    
    case $level in
        "ERROR")
            echo -e "${RED}[ERROR]${NC} $message" >&2
            ;;
        "WARN")
            echo -e "${YELLOW}[WARN]${NC} $message"
            ;;
        "INFO")
            echo -e "${BLUE}[INFO]${NC} $message"
            ;;
        "SUCCESS")
            echo -e "${GREEN}[SUCCESS]${NC} $message"
            ;;
    esac
}

# Usage function
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Options:
    --auto              Run in automatic mode (no prompts)
    --test              Test mode (validate environment only)
    --database DB       Backup specific database only
    --no-compress       Don't compress backup files
    --retention DAYS    Set retention period (default: $RETENTION_DAYS days)
    --help              Show this help message

Examples:
    $0                          # Interactive backup of all databases
    $0 --auto                   # Automatic backup (suitable for cron)
    $0 --database mydb          # Backup specific database
    $0 --test                   # Test backup environment
EOF
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --auto)
                AUTO_MODE=true
                shift
                ;;
            --test)
                TEST_MODE=true
                shift
                ;;
            --database)
                DATABASE="$2"
                shift 2
                ;;
            --no-compress)
                COMPRESS=false
                shift
                ;;
            --retention)
                RETENTION_DAYS="$2"
                shift 2
                ;;
            --help)
                usage
                exit 0
                ;;
            *)
                log "ERROR" "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
}

# Create necessary directories
create_directories() {
    log "INFO" "Creating backup directories..."
    
    # Create backup directory
    mkdir -p "$BACKUP_DIR"
    mkdir -p "$LOG_DIR"
    
    # Set permissions
    chmod 755 "$BACKUP_DIR"
    
    log "SUCCESS" "Backup directories created"
}

# Check prerequisites
check_prerequisites() {
    log "INFO" "Checking prerequisites..."
    
    # Check if PostgreSQL client is available
    if ! command -v pg_dump &> /dev/null; then
        log "ERROR" "pg_dump not found. Please install PostgreSQL client."
        exit 1
    fi
    
    # Check if Odoo user exists
    if ! id "$ODOO_USER" &>/dev/null; then
        log "ERROR" "Odoo user '$ODOO_USER' does not exist"
        exit 1
    fi
    
    # Check PostgreSQL connection
    if ! sudo -u "$ODOO_USER" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -l &>/dev/null; then
        log "ERROR" "Cannot connect to PostgreSQL database"
        exit 1
    fi
    
    # Check Odoo filestore
    if [[ ! -d "$ODOO_HOME/.local/share/Odoo/filestore" ]]; then
        log "WARN" "Odoo filestore not found at $ODOO_HOME/.local/share/Odoo/filestore"
    fi
    
    log "SUCCESS" "Prerequisites check passed"
}

# Get list of Odoo databases
get_databases() {
    log "INFO" "Getting list of Odoo databases..."
    
    local databases
    if [[ -n "$DATABASE" ]]; then
        # Check if specific database exists
        if sudo -u "$ODOO_USER" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -lqt | cut -d \| -f 1 | grep -qw "$DATABASE"; then
            databases=("$DATABASE")
            log "INFO" "Will backup database: $DATABASE"
        else
            log "ERROR" "Database '$DATABASE' not found"
            exit 1
        fi
    else
        # Get all databases that are not system databases
        mapfile -t databases < <(sudo -u "$ODOO_USER" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -lqt | cut -d \| -f 1 | grep -vwE 'postgres|template[0-1]|Name' | sed '/^$/d' | tr -d ' ')
        
        if [[ ${#databases[@]} -eq 0 ]]; then
            log "WARN" "No Odoo databases found"
            return
        fi
        
        log "INFO" "Found ${#databases[@]} database(s): ${databases[*]}"
    fi
    
    echo "${databases[@]}"
}

# Backup database
backup_database() {
    local db_name="$1"
    local timestamp=$(date +%Y%m%d-%H%M%S)
    local backup_file="$BACKUP_DIR/odoo-${db_name}-${timestamp}.sql"
    
    log "INFO" "Backing up database: $db_name"
    
    # Create database backup
    if sudo -u "$ODOO_USER" pg_dump -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -f "$backup_file" "$db_name" 2>&1 | tee -a "$LOG_FILE"; then
        log "SUCCESS" "Database backup created: $backup_file"
        
        # Compress backup if requested
        if [[ "$COMPRESS" == true ]]; then
            log "INFO" "Compressing backup..."
            gzip "$backup_file"
            backup_file="${backup_file}.gz"
            log "SUCCESS" "Backup compressed: $backup_file"
        fi
        
        # Set permissions
        chmod 600 "$backup_file"
        
        # Get file size
        local file_size=$(du -h "$backup_file" | cut -f1)
        log "INFO" "Backup size: $file_size"
        
        return 0
    else
        log "ERROR" "Failed to backup database: $db_name"
        return 1
    fi
}

# Backup filestore
backup_filestore() {
    local db_name="$1"
    local timestamp=$(date +%Y%m%d-%H%M%S)
    local filestore_dir="$ODOO_HOME/.local/share/Odoo/filestore/$db_name"
    local backup_file="$BACKUP_DIR/odoo-filestore-${db_name}-${timestamp}.tar.gz"
    
    if [[ -d "$filestore_dir" ]]; then
        log "INFO" "Backing up filestore for database: $db_name"
        
        # Create filestore backup
        if tar -czf "$backup_file" -C "$ODOO_HOME/.local/share/Odoo/filestore" "$db_name" 2>&1 | tee -a "$LOG_FILE"; then
            log "SUCCESS" "Filestore backup created: $backup_file"
            
            # Set permissions
            chmod 600 "$backup_file"
            
            # Get file size
            local file_size=$(du -h "$backup_file" | cut -f1)
            log "INFO" "Filestore backup size: $file_size"
            
            return 0
        else
            log "ERROR" "Failed to backup filestore for: $db_name"
            return 1
        fi
    else
        log "WARN" "Filestore not found for database: $db_name"
        return 0
    fi
}

# Clean old backups
cleanup_old_backups() {
    log "INFO" "Cleaning up old backups (older than $RETENTION_DAYS days)..."
    
    local deleted_count=0
    
    # Find and delete old backup files
    while IFS= read -r -d '' file; do
        log "INFO" "Deleting old backup: $(basename "$file")"
        rm -f "$file"
        ((deleted_count++))
    done < <(find "$BACKUP_DIR" -name "odoo-*.sql*" -o -name "odoo-filestore-*.tar.gz" -mtime +$RETENTION_DAYS -print0 2>/dev/null)
    
    if [[ $deleted_count -gt 0 ]]; then
        log "SUCCESS" "Deleted $deleted_count old backup files"
    else
        log "INFO" "No old backup files to delete"
    fi
}

# Generate backup report
generate_report() {
    local databases=("$@")
    local total_backups=0
    local successful_backups=0
    local total_size=0
    
    log "INFO" "Backup Report"
    log "INFO" "============="
    log "INFO" "Date: $(date)"
    log "INFO" "Backup directory: $BACKUP_DIR"
    log "INFO" "Retention: $RETENTION_DAYS days"
    log "INFO" ""
    
    # Count current backup files
    for db in "${databases[@]}"; do
        local db_backups=$(find "$BACKUP_DIR" -name "odoo-${db}-*.sql*" -mtime -1 | wc -l)
        local fs_backups=$(find "$BACKUP_DIR" -name "odoo-filestore-${db}-*.tar.gz" -mtime -1 | wc -l)
        
        if [[ $db_backups -gt 0 ]]; then
            log "INFO" "Database '$db': $db_backups backup(s) created"
            ((successful_backups++))
        fi
        
        if [[ $fs_backups -gt 0 ]]; then
            log "INFO" "Filestore '$db': $fs_backups backup(s) created"
        fi
        
        ((total_backups++))
    done
    
    # Calculate total backup size
    if command -v du &> /dev/null; then
        local backup_size=$(du -sh "$BACKUP_DIR" 2>/dev/null | cut -f1 || echo "Unknown")
        log "INFO" ""
        log "INFO" "Total backup directory size: $backup_size"
    fi
    
    # Summary
    log "INFO" ""
    log "INFO" "Summary: $successful_backups/$total_backups databases backed up successfully"
    
    if [[ $successful_backups -eq $total_backups ]]; then
        log "SUCCESS" "All backups completed successfully"
        return 0
    else
        log "WARN" "Some backups failed"
        return 1
    fi
}

# Main backup function
perform_backup() {
    local databases
    mapfile -t databases < <(get_databases)
    
    if [[ ${#databases[@]} -eq 0 ]]; then
        log "WARN" "No databases to backup"
        return 0
    fi
    
    local backup_count=0
    local failed_count=0
    
    for db in "${databases[@]}"; do
        log "INFO" "Processing database: $db"
        
        # Backup database
        if backup_database "$db"; then
            ((backup_count++))
        else
            ((failed_count++))
        fi
        
        # Backup filestore
        backup_filestore "$db"
        
        log "INFO" "Completed backup for: $db"
        echo ""
    done
    
    # Cleanup old backups
    cleanup_old_backups
    
    # Generate report
    generate_report "${databases[@]}"
    
    log "INFO" "Backup process completed: $backup_count successful, $failed_count failed"
    
    if [[ $failed_count -eq 0 ]]; then
        return 0
    else
        return 1
    fi
}

# Test mode function
run_test() {
    log "INFO" "Running backup system test..."
    
    check_prerequisites
    create_directories
    
    local databases
    mapfile -t databases < <(get_databases)
    
    log "INFO" "Test results:"
    log "INFO" "- PostgreSQL connection: OK"
    log "INFO" "- Backup directory: OK ($BACKUP_DIR)"
    log "INFO" "- Databases found: ${#databases[@]}"
    
    for db in "${databases[@]}"; do
        log "INFO" "  - $db"
    done
    
    log "SUCCESS" "Backup system test completed successfully"
}

# Main execution
main() {
    parse_arguments "$@"
    
    log "INFO" "Starting Odoo backup process..."
    log "INFO" "Mode: $([ "$AUTO_MODE" = true ] && echo "Automatic" || echo "Manual")"
    log "INFO" "Log file: $LOG_FILE"
    
    if [[ "$TEST_MODE" == true ]]; then
        run_test
        exit 0
    fi
    
    create_directories
    check_prerequisites
    
    if [[ "$AUTO_MODE" == false && -z "$DATABASE" ]]; then
        echo -e "${BLUE}Starting Odoo backup process...${NC}"
        echo -e "${YELLOW}This will backup all Odoo databases and filestores${NC}"
        read -p "Continue? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log "INFO" "Backup cancelled by user"
            exit 0
        fi
    fi
    
    if perform_backup; then
        log "SUCCESS" "Odoo backup completed successfully!"
        exit 0
    else
        log "ERROR" "Odoo backup completed with errors!"
        exit 1
    fi
}

# Run main function
main "$@"
#!/bin/bash

# Odoo Restore Script
# Restores Odoo databases and filestore from backups

set -e  # Exit on any error

# Configuration
ODOO_USER="odoo"
ODOO_HOME="/opt/odoo"
BACKUP_DIR="$(dirname "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)")/backups"
LOG_DIR="/var/log/odoo-upgrade"
LOG_FILE="$LOG_DIR/restore-$(date +%Y%m%d-%H%M%S).log"

# Database configuration
DB_HOST="localhost"
DB_PORT="5432"
DB_USER="odoo"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Command line options
BACKUP_FILE=""
DATABASE_NAME=""
LATEST=false
FORCE=false
LIST_ONLY=false

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
    --file FILE         Restore from specific backup file
    --latest            Restore from the latest backup
    --database DB       Target database name (if different from backup)
    --force             Force restore without confirmation
    --list              List available backups
    --help              Show this help message

Examples:
    $0 --list                                   # List all available backups
    $0 --latest                                 # Restore from latest backup
    $0 --file /path/to/backup.sql               # Restore from specific file
    $0 --latest --database newdb                # Restore to different database name
    $0 --file backup.sql.gz --force             # Force restore without confirmation

Note: This script will stop the Odoo service during restore operations.
EOF
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --file)
                BACKUP_FILE="$2"
                shift 2
                ;;
            --latest)
                LATEST=true
                shift
                ;;
            --database)
                DATABASE_NAME="$2"
                shift 2
                ;;
            --force)
                FORCE=true
                shift
                ;;
            --list)
                LIST_ONLY=true
                shift
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

# Create log directory
create_log_dir() {
    if [[ ! -d "$LOG_DIR" ]]; then
        sudo mkdir -p "$LOG_DIR"
        sudo chmod 755 "$LOG_DIR"
        log "INFO" "Created log directory: $LOG_DIR"
    fi
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log "ERROR" "This script must be run as root or with sudo"
        exit 1
    fi
}

# Check prerequisites
check_prerequisites() {
    log "INFO" "Checking prerequisites..."
    
    # Check if PostgreSQL client is available
    if ! command -v psql &> /dev/null || ! command -v pg_dump &> /dev/null; then
        log "ERROR" "PostgreSQL client tools not found. Please install PostgreSQL client."
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
    
    # Check backup directory
    if [[ ! -d "$BACKUP_DIR" ]]; then
        log "ERROR" "Backup directory not found: $BACKUP_DIR"
        exit 1
    fi
    
    log "SUCCESS" "Prerequisites check passed"
}

# List available backups
list_backups() {
    log "INFO" "Available backups:"
    log "INFO" "=================="
    
    local backup_count=0
    
    # Find SQL backup files
    if find "$BACKUP_DIR" -name "odoo-*.sql*" -type f &>/dev/null; then
        log "INFO" ""
        log "INFO" "Database backups:"
        while IFS= read -r -d '' file; do
            local filename=$(basename "$file")
            local filesize=$(du -h "$file" | cut -f1)
            local filedate=$(date -r "$file" '+%Y-%m-%d %H:%M:%S')
            log "INFO" "  $filename (${filesize}, $filedate)"
            ((backup_count++))
        done < <(find "$BACKUP_DIR" -name "odoo-*.sql*" -type f -print0 | sort -z)
    fi
    
    # Find filestore backups
    if find "$BACKUP_DIR" -name "odoo-filestore-*.tar.gz" -type f &>/dev/null; then
        log "INFO" ""
        log "INFO" "Filestore backups:"
        while IFS= read -r -d '' file; do
            local filename=$(basename "$file")
            local filesize=$(du -h "$file" | cut -f1)
            local filedate=$(date -r "$file" '+%Y-%m-%d %H:%M:%S')
            log "INFO" "  $filename (${filesize}, $filedate)"
        done < <(find "$BACKUP_DIR" -name "odoo-filestore-*.tar.gz" -type f -print0 | sort -z)
    fi
    
    log "INFO" ""
    log "INFO" "Total backup files found: $backup_count"
    
    if [[ $backup_count -eq 0 ]]; then
        log "WARN" "No backup files found in $BACKUP_DIR"
    fi
}

# Find latest backup
find_latest_backup() {
    local latest_file=""
    local latest_time=0
    
    # Find the most recent SQL backup
    while IFS= read -r -d '' file; do
        local file_time=$(stat -c %Y "$file" 2>/dev/null || echo 0)
        if [[ $file_time -gt $latest_time ]]; then
            latest_time=$file_time
            latest_file="$file"
        fi
    done < <(find "$BACKUP_DIR" -name "odoo-*.sql*" -type f -print0 2>/dev/null)
    
    if [[ -n "$latest_file" ]]; then
        echo "$latest_file"
        return 0
    else
        log "ERROR" "No backup files found"
        return 1
    fi
}

# Extract database name from backup filename
extract_database_name() {
    local backup_file="$1"
    local filename=$(basename "$backup_file")
    
    # Extract database name from filename pattern: odoo-DBNAME-TIMESTAMP.sql[.gz]
    if [[ $filename =~ ^odoo-([^-]+)-.+\.sql(\.gz)?$ ]]; then
        echo "${BASH_REMATCH[1]}"
        return 0
    else
        log "ERROR" "Cannot extract database name from filename: $filename"
        return 1
    fi
}

# Check if database exists
database_exists() {
    local db_name="$1"
    
    if sudo -u "$ODOO_USER" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -lqt | cut -d \| -f 1 | grep -qw "$db_name"; then
        return 0
    else
        return 1
    fi
}

# Stop Odoo service
stop_odoo() {
    log "INFO" "Stopping Odoo service..."
    
    if systemctl is-active --quiet odoo; then
        systemctl stop odoo
        log "SUCCESS" "Odoo service stopped"
    else
        log "INFO" "Odoo service is not running"
    fi
    
    # Wait a moment for connections to close
    sleep 3
}

# Start Odoo service
start_odoo() {
    log "INFO" "Starting Odoo service..."
    
    systemctl start odoo
    
    # Wait for service to start
    sleep 5
    
    if systemctl is-active --quiet odoo; then
        log "SUCCESS" "Odoo service started"
    else
        log "WARN" "Odoo service may not have started correctly"
        log "INFO" "Check status with: systemctl status odoo"
    fi
}

# Terminate database connections
terminate_connections() {
    local db_name="$1"
    
    log "INFO" "Terminating connections to database: $db_name"
    
    sudo -u "$ODOO_USER" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -c "
        SELECT pg_terminate_backend(pg_stat_activity.pid)
        FROM pg_stat_activity
        WHERE pg_stat_activity.datname = '$db_name'
        AND pid <> pg_backend_pid();
    " postgres &>/dev/null || true
    
    sleep 2
}

# Restore database
restore_database() {
    local backup_file="$1"
    local target_db="$2"
    
    log "INFO" "Restoring database from: $(basename "$backup_file")"
    log "INFO" "Target database: $target_db"
    
    # Check if backup file exists
    if [[ ! -f "$backup_file" ]]; then
        log "ERROR" "Backup file not found: $backup_file"
        return 1
    fi
    
    # Determine if file is compressed
    local is_compressed=false
    if [[ "$backup_file" =~ \.gz$ ]]; then
        is_compressed=true
    fi
    
    # Drop existing database if it exists
    if database_exists "$target_db"; then
        log "WARN" "Database '$target_db' already exists. Dropping it..."
        terminate_connections "$target_db"
        
        if sudo -u "$ODOO_USER" dropdb -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" "$target_db" 2>&1 | tee -a "$LOG_FILE"; then
            log "SUCCESS" "Database dropped successfully"
        else
            log "ERROR" "Failed to drop existing database"
            return 1
        fi
    fi
    
    # Create new database
    log "INFO" "Creating new database: $target_db"
    if sudo -u "$ODOO_USER" createdb -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" "$target_db" 2>&1 | tee -a "$LOG_FILE"; then
        log "SUCCESS" "Database created successfully"
    else
        log "ERROR" "Failed to create database"
        return 1
    fi
    
    # Restore data
    log "INFO" "Restoring database data..."
    if [[ "$is_compressed" == true ]]; then
        if gunzip -c "$backup_file" | sudo -u "$ODOO_USER" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$target_db" 2>&1 | tee -a "$LOG_FILE"; then
            log "SUCCESS" "Database restored successfully from compressed backup"
        else
            log "ERROR" "Failed to restore database from compressed backup"
            return 1
        fi
    else
        if sudo -u "$ODOO_USER" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$target_db" -f "$backup_file" 2>&1 | tee -a "$LOG_FILE"; then
            log "SUCCESS" "Database restored successfully"
        else
            log "ERROR" "Failed to restore database"
            return 1
        fi
    fi
    
    return 0
}

# Restore filestore
restore_filestore() {
    local db_name="$1"
    local backup_file="$2"
    
    # Look for corresponding filestore backup
    if [[ -z "$backup_file" ]]; then
        # Try to find filestore backup based on database name and timestamp
        local sql_filename=$(basename "$BACKUP_FILE")
        local timestamp=""
        
        if [[ $sql_filename =~ odoo-[^-]+-([0-9]{8}-[0-9]{6}) ]]; then
            timestamp="${BASH_REMATCH[1]}"
            backup_file=$(find "$BACKUP_DIR" -name "odoo-filestore-${db_name}-${timestamp}.tar.gz" -type f | head -1)
        fi
        
        if [[ -z "$backup_file" ]]; then
            # Try to find the latest filestore backup for this database
            backup_file=$(find "$BACKUP_DIR" -name "odoo-filestore-${db_name}-*.tar.gz" -type f -printf '%T@ %p\n' | sort -n | tail -1 | cut -d' ' -f2)
        fi
    fi
    
    if [[ -z "$backup_file" || ! -f "$backup_file" ]]; then
        log "WARN" "No filestore backup found for database: $db_name"
        return 0
    fi
    
    log "INFO" "Restoring filestore from: $(basename "$backup_file")"
    
    local filestore_dir="$ODOO_HOME/.local/share/Odoo/filestore"
    local target_dir="$filestore_dir/$db_name"
    
    # Create filestore directory if it doesn't exist
    mkdir -p "$filestore_dir"
    
    # Remove existing filestore
    if [[ -d "$target_dir" ]]; then
        log "INFO" "Removing existing filestore: $target_dir"
        rm -rf "$target_dir"
    fi
    
    # Extract filestore backup
    if tar -xzf "$backup_file" -C "$filestore_dir" 2>&1 | tee -a "$LOG_FILE"; then
        log "SUCCESS" "Filestore restored successfully"
        
        # Set correct permissions
        chown -R "$ODOO_USER:$ODOO_USER" "$target_dir"
        
        return 0
    else
        log "ERROR" "Failed to restore filestore"
        return 1
    fi
}

# Confirm restore operation
confirm_restore() {
    local backup_file="$1"
    local target_db="$2"
    
    if [[ "$FORCE" == true ]]; then
        return 0
    fi
    
    echo
    echo -e "${YELLOW}WARNING: This will completely replace the database '$target_db'${NC}"
    echo -e "${YELLOW}Backup file: $(basename "$backup_file")${NC}"
    echo -e "${YELLOW}Target database: $target_db${NC}"
    echo
    echo -e "${RED}This operation cannot be undone!${NC}"
    echo
    
    read -p "Are you sure you want to continue? Type 'yes' to confirm: " -r
    
    if [[ $REPLY == "yes" ]]; then
        return 0
    else
        log "INFO" "Restore operation cancelled by user"
        return 1
    fi
}

# Main restore function
perform_restore() {
    local backup_file="$BACKUP_FILE"
    local target_db="$DATABASE_NAME"
    
    # Find backup file if --latest is specified
    if [[ "$LATEST" == true ]]; then
        backup_file=$(find_latest_backup)
        if [[ $? -ne 0 ]]; then
            exit 1
        fi
        log "INFO" "Using latest backup: $(basename "$backup_file")"
    fi
    
    # Validate backup file
    if [[ -z "$backup_file" ]]; then
        log "ERROR" "No backup file specified. Use --file or --latest option."
        exit 1
    fi
    
    if [[ ! -f "$backup_file" ]]; then
        # Try to find the file in backup directory
        local full_path="$BACKUP_DIR/$backup_file"
        if [[ -f "$full_path" ]]; then
            backup_file="$full_path"
        else
            log "ERROR" "Backup file not found: $backup_file"
            exit 1
        fi
    fi
    
    # Extract database name if not specified
    if [[ -z "$target_db" ]]; then
        target_db=$(extract_database_name "$backup_file")
        if [[ $? -ne 0 ]]; then
            exit 1
        fi
    fi
    
    log "INFO" "Restore configuration:"
    log "INFO" "- Backup file: $backup_file"
    log "INFO" "- Target database: $target_db"
    log "INFO" "- File size: $(du -h "$backup_file" | cut -f1)"
    
    # Confirm restore
    if ! confirm_restore "$backup_file" "$target_db"; then
        exit 1
    fi
    
    # Perform restore
    stop_odoo
    
    if restore_database "$backup_file" "$target_db"; then
        restore_filestore "$target_db"
        start_odoo
        
        log "SUCCESS" "Restore completed successfully!"
        log "INFO" "Database '$target_db' has been restored from backup"
        
        return 0
    else
        log "ERROR" "Restore failed!"
        start_odoo
        return 1
    fi
}

# Main execution
main() {
    parse_arguments "$@"
    
    create_log_dir
    
    log "INFO" "Starting Odoo restore process..."
    log "INFO" "Log file: $LOG_FILE"
    
    if [[ "$LIST_ONLY" == true ]]; then
        list_backups
        exit 0
    fi
    
    check_root
    check_prerequisites
    
    if perform_restore; then
        log "SUCCESS" "Odoo restore completed successfully!"
        echo
        echo -e "${GREEN}Restore completed successfully!${NC}"
        echo -e "${BLUE}Log file: $LOG_FILE${NC}"
        exit 0
    else
        log "ERROR" "Odoo restore failed!"
        echo
        echo -e "${RED}Restore failed!${NC}"
        echo -e "${BLUE}Check log file: $LOG_FILE${NC}"
        exit 1
    fi
}

# Run main function
main "$@"
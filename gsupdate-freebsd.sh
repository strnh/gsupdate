#!/bin/sh
#
# GroupSession Update Script for FreeBSD
# 
# Usage: sudo ./gsupdate-freebsd.sh <gsession.war> [tomcat_dir] [backup_dir] [app_name]
#
# Example:
#   sudo ./gsupdate-freebsd.sh /path/to/gsession.war
#   sudo ./gsupdate-freebsd.sh /path/to/gsession.war /usr/local/apache-tomcat-9.0 /var/backups/gsession
#   sudo ./gsupdate-freebsd.sh /path/to/gsession.war /usr/local/apache-tomcat-9.0 /var/backups/gsession gs
#

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Source common functions
if [ -f "$SCRIPT_DIR/gsupdate-common.sh" ]; then
    . "$SCRIPT_DIR/gsupdate-common.sh"
else
    echo "ERROR: Common functions file not found: $SCRIPT_DIR/gsupdate-common.sh"
    exit 1
fi

# Default configuration for FreeBSD
DEFAULT_TOMCAT_DIR="/usr/local/apache-tomcat-9.0"
DEFAULT_BACKUP_DIR="/var/backups/gsession"

# Parse arguments
GSESSION_WAR="${1:-}"
TOMCAT_DIR="${2:-$DEFAULT_TOMCAT_DIR}"
BACKUP_DIR="${3:-$DEFAULT_BACKUP_DIR}"
APP_NAME="${4:-}"

# FreeBSD-specific Tomcat service control
stop_tomcat() {
    log_info "Stopping Tomcat service..."
    
    # Try service command (FreeBSD rc.d)
    if service tomcat9 status >/dev/null 2>&1; then
        service tomcat9 stop
    elif service tomcat85 status >/dev/null 2>&1; then
        service tomcat85 stop
    elif service tomcat status >/dev/null 2>&1; then
        service tomcat stop
    else
        log_warn "Could not find Tomcat service, attempting to kill process..."
        pkill -f catalina || true
    fi
    
    # Wait for Tomcat to stop
    WAIT_COUNT=0
    while is_tomcat_running && [ $WAIT_COUNT -lt 30 ]; do
        sleep 1
        WAIT_COUNT=$((WAIT_COUNT + 1))
    done
    
    if is_tomcat_running; then
        log_error "Failed to stop Tomcat"
        return 1
    fi
    
    log_info "Tomcat stopped successfully"
    return 0
}

start_tomcat() {
    log_info "Starting Tomcat service..."
    
    # Try service command (FreeBSD rc.d)
    if service tomcat9 status >/dev/null 2>&1 || [ -f /usr/local/etc/rc.d/tomcat9 ]; then
        service tomcat9 start
    elif service tomcat85 status >/dev/null 2>&1 || [ -f /usr/local/etc/rc.d/tomcat85 ]; then
        service tomcat85 start
    elif service tomcat status >/dev/null 2>&1 || [ -f /usr/local/etc/rc.d/tomcat ]; then
        service tomcat start
    else
        log_error "Could not find Tomcat service"
        return 1
    fi
    
    log_info "Tomcat started successfully"
    return 0
}

# Main update procedure
main() {
    log_info "=========================================="
    log_info "GroupSession Update Script for FreeBSD"
    log_info "=========================================="
    
    # Check root
    check_root
    
    # Validate parameters
    validate_params
    
    log_info "Configuration:"
    log_info "  Tomcat Directory: $TOMCAT_DIR"
    log_info "  Backup Directory: $BACKUP_DIR"
    log_info "  WAR File: $GSESSION_WAR"
    log_info ""
    
    # Create backup directory if not exists
    mkdir -p "$BACKUP_DIR"
    
    # Step 1: Stop Tomcat
    log_info "Step 1: Stopping Tomcat..."
    stop_tomcat || exit 1
    
    # Step 2: Backup existing data
    log_info "Step 2: Backing up existing data..."
    backup_app "$TOMCAT_DIR" "$BACKUP_DIR" || exit 1
    
    # Step 3: Deploy new WAR
    log_info "Step 3: Deploying new GroupSession WAR..."
    deploy_war "$TOMCAT_DIR" "$GSESSION_WAR" || exit 1
    
    # Step 4: Start Tomcat for WAR extraction
    log_info "Step 4: Starting Tomcat for WAR extraction..."
    start_tomcat || exit 1
    
    # Step 5: Stop Tomcat again
    log_info "Step 5: Stopping Tomcat for data restoration..."
    sleep 5
    stop_tomcat || exit 1
    
    # Step 6: Restore data directories
    log_info "Step 6: Restoring data directories..."
    restore_data "$TOMCAT_DIR" || exit 1
    
    # Step 7: Start Tomcat final
    log_info "Step 7: Starting Tomcat..."
    start_tomcat || exit 1
    
    # Step 8: Verify installation
    log_info "Step 8: Verifying installation..."
    sleep 3
    verify_installation "$TOMCAT_DIR"
    
    # Cleanup
    cleanup
    
    log_info ""
    log_info "=========================================="
    log_info "GroupSession update completed successfully!"
    log_info "=========================================="
    log_info "Please verify the installation at: http://[server]:8080/gsession/"
    log_info "Backup location: $(cat /tmp/gsupdate_backup_path.txt 2>/dev/null || echo 'N/A')"
}

# Run main function
main "$@"

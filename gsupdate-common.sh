#!/bin/bash
#
# GroupSession Update Common Functions
# Common functions used by OS-specific update scripts
#

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "This script must be run as root"
        exit 1
    fi
}

# Validate required parameters
validate_params() {
    if [ -z "$TOMCAT_DIR" ]; then
        log_error "TOMCAT_DIR is not set"
        exit 1
    fi
    
    if [ -z "$GSESSION_WAR" ]; then
        log_error "GSESSION_WAR is not set"
        exit 1
    fi
    
    if [ -z "$BACKUP_DIR" ]; then
        log_error "BACKUP_DIR is not set"
        exit 1
    fi
    
    if [ ! -f "$GSESSION_WAR" ]; then
        log_error "GroupSession WAR file not found: $GSESSION_WAR"
        exit 1
    fi
    
    if [ ! -d "$TOMCAT_DIR" ]; then
        log_error "Tomcat directory not found: $TOMCAT_DIR"
        exit 1
    fi
}

# Check if Tomcat is running
is_tomcat_running() {
    if [ -n "$(pgrep -f "catalina.*$TOMCAT_DIR")" ]; then
        return 0
    else
        return 1
    fi
}

# Backup GroupSession data
backup_gsession() {
    log_info "Starting backup process..."
    
    local GSESSION_DIR="$TOMCAT_DIR/webapps/gsession"
    
    if [ ! -d "$GSESSION_DIR" ]; then
        log_warn "GroupSession directory not found: $GSESSION_DIR"
        log_warn "This might be a fresh installation"
        return 0
    fi
    
    # Create backup directory with timestamp
    local TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    local BACKUP_PATH="$BACKUP_DIR/gsession_backup_$TIMESTAMP"
    
    log_info "Creating backup directory: $BACKUP_PATH"
    mkdir -p "$BACKUP_PATH"
    
    # Backup the entire gsession directory
    log_info "Backing up GroupSession directory..."
    cp -pr "$GSESSION_DIR" "$BACKUP_PATH/"
    
    if [ $? -eq 0 ]; then
        log_info "Backup completed successfully: $BACKUP_PATH"
        echo "$BACKUP_PATH" > /tmp/gsupdate_backup_path.txt
        return 0
    else
        log_error "Backup failed"
        return 1
    fi
}

# Deploy new GroupSession WAR
deploy_war() {
    log_info "Deploying new GroupSession WAR file..."
    
    local WEBAPP_DIR="$TOMCAT_DIR/webapps"
    local GSESSION_DIR="$WEBAPP_DIR/gsession"
    
    # Remove old deployment
    if [ -d "$GSESSION_DIR" ]; then
        log_info "Removing old GroupSession deployment..."
        rm -rf "$GSESSION_DIR"
    fi
    
    if [ -f "$WEBAPP_DIR/gsession.war" ]; then
        log_info "Removing old WAR file..."
        rm -f "$WEBAPP_DIR/gsession.war"
    fi
    
    # Copy new WAR file
    log_info "Copying new WAR file to webapps directory..."
    cp "$GSESSION_WAR" "$WEBAPP_DIR/gsession.war"
    
    if [ $? -eq 0 ]; then
        log_info "WAR file deployed successfully"
        return 0
    else
        log_error "Failed to deploy WAR file"
        return 1
    fi
}

# Restore data directories
restore_data() {
    log_info "Restoring data directories..."
    
    if [ ! -f /tmp/gsupdate_backup_path.txt ]; then
        log_warn "No backup path found, skipping data restoration"
        return 0
    fi
    
    local BACKUP_PATH=$(cat /tmp/gsupdate_backup_path.txt)
    local GSESSION_DIR="$TOMCAT_DIR/webapps/gsession"
    local BACKUP_GSESSION="$BACKUP_PATH/gsession"
    
    if [ ! -d "$BACKUP_GSESSION" ]; then
        log_warn "Backup directory not found: $BACKUP_GSESSION"
        return 0
    fi
    
    # Wait for WAR extraction
    log_info "Waiting for WAR extraction..."
    local WAIT_COUNT=0
    while [ ! -d "$GSESSION_DIR/WEB-INF" ] && [ $WAIT_COUNT -lt 60 ]; do
        sleep 2
        WAIT_COUNT=$((WAIT_COUNT + 1))
    done
    
    if [ ! -d "$GSESSION_DIR/WEB-INF" ]; then
        log_error "WAR extraction timeout. WEB-INF directory not found."
        return 1
    fi
    
    # Remove new data directories
    local DATA_DIRS="db file backup filekanri webmail"
    for DIR in $DATA_DIRS; do
        if [ -d "$GSESSION_DIR/WEB-INF/$DIR" ]; then
            log_info "Removing new $DIR directory..."
            rm -rf "$GSESSION_DIR/WEB-INF/$DIR"
        fi
    done
    
    # Restore data directories from backup
    for DIR in $DATA_DIRS; do
        if [ -d "$BACKUP_GSESSION/WEB-INF/$DIR" ]; then
            log_info "Restoring $DIR directory..."
            cp -pr "$BACKUP_GSESSION/WEB-INF/$DIR" "$GSESSION_DIR/WEB-INF/"
        else
            log_warn "Backup directory $DIR not found, skipping..."
        fi
    done
    
    # Restore gsdata.conf if exists
    if [ -f "$BACKUP_GSESSION/WEB-INF/conf/gsdata.conf" ]; then
        log_info "Restoring gsdata.conf..."
        cp -p "$BACKUP_GSESSION/WEB-INF/conf/gsdata.conf" "$GSESSION_DIR/WEB-INF/conf/"
    fi
    
    log_info "Data restoration completed"
    return 0
}

# Verify installation
verify_installation() {
    log_info "Verifying installation..."
    
    local GSESSION_DIR="$TOMCAT_DIR/webapps/gsession"
    
    if [ ! -d "$GSESSION_DIR" ]; then
        log_error "GroupSession directory not found after deployment"
        return 1
    fi
    
    if [ ! -d "$GSESSION_DIR/WEB-INF" ]; then
        log_error "WEB-INF directory not found"
        return 1
    fi
    
    log_info "Installation verification completed"
    log_info "Please verify the installation by accessing:"
    log_info "http://[server]:8080/gsession/"
    
    return 0
}

# Cleanup temporary files
cleanup() {
    if [ -f /tmp/gsupdate_backup_path.txt ]; then
        rm -f /tmp/gsupdate_backup_path.txt
    fi
}

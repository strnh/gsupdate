#!/bin/bash
#
# Common functions for gsupdate scripts
#

log_info() { echo "[INFO]  $*"; }
log_warn() { echo "[WARN]  $*"; }
log_error() { echo "[ERROR] $*" >&2; }

# Check running as root
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
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

# Simple tomcat running check (used by wrappers)
is_tomcat_running() {
    pgrep -f catalina >/dev/null 2>&1
}

# Detect application directory name under webapps (gsession / gs / etc.)
# Sets global APP_NAME (e.g., gsession or gs) and APP_DIR
detect_app_name() {
    local WEBAPP_DIR="$1"  # e.g. /var/lib/tomcat9/webapps
    # If already provided by wrapper, keep it
    if [ -n "${APP_NAME:-}" ]; then
        APP_DIR="$WEBAPP_DIR/$APP_NAME"
        log_info "Using explicit app name: $APP_NAME"
        return 0
    fi

    # Priority checks
    if [ -d "$WEBAPP_DIR/gsession" ]; then
        APP_NAME="gsession"
    elif [ -d "$WEBAPP_DIR/gs" ]; then
        APP_NAME="gs"
    else
        # try to find directories starting with gs or gsession
        local found
        found=$(ls -1 "$WEBAPP_DIR" 2>/dev/null | grep -E '^gs(session)?' | head -n1 || true)
        if [ -n "$found" ]; then
            APP_NAME="$found"
        else
            # fallback
            APP_NAME="gsession"
            log_warn "No existing app directory found. Falling back to default: $APP_NAME"
        fi
    fi

    APP_DIR="$WEBAPP_DIR/$APP_NAME"
    log_info "Detected application name: $APP_NAME -> $APP_DIR"
    return 0
}

# Backup the existing application (uses APP_NAME and BACKUP_DIR)
backup_app() {
    local TOMCAT_DIR="$1"      # e.g. /var/lib/tomcat9
    local BACKUP_DIR="$2"      # e.g. /var/backups/gsession
    local WEBAPP_DIR="$TOMCAT_DIR/webapps"

    detect_app_name "$WEBAPP_DIR"

    mkdir -p "$BACKUP_DIR"
    local TS
    TS=$(date +%Y%m%d_%H%M%S)
    local BACKUP_NAME="${APP_NAME}_backup_${TS}"
    local BACKUP_PATH="$BACKUP_DIR/$BACKUP_NAME"

    if [ -d "$APP_DIR" ]; then
        log_info "Backing up $APP_DIR -> $BACKUP_PATH"
        cp -pr "$APP_DIR" "$BACKUP_PATH"
        echo "$BACKUP_PATH" >/tmp/gsupdate_backup_path.txt
        log_info "Backup completed: $BACKUP_PATH"
        return 0
    else
        log_warn "Application directory not found: $APP_DIR. Skipping full directory backup."
        # still write backup path as empty to indicate no backup dir
        echo "" >/tmp/gsupdate_backup_path.txt
        return 0
    fi
}

# Deploy WAR: remove old WAR and directory for the detected app name, then copy new WAR as APP_NAME.war
deploy_war() {
    local TOMCAT_DIR="$1"
    local GSESSION_WAR="$2"
    local WEBAPP_DIR="$TOMCAT_DIR/webapps"

    detect_app_name "$WEBAPP_DIR"

    # Remove old deployment (both name forms if present)
    local DIR1="$WEBAPP_DIR/$APP_NAME"
    if [ -d "$DIR1" ]; then
        log_info "Removing old deployment directory: $DIR1"
        rm -rf "$DIR1"
    fi

    # Remove old war files with both possible names
    if [ -f "$WEBAPP_DIR/${APP_NAME}.war" ]; then
        log_info "Removing old WAR file: $WEBAPP_DIR/${APP_NAME}.war"
        rm -f "$WEBAPP_DIR/${APP_NAME}.war"
    fi
    # Also handle legacy name gsession.war -> gs.war mapping (if app name different)
    if [ "$APP_NAME" = "gs" ] && [ -f "$WEBAPP_DIR/gsession.war" ]; then
        log_info "Removing legacy WAR file: $WEBAPP_DIR/gsession.war"
        rm -f "$WEBAPP_DIR/gsession.war"
    fi

    # Copy new WAR file as <APP_NAME>.war
    local DEST_WAR="$WEBAPP_DIR/${APP_NAME}.war"
    log_info "Copying new WAR file to $DEST_WAR"
    cp "$GSESSION_WAR" "$DEST_WAR"

    if [ $? -eq 0 ]; then
        log_info "WAR file deployed successfully: $DEST_WAR"
        return 0
    else
        log_error "Failed to deploy WAR file to $DEST_WAR"
        return 1
    fi
}

# Restore data directories from backup (db, file, backup, filekanri, webmail)
restore_data() {
    local TOMCAT_DIR="$1"
    local BACKUP_PATH_FILE="/tmp/gsupdate_backup_path.txt"
    local WEBAPP_DIR="$TOMCAT_DIR/webapps"

    detect_app_name "$WEBAPP_DIR"

    if [ ! -f "$BACKUP_PATH_FILE" ]; then
        log_warn "No backup path found, skipping data restoration"
        return 0
    fi

    local BACKUP_PATH
    BACKUP_PATH=$(cat "$BACKUP_PATH_FILE")
    if [ -z "$BACKUP_PATH" ]; then
        log_warn "Backup path empty, skipping data restoration"
        return 0
    fi

    local BACKUP_APP_DIR="$BACKUP_PATH"
    if [ ! -d "$BACKUP_APP_DIR" ]; then
        log_warn "Backup directory not found: $BACKUP_APP_DIR"
        return 0
    fi

    local TARGET_APP_DIR="$WEBAPP_DIR/$APP_NAME"
    # Wait for WAR extraction
    log_info "Waiting for WAR extraction into $TARGET_APP_DIR ..."
    local WAIT_COUNT=0
    while [ ! -d "$TARGET_APP_DIR/WEB-INF" ] && [ $WAIT_COUNT -lt 60 ]; do
        sleep 2
        WAIT_COUNT=$((WAIT_COUNT + 1))
    done

    if [ ! -d "$TARGET_APP_DIR/WEB-INF" ]; then
        log_error "WAR extraction timeout. WEB-INF directory not found in $TARGET_APP_DIR"
        return 1
    fi

    local DATA_DIRS="db file backup filekanri webmail"
    for DIR in $DATA_DIRS; do
        if [ -d "$TARGET_APP_DIR/WEB-INF/$DIR" ]; then
            log_info "Removing new $DIR directory..."
            rm -rf "$TARGET_APP_DIR/WEB-INF/$DIR"
        fi
    done

    for DIR in $DATA_DIRS; do
        if [ -d "$BACKUP_APP_DIR/WEB-INF/$DIR" ]; then
            log_info "Restoring $DIR directory from backup..."
            cp -pr "$BACKUP_APP_DIR/WEB-INF/$DIR" "$TARGET_APP_DIR/WEB-INF/"
        else
            log_warn "Backup directory $DIR not found in $BACKUP_APP_DIR, skipping..."
        fi
    done

    # Restore gsdata.conf if exists
    if [ -f "$BACKUP_APP_DIR/WEB-INF/conf/gsdata.conf" ]; then
        log_info "Restoring gsdata.conf..."
        cp -p "$BACKUP_APP_DIR/WEB-INF/conf/gsdata.conf" "$TARGET_APP_DIR/WEB-INF/conf/"
    fi

    log_info "Data restoration completed"
    return 0
}

# Verify installation
verify_installation() {
    local TOMCAT_DIR="$1"
    local WEBAPP_DIR="$TOMCAT_DIR/webapps"

    detect_app_name "$WEBAPP_DIR"

    local TARGET_APP_DIR="$WEBAPP_DIR/$APP_NAME"

    if [ ! -d "$TARGET_APP_DIR" ]; then
        log_error "Application directory not found after deployment: $TARGET_APP_DIR"
        return 1
    fi

    if [ ! -d "$TARGET_APP_DIR/WEB-INF" ]; then
        log_warn "WEB-INF not found in $TARGET_APP_DIR; WAR may not have been extracted yet"
    fi

    log_info "Verification looks OK for $TARGET_APP_DIR"
    return 0
}

# Cleanup temporary files
cleanup() {
    if [ -f /tmp/gsupdate_backup_path.txt ]; then
        rm -f /tmp/gsupdate_backup_path.txt
    fi
}

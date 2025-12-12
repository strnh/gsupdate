# Example Usage Guide

This document provides practical examples for using the GroupSession update scripts.

## Quick Start Examples

### Ubuntu/Debian Example

Assume you have:
- Downloaded `gsession.war` to `/home/user/downloads/gsession.war`
- Tomcat installed at default location `/var/lib/tomcat9`

```bash
# Step 1: Copy the WAR file to a working directory
sudo cp /home/user/downloads/gsession.war /tmp/

# Step 2: Run the update script
sudo ./gsupdate-ubuntu.sh /tmp/gsession.war

# Step 3: Verify the update
# Open browser to http://localhost:8080/gsession/
# Check version number after login
```

### Fedora/RHEL Example

```bash
# With default paths
sudo ./gsupdate-fedora.sh /tmp/gsession.war

# With custom Tomcat location
sudo ./gsupdate-fedora.sh /tmp/gsession.war /opt/tomcat

# With custom backup location
sudo ./gsupdate-fedora.sh /tmp/gsession.war /opt/tomcat /mnt/backups/gsession
```

### FreeBSD Example

```bash
# Check Tomcat installation location first
ls -d /usr/local/apache-tomcat*

# Run update with detected path
sudo ./gsupdate-freebsd.sh /tmp/gsession.war /usr/local/apache-tomcat-9.0.65
```

## Pre-Update Checklist

Before running the update script:

1. ✅ Download the latest GroupSession WAR file
2. ✅ Verify sufficient disk space (at least 2x current installation size)
3. ✅ Note current GroupSession version
4. ✅ Inform users about maintenance window
5. ✅ Create manual backup (optional but recommended)
6. ✅ Review release notes for breaking changes

## Step-by-Step Manual Verification

### 1. Check Current Version

```bash
# Before update - check logs
sudo tail -100 /var/lib/tomcat9/logs/catalina.out | grep -i version
```

### 2. Run Update

```bash
sudo ./gsupdate-ubuntu.sh /tmp/gsession.war
```

**Expected output:**
```
[INFO] ==========================================
[INFO] GroupSession Update Script for Ubuntu
[INFO] ==========================================
[INFO] Configuration:
[INFO]   Tomcat Directory: /var/lib/tomcat9
[INFO]   Backup Directory: /var/backups/gsession
[INFO]   WAR File: /tmp/gsession.war
[INFO] 
[INFO] Step 1: Stopping Tomcat...
[INFO] Stopping Tomcat service...
[INFO] Tomcat stopped successfully
[INFO] Step 2: Backing up existing data...
...
[INFO] ==========================================
[INFO] GroupSession update completed successfully!
[INFO] ==========================================
```

### 3. Verify Update

```bash
# Check if Tomcat is running
sudo systemctl status tomcat9

# Check GroupSession logs
sudo tail -f /var/lib/tomcat9/logs/catalina.out

# Access via browser
# http://localhost:8080/gsession/
```

## Rollback Procedure

If the update fails or causes issues:

```bash
# 1. Stop Tomcat
sudo systemctl stop tomcat9

# 2. Remove updated deployment
sudo rm -rf /var/lib/tomcat9/webapps/gsession*

# 3. Restore from backup (check backup path from script output)
BACKUP_PATH="/var/backups/gsession/gsession_backup_20231212_123456"
sudo cp -pr "$BACKUP_PATH/gsession" /var/lib/tomcat9/webapps/

# 4. Start Tomcat
sudo systemctl start tomcat9

# 5. Verify restoration
# Access http://localhost:8080/gsession/
```

## Troubleshooting Common Issues

### Issue 1: Permission Denied

```bash
# Ensure running as root/sudo
sudo su -
./gsupdate-ubuntu.sh /tmp/gsession.war
```

### Issue 2: Tomcat Won't Stop

```bash
# Check running processes
ps aux | grep tomcat

# Force kill if necessary
sudo pkill -9 -f catalina

# Then retry update
sudo ./gsupdate-ubuntu.sh /tmp/gsession.war
```

### Issue 3: Disk Space Issues

```bash
# Check available space
df -h

# Clean up old backups if needed
sudo du -sh /var/backups/gsession/*
sudo rm -rf /var/backups/gsession/gsession_backup_OLD_DATE
```

### Issue 4: Port 8080 Already in Use

```bash
# Check what's using port 8080
sudo netstat -tulpn | grep 8080
sudo lsof -i :8080

# Kill the process or change Tomcat port in server.xml
```

## Advanced Usage

### Custom Tomcat Configuration

If using non-standard Tomcat setup:

```bash
# Find your Tomcat base directory
sudo find / -name catalina.sh 2>/dev/null

# Use the parent directory of bin/catalina.sh
TOMCAT_BASE="/path/to/tomcat"
sudo ./gsupdate-ubuntu.sh /tmp/gsession.war "$TOMCAT_BASE"
```

### Automated Backups Before Update

```bash
#!/bin/bash
# Pre-update backup script

BACKUP_ROOT="/mnt/external/gsession-backups"
DATE=$(date +%Y%m%d)
BACKUP_DIR="$BACKUP_ROOT/manual_backup_$DATE"

mkdir -p "$BACKUP_DIR"
cp -pr /var/lib/tomcat9/webapps/gsession "$BACKUP_DIR/"

echo "Manual backup created: $BACKUP_DIR"
```

### Monitoring Update Progress

```bash
# In one terminal, run the update
sudo ./gsupdate-ubuntu.sh /tmp/gsession.war

# In another terminal, monitor logs
sudo tail -f /var/lib/tomcat9/logs/catalina.out
```

## Production Environment Best Practices

1. **Test in staging first**: Always test updates on a staging environment
2. **Maintenance window**: Schedule updates during low-usage periods
3. **User notification**: Inform users about expected downtime
4. **Monitoring**: Have monitoring tools ready to detect issues
5. **Rollback plan**: Always have a tested rollback procedure ready
6. **Documentation**: Document any customizations or special configurations

## Scheduled Updates with Cron

**Not recommended for production**, but for development/testing:

```bash
# Edit crontab
sudo crontab -e

# Add scheduled update (example: every Saturday at 2 AM)
0 2 * * 6 /path/to/gsupdate-ubuntu.sh /path/to/gsession.war >> /var/log/gsupdate.log 2>&1
```

## Multi-Server Updates

For environments with multiple GroupSession servers:

```bash
#!/bin/bash
# update-all-servers.sh

SERVERS="server1 server2 server3"
WAR_FILE="/shared/gsession.war"

for server in $SERVERS; do
    echo "Updating $server..."
    ssh root@$server "cd /tmp && wget http://fileserver/gsession.war"
    ssh root@$server "/opt/gsupdate/gsupdate-ubuntu.sh /tmp/gsession.war"
    echo "$server update completed"
done
```

## Health Check Script

```bash
#!/bin/bash
# check-gsession-health.sh

URL="http://localhost:8080/gsession/"
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "$URL")

if [ "$RESPONSE" = "200" ]; then
    echo "✓ GroupSession is healthy"
    exit 0
else
    echo "✗ GroupSession returned HTTP $RESPONSE"
    exit 1
fi
```

## Getting Help

If you encounter issues:

1. Check the script output for specific error messages
2. Review Tomcat logs: `/var/lib/tomcat9/logs/catalina.out`
3. Verify file permissions and ownership
4. Ensure sufficient disk space
5. Check the official GroupSession documentation
6. Open an issue on GitHub with detailed error information

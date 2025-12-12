# Quick Reference Card

## Basic Usage

```bash
# Ubuntu/Debian
sudo ./gsupdate-ubuntu.sh /path/to/gsession.war

# Fedora/RHEL/CentOS
sudo ./gsupdate-fedora.sh /path/to/gsession.war

# FreeBSD
sudo ./gsupdate-freebsd.sh /path/to/gsession.war
```

## Default Paths

| OS | Tomcat Directory | Backup Directory |
|----|-----------------|------------------|
| Ubuntu/Debian | `/var/lib/tomcat9` | `/var/backups/gsession` |
| Fedora/RHEL | `/usr/share/tomcat` | `/var/backups/gsession` |
| FreeBSD | `/usr/local/apache-tomcat-9.0` | `/var/backups/gsession` |

## Custom Paths

```bash
# Syntax
./gsupdate-<OS>.sh <WAR_FILE> [TOMCAT_DIR] [BACKUP_DIR]

# Examples
./gsupdate-ubuntu.sh /tmp/gsession.war /opt/tomcat /mnt/backup
./gsupdate-fedora.sh /tmp/gsession.war /usr/local/tomcat
./gsupdate-freebsd.sh /tmp/gsession.war /usr/local/apache-tomcat-9.0.65
```

## Update Steps (Automated)

1. ✅ Stop Tomcat service
2. ✅ Backup existing data with timestamp
3. ✅ Deploy new WAR file
4. ✅ Start Tomcat to extract WAR
5. ✅ Stop Tomcat for data restoration
6. ✅ Restore data directories (db, file, backup, filekanri, webmail)
7. ✅ Start Tomcat with updated GroupSession
8. ✅ Verify installation

## Pre-Update Checklist

- [ ] Download new GroupSession WAR file
- [ ] Verify disk space (minimum 2x current size)
- [ ] Schedule maintenance window
- [ ] Notify users
- [ ] Note current version
- [ ] Review release notes

## Verification Steps

```bash
# 1. Check Tomcat is running
systemctl status tomcat9  # Ubuntu/Fedora
service tomcat9 status    # FreeBSD

# 2. Access GroupSession
# Open: http://[server]:8080/gsession/

# 3. Login and verify version
# Check version at bottom of admin menu
```

## Common Errors

| Error | Solution |
|-------|----------|
| Permission denied | Run with sudo/root |
| Tomcat won't stop | `sudo pkill -9 -f catalina` |
| Port 8080 in use | Check: `sudo lsof -i :8080` |
| Disk space full | Clean old backups, check `df -h` |
| WAR extraction timeout | Check logs: `tail -f $TOMCAT/logs/catalina.out` |

## Rollback

```bash
# 1. Stop Tomcat
sudo systemctl stop tomcat9

# 2. Remove updated deployment
sudo rm -rf $TOMCAT_DIR/webapps/gsession*

# 3. Restore from backup (use path from script output)
sudo cp -pr /var/backups/gsession/gsession_backup_*/gsession $TOMCAT_DIR/webapps/

# 4. Start Tomcat
sudo systemctl start tomcat9
```

## Getting Help

- Documentation: [README.md](README.md)
- Examples: [EXAMPLES.md](EXAMPLES.md)
- Official Guide: https://groupsession.jp/support/setup_06.html
- GitHub Issues: https://github.com/strnh/gsupdate/issues

## Important Notes

⚠️ **Always run as root/sudo**
⚠️ **Test in staging environment first**
⚠️ **Backups are automatic but manual backup recommended**
⚠️ **Major version upgrades may need data conversion**
⚠️ **Allow adequate time for large databases**

## Script Output Colors

- 🟢 **GREEN** = Info messages
- 🟡 **YELLOW** = Warning messages
- 🔴 **RED** = Error messages

## Version Info

Version: 1.0.0
Date: 2025-12-12
Supported OS: Ubuntu, Debian, Fedora, RHEL, CentOS, FreeBSD

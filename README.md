# gsupdate
Tool for GroupSession Version Update

## Overview

This repository provides automated shell scripts for updating GroupSession installations on various operating systems. The scripts automate the official update procedure documented at [GroupSession Update Guide](https://groupsession.jp/support/setup_06.html).

## Supported Operating Systems

- **Linux (Ubuntu/Debian)**: `gsupdate-ubuntu.sh`
- **Linux (Fedora/RHEL/CentOS)**: `gsupdate-fedora.sh`
- **FreeBSD**: `gsupdate-freebsd.sh`

## Features

- Automated backup of existing GroupSession data
- Safe deployment of new GroupSession WAR files
- Automatic service management (stop/start Tomcat)
- Data directory restoration (db, file, backup, filekanri, webmail)
- Configuration preservation (gsdata.conf)
- Comprehensive error checking and logging
- Color-coded console output for easy monitoring

## Prerequisites

- Root or sudo access
- Apache Tomcat installed and configured
- GroupSession currently installed (for updates)
- New GroupSession WAR file downloaded

## Installation

1. Clone this repository:
```bash
git clone https://github.com/strnh/gsupdate.git
cd gsupdate
```

2. Make scripts executable (if not already):
```bash
chmod +x gsupdate-*.sh
```

## Usage

### Ubuntu/Debian

```bash
sudo ./gsupdate-ubuntu.sh <path/to/gsession.war> [tomcat_dir] [backup_dir] [app_name]
```

**Default values:**
- `tomcat_dir`: `/var/lib/tomcat9`
- `backup_dir`: `/var/backups/gsession`
- `app_name`: Auto-detected (gsession, gs, or any gs* directory)

**Examples:**
```bash
# Using default directories
sudo ./gsupdate-ubuntu.sh /tmp/gsession.war

# Specifying custom Tomcat directory
sudo ./gsupdate-ubuntu.sh /tmp/gsession.war /opt/tomcat9

# Specifying both custom directories
sudo ./gsupdate-ubuntu.sh /tmp/gsession.war /opt/tomcat9 /backup/gsession

# Specifying custom app name (e.g., "gs" instead of "gsession")
sudo ./gsupdate-ubuntu.sh /tmp/gsession.war /var/lib/tomcat9 /var/backups/gsession gs
```

### Fedora/RHEL/CentOS

```bash
sudo ./gsupdate-fedora.sh <path/to/gsession.war> [tomcat_dir] [backup_dir] [app_name]
```

**Default values:**
- `tomcat_dir`: `/usr/share/tomcat`
- `backup_dir`: `/var/backups/gsession`
- `app_name`: Auto-detected (gsession, gs, or any gs* directory)

**Examples:**
```bash
# Using default directories
sudo ./gsupdate-fedora.sh /tmp/gsession.war

# Specifying custom directories
sudo ./gsupdate-fedora.sh /tmp/gsession.war /usr/local/tomcat /backup/gsession

# Specifying custom app name
sudo ./gsupdate-fedora.sh /tmp/gsession.war /usr/share/tomcat /var/backups/gsession gs
```

### FreeBSD

```bash
sudo ./gsupdate-freebsd.sh <path/to/gsession.war> [tomcat_dir] [backup_dir] [app_name]
```

**Default values:**
- `tomcat_dir`: `/usr/local/apache-tomcat-9.0`
- `backup_dir`: `/var/backups/gsession`
- `app_name`: Auto-detected (gsession, gs, or any gs* directory)

**Examples:**
```bash
# Using default directories
sudo ./gsupdate-freebsd.sh /tmp/gsession.war

# Specifying custom directories
sudo ./gsupdate-freebsd.sh /tmp/gsession.war /usr/local/tomcat /backup/gsession

# Specifying custom app name
sudo ./gsupdate-freebsd.sh /tmp/gsession.war /usr/local/apache-tomcat-9.0 /var/backups/gsession gs
```

## Update Procedure

The scripts follow the official GroupSession update procedure:

1. **Stop Tomcat** - Safely stops the Tomcat service
2. **Backup Data** - Creates timestamped backup of the entire gsession directory
3. **Deploy WAR** - Removes old deployment and copies new WAR file
4. **Extract WAR** - Starts Tomcat to extract the new WAR file
5. **Restore Data** - Copies data directories from backup (db, file, backup, filekanri, webmail)
6. **Restore Configuration** - Restores gsdata.conf if present
7. **Start Tomcat** - Starts Tomcat with updated GroupSession
8. **Verify** - Basic verification of deployment

## Backup Information

- Backups are created with timestamps: `gsession_backup_YYYYMMDD_HHMMSS`
- Backup location is displayed at the end of the update process
- The entire gsession directory is backed up before any changes
- To rollback, manually restore from the backup directory

## Verification

After the script completes successfully:

1. Access GroupSession: `http://[server]:8080/gsession/`
2. Log in with admin credentials
3. Verify the version number at the bottom of the admin menu
4. Test basic functionality

## Troubleshooting

### Tomcat won't stop
- Check if Tomcat is running: `ps aux | grep tomcat`
- Manually kill process: `sudo pkill -9 -f catalina`
- Check for port conflicts: `netstat -tulpn | grep 8080`

### WAR extraction timeout
- Check Tomcat logs: `tail -f $TOMCAT_DIR/logs/catalina.out`
- Verify disk space: `df -h`
- Check permissions on webapps directory

### Data restoration fails
- Verify backup directory exists and is accessible
- Check file permissions
- Review script output for specific error messages

### Service management issues
- Verify systemd/service scripts: `systemctl status tomcat`
- Check service names: `systemctl list-units | grep tomcat`
- Ensure proper permissions for service control

## Architecture

### Script Structure

- **gsupdate-common.sh**: Common functions shared by all OS-specific scripts
  - Logging utilities (color-coded output)
  - Parameter validation
  - Backup/restore operations
  - Process management
  - Verification functions

- **gsupdate-ubuntu.sh**: Ubuntu/Debian specific implementation
  - Systemd service management
  - Ubuntu-specific Tomcat paths

- **gsupdate-fedora.sh**: Fedora/RHEL/CentOS specific implementation
  - Systemd service management
  - RHEL-specific Tomcat paths

- **gsupdate-freebsd.sh**: FreeBSD specific implementation
  - rc.d service management
  - FreeBSD-specific Tomcat paths

## Important Notes

⚠️ **Always ensure you have a valid backup before running the update!**

- The script creates automatic backups, but manual backups are recommended for critical systems
- Test the update procedure on a non-production system first
- Major version upgrades (e.g., v4.x to v5.x) may require data conversion
- Large databases may take considerable time to process
- Ensure adequate disk space for backups and new deployment

## Requirements

- Bash 4.0+ (Linux scripts) or POSIX-compliant shell (FreeBSD)
- Standard Unix utilities: sed, awk, grep, cp, rm, mkdir
- Root/sudo privileges
- Apache Tomcat installed and configured
- Existing GroupSession installation (for updates)

## Contributing

Contributions are welcome! Please submit pull requests or open issues for:
- Bug fixes
- Support for additional operating systems
- Feature enhancements
- Documentation improvements

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## References

- [Official GroupSession Update Guide](https://groupsession.jp/support/setup_06.html)
- [GroupSession Official Website](https://groupsession.jp/)

## Author

Created for automated GroupSession updates across multiple platforms.

## Changelog

### Version 1.0.0 (2025-12-12)
- Initial release
- Support for Ubuntu/Debian, Fedora/RHEL/CentOS, and FreeBSD
- Automated backup and restore functionality
- Color-coded logging
- Comprehensive error handling 

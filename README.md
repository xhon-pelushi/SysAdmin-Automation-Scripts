# System Administration & Automation Scripts

Automation scripts for Windows Server administration, Active Directory management, and system monitoring.

## Overview

This repository contains PowerShell scripts for:
- Active Directory account management
- Automated patching and log rotation
- Windows Server hardening
- System monitoring and health checks
- Task Scheduler automation

## Scripts

### Active Directory
- **New-ADUser.ps1**: Automated user account creation
- **Reset-ADPassword.ps1**: Bulk password reset utility
- **Cleanup-ADOU.ps1**: Organizational Unit cleanup and maintenance

### System Administration
- **Update-WindowsServer.ps1**: Automated patching with Task Scheduler
- **Rotate-Logs.ps1**: Log rotation and cleanup
- **Harden-WindowsServer.ps1**: Security hardening templates

### Monitoring
- **Monitor-SystemHealth.ps1**: System health monitoring
- **Check-DiskSpace.ps1**: Disk space monitoring and alerts

## Requirements

- Windows Server 2019+
- Active Directory Domain Services
- PowerShell 5.1+
- Appropriate administrative privileges

## Usage

All scripts include detailed help documentation. Use `Get-Help` to view usage instructions:

```powershell
Get-Help .\Scripts\New-ADUser.ps1 -Full
```

## License

MIT License











































# Windows Server Update Script
# Automated patching with Task Scheduler integration

param(
    [Parameter(Mandatory=$false)]
    [switch]$InstallUpdates,
    
    [Parameter(Mandatory=$false)]
    [switch]$CheckOnly,
    
    [Parameter(Mandatory=$false)]
    [switch]$CreateScheduledTask,
    
    [Parameter(Mandatory=$false)]
    [string]$LogPath = "C:\Logs\WindowsUpdate"
)

# Create log directory
if (-not (Test-Path $LogPath)) {
    New-Item -ItemType Directory -Path $LogPath -Force | Out-Null
}

$LogFile = Join-Path $LogPath "WindowsUpdate-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

function Write-Log {
    param([string]$Message)
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogMessage = "[$Timestamp] $Message"
    Write-Host $LogMessage
    Add-Content -Path $LogFile -Value $LogMessage
}

Write-Log "Windows Update Script Started"

# Check for Windows Update module
if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
    Write-Log "Installing PSWindowsUpdate module..."
    Install-Module -Name PSWindowsUpdate -Force -AllowClobber
}

Import-Module PSWindowsUpdate -ErrorAction Stop

# Get available updates
Write-Log "Checking for available updates..."
$AvailableUpdates = Get-WindowsUpdate

if ($AvailableUpdates.Count -eq 0) {
    Write-Log "No updates available. System is up to date."
    exit 0
}

Write-Log "Found $($AvailableUpdates.Count) available updates"

# Display update list
$AvailableUpdates | ForEach-Object {
    Write-Log "Update: $($_.Title) - Size: $([math]::Round($_.Size / 1MB, 2)) MB"
}

if ($CheckOnly) {
    Write-Log "Check-only mode. Exiting without installing updates."
    exit 0
}

if ($InstallUpdates) {
    Write-Log "Installing updates..."
    
    try {
        # Install updates with auto-reboot if required
        $InstallResult = Install-WindowsUpdate -AcceptAll -AutoReboot
        
        if ($InstallResult) {
            Write-Log "Updates installed successfully. Reboot may be required."
            
            # Check if reboot is required
            if (Get-WURebootStatus) {
                Write-Log "System reboot is required. Scheduling reboot in 30 minutes..."
                shutdown /r /t 1800 /c "Windows Update completed. System will reboot in 30 minutes."
            }
        } else {
            Write-Log "Update installation completed with warnings."
        }
    } catch {
        Write-Log "Error installing updates: $_"
        exit 1
    }
}

# Create scheduled task for monthly updates
if ($CreateScheduledTask) {
    Write-Log "Creating scheduled task for monthly updates..."
    
    $TaskName = "MonthlyWindowsUpdate"
    $ScriptPath = $MyInvocation.MyCommand.Path
    $TaskAction = New-ScheduledTaskAction -Execute "PowerShell.exe" `
        -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`" -InstallUpdates"
    
    $TaskTrigger = New-ScheduledTaskTrigger -Monthly -DaysOfMonth 1 -At 2am
    
    $TaskPrincipal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    
    $TaskSettings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
        -StartWhenAvailable -RunOnlyIfNetworkAvailable
    
    Register-ScheduledTask -TaskName $TaskName `
        -Action $TaskAction `
        -Trigger $TaskTrigger `
        -Principal $TaskPrincipal `
        -Settings $TaskSettings `
        -Description "Monthly Windows Server updates" `
        -Force
    
    Write-Log "Scheduled task created: $TaskName"
}

Write-Log "Windows Update Script Completed"







































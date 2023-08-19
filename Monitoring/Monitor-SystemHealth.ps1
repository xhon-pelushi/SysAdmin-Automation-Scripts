# System Health Monitoring Script
# Monitors system resources and generates alerts

param(
    [Parameter(Mandatory=$false)]
    [int]$CPUThreshold = 80,
    
    [Parameter(Mandatory=$false)]
    [int]$MemoryThreshold = 85,
    
    [Parameter(Mandatory=$false)]
    [int]$DiskThreshold = 90,
    
    [Parameter(Mandatory=$false)]
    [string]$AlertEmail,
    
    [Parameter(Mandatory=$false)]
    [string]$LogPath = "C:\Logs\SystemHealth"
)

if (-not (Test-Path $LogPath)) {
    New-Item -ItemType Directory -Path $LogPath -Force | Out-Null
}

$LogFile = Join-Path $LogPath "system-health-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
$Alerts = @()

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogMessage = "[$Timestamp] [$Level] $Message"
    Write-Host $LogMessage
    Add-Content -Path $LogFile -Value $LogMessage
}

function Send-Alert {
    param([string]$Subject, [string]$Body)
    
    if ($AlertEmail) {
        try {
            Send-MailMessage -To $AlertEmail `
                -Subject $Subject `
                -Body $Body `
                -SmtpServer "smtp.lab.local" `
                -From "monitoring@lab.local"
            Write-Log "Alert email sent to $AlertEmail" "INFO"
        } catch {
            Write-Log "Failed to send alert email: $_" "ERROR"
        }
    }
}

Write-Log "System Health Monitoring Started"

# CPU Monitoring
$CPU = Get-Counter '\Processor(_Total)\% Processor Time' | 
    Select-Object -ExpandProperty CounterSamples | 
    Select-Object -ExpandProperty CookedValue

$CPU = [math]::Round($CPU, 2)
Write-Log "CPU Usage: $CPU%"

if ($CPU -gt $CPUThreshold) {
    $Alert = "CPU usage is $CPU% (Threshold: $CPUThreshold%)"
    Write-Log $Alert "WARNING"
    $Alerts += $Alert
    Send-Alert "High CPU Usage Alert" $Alert
}

# Memory Monitoring
$Memory = Get-CimInstance Win32_OperatingSystem
$MemoryUsed = [math]::Round((($Memory.TotalVisibleMemorySize - $Memory.FreePhysicalMemory) / $Memory.TotalVisibleMemorySize) * 100, 2)
Write-Log "Memory Usage: $MemoryUsed%"

if ($MemoryUsed -gt $MemoryThreshold) {
    $Alert = "Memory usage is $MemoryUsed% (Threshold: $MemoryThreshold%)"
    Write-Log $Alert "WARNING"
    $Alerts += $Alert
    Send-Alert "High Memory Usage Alert" $Alert
}

# Disk Monitoring
$Disks = Get-CimInstance Win32_LogicalDisk | Where-Object { $_.DriveType -eq 3 }

foreach ($Disk in $Disks) {
    $DiskUsed = [math]::Round((($Disk.Size - $Disk.FreeSpace) / $Disk.Size) * 100, 2)
    Write-Log "Disk $($Disk.DeviceID) Usage: $DiskUsed% (Free: $([math]::Round($Disk.FreeSpace / 1GB, 2)) GB)"
    
    if ($DiskUsed -gt $DiskThreshold) {
        $Alert = "Disk $($Disk.DeviceID) usage is $DiskUsed% (Threshold: $DiskThreshold%)"
        Write-Log $Alert "WARNING"
        $Alerts += $Alert
        Send-Alert "High Disk Usage Alert" $Alert
    }
}

# Service Status
$CriticalServices = @("DNS", "DHCP", "ADWS", "NTDS", "Netlogon")
$StoppedServices = @()

foreach ($Service in $CriticalServices) {
    $svc = Get-Service -Name $Service -ErrorAction SilentlyContinue
    if ($svc) {
        if ($svc.Status -ne "Running") {
            $StoppedServices += $Service
            Write-Log "Critical service $Service is not running (Status: $($svc.Status))" "WARNING"
        } else {
            Write-Log "Service $Service is running" "INFO"
        }
    }
}

if ($StoppedServices.Count -gt 0) {
    $Alert = "Critical services stopped: $($StoppedServices -join ', ')"
    $Alerts += $Alert
    Send-Alert "Critical Service Alert" $Alert
}

# Summary
if ($Alerts.Count -eq 0) {
    Write-Log "System health check completed. All systems normal." "INFO"
} else {
    Write-Log "System health check completed with $($Alerts.Count) alert(s)" "WARNING"
}

Write-Log "System Health Monitoring Completed"













































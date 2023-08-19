# Log Rotation Script
# Automates log file rotation and cleanup

param(
    [Parameter(Mandatory=$true)]
    [string]$LogDirectory,
    
    [Parameter(Mandatory=$false)]
    [int]$RetentionDays = 30,
    
    [Parameter(Mandatory=$false)]
    [int]$MaxLogSizeMB = 100,
    
    [Parameter(Mandatory=$false)]
    [switch]$CompressOldLogs,
    
    [Parameter(Mandatory=$false)]
    [switch]$WhatIf
)

$LogFile = "log-rotation-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

function Write-Log {
    param([string]$Message)
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogMessage = "[$Timestamp] $Message"
    Write-Host $LogMessage
    Add-Content -Path $LogFile -Value $LogMessage
}

Write-Log "Log Rotation Script Started"
Write-Log "Target Directory: $LogDirectory"
Write-Log "Retention Period: $RetentionDays days"
Write-Log "Max Log Size: $MaxLogSizeMB MB"

if (-not (Test-Path $LogDirectory)) {
    Write-Log "ERROR: Log directory does not exist: $LogDirectory"
    exit 1
}

# Get all log files
$LogFiles = Get-ChildItem -Path $LogDirectory -Filter "*.log" -File -Recurse

$TotalSize = ($LogFiles | Measure-Object -Property Length -Sum).Sum / 1MB
Write-Log "Total log files found: $($LogFiles.Count) ($([math]::Round($TotalSize, 2)) MB)"

# Rotate large log files
$LargeLogs = $LogFiles | Where-Object { $_.Length / 1MB -gt $MaxLogSizeMB }

foreach ($Log in $LargeLogs) {
    $RotatedName = "$($Log.BaseName)-$(Get-Date -Format 'yyyyMMdd-HHmmss')$($Log.Extension)"
    $RotatedPath = Join-Path $Log.DirectoryName $RotatedName
    
    Write-Log "Rotating large log: $($Log.Name) -> $RotatedName"
    
    if (-not $WhatIf) {
        Move-Item -Path $Log.FullName -Destination $RotatedPath -Force
    }
}

# Delete old log files
$CutoffDate = (Get-Date).AddDays(-$RetentionDays)
$OldLogs = $LogFiles | Where-Object { $_.LastWriteTime -lt $CutoffDate }

Write-Log "Found $($OldLogs.Count) log files older than $RetentionDays days"

foreach ($Log in $OldLogs) {
    Write-Log "Deleting old log: $($Log.Name) (Last modified: $($Log.LastWriteTime))"
    
    if (-not $WhatIf) {
        Remove-Item -Path $Log.FullName -Force
    }
}

# Compress old logs if requested
if ($CompressOldLogs) {
    $LogsToCompress = $LogFiles | Where-Object { 
        $_.LastWriteTime -lt (Get-Date).AddDays(-7) -and 
        $_.Extension -eq ".log" 
    }
    
    foreach ($Log in $LogsToCompress) {
        $ZipPath = $Log.FullName + ".zip"
        Write-Log "Compressing log: $($Log.Name)"
        
        if (-not $WhatIf) {
            Compress-Archive -Path $Log.FullName -DestinationPath $ZipPath -Force
            Remove-Item -Path $Log.FullName -Force
        }
    }
}

if ($WhatIf) {
    Write-Log "WhatIf mode: No changes were made"
}

Write-Log "Log Rotation Script Completed"
















































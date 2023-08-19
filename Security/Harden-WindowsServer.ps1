# Windows Server Hardening Script
# Applies security best practices and hardening configurations

param(
    [Parameter(Mandatory=$false)]
    [switch]$ApplySecurityPolicies,
    
    [Parameter(Mandatory=$false)]
    [switch]$ConfigureFirewall,
    
    [Parameter(Mandatory=$false)]
    [switch]$EnableAuditing,
    
    [Parameter(Mandatory=$false)]
    [switch]$WhatIf
)

$LogFile = "server-hardening-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

function Write-Log {
    param([string]$Message)
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogMessage = "[$Timestamp] $Message"
    Write-Host $LogMessage
    Add-Content -Path $LogFile -Value $LogMessage
}

Write-Log "Windows Server Hardening Script Started"

# Security Policies
if ($ApplySecurityPolicies) {
    Write-Log "Applying security policies..."
    
    # Password Policy
    if (-not $WhatIf) {
        net accounts /minpwlen:14
        net accounts /maxpwage:90
        net accounts /minpwage:1
        net accounts /uniquepw:12
        
        Write-Log "Password policy configured: Min 14 chars, Max 90 days, History 12"
    }
    
    # Account Lockout Policy
    if (-not $WhatIf) {
        net accounts /lockoutduration:30
        net accounts /lockoutthreshold:5
        net accounts /lockoutwindow:15
        
        Write-Log "Account lockout policy configured: 5 attempts, 30 min lockout"
    }
    
    # Disable unnecessary services
    $ServicesToDisable = @(
        "TlntSvr",  # Telnet
        "W3SVC",    # IIS (if not needed)
        "RemoteRegistry"
    )
    
    foreach ($Service in $ServicesToDisable) {
        $svc = Get-Service -Name $Service -ErrorAction SilentlyContinue
        if ($svc) {
            Write-Log "Disabling service: $Service"
            if (-not $WhatIf) {
                Stop-Service -Name $Service -Force
                Set-Service -Name $Service -StartupType Disabled
            }
        }
    }
}

# Firewall Configuration
if ($ConfigureFirewall) {
    Write-Log "Configuring Windows Firewall..."
    
    if (-not $WhatIf) {
        # Enable firewall for all profiles
        Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled True
        
        # Block inbound by default
        Set-NetFirewallProfile -Profile Domain,Public,Private -DefaultInboundAction Block
        
        # Allow outbound by default
        Set-NetFirewallProfile -Profile Domain,Public,Private -DefaultOutboundAction Allow
        
        # Allow essential services
        $Rules = @(
            @{Name="DNS-TCP"; Direction="Inbound"; Protocol="TCP"; LocalPort=53},
            @{Name="DNS-UDP"; Direction="Inbound"; Protocol="UDP"; LocalPort=53},
            @{Name="RDP"; Direction="Inbound"; Protocol="TCP"; LocalPort=3389},
            @{Name="WinRM-HTTP"; Direction="Inbound"; Protocol="TCP"; LocalPort=5985}
        )
        
        foreach ($Rule in $Rules) {
            New-NetFirewallRule -DisplayName $Rule.Name `
                -Direction $Rule.Direction `
                -Protocol $Rule.Protocol `
                -LocalPort $Rule.LocalPort `
                -Action Allow `
                -ErrorAction SilentlyContinue
        }
        
        Write-Log "Firewall configured with essential rules"
    }
}

# Enable Auditing
if ($EnableAuditing) {
    Write-Log "Enabling security auditing..."
    
    if (-not $WhatIf) {
        # Audit Policy
        auditpol /set /category:"Account Logon" /success:enable /failure:enable
        auditpol /set /category:"Account Management" /success:enable /failure:enable
        auditpol /set /category:"Logon/Logoff" /success:enable /failure:enable
        auditpol /set /category:"Policy Change" /success:enable /failure:enable
        auditpol /set /category:"Privilege Use" /success:enable /failure:enable
        auditpol /set /category:"System" /success:enable /failure:enable
        
        Write-Log "Security auditing enabled for all categories"
    }
}

# Registry Hardening
Write-Log "Applying registry hardening settings..."

$RegistrySettings = @{
    "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\ClearPageFileAtShutdown" = @{
        Value = 1
        Type = "DWord"
    }
    "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters\RequireSecuritySignature" = @{
        Value = 1
        Type = "DWord"
    }
    "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters\EnableSecuritySignature" = @{
        Value = 1
        Type = "DWord"
    }
}

foreach ($RegPath in $RegistrySettings.Keys) {
    $Setting = $RegistrySettings[$RegPath]
    Write-Log "Setting registry: $RegPath = $($Setting.Value)"
    
    if (-not $WhatIf) {
        if (-not (Test-Path $RegPath)) {
            New-Item -Path $RegPath -Force | Out-Null
        }
        Set-ItemProperty -Path $RegPath -Name (Split-Path $RegPath -Leaf) -Value $Setting.Value -Type $Setting.Type
    }
}

if ($WhatIf) {
    Write-Log "WhatIf mode: No changes were made"
}

Write-Log "Windows Server Hardening Script Completed"
Write-Log "Review log file: $LogFile"

































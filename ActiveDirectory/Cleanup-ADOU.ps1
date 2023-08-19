# Active Directory OU Cleanup Script
# Identifies and cleans up empty OUs and stale objects

param(
    [Parameter(Mandatory=$false)]
    [string]$SearchBase = (Get-ADDomain).DistinguishedName,
    
    [Parameter(Mandatory=$false)]
    [int]$DaysInactive = 90,
    
    [Parameter(Mandatory=$false)]
    [switch]$WhatIf,
    
    [Parameter(Mandatory=$false)]
    [string]$ReportPath = "AD-Cleanup-Report-$(Get-Date -Format 'yyyyMMdd-HHmmss').html"
)

Import-Module ActiveDirectory -ErrorAction Stop

# HTML report header
function Initialize-HTMLReport {
    $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>Active Directory Cleanup Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        table { border-collapse: collapse; width: 100%; margin-top: 20px; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #4CAF50; color: white; }
        tr:nth-child(even) { background-color: #f2f2f2; }
        .warning { color: orange; }
        .error { color: red; }
        .success { color: green; }
    </style>
</head>
<body>
    <h1>Active Directory Cleanup Report</h1>
    <p>Generated: $(Get-Date)</p>
    <p>Search Base: $SearchBase</p>
"@
    return $html
}

$Report = Initialize-HTMLReport
$Report += "<h2>Empty Organizational Units</h2><table><tr><th>OU Name</th><th>Path</th><th>Action</th></tr>"

# Find empty OUs
$EmptyOUs = Get-ADOrganizationalUnit -Filter * -SearchBase $SearchBase | 
    Where-Object {
        $OUChildren = Get-ADObject -Filter * -SearchBase $_.DistinguishedName -SearchScope OneLevel
        $OUChildren.Count -eq 0
    }

foreach ($OU in $EmptyOUs) {
    $Action = if ($WhatIf) { "Would be removed" } else { "Removed" }
    $Report += "<tr><td>$($OU.Name)</td><td>$($OU.DistinguishedName)</td><td class='warning'>$Action</td></tr>"
    
    if (-not $WhatIf) {
        Remove-ADOrganizationalUnit -Identity $OU.DistinguishedName -Confirm:$false
        Write-Host "Removed empty OU: $($OU.Name)" -ForegroundColor Yellow
    }
}

$Report += "</table>"

# Find inactive users
$Report += "<h2>Inactive User Accounts</h2><table><tr><th>Username</th><th>Display Name</th><th>Last Logon</th><th>Days Inactive</th><th>Action</th></tr>"

$InactiveDate = (Get-Date).AddDays(-$DaysInactive)
$InactiveUsers = Get-ADUser -Filter {Enabled -eq $true} -Properties LastLogonDate, DisplayName |
    Where-Object {
        ($_.LastLogonDate -lt $InactiveDate -or $null -eq $_.LastLogonDate) -and
        $_.Name -notlike "*Service*" -and
        $_.Name -notlike "*Admin*"
    }

foreach ($User in $InactiveUsers) {
    $DaysInactive = if ($User.LastLogonDate) {
        ((Get-Date) - $User.LastLogonDate).Days
    } else {
        "Never"
    }
    
    $Action = if ($WhatIf) { "Would be disabled" } else { "Disabled" }
    $Report += "<tr><td>$($User.SamAccountName)</td><td>$($User.DisplayName)</td><td>$($User.LastLogonDate)</td><td>$DaysInactive</td><td class='warning'>$Action</td></tr>"
    
    if (-not $WhatIf) {
        Disable-ADAccount -Identity $User.SamAccountName
        Write-Host "Disabled inactive user: $($User.SamAccountName)" -ForegroundColor Yellow
    }
}

$Report += "</table>"

# Find stale computer accounts
$Report += "<h2>Stale Computer Accounts</h2><table><tr><th>Computer Name</th><th>Last Logon</th><th>Days Inactive</th><th>Action</th></tr>"

$StaleComputers = Get-ADComputer -Filter * -Properties LastLogonDate |
    Where-Object {
        ($_.LastLogonDate -lt $InactiveDate -or $null -eq $_.LastLogonDate)
    }

foreach ($Computer in $StaleComputers) {
    $DaysInactive = if ($Computer.LastLogonDate) {
        ((Get-Date) - $Computer.LastLogonDate).Days
    } else {
        "Never"
    }
    
    $Action = if ($WhatIf) { "Would be removed" } else { "Removed" }
    $Report += "<tr><td>$($Computer.Name)</td><td>$($Computer.LastLogonDate)</td><td>$DaysInactive</td><td class='error'>$Action</td></tr>"
    
    if (-not $WhatIf) {
        Remove-ADComputer -Identity $Computer.DistinguishedName -Confirm:$false
        Write-Host "Removed stale computer: $($Computer.Name)" -ForegroundColor Red
    }
}

$Report += "</table></body></html>"

# Save report
$Report | Out-File -FilePath $ReportPath -Encoding UTF8
Write-Host "`nReport saved to: $ReportPath" -ForegroundColor Green

if ($WhatIf) {
    Write-Host "`nThis was a dry run. Use without -WhatIf to perform actual cleanup." -ForegroundColor Yellow
}






































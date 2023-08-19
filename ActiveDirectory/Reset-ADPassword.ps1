# Bulk Active Directory Password Reset Script
# Resets passwords for multiple users with secure password generation

param(
    [Parameter(Mandatory=$true)]
    [string[]]$Usernames,
    
    [Parameter(Mandatory=$false)]
    [switch]$GeneratePassword,
    
    [Parameter(Mandatory=$false)]
    [securestring]$Password,
    
    [Parameter(Mandatory=$false)]
    [switch]$ForceChangeAtLogon = $true,
    
    [Parameter(Mandatory=$false)]
    [string]$LogFile = "password-reset-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
)

# Import Active Directory module
Import-Module ActiveDirectory -ErrorAction Stop

# Function to generate secure password
function New-SecurePassword {
    param([int]$Length = 12)
    
    $PasswordChars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*"
    $Password = ""
    
    for ($i = 0; $i -lt $Length; $i++) {
        $Password += $PasswordChars[(Get-Random -Maximum $PasswordChars.Length)]
    }
    
    return ConvertTo-SecureString $Password -AsPlainText -Force
}

# Initialize log file
"Password Reset Log - $(Get-Date)" | Out-File -FilePath $LogFile
"=" * 60 | Out-File -FilePath $LogFile -Append

$SuccessCount = 0
$FailureCount = 0

foreach ($Username in $Usernames) {
    try {
        # Get user
        $User = Get-ADUser -Identity $Username -ErrorAction Stop
        
        # Generate or use provided password
        if ($GeneratePassword) {
            $NewPassword = New-SecurePassword -Length 14
            $PlainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
                [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($NewPassword)
            )
        } else {
            if (-not $Password) {
                $Password = Read-Host -AsSecureString "Enter password for $Username"
            }
            $NewPassword = $Password
        }
        
        # Reset password
        Set-ADAccountPassword -Identity $Username -NewPassword $NewPassword -Reset -ErrorAction Stop
        
        # Set change password at logon
        if ($ForceChangeAtLogon) {
            Set-ADUser -Identity $Username -ChangePasswordAtLogon $true
        }
        
        # Unlock account if locked
        Unlock-ADAccount -Identity $Username -ErrorAction SilentlyContinue
        
        $SuccessCount++
        $Message = "SUCCESS: Password reset for $Username ($($User.DisplayName))"
        Write-Host $Message -ForegroundColor Green
        
        if ($GeneratePassword) {
            $Message += " | Generated Password: $PlainPassword"
        }
        
        $Message | Out-File -FilePath $LogFile -Append
        
    } catch {
        $FailureCount++
        $Message = "FAILED: Could not reset password for $Username - $_"
        Write-Host $Message -ForegroundColor Red
        $Message | Out-File -FilePath $LogFile -Append
    }
}

# Summary
$Summary = @"
`nSummary:
Success: $SuccessCount
Failed: $FailureCount
Log file: $LogFile
"@

Write-Host $Summary -ForegroundColor Cyan
$Summary | Out-File -FilePath $LogFile -Append










































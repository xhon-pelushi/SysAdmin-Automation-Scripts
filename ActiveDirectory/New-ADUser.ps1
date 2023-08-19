# Active Directory User Creation Script
# Automates user account creation with proper OU assignment

param(
    [Parameter(Mandatory=$true)]
    [string]$FirstName,
    
    [Parameter(Mandatory=$true)]
    [string]$LastName,
    
    [Parameter(Mandatory=$true)]
    [string]$Username,
    
    [Parameter(Mandatory=$false)]
    [string]$OU = "OU=Users,DC=lab,DC=local",
    
    [Parameter(Mandatory=$false)]
    [string]$Department,
    
    [Parameter(Mandatory=$false)]
    [string]$Title,
    
    [Parameter(Mandatory=$false)]
    [string]$Email,
    
    [Parameter(Mandatory=$false)]
    [securestring]$Password,
    
    [Parameter(Mandatory=$false)]
    [switch]$ChangePasswordAtLogon = $true
)

# Import Active Directory module
Import-Module ActiveDirectory -ErrorAction Stop

# Generate password if not provided
if (-not $Password) {
    $Password = Read-Host -AsSecureString "Enter password for $Username"
}

# Validate OU exists
try {
    $OUExists = Get-ADOrganizationalUnit -Identity $OU -ErrorAction Stop
} catch {
    Write-Error "OU $OU does not exist. Please verify the OU path."
    exit 1
}

# Check if user already exists
$ExistingUser = Get-ADUser -Filter {SamAccountName -eq $Username} -ErrorAction SilentlyContinue
if ($ExistingUser) {
    Write-Warning "User $Username already exists!"
    return $ExistingUser
}

# Create user account
try {
    $NewUser = New-ADUser `
        -SamAccountName $Username `
        -UserPrincipalName "$Username@lab.local" `
        -Name "$FirstName $LastName" `
        -GivenName $FirstName `
        -Surname $LastName `
        -DisplayName "$FirstName $LastName" `
        -Path $OU `
        -AccountPassword $Password `
        -Enabled $true `
        -ChangePasswordAtLogon $ChangePasswordAtLogon `
        -EmailAddress $Email `
        -Department $Department `
        -Title $Title `
        -PassThru
    
    Write-Host "User account created successfully: $Username" -ForegroundColor Green
    
    # Add to default groups
    Add-ADGroupMember -Identity "Domain Users" -Members $NewUser -ErrorAction SilentlyContinue
    
    # Add to department group if specified
    if ($Department) {
        $DeptGroup = "Department-$Department"
        $GroupExists = Get-ADGroup -Filter {Name -eq $DeptGroup} -ErrorAction SilentlyContinue
        if ($GroupExists) {
            Add-ADGroupMember -Identity $DeptGroup -Members $NewUser
            Write-Host "Added user to group: $DeptGroup" -ForegroundColor Green
        }
    }
    
    return $NewUser
    
} catch {
    Write-Error "Failed to create user account: $_"
    exit 1
}












































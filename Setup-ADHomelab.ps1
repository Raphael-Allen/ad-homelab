# ============================================================
# Setup-ADHomelab.ps1
# Active Directory Homelab Setup Script
# Author: Raphael Allen
# Description: Automates the configuration of a Windows Server
#              2022 Domain Controller for a homelab environment.
#              Covers OU structure, bulk user creation, security
#              groups, and domain password policy.
#
# Prerequisites:
#   - Windows Server 2022 with AD DS role installed
#   - Server promoted to Domain Controller (corp.local)
#   - Run as Domain Administrator
#   - PowerShell 5.1 or later
# ============================================================

# ============================================================
# SECTION 1 — Verify Prerequisites
# ============================================================

Write-Host "`n=== Active Directory Homelab Setup ===" -ForegroundColor Cyan
Write-Host "Verifying prerequisites..." -ForegroundColor Yellow

# Check AD DS module is available
if (-not (Get-Module -ListAvailable -Name ActiveDirectory)) {
    Write-Host "ERROR: ActiveDirectory module not found. Ensure AD DS role is installed." -ForegroundColor Red
    exit 1
}

Import-Module ActiveDirectory

# Verify domain is accessible
try {
    $domain = Get-ADDomain
    Write-Host "Domain found: $($domain.DNSRoot)" -ForegroundColor Green
} catch {
    Write-Host "ERROR: Cannot connect to domain. Ensure this server is a Domain Controller." -ForegroundColor Red
    exit 1
}

# ============================================================
# SECTION 2 — Network Configuration
# ============================================================
# NOTE: Run these commands manually before running this script.
# They are included here for documentation purposes.
#
# Rename the server:
#   Rename-Computer -NewName "DC01" -Restart
#
# Set static IP:
#   New-NetIPAddress -InterfaceAlias "Ethernet0" -IPAddress "192.168.106.10" -PrefixLength 24 -DefaultGateway "192.168.106.2"
#   Set-DnsClientServerAddress -InterfaceAlias "Ethernet0" -ServerAddresses "192.168.106.10"
#
# Install AD DS role:
#   Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools
#
# Promote to Domain Controller:
#   Install-ADDSForest -DomainName "corp.local" -DomainNetbiosName "CORP" -InstallDns:$true -Force:$true

# ============================================================
# SECTION 3 — Create OU Structure
# ============================================================

Write-Host "`n--- Creating OU Structure ---" -ForegroundColor Cyan

$ouList = @(
    @{Name="Corp Users";    Path="DC=corp,DC=local"},
    @{Name="Corp Computers"; Path="DC=corp,DC=local"},
    @{Name="Corp Groups";   Path="DC=corp,DC=local"},
    @{Name="IT";            Path="OU=Corp Users,DC=corp,DC=local"},
    @{Name="HR";            Path="OU=Corp Users,DC=corp,DC=local"},
    @{Name="Finance";       Path="OU=Corp Users,DC=corp,DC=local"},
    @{Name="Sales";         Path="OU=Corp Users,DC=corp,DC=local"}
)

foreach ($ou in $ouList) {
    try {
        New-ADOrganizationalUnit -Name $ou.Name -Path $ou.Path -ErrorAction Stop
        Write-Host "Created OU: $($ou.Name)" -ForegroundColor Green
    } catch {
        Write-Host "OU already exists or error: $($ou.Name) — $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# Verify OU structure
Write-Host "`nOU Structure:" -ForegroundColor Cyan
Get-ADOrganizationalUnit -Filter * | Select-Object Name, DistinguishedName | Format-Table -AutoSize

# ============================================================
# SECTION 4 — Bulk Create Users
# ============================================================

Write-Host "`n--- Creating Users ---" -ForegroundColor Cyan

$users = @(
    @{Name="John Smith";    Username="jsmith";    Department="IT";      Title="Systems Engineer"},
    @{Name="Sarah Connor";  Username="sconnor";   Department="IT";      Title="Security Analyst"},
    @{Name="James Wilson";  Username="jwilson";   Department="IT";      Title="Network Engineer"},
    @{Name="Emma Taylor";   Username="etaylor";   Department="HR";      Title="HR Manager"},
    @{Name="Lucy Brown";    Username="lbrown";    Department="HR";      Title="HR Advisor"},
    @{Name="David Clark";   Username="dclark";    Department="Finance"; Title="Finance Manager"},
    @{Name="Sophie Evans";  Username="sevans";    Department="Finance"; Title="Accountant"},
    @{Name="Mark Johnson";  Username="mjohnson";  Department="Sales";   Title="Sales Manager"},
    @{Name="Kate Williams"; Username="kwilliams"; Department="Sales";   Title="Sales Executive"},
    @{Name="Tom Davis";     Username="tdavis";    Department="Sales";   Title="Sales Executive"}
)

# Default password for all users — should be changed on first login in production
$Password = ConvertTo-SecureString "Passw0rd123!" -AsPlainText -Force

foreach ($user in $users) {
    $OU = "OU=$($user.Department),OU=Corp Users,DC=corp,DC=local"
    try {
        New-ADUser `
            -Name $user.Name `
            -SamAccountName $user.Username `
            -UserPrincipalName "$($user.Username)@corp.local" `
            -Department $user.Department `
            -Title $user.Title `
            -Path $OU `
            -AccountPassword $Password `
            -Enabled $true `
            -ErrorAction Stop
        Write-Host "Created user: $($user.Name) in $($user.Department)" -ForegroundColor Green
    } catch {
        Write-Host "Error creating user $($user.Name): $($_.Exception.Message)" -ForegroundColor Red
    }
}

# ============================================================
# SECTION 5 — Create Security Groups and Add Members
# ============================================================

Write-Host "`n--- Creating Security Groups ---" -ForegroundColor Cyan

$groups = @("IT Team", "HR Team", "Finance Team", "Sales Team")

foreach ($group in $groups) {
    try {
        New-ADGroup `
            -Name $group `
            -GroupScope Global `
            -GroupCategory Security `
            -Path "OU=Corp Groups,DC=corp,DC=local" `
            -Description "Security group for $group" `
            -ErrorAction Stop
        Write-Host "Created group: $group" -ForegroundColor Green
    } catch {
        Write-Host "Error creating group $group: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "`n--- Adding Users to Groups ---" -ForegroundColor Cyan

$groupMemberships = @(
    @{Group="IT Team";      Members=@("jsmith","sconnor","jwilson")},
    @{Group="HR Team";      Members=@("etaylor","lbrown")},
    @{Group="Finance Team"; Members=@("dclark","sevans")},
    @{Group="Sales Team";   Members=@("mjohnson","kwilliams","tdavis")}
)

foreach ($entry in $groupMemberships) {
    try {
        Add-ADGroupMember -Identity $entry.Group -Members $entry.Members -ErrorAction Stop
        Write-Host "Added members to: $($entry.Group)" -ForegroundColor Green
    } catch {
        Write-Host "Error adding members to $($entry.Group): $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Verify group membership
Write-Host "`nGroup Membership Summary:" -ForegroundColor Cyan
foreach ($group in $groups) {
    $members = Get-ADGroupMember -Identity $group | Select-Object -ExpandProperty Name
    Write-Host "`n  $group" -ForegroundColor Yellow
    $members | ForEach-Object { Write-Host "    - $_" -ForegroundColor White }
}

# ============================================================
# SECTION 6 — Configure Domain Password Policy
# ============================================================

Write-Host "`n--- Configuring Domain Password Policy ---" -ForegroundColor Cyan

try {
    Set-ADDefaultDomainPasswordPolicy -Identity "corp.local" `
        -MinPasswordLength 10 `
        -PasswordHistoryCount 10 `
        -MaxPasswordAge 90.00:00:00 `
        -MinPasswordAge 1.00:00:00 `
        -ComplexityEnabled $true `
        -LockoutThreshold 5 `
        -LockoutDuration 00:30:00 `
        -LockoutObservationWindow 00:30:00 `
        -ErrorAction Stop
    Write-Host "Password policy configured successfully" -ForegroundColor Green
} catch {
    Write-Host "Error configuring password policy: $($_.Exception.Message)" -ForegroundColor Red
}

# Verify policy
Write-Host "`nPassword Policy Summary:" -ForegroundColor Cyan
Get-ADDefaultDomainPasswordPolicy | Select-Object `
    MinPasswordLength, `
    PasswordHistoryCount, `
    MaxPasswordAge, `
    ComplexityEnabled, `
    LockoutThreshold, `
    LockoutDuration | Format-List

# ============================================================
# SECTION 7 — Final Summary
# ============================================================

Write-Host "`n=== Setup Complete ===" -ForegroundColor Cyan
Write-Host "Domain:        corp.local" -ForegroundColor White
Write-Host "Domain Controller: DC01 (192.168.106.10)" -ForegroundColor White
Write-Host "OUs created:   Corp Users, Corp Computers, Corp Groups, IT, HR, Finance, Sales" -ForegroundColor White
Write-Host "Users created: 10 users across IT, HR, Finance, Sales" -ForegroundColor White
Write-Host "Groups created: IT Team, HR Team, Finance Team, Sales Team" -ForegroundColor White
Write-Host "Password policy: Complexity enabled, 10 char min, 90 day expiry, lockout after 5 attempts" -ForegroundColor White
Write-Host "`nNext steps:" -ForegroundColor Yellow
Write-Host "  1. Deploy Windows 10 client VM in VMware" -ForegroundColor White
Write-Host "  2. Join client to corp.local domain" -ForegroundColor White
Write-Host "  3. Test domain user login from client" -ForegroundColor White
Write-Host "  4. Configure Group Policy Objects" -ForegroundColor White

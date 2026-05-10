# Active Directory Homelab — Domain Controller Setup
#active-directory #homelab #windows-server #powershell #dc01 #corp-local

Personal build notes for setting up a Windows Server 2022 Domain Controller in VMware Workstation Pro.

---

## Environment
#environment #vmware

| Component | Detail |
|---|---|
| Hypervisor | VMware Workstation Pro (free for personal use) |
| Host OS | Windows 10 Home |
| Host RAM | 16GB |
| Server OS | Windows Server 2022 Datacenter Evaluation (180 day) |
| VM RAM | 4GB assigned |
| VM Disk | 60GB single file |
| Server Name | DC01 |
| Domain | corp.local |
| NetBIOS Name | CORP |
| Static IP | 192.168.106.10 |
| Subnet | /24 (255.255.255.0) |
| Gateway | 192.168.106.2 |
| DNS | 192.168.106.10 (itself) |

---

## Step 1 — Rename the Server
#rename #powershell #step-1

A Domain Controller should have a meaningful name before promotion. Renaming after is painful.

```powershell
Rename-Computer -NewName "DC01" -Restart
```

**Verify after restart:**
```powershell
hostname
# or
$env:COMPUTERNAME
```

Expected output: `DC01`

---

## Step 2 — Set a Static IP Address
#networking #static-ip #powershell #step-2

A Domain Controller must have a static IP — if it changes, all clients lose the ability to find the domain.

**Check current network adapter and IP first:**
```powershell
Get-NetAdapter
Get-NetIPAddress
```

**Set the static IP:**
```powershell
New-NetIPAddress -InterfaceAlias "Ethernet0" -IPAddress "192.168.106.10" -PrefixLength 24 -DefaultGateway "192.168.106.2"
```

**Set DNS to point to itself:**
```powershell
Set-DnsClientServerAddress -InterfaceAlias "Ethernet0" -ServerAddresses "192.168.106.10"
```

A Domain Controller must be its own DNS server — AD DS relies heavily on DNS to function.

**Verify:**
```powershell
Get-NetIPAddress
```

Look for:
- `IPAddress: 192.168.106.10`
- `PrefixOrigin: Manual` — confirms it is static not DHCP
- `AddressState: Preferred` — confirms it is active

**Subnetting note:**
With a `/24` prefix length the first three octets define the network. Devices must share the same first three octets to communicate without a router:
```
192.168.106.10  ✅ same subnet as 192.168.106.x
192.168.1.10    ❌ different subnet — won't communicate
```

---

## Step 3 — Install AD DS Role
#ad-ds #powershell #windows-feature #step-3

Installs the Active Directory Domain Services role and all management tools including Active Directory Users and Computers, Group Policy Management, and DNS management.

```powershell
Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools
```

**Expected output:**
```
Success  Restart Needed  Exit Code  Feature Result
True     No              Success    {Active Directory Domain Services, Group P...}
```

- `Success: True` — role installed correctly
- `Restart Needed: No` — no restart required at this stage
- Group Policy tools also install automatically alongside AD DS

---

## Step 4 — Promote Server to Domain Controller
#domain-controller #forest #powershell #step-4

Creates a new AD forest and promotes DC01 to Domain Controller. This is the main event.

```powershell
Install-ADDSForest -DomainName "corp.local" -DomainNetbiosName "CORP" -InstallDns:$true -Force:$true
```

**Parameters explained:**
- `-DomainName "corp.local"` — full DNS name of the domain
- `-DomainNetbiosName "CORP"` — legacy short name for older compatibility
- `-InstallDns:$true` — installs DNS server automatically, essential for AD
- `-Force:$true` — skips confirmation prompts

**During installation:**
- You will be prompted for a **DSRM password** — Directory Services Restore Mode
- This is an emergency recovery password used if AD ever breaks
- Save it in KeePass as: `DSRM Password - DC01`
- The server will **automatically restart** after promotion — this is normal

**After restart:** The Windows login screen will show `CORP\` prefix — this confirms the server is now serving the domain.

---

## Step 5 — Verify Domain Controller
#verification #powershell #step-5

**Verify the domain:**
```powershell
Get-ADDomain
```

Key fields to check:
- `DNSRoot: corp.local` — domain name correct
- `Forest: corp.local` — single forest confirmed
- `PDCEmulator: DC01.corp.local` — DC01 is primary
- `InfrastructureMaster: DC01.corp.local` — DC01 holds FSMO roles

**Verify the Domain Controller:**
```powershell
Get-ADDomainController
```

Key fields to check:
- `HostName: DC01.corp.local` — fully qualified domain name
- `IPv4Address: 192.168.106.10` — static IP confirmed
- `IsGlobalCatalog: True` — DC01 is the Global Catalog server
- `OperationMasterRoles: SchemaMaster, DomainNamingMaster, PDCEmulator, RIDMaster` — all five FSMO roles held by DC01 (correct for single DC environment)

---

## Step 6 — Create OU Structure
#ou #organisational-units #powershell #step-6

Organisational Units organise users, computers, and groups into a logical hierarchy — like folders in AD.

```powershell
# Create top level OUs
New-ADOrganizationalUnit -Name "Corp Users" -Path "DC=corp,DC=local"
New-ADOrganizationalUnit -Name "Corp Computers" -Path "DC=corp,DC=local"
New-ADOrganizationalUnit -Name "Corp Groups" -Path "DC=corp,DC=local"

# Create department OUs under Corp Users
New-ADOrganizationalUnit -Name "IT" -Path "OU=Corp Users,DC=corp,DC=local"
New-ADOrganizationalUnit -Name "HR" -Path "OU=Corp Users,DC=corp,DC=local"
New-ADOrganizationalUnit -Name "Finance" -Path "OU=Corp Users,DC=corp,DC=local"
New-ADOrganizationalUnit -Name "Sales" -Path "OU=Corp Users,DC=corp,DC=local"
```

**Structure created:**
```
corp.local
├── Corp Users
│   ├── IT
│   ├── HR
│   ├── Finance
│   └── Sales
├── Corp Computers
└── Corp Groups
```

**Verify:**
```powershell
Get-ADOrganizationalUnit -Filter * | Select-Object Name, DistinguishedName
```

**DistinguishedName explained:**
Reads right to left — `OU=IT,OU=Corp Users,DC=corp,DC=local` means:
inside the `corp.local` domain, inside `Corp Users` OU, inside `IT` OU.

---

## Step 7 — Bulk Create Users
#users #bulk-create #powershell #step-7

Creates 10 realistic users across departments and places each in the correct OU automatically.

```powershell
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

$Password = ConvertTo-SecureString "Passw0rd123!" -AsPlainText -Force

foreach ($user in $users) {
    $OU = "OU=$($user.Department),OU=Corp Users,DC=corp,DC=local"
    New-ADUser `
        -Name $user.Name `
        -SamAccountName $user.Username `
        -UserPrincipalName "$($user.Username)@corp.local" `
        -Department $user.Department `
        -Title $user.Title `
        -Path $OU `
        -AccountPassword $Password `
        -Enabled $true
    Write-Host "Created user: $($user.Name) in $($user.Department)" -ForegroundColor Green
}
```

**Users created:**

| Name | Username | Department | Title |
|---|---|---|---|
| John Smith | jsmith | IT | Systems Engineer |
| Sarah Connor | sconnor | IT | Security Analyst |
| James Wilson | jwilson | IT | Network Engineer |
| Emma Taylor | etaylor | HR | HR Manager |
| Lucy Brown | lbrown | HR | HR Advisor |
| David Clark | dclark | Finance | Finance Manager |
| Sophie Evans | sevans | Finance | Accountant |
| Mark Johnson | mjohnson | Sales | Sales Manager |
| Kate Williams | kwilliams | Sales | Sales Executive |
| Tom Davis | tdavis | Sales | Sales Executive |

---

## Step 8 — Create Security Groups and Add Members
#groups #security-groups #powershell #step-8

Creates one security group per department in the Corp Groups OU, then adds users.

```powershell
# Create department security groups
$groups = @("IT Team", "HR Team", "Finance Team", "Sales Team")

foreach ($group in $groups) {
    New-ADGroup `
        -Name $group `
        -GroupScope Global `
        -GroupCategory Security `
        -Path "OU=Corp Groups,DC=corp,DC=local" `
        -Description "Security group for $group"
    Write-Host "Created group: $group" -ForegroundColor Green
}

# Add users to groups
Add-ADGroupMember -Identity "IT Team" -Members jsmith, sconnor, jwilson
Add-ADGroupMember -Identity "HR Team" -Members etaylor, lbrown
Add-ADGroupMember -Identity "Finance Team" -Members dclark, sevans
Add-ADGroupMember -Identity "Sales Team" -Members mjohnson, kwilliams, tdavis
```

**Verify group membership:**
```powershell
$groups = @("IT Team", "HR Team", "Finance Team", "Sales Team")
foreach ($group in $groups) {
    $members = Get-ADGroupMember -Identity $group | Select-Object -ExpandProperty Name
    Write-Host "`n$group members:" -ForegroundColor Cyan
    $members | ForEach-Object { Write-Host "  - $_" -ForegroundColor White }
}
```

---

## Step 9 — Configure Domain Password Policy
#password-policy #gpo #powershell #step-9 #security

Sets the default domain password policy applying to all users in corp.local.

```powershell
Set-ADDefaultDomainPasswordPolicy -Identity "corp.local" `
    -MinPasswordLength 10 `
    -PasswordHistoryCount 10 `
    -MaxPasswordAge 90.00:00:00 `
    -MinPasswordAge 1.00:00:00 `
    -ComplexityEnabled $true `
    -LockoutThreshold 5 `
    -LockoutDuration 00:30:00 `
    -LockoutObservationWindow 00:30:00
```

**Policy settings:**

| Setting | Value | Purpose |
|---|---|---|
| MinPasswordLength | 10 | Minimum 10 characters |
| PasswordHistoryCount | 10 | Cannot reuse last 10 passwords |
| MaxPasswordAge | 90 days | Passwords expire after 90 days |
| MinPasswordAge | 1 day | Must wait 1 day before changing again |
| ComplexityEnabled | True | Must include uppercase, lowercase, number, symbol |
| LockoutThreshold | 5 | Account locks after 5 failed attempts |
| LockoutDuration | 30 minutes | Account locked for 30 minutes |
| LockoutObservationWindow | 30 minutes | Failed attempt counter resets after 30 minutes |

**Verify:**
```powershell
Get-ADDefaultDomainPasswordPolicy
```

---

## Step 10 — Configure Group Policy Objects
#gpo #group-policy #powershell #step-10 #security

Creates and links three GPOs to the domain to enforce desktop and security settings.

**Key concept:** GPOs write registry values to either HKLM (machine-wide, applies regardless of who logs in) or HKCU (per user profile). At their core, GPOs are just a mechanism for delivering and enforcing registry settings across the domain at scale — refreshing automatically every 90 minutes or on demand with `gpupdate /force`.

```powershell
# GPO 1 — Corporate Wallpaper
New-GPO -Name "Corporate Wallpaper" -Comment "Sets corporate desktop wallpaper for all domain computers"
New-GPLink -Name "Corporate Wallpaper" -Target "DC=corp,DC=local"
Set-GPRegistryValue -Name "Corporate Wallpaper" -Key "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\System" -ValueName "Wallpaper" -Type String -Value "C:\Windows\Web\Wallpaper\Windows\img0.jpg"
Set-GPRegistryValue -Name "Corporate Wallpaper" -Key "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\System" -ValueName "WallpaperStyle" -Type String -Value "2"

# GPO 2 — Disable USB Storage
New-GPO -Name "Disable USB Storage" -Comment "Prevents users from using USB storage devices"
New-GPLink -Name "Disable USB Storage" -Target "DC=corp,DC=local"
Set-GPRegistryValue -Name "Disable USB Storage" -Key "HKLM\SYSTEM\CurrentControlSet\Services\USBSTOR" -ValueName "Start" -Type DWord -Value 4

# GPO 3 — Disable Lock Screen
New-GPO -Name "Disable Lock Screen" -Comment "Disables the Windows lock screen for domain users"
New-GPLink -Name "Disable Lock Screen" -Target "DC=corp,DC=local"
Set-GPRegistryValue -Name "Disable Lock Screen" -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows\Personalization" -ValueName "NoLockScreen" -Type DWord -Value 1
```

**GPOs created:**

| GPO | Hive | Registry Key | Value | Purpose |
|---|---|---|---|---|
| Corporate Wallpaper | HKCU | ...\Policies\System | Wallpaper = img0.jpg | Sets domain wallpaper path |
| Corporate Wallpaper | HKCU | ...\Policies\System | WallpaperStyle = 2 | Stretched display mode |
| Disable USB Storage | HKLM | ...\USBSTOR | Start = 4 | Disables USB storage service |
| Disable Lock Screen | HKLM | ...\Personalization | NoLockScreen = 1 | Removes Windows lock screen |

**WallpaperStyle values reference:**
- `0` — Centred
- `1` — Tiled
- `2` — Stretched
- `3` — Fit
- `4` — Fill

**USBSTOR Start values reference:**
- `3` — Enabled (default)
- `4` — Disabled

**Verify GPO application on client:**
```powershell
gpupdate /force
gpresult /r
```

Look for all three GPOs listed under Applied Group Policy Objects. Policy is applied from DC01.corp.local.

---

## Step 11 — Deploy Windows 10 Client and Join Domain
#client #domain-join #powershell #step-11

**Prerequisites:** Windows 10 Pro (Home does not support domain join). Deploy VM in VMware on the same NAT network as DC01.

**On CLIENT01 — set DNS to point at DC01:**
```powershell
Set-DnsClientServerAddress -InterfaceAlias "Ethernet0" -ServerAddresses "192.168.106.10"
```

**Verify connectivity to DC01:**
```powershell
ping 192.168.106.10
```

**Join the domain:**
```powershell
Add-Computer -DomainName "corp.local" -Restart
```

Provide Domain Administrator credentials when prompted. CLIENT01 will restart and join corp.local.

**On DC01 — move CLIENT01 to Corp Computers OU:**
```powershell
Get-ADComputer -Identity "CLIENT01" | Move-ADObject -TargetPath "OU=Corp Computers,DC=corp,DC=local"
```

**Verify:**
```powershell
Get-ADComputer -Identity "CLIENT01"
```

DistinguishedName should show `CN=CLIENT01,OU=Corp Computers,DC=corp,DC=local`.

**Test domain user login from CLIENT01:**

On the CLIENT01 login screen select Other User and log in with:
- Username: `CORP\jsmith`
- Password: `Passw0rd123!`

**To log back in with the local account if needed:**
- Username: `.\administrator`

---

## FSMO Roles Reference
#fsmo #reference

In a single domain controller environment DC01 holds all five FSMO roles:

| Role | Purpose |
|---|---|
| Schema Master | Controls changes to the AD schema |
| Domain Naming Master | Controls adding/removing domains in the forest |
| PDC Emulator | Primary DC, handles password changes and time sync |
| RID Master | Allocates pools of unique IDs for new AD objects |
| Infrastructure Master | Maintains references between objects in different domains |

---

## Build Status
#status

| Step | Status |
|---|---|
| Rename server to DC01 | ✅ Complete |
| Set static IP 192.168.106.10 | ✅ Complete |
| Install AD DS role | ✅ Complete |
| Promote to Domain Controller | ✅ Complete |
| Create corp.local domain | ✅ Complete |
| DNS installed and running | ✅ Complete |
| Verify domain and DC | ✅ Complete |
| Create OU structure | ✅ Complete |
| Bulk create users with PowerShell | ✅ Complete |
| Create security groups | ✅ Complete |
| Configure domain password policy | ✅ Complete |
| Configure Group Policy Objects | ✅ Complete |
| Set up Windows 10 client VM | ✅ Complete |
| Join client to domain | ✅ Complete |
| Test user login from client | ✅ Complete |
| Push scripts to GitHub | ✅ Complete |

---

## Next Steps
#next-steps

- Add second Domain Controller for redundancy
- Configure fine-grained password policies per OU
- Expand GPOs — drive mappings, software restriction policies
z
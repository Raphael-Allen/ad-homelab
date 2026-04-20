# Active Directory Homelab

A hands-on homelab project building a realistic corporate Active Directory environment using Windows Server 2022 and VMware Workstation Pro. All infrastructure is configured and automated using PowerShell.

---

## Overview

This project simulates a corporate network with a fully configured Windows Server 2022 Domain Controller, organisational structure, user accounts, security groups, and domain security policies. The goal is to build practical Active Directory administration skills directly applicable to real-world IT and cloud infrastructure roles.

---

## Environment

| Component | Detail |
|---|---|
| Hypervisor | VMware Workstation Pro (free for personal use) |
| Host OS | Windows 10 Home, 16GB RAM |
| Domain Controller OS | Windows Server 2022 Datacenter Evaluation |
| Domain | corp.local |
| Domain Controller | DC01 — 192.168.106.10 |

---

## What Was Built

### Domain Controller
- Windows Server 2022 VM deployed in VMware Workstation Pro
- Server renamed to DC01 and configured with a static IP
- Active Directory Domain Services role installed
- Server promoted to Domain Controller for the `corp.local` forest
- DNS role installed and configured automatically alongside AD DS
- DC01 holds all five FSMO roles appropriate for a single DC environment

### Organisational Unit Structure
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

### Users
10 domain users created across four departments via PowerShell bulk creation script:

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

### Security Groups
Four global security groups created in the Corp Groups OU with appropriate membership:

- IT Team — jsmith, sconnor, jwilson
- HR Team — etaylor, lbrown
- Finance Team — dclark, sevans
- Sales Team — mjohnson, kwilliams, tdavis

### Domain Password Policy
Production-grade password policy applied across the domain:

| Setting | Value |
|---|---|
| Minimum password length | 10 characters |
| Password history | Last 10 passwords |
| Maximum password age | 90 days |
| Complexity | Enabled |
| Lockout threshold | 5 failed attempts |
| Lockout duration | 30 minutes |

---

## Files

| File | Description |
|---|---|
| `Setup-ADHomelab.ps1` | Full PowerShell automation script covering OU creation, bulk user creation, security groups, and password policy |
| `AD_Homelab_DC_Setup.md` | Step-by-step build documentation with all PowerShell commands, expected outputs, and verification steps |

---

## How to Use

> **Prerequisites:** Windows Server 2022 with AD DS role installed and promoted to Domain Controller. Run all scripts as Domain Administrator.

1. Clone the repository
2. Review `AD_Homelab_DC_Setup.md` for full build documentation
3. Run `Setup-ADHomelab.ps1` in PowerShell as Administrator on your Domain Controller

```powershell
.\Setup-ADHomelab.ps1
```

The script will verify prerequisites, create the OU structure, bulk create users, set up security groups, and apply the domain password policy. Progress is colour-coded — green for success, yellow for warnings, red for errors.

---

## Skills Demonstrated

- Windows Server 2022 administration
- Active Directory Domain Services configuration
- PowerShell automation for AD administration
- Organisational Unit design and management
- Bulk user creation via scripted deployment
- Security group management
- Domain password and lockout policy configuration
- VMware Workstation Pro VM deployment
- Network configuration — static IP, DNS, subnetting

---

## Roadmap

- [ ] Deploy Windows 10 client VM and join to corp.local domain
- [ ] Test domain user login from client machine
- [ ] Configure Group Policy Objects — desktop restrictions, drive mappings
- [ ] Add second Domain Controller for redundancy
- [ ] Document client join process with PowerShell

---

## Certifications

This project supports skills covered by:
- Microsoft AZ-500 Azure Security Engineer Associate
- CompTIA Security+ SY0-701

---

## Author

**Raphael Allen**
[LinkedIn](https://linkedin.com/in/raphael-allen) | [GitHub](https://github.com/Raphael-Allen)

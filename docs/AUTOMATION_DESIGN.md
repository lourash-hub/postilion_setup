# Postilion Realtime Framework v5.6 — Automation Design Document

## 1. Overview

This document describes the automated deployment of **ACI Postilion Realtime Framework v5.6.00.654114 Standard Edition** on **Windows Server 2022** using **Ansible** with **AutoIt** for GUI interaction.

### Problem Statement
The Postilion Realtime installer (`setup.exe`) is a GUI-based wizard with no documented silent/unattended install mode. Both `setup.exe` and `setupc.exe` launch the same GUI wizard. Automating this installation requires programmatic interaction with 13 GUI screens including 3 conditional popup dialogs.

### Solution Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                      Ansible Control Node (Linux)                │
│                                                                  │
│  ┌────────────┐  ┌──────────────┐  ┌──────────────────────────┐ │
│  │  Inventory  │  │   Playbook   │  │   Vault (credentials)    │ │
│  │  hosts.yml  │  │  deploy.yml  │  │   vault.yml              │ │
│  └────────────┘  └──────────────┘  └──────────────────────────┘ │
└──────────────────────────┬───────────────────────────────────────┘
                           │ WinRM (HTTPS/5986)
                           ▼
┌──────────────────────────────────────────────────────────────────┐
│               Target: Windows Server 2022                        │
│                                                                  │
│  Phase 1: Prerequisites                                          │
│  ├── .NET Framework 4.8                                          │
│  ├── SQL Server 2019 (pre-installed)                             │
│  ├── SSMS (optional)                                             │
│  ├── Grant SeServiceLogonRight to service account                │
│  ├── Close Event Viewer (mmc.exe)                                │
│  └── Pre-create license directory + copy license file            │
│                                                                  │
│  Phase 2: Extract Installer                                      │
│  └── RealtimeFramework_se_v5.6_build654114.exe /auto "D:\..."   │
│                                                                  │
│  Phase 3: Install (AutoIt GUI Automation)                        │
│  ├── Launch setup.exe in background                              │
│  ├── Run compiled AutoIt script (postilion_install.exe)          │
│  │   ├── Screen 1:  Welcome → Next                              │
│  │   ├── Screen 2:  Destination → set path → Next               │
│  │   ├── Screen 2a: Directory Exists (conditional) → Yes        │
│  │   ├── Screen 3:  Installation Type → Principal Server → Next │
│  │   ├── Screen 4:  License Validation → Next                   │
│  │   ├── Screen 5:  Data Source → fill DB fields → Next         │
│  │   ├── Screen 6:  Database Details → Local DB → Next          │
│  │   ├── Screen 7:  Services Server → hostname → Next           │
│  │   ├── Screen 8:  Service Account → credentials → Next        │
│  │   ├── Screen 8a: Logon As Service (conditional) → Yes        │
│  │   ├── Screen 9:  Default Currency → Naira (566) → Next      │
│  │   ├── Screen 10: Ready to Install → Next                     │
│  │   ├── Screen 10a:Event Viewer warning (conditional) → OK     │
│  │   ├── Screen 11: Installing... → Wait                        │
│  │   ├── Screen 12: PCI DSS Considerations → Next               │
│  │   └── Screen 13: Installation Complete → Finish              │
│  └── Verify installation success                                 │
│                                                                  │
│  Phase 4: Post-Install Validation                                │
│  ├── Verify install directory exists                             │
│  ├── Verify Windows services created                             │
│  ├── Verify database tables created                              │
│  └── Verify license file in place                                │
└──────────────────────────────────────────────────────────────────┘
```

---

## 2. Installer Analysis

### Installer Details
| Property | Value |
|----------|-------|
| Filename | `RealtimeFramework_se_v5.6_build654114.exe` |
| Type | WinZip Self-Extractor → GUI Wizard |
| Version | v5.6.00.654114 Standard Edition |
| Silent mode | **Not available** (`/?`, `/s`, `/silent`, `/quiet` all tested) |
| setupc.exe | Console extraction only — still launches GUI wizard |
| Extraction | `RealtimeFramework_se_v5.6_build654114.exe /auto "D:\Postilion"` |
| Installer path | `D:\Postilion\Postilion\Realtime\RealtimeFramework_se_v5.6_build654114\setup.exe` |
| Disk required | 500 MB |
| Platform | Microsoft SQL Server (required pre-installed) |

### GUI Screen Inventory

| # | Window Title | Screen Name | Controls | Action |
|---|-------------|-------------|----------|--------|
| 1 | Realtime Install Framework | Welcome | Next, Back, Finish, Cancel | Click Next |
| 2 | Realtime Install Framework | Destination Directory | Edit (path), Browse, Next | Set `C:\Postilion`, click Next |
| 2a | Directory Exists | Overwrite confirm | Yes, No | Click Yes (conditional) |
| 3 | Realtime Install Framework | Installation Type | 3 radio buttons, Next | Select Principal Server, click Next |
| 4 | Realtime Install Framework | License Validation | Edit (path), Browse, Next | Verify path, click Next |
| 5 | Realtime Install Framework | Data Source | Server, Port, Schema, Database, Auth dropdown, Login, Password, Next | Fill all fields, click Next |
| 6 | Realtime Install Framework | Database Details | Radio (Local/Remote), DB name, device names, file paths, Next | Select Local, click Next |
| 7 | Realtime Install Framework | Services Server | Edit (hostname), Next | Verify hostname, click Next |
| 8 | Realtime Install Framework | Service Account | Domain, Username, Password, Next | Fill credentials, click Next |
| 8a | Logon As Service | Grant privilege | Yes, No | Click Yes (conditional) |
| 9 | Realtime Install Framework | Default Currency | Dropdown, Next | Select Naira (566), click Next |
| 10 | Realtime Install Framework | Ready to Install | Next, Back | Click Next |
| 10a | Event Viewer | Close warning | OK | Click OK (conditional) |
| 11 | Realtime Install Framework | Install in progress | (progress bar) | Wait |
| 12 | Realtime Install Framework | PCI DSS Considerations | Next | Click Next |
| 13 | Realtime Install Framework | Installation Complete | Finish | Click Finish |

---

## 3. Variable Definitions

### Environment Variables (per-host or per-group)

```yaml
# Installation paths
postilion_install_dir: "C:\\Postilion"
postilion_installer_source: "D:\\Postilion\\Postilion\\Realtime\\RealtimeFramework_se_v5.6_build654114"
postilion_license_source: "D:\\postilion.lic"

# Database configuration
postilion_db_platform: "Microsoft SQL Server"
postilion_db_server: "{{ ansible_hostname }}"
postilion_db_port: "1433"
postilion_db_schema: "dbo"
postilion_db_name: "realtime"
postilion_db_auth: "Windows Authentication"   # or "SQL Server Authentication"
postilion_db_login: ""                         # only for SQL auth
postilion_db_password: ""                      # only for SQL auth

# Database file details
postilion_db_location: "local"                 # "local" or "remote"
postilion_db_data_device: "realtime_data"
postilion_db_log_device: "realtime_log"
postilion_db_data_path: "D:\\Program Files\\Microsoft SQL Server\\MSSQL15.MSSQLSERVER\\MSSQL\\data"
postilion_db_log_path: "D:\\Program Files\\Microsoft SQL Server\\MSSQL15.MSSQLSERVER\\MSSQL\\data"

# Service configuration
postilion_svc_hostname: "{{ ansible_hostname }}"
postilion_svc_domain: "{{ ansible_hostname }}"
postilion_svc_username: "Administrator"         # should be a dedicated service account
postilion_svc_password: "{{ vault_postilion_svc_password }}"

# Application configuration
postilion_default_currency: "Naira (566)"

# Timeouts
postilion_install_timeout: 900                  # seconds to wait for install to complete
postilion_screen_wait: 2000                     # ms to wait between screens in AutoIt
```

### Vault Variables (encrypted)

```yaml
vault_postilion_svc_password: "<encrypted>"
vault_postilion_db_password: "<encrypted>"      # if using SQL auth
```

---

## 4. File Structure

```
postilion-automation/
├── README.md
├── ansible.cfg
├── inventory/
│   ├── hosts.yml
│   └── group_vars/
│       ├── all.yml                # shared defaults
│       ├── postilion_servers.yml  # postilion-specific vars
│       └── vault.yml              # encrypted secrets
├── playbooks/
│   ├── site.yml                   # main orchestrator
│   ├── 01_prerequisites.yml       # .NET, permissions, directories
│   ├── 02_extract_installer.yml   # WinZip self-extractor
│   ├── 03_install_realtime.yml    # AutoIt GUI automation
│   └── 04_validate.yml            # post-install checks
├── roles/
│   └── postilion_realtime/
│       ├── tasks/
│       │   ├── main.yml
│       │   ├── prerequisites.yml
│       │   ├── extract.yml
│       │   ├── install.yml
│       │   └── validate.yml
│       ├── templates/
│       │   └── postilion_install.au3.j2    # AutoIt template
│       ├── files/
│       │   └── postilion_install.exe        # compiled AutoIt script
│       ├── vars/
│       │   └── main.yml
│       ├── defaults/
│       │   └── main.yml
│       └── handlers/
│           └── main.yml
├── scripts/
│   ├── autoit/
│   │   ├── postilion_install.au3            # AutoIt source
│   │   ├── compile_autoit.ps1               # helper to compile .au3 to .exe
│   │   └── README.md                        # AutoIt setup instructions
│   └── powershell/
│       ├── verify_installation.ps1
│       └── pre_flight_checks.ps1
└── docs/
    ├── AUTOMATION_DESIGN.md                 # this document
    ├── INSTALLATION_SCREENS.md              # screenshots reference
    └── TROUBLESHOOTING.md
```

---

## 5. AutoIt Script Design

### Key Design Decisions

1. **Window identification**: Use window title "Realtime Install Framework" with screen-specific text matching for disambiguation.
2. **Conditional popups**: Use `WinWaitActive` with short timeouts + `If WinExists()` checks for the 3 known conditional dialogs.
3. **Parameterization**: All installation values (paths, DB config, credentials) are injected at the top of the script as variables, generated by Ansible via Jinja2 template.
4. **Error handling**: Each screen interaction is wrapped in timeout checks with logging. If any screen fails to appear within the expected timeout, the script logs the failure and exits with a non-zero code.
5. **Logging**: All actions are logged to `C:\logs\postilion_autoit_install.log` for troubleshooting.

### AutoIt Control Identification Strategy

| Screen | Control Type | Identification Method |
|--------|-------------|----------------------|
| Next button | Button | `[TEXT:Next >]` or `[CLASS:Button; INSTANCE:2]` |
| Back button | Button | `[TEXT:< Back]` |
| Finish button | Button | `[TEXT:Finish]` |
| Cancel button | Button | `[TEXT:Cancel]` |
| Yes button | Button | `[TEXT:Yes]` |
| OK button | Button | `[TEXT:OK]` |
| Path edit field | Edit | `[CLASS:Edit; INSTANCE:1]` |
| Radio buttons | Radio | `[CLASS:Button; TEXT:Principal Server]` |
| Currency dropdown | ComboBox | `[CLASS:ComboBox; INSTANCE:1]` |

### Error Handling Strategy

```
For each screen:
  1. WinWaitActive(title, screen_text, timeout)
  2. If timeout → log error, capture screenshot, exit 1
  3. Perform action (click, type, select)
  4. Sleep(screen_wait) to allow GUI to respond
  5. Check for conditional popup → handle if present
  6. Proceed to next screen
```

---

## 6. Ansible Playbook Design

### Phase 1: Prerequisites

```yaml
tasks:
  - Ensure .NET Framework 4.8 is installed
  - Ensure SQL Server is running
  - Create C:\Postilion directory
  - Create C:\Postilion\realtime\license directory
  - Copy postilion.lic to license directory
  - Grant SeServiceLogonRight to service account
  - Close Event Viewer (Stop-Process mmc)
  - Create C:\logs directory for install logging
  - Copy AutoIt compiled script to target
```

### Phase 2: Extract Installer

```yaml
tasks:
  - Run self-extractor with /auto flag (silent extraction)
  - Verify extraction completed (check for setup.exe)
```

### Phase 3: Install via AutoIt

```yaml
tasks:
  - Generate AutoIt script from template with environment variables
  - Launch setup.exe as background process
  - Execute AutoIt script with timeout
  - Monitor for completion
  - Check exit code
```

### Phase 4: Post-Install Validation

```yaml
tasks:
  - Verify C:\Postilion\realtime directory exists
  - Verify Postilion Windows services exist
  - Verify services can start
  - Verify database 'realtime' exists and has tables
  - Verify license file in final location
  - Verify event log for errors
```

---

## 7. Idempotency Considerations

| Check | How |
|-------|-----|
| Already installed? | Check for `C:\Postilion\realtime` directory and services |
| Already extracted? | Check for `setup.exe` in extraction path |
| License present? | Check for `postilion.lic` in target directory |
| Service account rights? | Query `SeServiceLogonRight` before granting |
| Database exists? | Query SQL Server for 'realtime' database |

The playbook should skip installation entirely if the product is already installed and the version matches. Use `creates:` parameter or `when:` conditions.

---

## 8. Rollback Strategy

If installation fails:
1. AutoIt script exits with non-zero code
2. Ansible captures the failure
3. Run cleanup:
   - Stop any Postilion services that may have been partially created
   - Remove `C:\Postilion` directory
   - Drop `realtime` database if partially created
   - Remove Windows Event Log sources
4. Log failure details for investigation

---

## 9. Security Considerations

- Service account credentials stored in Ansible Vault (AES-256 encrypted)
- Database passwords never logged or stored in plaintext
- AutoIt script with embedded credentials is generated at runtime, used, then deleted
- WinRM connection uses HTTPS with certificate validation
- Service account should be a dedicated account, not Administrator (production)
- Minimum required permissions for service account:
  - SQL Server: db_owner on 'realtime' database
  - Windows: SeServiceLogonRight
  - File system: Full control on `C:\Postilion`

---

## 10. Testing Checklist

- [ ] Fresh Windows Server 2022 VM with SQL Server 2019 pre-installed
- [ ] WinRM connectivity from Ansible control node
- [ ] Self-extractor runs silently with /auto flag
- [ ] AutoIt script navigates all 13 screens correctly
- [ ] Conditional popups handled (Directory Exists, Logon As Service, Event Viewer)
- [ ] All variables correctly injected into AutoIt script
- [ ] Installation completes successfully
- [ ] Post-install validation passes
- [ ] Idempotency: re-running playbook does not break existing install
- [ ] Rollback: failed install cleans up properly
- [ ] Credentials are not exposed in logs or on disk

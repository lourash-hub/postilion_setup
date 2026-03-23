# Postilion Realtime Framework v5.6 — Ansible Automation

Automated deployment of **ACI Postilion Realtime Framework v5.6.00.654114 Standard Edition** on **Windows Server 2022** using Ansible + AutoIt GUI automation.

## Overview

The Postilion Realtime installer is a GUI wizard with **no silent/unattended mode**. This project uses:

- **Ansible** — orchestates the end-to-end deployment over WinRM
- **AutoIt v3** — automates the 13-screen GUI installer (compiled to `.exe`)
- **PowerShell** — pre-flight checks and post-install validation

## Prerequisites

### Ansible Control Node (Linux)
- Ansible 2.15+
- `ansible.windows` collection: `ansible-galaxy collection install ansible.windows`
- `pywinrm` library: `pip install pywinrm`

### Target Windows Server
- Windows Server 2022
- SQL Server 2019 (pre-installed and running)
- .NET Framework 4.8+
- WinRM enabled over HTTPS (port 5986)
- Installer file: `D:\RealtimeFramework_se_v5.6_build654114.exe`
- License file: `D:\postilion.lic`

### AutoIt Compilation (one-time)
- AutoIt v3 installed on a Windows machine
- Compile the script: `scripts\autoit\compile_autoit.ps1`
- Place compiled `postilion_install.exe` in `roles/postilion_realtime/files/`

## Project Structure

```
├── ansible.cfg                           # Ansible configuration
├── inventory/
│   ├── hosts.yml                         # Target hosts
│   └── group_vars/
│       ├── all.yml                       # Global variables & credentials
│       └── postilion_servers.yml         # Postilion-specific variables
├── playbooks/
│   ├── site.yml                          # Main orchestrator
│   ├── 01_prerequisites.yml              # Phase 1: Prerequisites
│   ├── 02_extract_installer.yml          # Phase 2: Extract
│   ├── 03_install_realtime.yml           # Phase 3: Install (AutoIt)
│   └── 04_validate.yml                   # Phase 4: Validate
├── roles/
│   └── postilion_realtime/
│       ├── tasks/                        # Ansible task files
│       ├── templates/                    # Jinja2 templates (AutoIt)
│       ├── files/                        # Compiled AutoIt .exe
│       ├── defaults/                     # Default variables
│       ├── vars/                         # Role variables
│       └── handlers/                     # Service handlers
├── scripts/
│   ├── autoit/                           # AutoIt source + compiler
│   └── powershell/                       # Verification scripts
└── docs/                                 # Design documentation
```

## Quick Start

### 1. Configure Inventory

Edit `inventory/hosts.yml` — set the target server IP/hostname:

```yaml
postilion_servers:
  hosts:
    postilion-srv01:
      ansible_host: 192.168.1.100
```

### 2. Configure Credentials

Edit `inventory/group_vars/all.yml` — set the default user and password:

```yaml
ansible_user: "Administrator"
ansible_password: "MyP@ssw0rd!"
postilion_svc_password: "MyP@ssw0rd!"
```

Also update `inventory/hosts.yml` with matching credentials.

### 3. Compile AutoIt Script

On a Windows machine with AutoIt v3 installed:

```powershell
cd scripts\autoit
.\compile_autoit.ps1
# Copy output to roles/postilion_realtime/files/postilion_install.exe
```

### 4. Run Pre-Flight Checks (Optional)

Run on the target server to verify readiness:

```powershell
.\scripts\powershell\pre_flight_checks.ps1
```

### 5. Deploy

```bash
# Full deployment (all 4 phases)
ansible-playbook playbooks/site.yml

# Individual phases
ansible-playbook playbooks/01_prerequisites.yml
ansible-playbook playbooks/02_extract_installer.yml
ansible-playbook playbooks/03_install_realtime.yml
ansible-playbook playbooks/04_validate.yml

# Using tags with site.yml
ansible-playbook playbooks/site.yml --tags prerequisites
ansible-playbook playbooks/site.yml --tags validate
```

### 6. Post-Install Verification

```powershell
# Run on target server
.\scripts\powershell\verify_installation.ps1
```

## Installer GUI Flow

The AutoIt script navigates 13 screens in order, handling 3 conditional popups:

| # | Screen | Action |
|---|--------|--------|
| 1 | Welcome | Click Next |
| 2 | Destination Directory | Set path, click Next |
| 2a | *Directory Exists* | Click Yes *(conditional)* |
| 3 | Installation Type | Select Principal Server, click Next |
| 4 | License Validation | Verify path, click Next |
| 5 | Data Source | Fill DB fields, click Next |
| 6 | Database Details | Select Local, click Next |
| 7 | Services Server | Verify hostname, click Next |
| 8 | Service Account | Fill credentials, click Next |
| 8a | *Logon As Service* | Click Yes *(conditional)* |
| 9 | Default Currency | Select Naira (566), click Next |
| 10 | Ready to Install | Click Next |
| 10a | *Event Viewer* | Click OK *(conditional)* |
| 11 | Installing... | Wait (up to 10 min) |
| 12 | PCI DSS Considerations | Click Next |
| 13 | Installation Complete | Click Finish |

## Key Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `postilion_install_dir` | `C:\Postilion` | Installation directory |
| `postilion_db_server` | `{{ ansible_hostname }}` | SQL Server hostname |
| `postilion_db_name` | `realtime` | Database name |
| `postilion_db_auth` | `Windows Authentication` | Auth method |
| `postilion_svc_username` | `Administrator` | Service account |
| `postilion_default_currency` | `Naira (566)` | Default currency |
| `postilion_install_timeout` | `900` | Max install time (seconds) |

## AutoIt Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Timeout waiting for screen |
| 2 | Unexpected window/error |
| 3 | Control not found |
| 99 | Fatal/unhandled error |

## Idempotency

The playbook checks for an existing installation before proceeding:
- If `C:\Postilion\realtime\bin` exists, the install phase is skipped
- Extraction checks for `setup.exe` before re-extracting
- Prerequisites use `creates:` and `when:` conditions

## Troubleshooting

| Issue | Solution |
|-------|----------|
| WinRM connection failed | Verify port 5986, HTTPS listener, firewall rules |
| AutoIt times out on screen | Check installer is visible (no RDP disconnect), increase timeout |
| Currency dropdown not selecting | Verify exact string "Naira (566)" matches dropdown entries |
| SQL Server not found | Ensure MSSQLSERVER service is running |
| License validation fails | Verify `postilion.lic` is copied to the correct path before install |
| Event Viewer popup | Close mmc.exe in prerequisites phase |

## Security Notes

- Default credentials are stored in plaintext in `inventory/group_vars/all.yml` (suitable for dev/lab; use Ansible Vault for production)
- Generated AutoIt scripts with credentials are deleted after use
- WinRM uses HTTPS with certificate validation
- Service account should use dedicated account (not Administrator) in production

## License

Internal use only — ACI Postilion is proprietary software.

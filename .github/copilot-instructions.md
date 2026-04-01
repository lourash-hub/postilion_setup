# Copilot Custom Instructions

This repository automates the deployment of ACI Postilion Realtime Framework v5.6 on Windows Server 2022 using Ansible + AutoIt.

## Key Context
- The Postilion installer is GUI-only (no silent mode). AutoIt automates 13 GUI screens.
- Target: Windows Server 2022 with SQL Server 2019 pre-installed.
- Connection: Ansible over WinRM (HTTPS/5986).
- Secrets: Ansible Vault for all credentials.

## When writing Ansible:
- Always use FQCN (e.g. `ansible.windows.win_shell`)
- Always use `win_*` modules for Windows targets
- Tag tasks with phase names: `prerequisites`, `extract`, `install`, `validate`
- Reference `vault_` prefixed vars for secrets
- Set explicit timeouts on long tasks
- Check idempotency with `win_stat` or `creates:`

## When writing AutoIt (.au3):
- Always use `WinWaitActive()` before interacting with any window
- Always use `ControlClick()` over `Send()` for button clicks
- Always use `ControlSetText()` over typing for text fields
- Handle all 3 conditional popups: "Directory Exists", "Logon As Service", "Event Viewer"
- Log every action with timestamps
- Exit with meaningful codes (0=success, 1=timeout, 2=unexpected, 3=control not found, 99=fatal)
- Main window title is always "Realtime Install Framework"

## Variable naming convention:
- `postilion_` prefix for all Postilion-related variables
- `vault_` prefix for encrypted secrets
- `ansible_` prefix for connection/system variables

## Refer to docs/COPILOT_INSTRUCTIONS.md for the complete GUI screen flow and coding standards.


Ansible host is 172.26.42.122
ansible user is : Administrator
ansible password is : Password@123
postilion_svc_username: Administrator
postilion_svc_password: Password@123
ansible_port: 5985
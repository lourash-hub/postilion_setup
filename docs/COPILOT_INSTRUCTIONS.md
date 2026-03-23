# Postilion Realtime Automation — GitHub Copilot Instructions

## Project Context

You are helping build Ansible automation to deploy ACI Postilion Realtime Framework v5.6.00.654114 Standard Edition on Windows Server 2022. The installer is a GUI wizard with no silent/unattended mode, so we use AutoIt to automate GUI interactions and Ansible for orchestration.

## Technology Stack

- **Orchestration**: Ansible 2.15+ with `ansible.windows` collection
- **Target OS**: Windows Server 2022
- **GUI Automation**: AutoIt v3 (compiled to .exe)
- **Database**: Microsoft SQL Server 2019
- **Connection**: WinRM over HTTPS (port 5986)
- **Secrets**: Ansible Vault

## Project Structure

```
postilion-automation/
├── ansible.cfg
├── inventory/
│   ├── hosts.yml
│   └── group_vars/
│       ├── all.yml
│       ├── postilion_servers.yml
│       └── vault.yml
├── playbooks/
│   ├── site.yml
│   ├── 01_prerequisites.yml
│   ├── 02_extract_installer.yml
│   ├── 03_install_realtime.yml
│   └── 04_validate.yml
├── roles/
│   └── postilion_realtime/
│       ├── tasks/
│       │   ├── main.yml
│       │   ├── prerequisites.yml
│       │   ├── extract.yml
│       │   ├── install.yml
│       │   └── validate.yml
│       ├── templates/
│       │   └── postilion_install.au3.j2
│       ├── files/
│       │   └── postilion_install.exe
│       ├── vars/
│       │   └── main.yml
│       ├── defaults/
│       │   └── main.yml
│       └── handlers/
│           └── main.yml
├── scripts/
│   └── autoit/
│       ├── postilion_install.au3
│       └── compile_autoit.ps1
└── docs/
    └── AUTOMATION_DESIGN.md
```

## Key Variables

When generating Ansible vars files or templates, use these variable names consistently:

```yaml
# Installation paths
postilion_install_dir: "C:\\Postilion"
postilion_installer_source: "D:\\Postilion\\Postilion\\Realtime\\RealtimeFramework_se_v5.6_build654114"
postilion_self_extractor: "D:\\RealtimeFramework_se_v5.6_build654114.exe"
postilion_license_source: "D:\\postilion.lic"
postilion_license_dest: "C:\\Postilion\\realtime\\license\\postilion.lic"

# Database
postilion_db_server: "{{ ansible_hostname }}"
postilion_db_port: "1433"
postilion_db_schema: "dbo"
postilion_db_name: "realtime"
postilion_db_auth: "Windows Authentication"
postilion_db_location: "local"
postilion_db_data_device: "realtime_data"
postilion_db_log_device: "realtime_log"
postilion_db_data_path: "D:\\Program Files\\Microsoft SQL Server\\MSSQL15.MSSQLSERVER\\MSSQL\\data"
postilion_db_log_path: "D:\\Program Files\\Microsoft SQL Server\\MSSQL15.MSSQLSERVER\\MSSQL\\data"

# Service account
postilion_svc_hostname: "{{ ansible_hostname }}"
postilion_svc_domain: "{{ ansible_hostname }}"
postilion_svc_username: "Administrator"
postilion_svc_password: "{{ vault_postilion_svc_password }}"

# Application
postilion_default_currency: "Naira (566)"

# Timeouts
postilion_install_timeout: 900
postilion_screen_wait: 2000
```

## Installer GUI Flow (13 Screens)

The AutoIt script must handle these screens IN THIS EXACT ORDER. The main window title is always "Realtime Install Framework" except for conditional popups.

### Screen 1: Welcome
- Window: "Realtime Install Framework"
- Text contains: "Welcome to the Installation Wizard"
- Action: Click "Next >" button

### Screen 2: Destination Directory
- Window: "Realtime Install Framework"
- Text contains: "Destination Directory"
- Action: Clear the Edit field (CLASS:Edit, INSTANCE:1), type the install path (e.g. C:\Postilion), click "Next >"

### Screen 2a: Directory Exists (CONDITIONAL)
- Window: "Directory Exists"
- Text contains: "Are you sure you want to continue?"
- Action: Click "Yes"
- NOTE: Only appears if the destination directory already exists. Use WinWaitActive with 3-5 second timeout, then check WinExists.

### Screen 3: Installation Type
- Window: "Realtime Install Framework"
- Text contains: "Installation Type"
- Three radio buttons: "Principal Server" (default selected), "Auxiliary Server", "Console Client"
- Action: Ensure "Principal Server" is selected (it is by default), click "Next >"

### Screen 4: License Validation
- Window: "Realtime Install Framework"
- Text contains: "License Validation"
- Edit field contains license file path
- Action: If path needs changing, clear and type new path. Click "Next >"
- NOTE: Pre-copying the license to C:\Postilion\realtime\license\postilion.lic means the default path should be correct.

### Screen 5: Realtime Framework Data Source
- Window: "Realtime Install Framework"
- Text contains: "Realtime Framework Data Source"
- Fields:
  - Platform: "Microsoft SQL Server" (read-only, greyed out)
  - Server: Edit field (hostname, e.g. POST-TEST)
  - Port: Edit field (default 1433)
  - Schema: Edit field (default "dbo")
  - Database: Edit field (default "realtime")
  - Authentication: Dropdown — "Windows Authentication" or "SQL Server Authentication"
  - Login: Edit field (greyed out if Windows Auth)
  - Password: Edit field (greyed out if Windows Auth)
- Action: Verify/set Server name, verify other defaults, click "Next >"

### Screen 6: Realtime Framework Database
- Window: "Realtime Install Framework"
- Text contains: "Realtime Framework Database"
- Radio buttons: "Local database server" (default), "Remote database server"
- Fields: Database Name, Data Device Name, Data Device Filename, Log Device Name, Log Device Filename
- Action: Ensure "Local database server" is selected, verify fields, click "Next >"

### Screen 7: Services Server
- Window: "Realtime Install Framework"
- Text contains: "Services Server"
- Field: Server host name (auto-detected hostname)
- Action: Verify hostname, click "Next >"

### Screen 8: Service Account
- Window: "Realtime Install Framework"
- Text contains: "Service Account"
- Fields: Domain, Username, Password
- Action: Verify Domain, type Username, type Password, click "Next >"
- NOTE: "Next >" is greyed out until Username and Password are filled.

### Screen 8a: Logon As Service (CONDITIONAL)
- Window: "Logon As Service"
- Text contains: "Grant Logon As Service permission now?"
- Action: Click "Yes"
- NOTE: Only appears if the account doesn't already have SeServiceLogonRight. Can be pre-granted in prerequisites.

### Screen 9: Default Currency
- Window: "Realtime Install Framework"
- Text contains: "Default Currency"
- Dropdown: List of currencies
- Action: Select "Naira (566)" from dropdown, click "Next >"
- NOTE: For AutoIt dropdown selection, use ControlCommand with "SelectString".

### Screen 10: Ready to Install
- Window: "Realtime Install Framework"
- Text contains: "Ready to Install"
- Action: Click "Next >"

### Screen 10a: Event Viewer Warning (CONDITIONAL)
- Window: "Event Viewer"
- Text contains: "Windows Event Viewer is closed"
- Action: Click "OK"
- NOTE: Only appears if Event Viewer (mmc.exe) is running. Can be pre-closed in prerequisites.

### Screen 11: Install in Progress
- Window: "Realtime Install Framework"
- Text contains: "Install in progress"
- Action: WAIT. Do not click anything. Use WinWaitActive for the next screen with a long timeout (600+ seconds).

### Screen 12: PCI DSS Considerations
- Window: "Realtime Install Framework"
- Text contains: "PCI DSS considerations"
- Action: Click "Next >"

### Screen 13: Installation Complete
- Window: "Realtime Install Framework"
- Text contains: "Installation Complete"
- Action: Click "Finish"

## AutoIt Coding Standards

When generating AutoIt (.au3) code:

1. **Always use explicit waits**: `WinWaitActive("title", "text", timeout)` before any interaction
2. **Always add Sleep() after clicks**: Minimum 1000ms between actions to let GUI respond
3. **Always handle timeouts**: Check return value of WinWaitActive, log and exit on failure
4. **Use ControlClick over Send**: ControlClick is more reliable than sending keystrokes
5. **Use ControlSetText for text fields**: More reliable than clicking and typing
6. **Log every action**: Write to a log file with timestamps
7. **Use meaningful exit codes**:
   - 0 = Success
   - 1 = Timeout waiting for screen
   - 2 = Unexpected window/error
   - 3 = Control not found
   - 99 = Fatal/unhandled error
8. **Handle conditional popups with If WinExists() after a short Sleep()**
9. **Use variables for all installation values** — never hardcode paths, credentials, or config
10. **Screen identification**: Use window title + partial text match for reliability

### AutoIt Template Pattern

```autoit
; === Configuration (injected by Ansible/Jinja2) ===
Local $installDir = "{{ postilion_install_dir }}"
Local $dbServer = "{{ postilion_db_server }}"
; ... etc

; === Logging ===
Func _Log($msg)
    Local $timestamp = @YEAR & "-" & @MON & "-" & @MDAY & " " & @HOUR & ":" & @MIN & ":" & @SEC
    FileWriteLine($logFile, $timestamp & " | " & $msg)
EndFunc

; === Screen Handler Pattern ===
Func _HandleScreen($screenName, $expectedText, $timeout = 60)
    _Log("Waiting for: " & $screenName)
    Local $result = WinWaitActive("Realtime Install Framework", $expectedText, $timeout)
    If $result = 0 Then
        _Log("ERROR: Timeout waiting for " & $screenName)
        Exit 1
    EndIf
    _Log("Found: " & $screenName)
    Sleep($screenWait)
EndFunc

; === Conditional Popup Handler Pattern ===
Func _HandlePopup($title, $buttonText, $waitTime = 3)
    Sleep($waitTime * 1000)
    If WinExists($title) Then
        _Log("Popup detected: " & $title)
        ControlClick($title, "", "[TEXT:" & $buttonText & "]")
        Sleep(1000)
        Return True
    EndIf
    Return False
EndFunc
```

## Ansible Coding Standards

When generating Ansible playbooks and roles:

1. **Use FQCN**: Always use fully qualified collection names (e.g. `ansible.windows.win_shell`, not `win_shell`)
2. **Use win_* modules**: `win_shell`, `win_command`, `win_copy`, `win_file`, `win_service`, `win_stat`, `win_user_right`, `win_package`
3. **Idempotency**: Always check if action is needed before performing it (use `creates:`, `when:`, `win_stat`)
4. **Error handling**: Use `register:` + `failed_when:` for custom failure conditions
5. **Vault for secrets**: Never put passwords in plaintext — always reference `vault_` prefixed variables
6. **Timeouts**: Set explicit `timeout:` on long-running tasks (installer can take 10+ minutes)
7. **Tags**: Tag each phase for selective execution (`prerequisites`, `extract`, `install`, `validate`)
8. **Handlers**: Use handlers for actions that should only run on change (e.g. restart services)
9. **WinRM connection vars**:

```yaml
ansible_connection: winrm
ansible_winrm_transport: ntlm
ansible_winrm_server_cert_validation: ignore
ansible_port: 5986
```

### Key Ansible Task Patterns

#### Launching installer in background + running AutoIt
```yaml
- name: Launch Postilion installer in background
  ansible.windows.win_shell: |
    Start-Process -FilePath "{{ postilion_installer_source }}\\setup.exe" -PassThru
  register: installer_process

- name: Run AutoIt GUI automation script
  ansible.windows.win_command: "C:\\temp\\postilion_install.exe"
  timeout: "{{ postilion_install_timeout }}"
  register: autoit_result
  failed_when: autoit_result.rc != 0
```

#### Pre-granting SeServiceLogonRight
```yaml
- name: Grant Log on as Service right to service account
  ansible.windows.win_user_right:
    name: SeServiceLogonRight
    users:
      - "{{ postilion_svc_domain }}\\{{ postilion_svc_username }}"
    action: add
```

#### Silent extraction of WinZip self-extractor
```yaml
- name: Extract Postilion installer silently
  ansible.windows.win_command: >
    D:\RealtimeFramework_se_v5.6_build654114.exe /auto "D:\Postilion"
  args:
    creates: "D:\\Postilion\\Postilion\\Realtime\\RealtimeFramework_se_v5.6_build654114\\setup.exe"
```

#### Post-install validation
```yaml
- name: Verify Postilion installation directory
  ansible.windows.win_stat:
    path: "{{ postilion_install_dir }}\\realtime"
  register: install_dir
  failed_when: not install_dir.stat.exists

- name: Verify Postilion services exist
  ansible.windows.win_shell: |
    Get-Service | Where-Object { $_.DisplayName -like "*Postilion*" -or $_.DisplayName -like "*Realtime*" } | ConvertTo-Json
  register: postilion_services

- name: Verify realtime database exists
  ansible.windows.win_shell: |
    Invoke-Sqlcmd -Query "SELECT name FROM sys.databases WHERE name = 'realtime'" -ServerInstance "{{ postilion_db_server }}"
  register: db_check
  failed_when: "'realtime' not in db_check.stdout"
```

## Important Notes for Code Generation

1. **The installer is GUI-only**: Do not attempt silent install flags — they do not work. AutoIt is required.
2. **setupc.exe is NOT console-mode**: It extracts in console but launches the same GUI wizard. Use setup.exe.
3. **Self-extractor is WinZip format**: Use `/auto "path"` for silent extraction.
4. **SQL Server must be pre-installed**: The installer requires it for database creation.
5. **License file must exist before installation**: Pre-copy to `C:\Postilion\realtime\license\postilion.lic`.
6. **Currency dropdown**: AutoIt should use `ControlCommand($hwnd, "", "[CLASS:ComboBox; INSTANCE:1]", "SelectString", "Naira (566)")` for reliable selection.
7. **Three conditional popups** exist — the AutoIt script must handle all three even if prerequisites eliminate some of them:
   - "Directory Exists" — when install path already exists
   - "Logon As Service" — when account lacks the privilege
   - "Event Viewer" — when mmc.exe is running
8. **Window title consistency**: The main installer always uses "Realtime Install Framework". Popups have their own titles ("Directory Exists", "Logon As Service", "Event Viewer").
9. **The installation takes several minutes**: The progress screen (Screen 11) requires a long wait timeout — at least 600 seconds.
10. **Post-install**: The installer creates Windows services and database tables. Validate both.

## Generating Files

When I ask you to generate a specific file, follow these guidelines:

- **For .au3 files**: Follow the AutoIt coding standards above. Use the template pattern. Make all values parameterized.
- **For .yml playbooks**: Follow Ansible coding standards. Use FQCN. Include tags. Handle idempotency.
- **For Jinja2 templates (.j2)**: Use Ansible variable names from the Key Variables section.
- **For inventory files**: Use YAML format. Include connection vars.
- **For README files**: Include setup instructions, prerequisites, usage examples, and troubleshooting.

## Example Prompts for Copilot

Use these prompts to generate specific files:

1. "Generate the ansible.cfg file for this project"
2. "Generate the inventory/hosts.yml with Windows connection settings"
3. "Generate the group_vars/postilion_servers.yml with all variables"
4. "Generate the AutoIt script postilion_install.au3 that handles all 13 screens"
5. "Generate the Jinja2 template postilion_install.au3.j2 with Ansible variables"
6. "Generate the prerequisites playbook 01_prerequisites.yml"
7. "Generate the extract playbook 02_extract_installer.yml"
8. "Generate the install playbook 03_install_realtime.yml that uses AutoIt"
9. "Generate the validation playbook 04_validate.yml"
10. "Generate the site.yml that orchestrates all phases"
11. "Generate the role tasks/main.yml that imports all task files"
12. "Generate a PowerShell verification script to validate the installation"

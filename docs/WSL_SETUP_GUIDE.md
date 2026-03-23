# Postilion Automation — WSL Setup Guide

Step-by-step guide to running the Postilion Realtime deployment playbooks from **Ubuntu on WSL** (Windows Subsystem for Linux) targeting a remote **Windows Server 2022**.

---

## Step 1: Install Ansible + WinRM on WSL Ubuntu

```bash
# Update packages
sudo apt update && sudo apt upgrade -y

# Install Python 3 and pip
sudo apt install -y python3 python3-pip python3-venv

# Create a virtual environment (recommended)
python3 -m venv ~/ansible-venv
source ~/ansible-venv/bin/activate

# Install Ansible and WinRM support
pip install ansible pywinrm requests-ntlm

# Install the Windows Ansible collection
ansible-galaxy collection install ansible.windows
```

---

## Step 2: Access the Project from WSL

Your Windows workspace is accessible from WSL at:

```bash
cd /mnt/c/Users/lourash/Documents/Lou_Workspace/Postilion_Automation
```

Alternatively, clone to your WSL home for better filesystem performance:

```bash
cd ~
git clone <your-repo-url> Postilion_Automation
cd Postilion_Automation
```

> **Tip**: Ansible runs faster on native Linux filesystem (`~/`) than on `/mnt/c/` due to WSL filesystem translation overhead.

---

## Step 3: Configure Target Server

### 3a. Set the target IP

Edit `inventory/hosts.yml` — replace `192.168.1.100` with your actual Windows Server IP:

```yaml
postilion-srv01:
  ansible_host: 10.0.0.50  # your actual server IP or hostname
```

### 3b. Set credentials

Edit `inventory/group_vars/all.yml` — set the real credentials:

```yaml
ansible_user: "Administrator"
ansible_password: "YourActualPassword"
postilion_svc_password: "YourActualPassword"
```

Also update the matching credentials in `inventory/hosts.yml`.

---

## Step 4: Configure WinRM on the Target Windows Server

On the **target Windows Server 2022**, run these in an **elevated PowerShell**:

### Enable WinRM

```powershell
winrm quickconfig -force

winrm set winrm/config/service '@{AllowUnencrypted="true"}'
winrm set winrm/config/service/auth '@{Basic="true"}'
winrm set winrm/config/service/auth '@{Negotiate="true"}'
```

### Option A: HTTPS Listener (recommended — matches port 5986 config)

```powershell
# Create a self-signed certificate
$cert = New-SelfSignedCertificate -DnsName $env:COMPUTERNAME -CertStoreLocation Cert:\LocalMachine\My

# Create HTTPS listener
winrm create winrm/config/listener?Address=*+Transport=HTTPS `
  "@{Hostname=`"$env:COMPUTERNAME`";CertificateThumbprint=`"$($cert.Thumbprint)`"}"

# Open firewall for HTTPS
New-NetFirewallRule -Name "WinRM-HTTPS" -DisplayName "WinRM HTTPS" `
  -Protocol TCP -LocalPort 5986 -Action Allow
```

### Option B: HTTP Listener (simpler for lab/dev)

```powershell
# Open firewall for HTTP
New-NetFirewallRule -Name "WinRM-HTTP" -DisplayName "WinRM HTTP" `
  -Protocol TCP -LocalPort 5985 -Action Allow
```

If using HTTP, update `inventory/hosts.yml`:

```yaml
ansible_port: 5985
ansible_winrm_scheme: http
```

### Verify listeners

```powershell
winrm enumerate winrm/config/listener
```

---

## Step 5: Test Connectivity from WSL

```bash
# Activate venv if you created one
source ~/ansible-venv/bin/activate

# Navigate to project
cd /mnt/c/Users/lourash/Documents/Lou_Workspace/Postilion_Automation

# Ping test
ansible postilion_servers -m ansible.windows.win_ping
```

Expected success output:

```
postilion-srv01 | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
```

### Common connectivity failures

| Error | Fix |
|-------|-----|
| `Connection refused` | WinRM listener not created, or firewall blocking port |
| `401 Unauthorized` | Wrong username/password, or Basic auth not enabled |
| `SSL: CERTIFICATE_VERIFY_FAILED` | Already handled by `ansible_winrm_server_cert_validation: ignore` |
| `Connection timed out` | Wrong IP, server not reachable from WSL, or firewall |

---

## Step 6: Prepare the Target Server Files

Before running the playbooks, ensure these files exist on the **target Windows Server**:

| File | Location | Purpose |
|------|----------|---------|
| Installer | `D:\RealtimeFramework_se_v5.6_build654114.exe` | WinZip self-extractor |
| License | `D:\postilion.lic` | Postilion license file |

---

## Step 7: Compile the AutoIt Script

On **any Windows machine** with AutoIt v3 installed:

```powershell
cd C:\Users\lourash\Documents\Lou_Workspace\Postilion_Automation\scripts\autoit
.\compile_autoit.ps1

# Copy the compiled .exe to the role files directory
Copy-Item postilion_install.exe ..\..\roles\postilion_realtime\files\
```

Download AutoIt v3: https://www.autoitscript.com/site/autoit/downloads/

---

## Step 8: Deploy

From WSL:

```bash
source ~/ansible-venv/bin/activate

# If you cloned to WSL home:
cd ~/Postilion_Automation

# OR if running from the Windows filesystem:
# cd /mnt/c/Users/lourash/Documents/Lou_Workspace/Postilion_Automation

# Run all 4 phases
ansible-playbook playbooks/site.yml

# Or run phases individually
ansible-playbook playbooks/01_prerequisites.yml
ansible-playbook playbooks/02_extract_installer.yml
ansible-playbook playbooks/03_install_realtime.yml
ansible-playbook playbooks/04_validate.yml

# Run only validation
ansible-playbook playbooks/site.yml --tags validate

# Verbose output for troubleshooting
ansible-playbook playbooks/site.yml -vvv
```

---

## WSL-Specific Gotchas

### 1. File permissions warning

Ansible may warn about `ansible.cfg` being world-writable on `/mnt/c/`. Fix with:

```bash
export ANSIBLE_CONFIG=/mnt/c/Users/lourash/Documents/Lou_Workspace/Postilion_Automation/ansible.cfg
```

Or clone the repo to `~/` instead of running from `/mnt/c/`.

### 2. Line endings (CRLF vs LF)

If you edit files on Windows, they may get CRLF line endings. Ansible handles YAML fine, but if you see odd parse errors:

```bash
sudo apt install dos2unix
find . -name "*.yml" -exec dos2unix {} \;
```

### 3. DNS resolution

WSL may not resolve Windows hostnames. Use **IP addresses** in `ansible_host` instead of hostnames.

### 4. Network connectivity

Ensure WSL can reach the target server:

```bash
# Bypass proxy for the target server (critical in corporate environments)
export no_proxy=172.26.42.122
export NO_PROXY=172.26.42.122

# Add to ~/.bashrc to make permanent:
echo 'export no_proxy=172.26.42.122' >> ~/.bashrc
echo 'export NO_PROXY=172.26.42.122' >> ~/.bashrc

# Basic ping test
ping 172.26.42.122

# WinRM port test (should get 405 or auth error, NOT timeout)
curl -k https://172.26.42.122:5986/wsman
```

> **Important**: If your WSL uses a corporate proxy, WinRM connections will fail with `Connection refused` unless you add the target IP to `no_proxy` / `NO_PROXY`. This must be set **before** running any `ansible-playbook` commands.

If WSL cannot reach the target, check:
- WSL networking mode (NAT vs bridged)
- Windows firewall on both the WSL host and the target
- VPN or network segmentation

### 5. Virtual environment activation

Always activate the Python venv before running Ansible commands:

```bash
source ~/ansible-venv/bin/activate
```

Add to `~/.bashrc` for convenience:

```bash
echo 'alias ansible-env="source ~/ansible-venv/bin/activate"' >> ~/.bashrc
source ~/.bashrc
```

---

## Quick Reference

| Action | Command |
|--------|---------|
| Activate venv | `source ~/ansible-venv/bin/activate` |
| Test connectivity | `ansible postilion_servers -m ansible.windows.win_ping` |
| Full deploy | `ansible-playbook playbooks/site.yml` |
| Prerequisites only | `ansible-playbook playbooks/site.yml --tags prerequisites` |
| Validate only | `ansible-playbook playbooks/site.yml --tags validate` |
| Verbose mode | `ansible-playbook playbooks/site.yml -vvv` |
| Check mode (dry run) | `ansible-playbook playbooks/site.yml --check` |

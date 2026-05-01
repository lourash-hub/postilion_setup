# Postilion Patch Deployment Guide

## Overview

The patch automation installs Postilion Realtime Framework patches using AutoIt GUI automation with the same Session 0 workaround as the main installer. Patches are installed in ascending order (oldest first) and already-installed patches are automatically skipped.

## Prerequisites

### On the Control Node (WSL/Linux)

1. **Ansible 2.15+** with `ansible.windows` collection
2. **pywinrm** library installed (`pip install pywinrm`)
3. **ANSIBLE_CONFIG** must be set explicitly when running from WSL on an NTFS mount:
   ```bash
   export ANSIBLE_CONFIG=./ansible.cfg
   ```
   This is required because WSL treats NTFS directories as world-writable and ignores `ansible.cfg` otherwise.

### On the Target Windows Server

1. **Postilion Realtime Framework v5.6** must be installed first (run the main installer playbook)
2. **WinRM** enabled and accessible from the control node
3. **Patch files** placed in `D:\Patches` (or custom path) on the target server
4. **Interactive RDP session** — a user must be logged into the desktop (the automation runs GUI automation via scheduled task in the interactive session)

### Compiling the AutoIt Patch Script (One-Time Setup)

The patch automation uses the same pattern as the main installer — a **pre-compiled AutoIt `.exe`** that is copied from the control node to the target at runtime. AutoIt does **not** need to be installed on the target server.

You need a Windows machine with AutoIt v3 installed to compile. This only needs to be done **once** (or when you modify `scripts/autoit/postilion_patch.au3`).

**Steps:**

1. Install AutoIt v3 on any Windows machine (your dev workstation, not the target server):
   https://www.autoitscript.com/site/autoit/downloads/

2. Compile the patch script:
   ```powershell
   cd scripts\autoit
   .\compile_autoit.ps1 -Au3Source postilion_patch.au3 -OutputExe postilion_patch.exe
   ```

3. Copy the compiled `.exe` into the role's files directory:
   ```powershell
   Copy-Item postilion_patch.exe ..\..\roles\postilion_patches\files\
   ```

4. Commit `roles/postilion_patches/files/postilion_patch.exe` to the repo.

**When do I need to recompile?**

Only if you change the AutoIt GUI automation logic in `scripts/autoit/postilion_patch.au3`. Per-patch variables (patch name, log file, timeouts) are read from a config INI file at runtime, so adding new patches does **not** require recompilation.

## Patch File Setup

Place patch `.exe` files in `D:\Patches` on the target server:

```
D:\Patches\
├── RealtimeFramework_v5.6_patch144_build788965.exe    (202 MB)
├── RealtimeFramework_v5.6_patch221_build839428.exe
└── (any other patch .exe files)
```

The automation will:
1. Discover all files matching `RealtimeFramework_v5.6_patch*.exe`
2. Sort them in ascending order (patch 144 before patch 221)
3. For each patch, check if it's already installed before proceeding

### Idempotency

Before installing each patch, the automation checks `C:\Postilion\realtime` for a directory matching the pattern `*Patch_NNN*` (e.g., `Realtime Framework_v5.6.00_Patch_221`). If found, the patch is skipped with a message. This makes it safe to re-run the playbook — only new patches will be installed.

## Running the Playbook

### Option 1: Standalone Patch Playbook (Recommended)

```bash
# From the project root, with ANSIBLE_CONFIG set:
export ANSIBLE_CONFIG=./ansible.cfg

# Install all pending patches
ansible-playbook playbooks/05_patch_realtime.yml

# Install patches from a different directory
ansible-playbook playbooks/05_patch_realtime.yml -e postilion_patches_dir=D:\\OtherPatches

# Skip service stop/start (if you manage services manually)
ansible-playbook playbooks/05_patch_realtime.yml -e postilion_patch_manage_services=false
```

### Option 2: Via site.yml (Full Deployment)

```bash
# Run everything (install + patch)
ansible-playbook playbooks/site.yml

# Run only the patch phase
ansible-playbook playbooks/site.yml --tags patch
```

### Option 3: Run Individual Phases

```bash
# Run only prerequisites check
ansible-playbook playbooks/01_prerequisites.yml

# Run only the patch phase
ansible-playbook playbooks/05_patch_realtime.yml
```

## What the Automation Does (Per Patch)

| Step | Action | Details |
|------|--------|---------|
| 0 | **Idempotency check** | Looks for `*Patch_NNN*` directory in `C:\Postilion\realtime` |
| 1 | **Extract** | Runs the patch `.exe` with `/auto` flag (WinZip self-extractor) |
| 2 | **Find setup.exe** | Locates `setup*.exe` in the extracted directory |
| 3 | **Generate config INI** | Writes per-patch config (name, log path, timeouts) to `C:\temp\patch_config.ini` |
| 4 | **Create launcher** | Renders `patch_launcher.ps1.j2` (starts setup.exe, waits for window, launches AutoIt `.exe`) |
| 5 | **Scheduled task** | Creates and runs `PostilionPatch` task with `LogonType Interactive` |
| 6 | **Wait** | Polls scheduled task state every 10 seconds until completion or timeout |
| 7 | **Cleanup** | Removes temp scripts, config INI, scheduled task, and exit code marker |

### How It Works — Compiled .exe + INI Config

Unlike the main installer (which uses a Jinja2 template `.au3` with baked-in variables), the patch automation uses a **compiled `.exe`** that reads its configuration from an **INI file** at runtime:

```
postilion_patch.exe "C:\temp\patch_config.ini"
```

This means:
- The `.exe` is compiled **once** and stored in the repo
- Per-patch variables are written to `patch_config.ini` by Ansible before each patch
- No AutoIt interpreter needed on the target server (the runtime is bundled in the `.exe`)
- No recompilation needed when adding new patches

### GUI Flow (Automated by AutoIt)

```
Screen 1: Welcome                → Click Next >
          [Event Viewer popup?]  → Click OK (if it appears)
Screen 2: Ready to Install       → Click Next >
          [Event Viewer popup?]  → Click OK (if it appears)
Screen 3: Install in progress    → Wait for progress bar
Screen 4: Installation Complete  → Click Finish
```

## Configuration Variables

Override any of these with `-e variable=value` on the command line:

| Variable | Default | Description |
|----------|---------|-------------|
| `postilion_patches_dir` | `D:\Patches` | Directory containing patch `.exe` files |
| `postilion_install_dir` | `C:\Postilion` | Postilion install directory (for idempotency check) |
| `postilion_patch_timeout` | `900` | Timeout per patch in seconds |
| `postilion_patch_screen_wait` | `2000` | Milliseconds to wait after each screen action |
| `postilion_patch_popup_wait` | `3` | Seconds to wait for Event Viewer popup |
| `postilion_patch_progress_timeout` | `600` | Seconds to wait for progress bar to complete |
| `postilion_patch_manage_services` | `true` | Stop/start Postilion services around patching |
| `postilion_patch_cleanup` | `true` | Remove temp files after patching |

## Logs and Troubleshooting

### Log Files

Each patch produces an AutoIt log at:
```
C:\logs\patch_autoit_RealtimeFramework_v5.6_patchNNN_buildXXXXXX.log
```

### AutoIt Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Timeout waiting for a screen |
| 2 | Unexpected error |
| 3 | Control not found |
| 99 | Fatal error / postilion_patch.exe not found |

### Common Issues

**1. Task hangs / timeout**
- Ensure an RDP session is active on the target server (GUI automation requires an interactive desktop)
- Check if Event Viewer is open — the automation closes `mmc.exe` but it may reopen
- Review the AutoIt log for which screen it was waiting on

**2. "Patch already installed" when it shouldn't be**
- Check `C:\Postilion\realtime` for directories matching `*Patch_NNN*`
- The idempotency check uses the patch number extracted from the filename

**3. "postilion_patch.exe not found"**
- Compile the AutoIt script and place it at `roles/postilion_patches/files/postilion_patch.exe`
- See the "Compiling the AutoIt Patch Script" section above

**4. ansible.cfg ignored (WSL)**
- Always set `export ANSIBLE_CONFIG=./ansible.cfg` before running playbooks from WSL
- Alternatively, set it inline: `ANSIBLE_CONFIG=./ansible.cfg ansible-playbook ...`

## Role File Structure

```
roles/postilion_patches/
├── defaults/main.yml                          # Default variables
├── files/
│   ├── README.md                              # Compilation instructions
│   └── postilion_patch.exe                    # Compiled AutoIt script (you must compile this)
├── tasks/
│   ├── main.yml                               # Entry point (imports patch.yml)
│   ├── patch.yml                              # Orchestrator (discover, loop, services)
│   └── install_single_patch.yml               # Per-patch logic (extract, scheduled task, wait)
└── templates/
    ├── patch_config.ini.j2                    # Per-patch config INI (read by the .exe at runtime)
    └── patch_launcher.ps1.j2                  # PowerShell launcher for interactive session

scripts/autoit/
├── postilion_patch.au3                        # AutoIt source (compile this → postilion_patch.exe)
├── compile_autoit.ps1                         # Compilation helper script
└── postilion_install.au3                      # Main installer AutoIt source (separate)
```

# AutoIt Scripts

## Overview

The AutoIt scripts automate the Postilion Realtime Framework GUI installer which has no silent/unattended mode.

## Files

| File | Purpose |
|------|---------|
| `postilion_install.au3` | Standalone AutoIt source (hardcoded defaults for testing) |
| `compile_autoit.ps1` | PowerShell script to compile `.au3` to `.exe` |

## Jinja2 Template

The Ansible role uses a Jinja2 template version of this script:
- Location: `roles/postilion_realtime/templates/postilion_install.au3.j2`
- Variables are injected by Ansible at runtime
- The template version should be used for all Ansible deployments

## Compiling

### Prerequisites
- AutoIt v3 installed: https://www.autoitscript.com/site/autoit/downloads/

### Steps

```powershell
# Compile using the helper script
.\compile_autoit.ps1

# Or compile manually
& "C:\Program Files (x86)\AutoIt3\Aut2Exe\Aut2exe.exe" /in postilion_install.au3 /out postilion_install.exe /nopack

# Copy compiled .exe to role files directory
Copy-Item postilion_install.exe ..\..\roles\postilion_realtime\files\
```

## Testing

1. Launch `setup.exe` from the extracted Postilion installer
2. Run the `.au3` script in AutoIt SciTE editor for debugging
3. Check `C:\logs\postilion_autoit_install.log` for results

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Timeout waiting for screen |
| 2 | Unexpected window/error |
| 3 | Control not found |
| 99 | Fatal/unhandled error |

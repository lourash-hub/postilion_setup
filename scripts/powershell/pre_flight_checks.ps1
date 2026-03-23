# =============================================================================
# pre_flight_checks.ps1 — Pre-flight checks before Postilion installation
# =============================================================================
# Run on the target Windows Server BEFORE starting the Postilion deployment.
# Usage: .\pre_flight_checks.ps1 [-InstallerPath "D:\RealtimeFramework...exe"]
# =============================================================================

[CmdletBinding()]
param(
    [string]$InstallerPath = "D:\RealtimeFramework_se_v5.6_build654114.exe",
    [string]$LicenseSource = "D:\postilion.lic",
    [string]$InstallDir = "C:\Postilion",
    [string]$DbServer = $env:COMPUTERNAME,
    [int]$RequiredDiskSpaceMB = 1024
)

$ErrorActionPreference = "Continue"
$passCount = 0
$failCount = 0
$warnCount = 0

function Test-PreFlight {
    param(
        [string]$Name,
        [string]$Status,  # PASS, FAIL, WARN
        [string]$Detail = ""
    )
    $color = switch ($Status) {
        "PASS" { "Green" }
        "FAIL" { "Red" }
        "WARN" { "Yellow" }
        default { "White" }
    }
    Write-Host "  [$Status] $Name" -ForegroundColor $color
    if ($Detail) { Write-Host "         $Detail" -ForegroundColor Gray }
    switch ($Status) {
        "PASS" { $script:passCount++ }
        "FAIL" { $script:failCount++ }
        "WARN" { $script:warnCount++ }
    }
}

Write-Host ""
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host " POSTILION PRE-FLIGHT CHECKS" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host " Server:    $env:COMPUTERNAME"
Write-Host " OS:        $((Get-CimInstance Win32_OperatingSystem).Caption)"
Write-Host " Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""

# --- 1. Operating System ---
Write-Host "1. Operating System" -ForegroundColor Yellow
$os = Get-CimInstance Win32_OperatingSystem
$isServer2022 = $os.Caption -like "*2022*"
Test-PreFlight "Windows Server 2022" $(if ($isServer2022) { "PASS" } else { "WARN" }) $os.Caption

# --- 2. Disk Space ---
Write-Host ""
Write-Host "2. Disk Space" -ForegroundColor Yellow
$cDrive = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
$cFreeGB = [math]::Round($cDrive.FreeSpace / 1GB, 2)
Test-PreFlight "C: drive free space >= $($RequiredDiskSpaceMB)MB" $(if ($cFreeGB * 1024 -ge $RequiredDiskSpaceMB) { "PASS" } else { "FAIL" }) "$cFreeGB GB free"

$dDrive = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='D:'" -ErrorAction SilentlyContinue
if ($dDrive) {
    $dFreeGB = [math]::Round($dDrive.FreeSpace / 1GB, 2)
    Test-PreFlight "D: drive available" "PASS" "$dFreeGB GB free"
} else {
    Test-PreFlight "D: drive available" "WARN" "D: drive not found — adjust paths if needed"
}

# --- 3. .NET Framework ---
Write-Host ""
Write-Host "3. .NET Framework" -ForegroundColor Yellow
$dotnetRelease = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full" -ErrorAction SilentlyContinue).Release
if ($dotnetRelease -ge 528040) {
    Test-PreFlight ".NET Framework 4.8+ installed" "PASS" "Release: $dotnetRelease"
} elseif ($dotnetRelease) {
    Test-PreFlight ".NET Framework 4.8+ installed" "FAIL" "Release: $dotnetRelease (need >= 528040)"
} else {
    Test-PreFlight ".NET Framework 4.8+ installed" "FAIL" ".NET 4.x not detected"
}

# --- 4. SQL Server ---
Write-Host ""
Write-Host "4. SQL Server" -ForegroundColor Yellow
$sqlService = Get-Service -Name "MSSQLSERVER" -ErrorAction SilentlyContinue
if ($sqlService) {
    Test-PreFlight "SQL Server service installed" "PASS" "Status: $($sqlService.Status)"
    if ($sqlService.Status -eq "Running") {
        Test-PreFlight "SQL Server service running" "PASS" ""
    } else {
        Test-PreFlight "SQL Server service running" "FAIL" "Status: $($sqlService.Status) — start MSSQLSERVER service"
    }

    # Test connectivity
    try {
        $sqlTest = Invoke-Sqlcmd -Query "SELECT @@VERSION AS Version" -ServerInstance $DbServer -ErrorAction Stop
        Test-PreFlight "SQL Server connectivity" "PASS" ($sqlTest.Version -split "`n")[0]
    } catch {
        Test-PreFlight "SQL Server connectivity" "FAIL" $_.Exception.Message
    }
} else {
    Test-PreFlight "SQL Server service installed" "FAIL" "MSSQLSERVER service not found"
}

# --- 5. Installer files ---
Write-Host ""
Write-Host "5. Installation Files" -ForegroundColor Yellow
Test-PreFlight "Installer exists" $(if (Test-Path $InstallerPath) { "PASS" } else { "FAIL" }) $InstallerPath
Test-PreFlight "License file exists" $(if (Test-Path $LicenseSource) { "PASS" } else { "FAIL" }) $LicenseSource

# --- 6. WinRM ---
Write-Host ""
Write-Host "6. WinRM Configuration" -ForegroundColor Yellow
$winrm = Get-Service -Name "WinRM" -ErrorAction SilentlyContinue
if ($winrm -and $winrm.Status -eq "Running") {
    Test-PreFlight "WinRM service running" "PASS" ""

    # Check HTTPS listener
    $httpsListener = Get-ChildItem WSMan:\localhost\Listener -ErrorAction SilentlyContinue |
        Where-Object { $_.Keys -contains "Transport=HTTPS" }
    if ($httpsListener) {
        Test-PreFlight "WinRM HTTPS listener" "PASS" "Port 5986"
    } else {
        Test-PreFlight "WinRM HTTPS listener" "WARN" "No HTTPS listener found — Ansible requires HTTPS"
    }
} else {
    Test-PreFlight "WinRM service running" "FAIL" "WinRM is required for Ansible connectivity"
}

# --- 7. Check for existing Postilion installation ---
Write-Host ""
Write-Host "7. Existing Installation" -ForegroundColor Yellow
if (Test-Path "$InstallDir\realtime") {
    Test-PreFlight "Previous install detected" "WARN" "$InstallDir\realtime exists — installer will ask to overwrite"
} else {
    Test-PreFlight "Clean installation target" "PASS" "$InstallDir\realtime does not exist"
}

# Check for running Postilion processes
$postilionProcs = Get-Process | Where-Object { $_.ProcessName -like "*postilion*" -or $_.ProcessName -like "*realtime*" }
if ($postilionProcs) {
    Test-PreFlight "No Postilion processes running" "WARN" "$($postilionProcs.Count) process(es) detected"
} else {
    Test-PreFlight "No Postilion processes running" "PASS" ""
}

# --- 8. Event Viewer ---
Write-Host ""
Write-Host "8. Event Viewer (mmc.exe)" -ForegroundColor Yellow
$mmc = Get-Process -Name "mmc" -ErrorAction SilentlyContinue
if ($mmc) {
    Test-PreFlight "Event Viewer not running" "WARN" "mmc.exe is running — will trigger popup during install"
} else {
    Test-PreFlight "Event Viewer not running" "PASS" ""
}

# --- Summary ---
Write-Host ""
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host " SUMMARY: $passCount PASSED, $failCount FAILED, $warnCount WARNINGS" -ForegroundColor $(if ($failCount -eq 0) { "Green" } else { "Red" })
Write-Host "=============================================" -ForegroundColor Cyan

if ($failCount -gt 0) {
    Write-Host " STATUS: NOT READY — fix $failCount failure(s) before proceeding" -ForegroundColor Red
    exit 1
} elseif ($warnCount -gt 0) {
    Write-Host " STATUS: READY WITH WARNINGS — review $warnCount warning(s)" -ForegroundColor Yellow
    exit 0
} else {
    Write-Host " STATUS: READY FOR DEPLOYMENT" -ForegroundColor Green
    exit 0
}

# =============================================================================
# verify_installation.ps1 — Post-install verification for Postilion Realtime
# =============================================================================
# Runs on the target Windows Server to validate the installation.
# Usage: .\verify_installation.ps1 [-InstallDir "C:\Postilion"] [-DbServer "localhost"]
# =============================================================================

[CmdletBinding()]
param(
    [string]$InstallDir = "C:\Postilion",
    [string]$DbServer = $env:COMPUTERNAME,
    [string]$DbName = "realtime",
    [string]$LicensePath = "C:\Postilion\realtime\license\postilion.lic"
)

$ErrorActionPreference = "Continue"
$results = @()
$passCount = 0
$failCount = 0

function Test-Check {
    param([string]$Name, [bool]$Condition, [string]$Detail = "")
    $status = if ($Condition) { "PASS" } else { "FAIL" }
    $color = if ($Condition) { "Green" } else { "Red" }
    Write-Host "  [$status] $Name" -ForegroundColor $color
    if ($Detail) { Write-Host "         $Detail" -ForegroundColor Gray }
    if ($Condition) { $script:passCount++ } else { $script:failCount++ }
    return [PSCustomObject]@{
        Check  = $Name
        Status = $status
        Detail = $Detail
    }
}

Write-Host ""
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host " POSTILION REALTIME INSTALLATION VERIFICATION" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host " Server:      $env:COMPUTERNAME"
Write-Host " Install Dir: $InstallDir"
Write-Host " DB Server:   $DbServer"
Write-Host " DB Name:     $DbName"
Write-Host " Timestamp:   $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""

# --- 1. Installation directory ---
Write-Host "1. File System Checks" -ForegroundColor Yellow
$results += Test-Check "Installation directory exists" (Test-Path "$InstallDir\realtime") $InstallDir
$results += Test-Check "Bin directory exists" (Test-Path "$InstallDir\realtime\bin") "$InstallDir\realtime\bin"
$results += Test-Check "License file exists" (Test-Path $LicensePath) $LicensePath

# Count files in realtime directory
if (Test-Path "$InstallDir\realtime") {
    $fileCount = (Get-ChildItem -Path "$InstallDir\realtime" -Recurse -File).Count
    $results += Test-Check "Realtime directory has files" ($fileCount -gt 0) "$fileCount files found"
}

Write-Host ""

# --- 2. Windows Services ---
Write-Host "2. Windows Services" -ForegroundColor Yellow
$services = Get-Service | Where-Object {
    $_.DisplayName -like "*Postilion*" -or
    $_.DisplayName -like "*Realtime*" -or
    $_.ServiceName -like "*Postilion*" -or
    $_.ServiceName -like "*Realtime*"
}

$results += Test-Check "Postilion services exist" ($null -ne $services -and $services.Count -gt 0) "$($services.Count) service(s) found"

if ($services) {
    foreach ($svc in $services) {
        Write-Host "         Service: $($svc.DisplayName) [$($svc.ServiceName)] - Status: $($svc.Status)" -ForegroundColor Gray
    }
}

Write-Host ""

# --- 3. Database ---
Write-Host "3. Database Checks" -ForegroundColor Yellow
try {
    $dbExists = Invoke-Sqlcmd -Query "SELECT name, state_desc FROM sys.databases WHERE name = '$DbName'" -ServerInstance $DbServer -ErrorAction Stop
    $results += Test-Check "Database '$DbName' exists" ($null -ne $dbExists) "state=$($dbExists.state_desc)"

    if ($dbExists) {
        $tableCount = Invoke-Sqlcmd -Query "SELECT COUNT(*) AS TableCount FROM [$DbName].INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE = 'BASE TABLE'" -ServerInstance $DbServer -ErrorAction Stop
        $results += Test-Check "Database has tables" ($tableCount.TableCount -gt 0) "$($tableCount.TableCount) tables found"
    }
} catch {
    $results += Test-Check "Database connectivity" $false $_.Exception.Message
}

Write-Host ""

# --- 4. .NET Framework ---
Write-Host "4. Prerequisites" -ForegroundColor Yellow
$dotnetRelease = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full" -ErrorAction SilentlyContinue).Release
$results += Test-Check ".NET Framework 4.8+ installed" ($dotnetRelease -ge 528040) "Release: $dotnetRelease"

# SQL Server
$sqlService = Get-Service -Name "MSSQLSERVER" -ErrorAction SilentlyContinue
$results += Test-Check "SQL Server running" ($sqlService -and $sqlService.Status -eq 'Running') $sqlService.Status

Write-Host ""

# --- 5. Event Log ---
Write-Host "5. Event Log" -ForegroundColor Yellow
$errors = Get-EventLog -LogName Application -Newest 100 -EntryType Error -ErrorAction SilentlyContinue |
    Where-Object { $_.Message -like "*Postilion*" -or $_.Source -like "*Postilion*" }
$results += Test-Check "No Postilion errors in Event Log" ($null -eq $errors -or $errors.Count -eq 0) "$($errors.Count) error(s) found"

Write-Host ""

# --- Summary ---
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host " SUMMARY: $passCount PASSED, $failCount FAILED" -ForegroundColor $(if ($failCount -eq 0) { "Green" } else { "Red" })
Write-Host "=============================================" -ForegroundColor Cyan

# Return exit code
if ($failCount -gt 0) {
    Write-Host " RESULT: VERIFICATION FAILED" -ForegroundColor Red
    exit 1
} else {
    Write-Host " RESULT: ALL CHECKS PASSED" -ForegroundColor Green
    exit 0
}

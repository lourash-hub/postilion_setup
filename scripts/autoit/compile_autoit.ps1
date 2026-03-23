# =============================================================================
# compile_autoit.ps1 — Compiles AutoIt .au3 script to .exe
# =============================================================================
# Prerequisites: AutoIt v3 must be installed (default: C:\Program Files (x86)\AutoIt3)
# Usage: .\compile_autoit.ps1 [-Au3Source <path>] [-OutputExe <path>]
# =============================================================================

[CmdletBinding()]
param(
    [string]$Au3Source = "$PSScriptRoot\postilion_install.au3",
    [string]$OutputExe = "$PSScriptRoot\postilion_install.exe",
    [string]$AutoItPath = "C:\Program Files (x86)\AutoIt3"
)

$ErrorActionPreference = "Stop"

# --- Locate AutoIt compiler ---
$aut2exe = Join-Path $AutoItPath "Aut2Exe\Aut2exe.exe"

if (-not (Test-Path $aut2exe)) {
    # Try alternative locations
    $altPaths = @(
        "C:\Program Files\AutoIt3\Aut2Exe\Aut2exe.exe",
        "${env:ProgramFiles(x86)}\AutoIt3\Aut2Exe\Aut2exe.exe",
        "$env:ProgramFiles\AutoIt3\Aut2Exe\Aut2exe.exe"
    )

    $found = $false
    foreach ($alt in $altPaths) {
        if (Test-Path $alt) {
            $aut2exe = $alt
            $found = $true
            break
        }
    }

    if (-not $found) {
        Write-Error "AutoIt compiler (Aut2exe.exe) not found. Install AutoIt v3 from https://www.autoitscript.com/site/autoit/downloads/"
        exit 1
    }
}

Write-Host "AutoIt compiler: $aut2exe" -ForegroundColor Cyan

# --- Validate source file ---
if (-not (Test-Path $Au3Source)) {
    Write-Error "Source file not found: $Au3Source"
    exit 1
}

Write-Host "Source: $Au3Source" -ForegroundColor Cyan
Write-Host "Output: $OutputExe" -ForegroundColor Cyan

# --- Compile ---
Write-Host "Compiling..." -ForegroundColor Yellow

$compileArgs = @(
    "/in", $Au3Source,
    "/out", $OutputExe,
    "/nopack"
)

$process = Start-Process -FilePath $aut2exe -ArgumentList $compileArgs -Wait -PassThru -NoNewWindow
if ($process.ExitCode -ne 0) {
    Write-Error "Compilation failed with exit code: $($process.ExitCode)"
    exit 1
}

# --- Verify output ---
if (Test-Path $OutputExe) {
    $fileInfo = Get-Item $OutputExe
    Write-Host "Compilation successful!" -ForegroundColor Green
    Write-Host "  Output: $($fileInfo.FullName)" -ForegroundColor Green
    Write-Host "  Size:   $([math]::Round($fileInfo.Length / 1KB, 1)) KB" -ForegroundColor Green
} else {
    Write-Error "Compilation appeared to succeed, but output file not found: $OutputExe"
    exit 1
}

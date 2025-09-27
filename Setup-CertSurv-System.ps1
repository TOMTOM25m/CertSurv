#Requires -version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Certificate Surveillance System - Setup Script
.DESCRIPTION
    Basic setup script for Certificate Surveillance System.
    Initializes the system and loads required modules.
.NOTES
    Version: v1.2.1
    Author: GitHub Copilot
    Regelwerk: v9.5.0
#>

# Version Management (MANDATORY - Regelwerk v9.5.0)
if (Test-Path "$PSScriptRoot\VERSION.ps1") {
    . "$PSScriptRoot\VERSION.ps1"
} else {
    $Global:CertSurvSetupVersion = "1.3.0"
    $Global:CertSurvRegelwerkVersion = "9.5.0"
}

# Script variables
$ScriptName = $MyInvocation.MyCommand.Name
$ScriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Definition

# PowerShell Version Detection
$PowerShellVersion = $PSVersionTable.PSVersion
$IsPowerShell7Plus = $PSVersionTable.PSVersion.Major -ge 7

if (Get-Command Show-CertSurvVersionBanner -ErrorAction SilentlyContinue) {
    Show-CertSurvVersionBanner -ComponentName "System Setup"
} else {
    Write-Host "Certificate Surveillance Setup v$($Global:CertSurvSetupVersion)" -ForegroundColor Green
    Write-Host "PowerShell Version: $PowerShellVersion" -ForegroundColor Gray
    Write-Host "Regelwerk: v$($Global:CertSurvRegelwerkVersion)" -ForegroundColor Gray
}
Write-Host "=" * 60 -ForegroundColor Gray

# Basic setup tasks
Write-Host "[INFO] Checking system requirements..." -ForegroundColor Cyan

# Check directories
$configPath = Join-Path -Path $ScriptDirectory -ChildPath "Config"
$modulesPath = Join-Path -Path $ScriptDirectory -ChildPath "Modules"
$logPath = Join-Path -Path $ScriptDirectory -ChildPath "LOG"

if (Test-Path $configPath) {
    Write-Host "[OK] Config directory found: $configPath" -ForegroundColor Green
} else {
    Write-Host "[WARN] Config directory not found: $configPath" -ForegroundColor Yellow
}

if (Test-Path $modulesPath) {
    Write-Host "[OK] Modules directory found: $modulesPath" -ForegroundColor Green
} else {
    Write-Host "[WARN] Modules directory not found: $modulesPath" -ForegroundColor Yellow
}

# Create LOG directory if it doesn't exist
if (-not (Test-Path $logPath)) {
    try {
        New-Item -Path $logPath -ItemType Directory -Force | Out-Null
        Write-Host "[OK] LOG directory created: $logPath" -ForegroundColor Green
    }
    catch {
        Write-Host "[WARN] Could not create LOG directory: $($_.Exception.Message)" -ForegroundColor Yellow
    }
} else {
    Write-Host "[OK] LOG directory found: $logPath" -ForegroundColor Green
}

# Check main scripts
$mainScript = Join-Path -Path $ScriptDirectory -ChildPath "Main.ps1"
$guiScript = Join-Path -Path $ScriptDirectory -ChildPath "Setup-CertSurvGUI.ps1"

if (Test-Path $mainScript) {
    Write-Host "[OK] Main script found: Main.ps1" -ForegroundColor Green
} else {
    Write-Host "[WARN] Main script not found: Main.ps1" -ForegroundColor Yellow
}

if (Test-Path $guiScript) {
    Write-Host "[OK] GUI script found: Setup-CertSurvGUI.ps1" -ForegroundColor Green
} else {
    Write-Host "[WARN] GUI script not found: Setup-CertSurvGUI.ps1" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "[SUCCESS] Certificate Surveillance System setup completed!" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. Configure system using GUI: PowerShell.exe -ExecutionPolicy Bypass -File 'Setup-CertSurvGUI.ps1'" -ForegroundColor White
Write-Host "2. Test system: PowerShell.exe -ExecutionPolicy Bypass -File 'Check.ps1'" -ForegroundColor White
Write-Host "3. Run surveillance: PowerShell.exe -ExecutionPolicy Bypass -File 'Main.ps1'" -ForegroundColor White
Write-Host ""
Write-Host "=" * 60 -ForegroundColor Gray
Write-Host "Setup complete - Certificate Surveillance System v$($Global:SystemVersion)" -ForegroundColor Green
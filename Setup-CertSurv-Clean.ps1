#requires -Version 5.1

<#
.SYNOPSIS
    Setup GUI for Certificate Surveillance System
.DESCRIPTION
    Launches a graphical user interface for configuring the Certificate Surveillance System.
    Allows editing of all parameters through a user-friendly GUI.
.NOTES
    Author:         Flecki (Tom) Garnreiter
    Created on:     2025.09.04
    Last modified:  2025.09.04
    Version:        v1.0.0
    MUW-Regelwerk:  v9.3.0
    Copyright:      © 2025 Flecki Garnreiter
    License:        MIT License
#>

[CmdletBinding()]
param()

# Script Variables
$Global:ScriptName = $MyInvocation.MyCommand.Name
$Global:ScriptVersion = "v1.0.0"
$Global:RulebookVersion = "v9.3.0"
$Global:ScriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Definition

# PowerShell Version Detection
$Global:PowerShellVersion = $PSVersionTable.PSVersion
$Global:IsPowerShell7Plus = $PSVersionTable.PSVersion.Major -ge 7

Write-Host "Certificate Surveillance Setup v$Global:ScriptVersion" -ForegroundColor Green
Write-Host "PowerShell Version: $($Global:PowerShellVersion)" -ForegroundColor Gray
Write-Host "=" * 60 -ForegroundColor Gray

# Module Loading
$internalModules = @(
    'FL-Config',
    'FL-Gui'
)

$modulesPath = Join-Path -Path $Global:ScriptDirectory -ChildPath "Modules"

foreach ($module in $internalModules) {
    $modulePath = Join-Path -Path $modulesPath -ChildPath "$module.psm1"
    try {
        Import-Module $modulePath -Force -ErrorAction Stop
        Write-Host "Loaded module: $module" -ForegroundColor Green
    }
    catch {
        Write-Host "FATAL: Failed to load module '$module': $($_.Exception.Message)" -ForegroundColor Red
        Read-Host "Press Enter to exit"
        exit 1
    }
}

# Configuration Loading
try {
    Write-Host "Loading configuration..." -ForegroundColor Yellow
    
    $ScriptConfig = Get-ScriptConfiguration -ScriptDirectory $Global:ScriptDirectory
    $Global:Config = $ScriptConfig.Config
    $Global:Localization = $ScriptConfig.Localization
    
    Write-Host "Configuration loaded successfully" -ForegroundColor Green
    Write-Host "  Version: $($Global:Config.Version)" -ForegroundColor Gray
    Write-Host "  Language: $($Global:Config.Language)" -ForegroundColor Gray
    Write-Host "  Run Mode: $($Global:Config.RunMode)" -ForegroundColor Gray
    
} catch {
    Write-Host "FATAL: Failed to load configuration: $($_.Exception.Message)" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

# GUI Launch
try {
    Write-Host "`nLaunching setup GUI..." -ForegroundColor Yellow
    
    $result = Show-CertSurvSetupGUI -Config $Global:Config -Localization $Global:Localization -ScriptDirectory $Global:ScriptDirectory
    
    if ($result) {
        Write-Host "Configuration saved successfully!" -ForegroundColor Green
        Write-Host "  You can now run Cert-Surveillance.ps1" -ForegroundColor Gray
        
        $runMain = Read-Host "`nDo you want to run the main script now? (y/n)"
        if ($runMain -eq 'y' -or $runMain -eq 'Y') {
            $mainScriptPath = Join-Path -Path $Global:ScriptDirectory -ChildPath "Cert-Surveillance.ps1"
            if (Test-Path $mainScriptPath) {
                Write-Host "Starting main script..." -ForegroundColor Yellow
                & $mainScriptPath
            } else {
                Write-Host "Main script not found: $mainScriptPath" -ForegroundColor Red
            }
        }
    } else {
        Write-Host "Setup cancelled by user" -ForegroundColor Yellow
    }
    
} catch {
    Write-Host "Error launching GUI: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack trace:" -ForegroundColor Gray
    Write-Host $_.ScriptStackTrace -ForegroundColor Gray
}

Write-Host "`n" + "=" * 60 -ForegroundColor Gray
Write-Host "Setup completed" -ForegroundColor Green
Read-Host "Press Enter to exit"

# --- End of Setup Script --- v1.0.0 ; Regelwerk: v9.3.0 ---

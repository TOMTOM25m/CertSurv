#Requires -version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    [DE] Setup-GUI für Certificate Surveillance System
    [EN] Setup GUI for Certificate Surveillance System
.DESCRIPTION
    [DE] Startet eine grafische Benutzeroberfläche zur Konfiguration des Certificate Surveillance Systems.
         Ermöglicht die Bearbeitung aller Parameter über ein benutzerfreundliches GUI.
    [EN] Launches a graphical user interface for configuring the Certificate Surveillance System.
         Allows editing of all parameters through a user-friendly GUI.
.EXAMPLE
    .\Setup-CertSurv.ps1
    [DE] Startet die Setup-GUI
    [EN] Launches the setup GUI
.NOTES
    Version: v1.1.0
    Author: GitHub Copilot
    MUW-Regelwerk:  v9.3.1
#>

[CmdletBinding()]
param()

#----------------------------------------------------------[Declarations / Deklarationen]----------------------------------------------------------
$Global:ScriptName = $MyInvocation.MyCommand.Name
$Global:ScriptVersion = "v1.1.0"
$Global:RulebookVersion = "v9.3.1"
$Global:ScriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Definition

#----------------------------------------------------------[PowerShell Version Detection / PowerShell Versionserkennung]----------------------------------------
$Global:PowerShellVersion = $PSVersionTable.PSVersion
$Global:IsPowerShell7Plus = $PSVersionTable.PSVersion.Major -ge 7

Write-Host "Certificate Surveillance Setup v$Global:ScriptVersion" -ForegroundColor Green
Write-Host "PowerShell Version: $($Global:PowerShellVersion)" -ForegroundColor Gray
Write-Host "=" * 60 -ForegroundColor Gray

#----------------------------------------------------------[Module Loading / Modul-Laden]--------------------------------------------------------
# [DE] Interne Module laden / [EN] Load internal modules
$internalModules = @(
    'FL-Config',
    'FL-Gui'
)

$modulesPath = Join-Path -Path $Global:ScriptDirectory -ChildPath "Modules"

foreach ($module in $internalModules) {
    $modulePath = Join-Path -Path $modulesPath -ChildPath "$module.psm1"
    try {
        Import-Module $modulePath -Force -ErrorAction Stop
        Write-Host "✓ Loaded module: $module" -ForegroundColor Green
    }
    catch {
        Write-Host "✗ FATAL: Failed to load internal module '$module': $($_.Exception.Message)" -ForegroundColor Red
        Read-Host "Press Enter to exit / Drücken Sie Enter zum Beenden"
        exit 1
    }
}

#----------------------------------------------------------[Configuration Loading / Konfiguration laden]--------------------------------------------------------
try {
    Write-Host "Loading configuration / Konfiguration wird geladen..." -ForegroundColor Yellow
    
    # [DE] Konfiguration laden / [EN] Load configuration
    $ScriptConfig = Get-ScriptConfiguration -ScriptDirectory $Global:ScriptDirectory
    $Global:Config = $ScriptConfig.Config
    $Global:Localization = $ScriptConfig.Localization
    
    Write-Host "✓ Configuration loaded successfully / Konfiguration erfolgreich geladen" -ForegroundColor Green
    Write-Host "  Version: $($Global:Config.Version)" -ForegroundColor Gray
    Write-Host "  Language: $($Global:Config.Language)" -ForegroundColor Gray
    Write-Host "  Run Mode: $($Global:Config.RunMode)" -ForegroundColor Gray
    
} catch {
    Write-Host "✗ FATAL: Failed to load configuration: $($_.Exception.Message)" -ForegroundColor Red
    Read-Host "Press Enter to exit / Drücken Sie Enter zum Beenden"
    exit 1
}

#----------------------------------------------------------[GUI Launch / GUI starten]--------------------------------------------------------
try {
    Write-Host "`nLaunching setup GUI / Setup-GUI wird gestartet..." -ForegroundColor Yellow
    
    # [DE] Setup-GUI anzeigen / [EN] Show setup GUI
    $result = Show-CertSurvSetupGUI -Config $Global:Config -Localization $Global:Localization -ScriptDirectory $Global:ScriptDirectory
    
    if ($result) {
        Write-Host "checkmark Configuration saved successfully! / Konfiguration erfolgreich gespeichert!" -ForegroundColor Green
        Write-Host "  You can now run Cert-Surveillance.ps1 / Sie koennen nun Cert-Surveillance.ps1 ausfuehren" -ForegroundColor Gray
        
        # [DE] Fragen ob das Hauptskript gestartet werden soll / [EN] Ask if main script should be started
        $runMain = Read-Host "`nDo you want to run the main script now? (y/n) / Moechten Sie das Hauptskript jetzt ausfuehren? (y/n)"
        if ($runMain -eq 'y' -or $runMain -eq 'Y' -or $runMain -eq 'j' -or $runMain -eq 'J') {
            $mainScriptPath = Join-Path -Path $Global:ScriptDirectory -ChildPath "Cert-Surveillance.ps1"
            if (Test-Path $mainScriptPath) {
                Write-Host "Starting main script / Hauptskript wird gestartet..." -ForegroundColor Yellow
                & $mainScriptPath
            } else {
                Write-Host "✗ Main script not found: $mainScriptPath" -ForegroundColor Red
            }
        }
    } else {
        Write-Host "Setup cancelled by user / Setup vom Benutzer abgebrochen" -ForegroundColor Yellow
    }
    
} catch {
    Write-Host "✗ Error launching GUI: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack trace:" -ForegroundColor Gray
    Write-Host $_.ScriptStackTrace -ForegroundColor Gray
}

Write-Host "`n" + "=" * 60 -ForegroundColor Gray
Write-Host "Setup completed / Setup abgeschlossen" -ForegroundColor Green
Read-Host "Press Enter to exit / Druecken Sie Enter zum Beenden"

#----------------------------------------------------------[End of Script]----------------------------------------------------------
# --- End of Setup Script --- v1.1.0 ; Regelwerk: v9.3.1 ; PowerShell: $($Global:PowerShellVersion) ---

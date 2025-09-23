#Requires -version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    [DE] Certificate Surveillance Script - Umfassende SSL/TLS-Zertifikatsueberwachung fuer Server-Infrastrukturen
    [EN] Certificate Surveillance Script - Comprehensive SSL/TLS certificate monitoring for server infrastructures
.DESCRIPTION
    [DE] Ein minimalistisches PowerShell-Skript zur Ueberwachung von SSL/TLS-Zertifikaten nach Regelwerk v9.4.0.
         Das Hauptskript ist universal und minimalistisch - ALLE spezifische Logik wird von spezialisierten FL-*-Modulen behandelt.
         Strikte Modularitaet: Excel-Verarbeitung, AD-Abfragen, Zertifikatsabruf, Berichtserstellung - alles ausgelagert.
    [EN] A minimalistic PowerShell script for SSL/TLS certificate monitoring according to Rulebook v9.4.0.
         The main script is universal and minimalistic - ALL specific logic is handled by specialized FL-* modules.
         Strict modularity: Excel processing, AD queries, certificate retrieval, reporting - all externalized.
.PARAMETER ExcelPath
    [DE] Optional: Ueberschreibt den Excel-Dateipfad aus der Konfiguration. Ermoeglicht die Verwendung einer alternativen Serverliste.
    [EN] Optional: Override Excel file path from configuration. Allows using an alternative server list.
.PARAMETER Setup
    [DE] Startet die WPF-Konfigurations-GUI, um die Einstellungen zu bearbeiten.
    [EN] Starts the WPF configuration GUI to edit the settings.
.EXAMPLE
    .\Cert-Surveillance.ps1
    [DE] Fuehrt das Skript mit der Standardkonfiguration aus. Verwendet die in Config-Cert-Surveillance.json definierte Excel-Datei.
    [EN] Runs the script with default configuration. Uses the Excel file defined in Config-Cert-Surveillance.json.
.EXAMPLE
    .\Cert-Surveillance.ps1 -ExcelPath "C:\Custom\Servers.xlsx"
    [DE] Fuehrt das Skript mit einer benutzerdefinierten Excel-Datei aus, ueberschreibt die Konfiguration temporaer.
    [EN] Runs the script with a custom Excel file, temporarily overriding the configuration.
.EXAMPLE
    .\Cert-Surveillance.ps1 -Setup
    [DE] Oeffnet die Konfigurations-GUI, um die aktuellen Einstellungen zu aendern.
    [EN] Opens the configuration GUI to change the current settings.
.NOTES
    Author:         Flecki (Tom) Garnreiter
    Created on:     2025.09.04
    Last modified:  2025.09.22
    Version:        v1.2.0
    MUW-Regelwerk:  v9.4.0 (PowerShell Version Adaptation)
    Copyright:      © 2025 Flecki Garnreiter
    License:        MIT License
    Architecture:   Strict Modularity (FL-* modules only)
.DISCLAIMER
    [DE] Die bereitgestellten Skripte und die zugehoerige Dokumentation werden "wie besehen" ("as is")
    ohne ausdrueckliche oder stillschweigende Gewaehrleistung jeglicher Art zur Verfuegung gestellt.
    Insbesondere wird keinerlei Gewaehr uebernommen fuer die Marktgaengigkeit, die Eignung fuer einen bestimmten Zweck
    oder die Nichtverletzung von Rechten Dritter.
    Es besteht keine Verpflichtung zur Wartung, Aktualisierung oder Unterstützung der Skripte. Jegliche Nutzung erfolgt auf eigenes Risiko.
    In keinem Fall haften Herr Flecki Garnreiter, sein Arbeitgeber oder die Mitwirkenden an der Erstellung,
    Entwicklung oder Verbreitung dieser Skripte für direkte, indirekte, zufällige, besondere oder Folgeschäden - einschließlich,
    aber nicht beschränkt auf entgangenen Gewinn, Betriebsunterbrechungen, Datenverlust oder sonstige wirtschaftliche Verluste -,
    selbst wenn sie auf die Möglichkeit solcher Schäden hingewiesen wurden.
    Durch die Nutzung der Skripte erklären Sie sich mit diesen Bedingungen einverstanden.
    
    [EN] The scripts and accompanying documentation are provided "as is," without warranty of any kind, either express or implied.
    Flecki Garnreiter and his employer disclaim all warranties, including but not limited to the implied warranties of merchantability,
    fitness for a particular purpose, and non-infringement.
    There is no obligation to provide maintenance, support, updates, or enhancements for the scripts.
    Use of these scripts is at your own risk. Under no circumstances shall Flecki Garnreiter, his employer, the authors,
    or any party involved in the creation, production, or distribution of the scripts be held liable for any damages whatever,
    including but not limited to direct, indirect, incidental, consequential, or special damages
    (such as loss of profits, business interruption, or loss of business data), even if advised of the possibility of such damages.
    By using these scripts, you agree to be bound by the above terms.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ExcelPath,
    
    [Parameter(Mandatory = $false)]
    [switch]$Setup
)

#region PowerShell Version Detection (MANDATORY - Regelwerk v9.4.0)
$PSVersion = $PSVersionTable.PSVersion
$IsPS7Plus = $PSVersion.Major -ge 7
$IsPS5 = $PSVersion.Major -eq 5
$IsPS51 = $PSVersion.Major -eq 5 -and $PSVersion.Minor -eq 1

Write-Verbose "Certificate Surveillance - PowerShell Version: $($PSVersion.ToString())"
Write-Verbose "Compatibility Mode: $(if($IsPS7Plus){'PowerShell 7.x Enhanced'}elseif($IsPS51){'PowerShell 5.1 Compatible'}else{'PowerShell 5.x Standard'})"
Write-Verbose "Edition: $($PSVersionTable.PSEdition)"

# Legacy compatibility for existing code
$Global:PowerShellVersion = $PSVersionTable.PSVersion
$Global:IsPowerShell5 = $IsPS5
$Global:IsPowerShell7Plus = $IsPS7Plus
$Global:IsWindowsPowerShell = $PSVersionTable.PSEdition -eq 'Desktop'
$Global:IsPowerShellCore = $PSVersionTable.PSEdition -eq 'Core'

if ($IsPS7Plus) {
    Write-Verbose "Platform: $($PSVersionTable.Platform)"
}
#endregion

#----------------------------------------------------------[Declarations / Deklarationen]----------------------------------------------------------
$Global:ScriptName = $MyInvocation.MyCommand.Name
$Global:ScriptVersion = "v1.2.0"
$Global:RulebookVersion = "v9.4.0"
$Global:ScriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Definition

#----------------------------------------------------------[Module Loading / Modul-Laden]--------------------------------------------------------
# Internal Modules / Interne Module

# Add FL-Certificate module for remote certificate checks / FL-Certificate Modul für Remote-Zertifikatsprüfungen hinzufügen
$internalModules = @(
    'FL-Compatibility',
    'FL-Config',
    'FL-Logging',
    'FL-Maintenance',
    'FL-Utils',
    'FL-ActiveDirectory',
    'FL-DataProcessing',
    'FL-NetworkOperations',
    'FL-Security',
    'FL-Reporting',
    'FL-CoreLogic',
    'FL-Certificate',
    'FL-CertificateAPI'
)

$modulesPath = Join-Path -Path $Global:ScriptDirectory -ChildPath "Modules"

foreach ($module in $internalModules) {
    $modulePath = Join-Path -Path $modulesPath -ChildPath "$module.psm1"
    try {
        Import-Module $modulePath -Force -ErrorAction Stop
        Write-Verbose "Loaded module: $module"
    }
    catch {
        Write-Host "FATAL: Failed to load internal module '$module': $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

# External Modules / Externe Module
try {
    Import-Module ImportExcel -ErrorAction Stop
    Write-Verbose "Loaded module: ImportExcel"
}
catch {
    Write-Host "FATAL: Failed to load module 'ImportExcel'. Please ensure it is installed from the PowerShell Gallery (Install-Module -Name ImportExcel)." -ForegroundColor Red
    exit 1
}

#----------------------------------------------------------[Configuration & Initialization / Konfiguration & Initialisierung]----------------------------------------
try {
    # Load configuration / Konfiguration laden
    $ScriptConfig = Get-ScriptConfiguration -ScriptDirectory $Global:ScriptDirectory
    $Global:Config = $ScriptConfig.Config
    $Global:Localization = $ScriptConfig.Localization
    
    # Check if Setup GUI should be launched / Prüfen ob Setup-GUI gestartet werden soll
    if ($Setup) {
        Write-Host "Starting Setup GUI / Setup-GUI wird gestartet..." -ForegroundColor Yellow
        try {
            # Import GUI module / GUI-Modul importieren
            $guiModulePath = Join-Path -Path $modulesPath -ChildPath "FL-Gui.psm1"
            Import-Module $guiModulePath -Force -ErrorAction Stop
            
            # Launch Setup GUI / Setup-GUI starten
            $setupResult = Show-CertSurvSetupGUI -Config $Global:Config -Localization $Global:Localization -ScriptDirectory $Global:ScriptDirectory
            
            if ($setupResult) {
                Write-Host "Configuration saved successfully! / Konfiguration erfolgreich gespeichert!" -ForegroundColor Green
                # Reload configuration after changes / Konfiguration nach Änderungen neu laden
                $ScriptConfig = Get-ScriptConfiguration -ScriptDirectory $Global:ScriptDirectory
                $Global:Config = $ScriptConfig.Config
                $Global:Localization = $ScriptConfig.Localization
            } else {
                Write-Host "Setup cancelled by user / Setup vom Benutzer abgebrochen" -ForegroundColor Yellow
                exit 0
            }
        } catch {
            Write-Host "Error launching Setup GUI: $($_.Exception.Message)" -ForegroundColor Red
            exit 1
        }
    }
    
    # Override Excel path if provided / Excel-Pfad überschreiben falls angegeben
    if ($ExcelPath) {
        $Global:Config.Excel.ExcelPath = $ExcelPath
    }
    
    # Initialize logging / Logging initialisieren
    $logPath = Join-Path -Path $Global:ScriptDirectory -ChildPath $Global:Config.Paths.LogDirectory
    if (!(Test-Path $logPath)) {
        New-Item -Path $logPath -ItemType Directory -Force | Out-Null
    }
    
    $scriptBaseName = $Global:ScriptName -replace '\.ps1$', ''
    $logName = "$($Global:Config.RunMode)_${scriptBaseName}_$(Get-Date -Format 'yyyy-MM-dd').log"
    $Global:sLogFile = Join-Path -Path $logPath -ChildPath $logName
    
    Write-Log "=== Certificate Surveillance Script v$Global:ScriptVersion Started ===" -LogFile $Global:sLogFile
    Write-Log "Rulebook Version: $Global:RulebookVersion" -LogFile $Global:sLogFile
    Write-Log "PowerShell Version: $($Global:PowerShellVersion)" -LogFile $Global:sLogFile
    
    # Validate prerequisites / Voraussetzungen validieren
    if (!(Test-WorkflowPrerequisites -Config $Global:Config -LogFile $Global:sLogFile)) {
        throw "Prerequisites validation failed. Check log for details."
    }
    
}
catch {
    Write-Host "FATAL: Initialization failed: $($_.Exception.Message)" -ForegroundColor Red
    if ($Global:sLogFile) {
        Write-Log "FATAL: Initialization failed: $($_.Exception.Message)" -Level ERROR -LogFile $Global:sLogFile
    }
    exit 1
}

#----------------------------------------------------------[Main Execution / Hauptausführung]--------------------------------------------------------
try {
    # Execute main workflow (all logic delegated to modules) / Hauptworkflow ausführen (alle Logik an Module delegiert)
    $workflowResult = Invoke-MainWorkflow -Config $Global:Config -Parameters $PSBoundParameters -ScriptDirectory $Global:ScriptDirectory -LogFile $Global:sLogFile

    Write-Log "=== Script completed successfully ===" -LogFile $Global:sLogFile
    Write-Log "Workflow result: $($workflowResult | ConvertTo-Json -Depth 2)" -LogFile $Global:sLogFile

    if ($workflowResult.EmailSent) {
        Write-Host "SUCCESS: Report generated and email sent." -ForegroundColor Green
    } else {
        Write-Host "SUCCESS: Report generated (email disabled)." -ForegroundColor Green
    }
}
catch {
    Write-Log "=== SCRIPT FAILED ===" -Level ERROR -LogFile $Global:sLogFile
    Write-Log "Error: $($_.Exception.Message)" -Level ERROR -LogFile $Global:sLogFile
    
    # Send error notification using Utils implementation if available / Fehlerbenachrichtigung senden wenn Utils-Implementierung verfügbar
    try {
        if (Get-Command -Name Send-MailNotification -Module FL-Utils -ErrorAction SilentlyContinue) {
            # Only attempt if a recipient can be resolved / Nur versuchen wenn ein Empfänger aufgelöst werden kann
            $toCandidate = if ($Global:Config.RunMode -eq 'PROD') { $Global:Config.Mail.ProdTo } else { $Global:Config.Mail.DevTo }
            if ($Global:Config.Mail.Enabled -and $toCandidate) {
                Send-MailNotification -MailConfig $Global:Config.Mail -Subject "SCRIPT FAILED: $($Global:ScriptName)" -Body "<h2>Script Execution Failed</h2><p>Error: $($_.Exception.Message)</p><p>Check log file for details.</p>"
            } else {
                Write-Log "Skipping error email: Mail disabled or no recipient configured" -Level WARN -LogFile $Global:sLogFile
            }
        }
        else {
            Write-Log "No Send-MailNotification command available from FL-Utils; skipping error email" -Level WARN -LogFile $Global:sLogFile
        }
    }
    catch {
        Write-Log "Failed to send error notification: $($_.Exception.Message)" -Level ERROR -LogFile $Global:sLogFile
    }
    
    Write-Host "FAILED: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    # Cleanup operations / Aufräumoperationen
    try {
        Invoke-LogCleanup -LogDirectory $logPath -ArchiveLogsOlderThanDays $Global:Config.Intervals.ArchiveLogsOlderThanDays -DeleteZipArchivesOlderThanDays $Global:Config.Intervals.DeleteZipArchivesOlderThanDays -PathTo7Zip $Global:Config.Paths.PathTo7Zip
        Write-Log "Cleanup completed" -LogFile $Global:sLogFile
    }
    catch {
        Write-Log "Cleanup failed: $($_.Exception.Message)" -Level WARN -LogFile $Global:sLogFile
    }
}

#----------------------------------------------------------[End of Script]----------------------------------------------------------
# --- End of Script --- v1.2.0 ; Regelwerk: v9.4.0 ; PowerShell: $($Global:PowerShellVersion) ---

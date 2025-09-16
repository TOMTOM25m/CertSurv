<#
.SYNOPSIS
    [DE] Liest Zertifikatsinformationen aus einer Excel-Datei, prüft deren Ablaufdaten und versendet einen HTML-Report.
    [EN] Reads certificate information from an Excel file, checks their expiration dates, and sends an HTML report.

.DESCRIPTION
    [DE] Dieses Skript verarbeitet SSL/TLS-Zertifikate aus einer Excel-Datei. Es ruft die Ablaufdaten ab und versendet einen HTML-Statusbericht per E-Mail. Die Excel-Datei wird nur gelesen.
         Es werden nur Zeilen und Zertifikats-Einträge verarbeitet, die '.meduniwien.ac.at' enthalten.
    [EN] This script processes SSL/TLS certificates from an Excel sheet. It retrieves expiration dates and sends an HTML status report via email. The Excel file is read-only.
         Only rows and certificate entries containing '.meduniwien.ac.at' are processed.

.PARAMETER Setup
    [DE] Startet die Konfigurations-GUI (WPF), um die Einstellungen zu bearbeiten.
    [EN] Starts the configuration GUI (WPF) to edit the settings.

.NOTES
    Author: Flecki (Tom) Garnreiter
    Created on: 2024.12.19
    Last modified: 2025.07.15
    Version: v09.00.05
    Notes:  [DE] Finale, stabile Version. Filtert einzelne Zertifikatseinträge nach der Domain.
            [EN] Final, stable version. Filters individual certificate entries by domain.
    Copyright: (c) Flecki (Tom) Garnreiter

.DISCLAIMER
    [EN] The scripts and accompanying documentation are provided "as is," without warranty of any kind, either express or implied.
    There is no obligation to provide maintenance, support, updates, or enhancements for the scripts. Use of these scripts is at your own risk.
    [DE] Die bereitgestellten Skripte und die zugehörige Dokumentation werden „wie besehen“ („as is“) ohne Gewährleistung jeglicher Art zur Verfügung gestellt.
    Jegliche Nutzung erfolgt auf eigenes Risiko.
#>
#requires -version 5.1

[CmdletBinding(SupportsShouldProcess = $true)]
param (
    [Parameter(Mandatory = $false)]
    [switch]$Setup
)

# Lädt benötigte .NET Assemblies für alle Ausführungsmodi
Add-Type -AssemblyName System.Windows.Forms, PresentationCore, PresentationFramework

#region Initialisierung und globale Zustandsverwaltung
$Global:State = @{
    ScriptName      = $MyInvocation.MyCommand.Name
    ScriptRoot      = $PSScriptRoot
    ScriptVersion   = 'v09.00.05'
    BaseScriptName  = $MyInvocation.MyCommand.Name -replace '\.ps1$'
    Config          = $null
    UIStrings       = $null
    LogFilePath     = $null
    CorrectEncoding = 'utf8BOM'
}

# Self-Elevation Block
if (-not ([System.Security.Principal.WindowsPrincipal][System.Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "Administratorrechte sind erforderlich. Versuche, das Skript mit erhöhten Rechten neu zu starten..."
    $powershellPath = (Get-Command powershell).Source
    $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Definition)`""
    $PSBoundParameters.GetEnumerator() | ForEach-Object { $arguments += " -$($_.Key) `"$($_.Value)`"" }
    Start-Process -FilePath $powershellPath -ArgumentList $arguments -Verb RunAs
    exit
}

function Get-UIStrings {
    @{
        EN = @{
            GUIWindowTitle = "ConfigGUI {0} - {1}"; OK = "OK"; Cancel = "Cancel"; TabGeneral = "General"; TabPaths = "Paths"; TabExcel = "Excel"; TabNetwork = "Network"; TabMail = "E-Mail"; RunMode = "Run Mode"; DevMode = "Development (DEV)"; ProdMode = "Production (PROD)"; Language = "Language"; Path7Zip = "7-Zip Path (7z.exe)"; PathLogo = "Logo Directory"; PathReport = "Report Directory"; PathLog = "Log Directory"; ExcelFilePath = "Excel File Path"; BrowseFile = "Browse File..."; BrowseFolder = "Browse Folder..."; AlwaysUsePath = "Always use this path (suppress dialog)"; SheetName = "Sheet Name"; HeaderRow = "Header Row"; CertColumn = "Certificate Column"; DNSServer = "DNS Server"; EnableMail = "Enable E-Mail Notifications"; SmtpServer = "SMTP Server"; SmtpPort = "SMTP Port"; UseSsl = "Use SSL"; SenderAddress = "Sender Address"; DevRecipient = "DEV Recipient"; ProdRecipient = "PROD Recipient"; SubjectPrefix = "Subject Prefix"; SetSmtpCreds = "Set/Change SMTP Credentials"; CredsSavedTitle = "Credentials Saved"; CredsSavedMsg = "SMTP credentials were securely saved."; SelectExcelFile = "Select the Excel certificate file"; SelectFolder = "Select Folder"; Select7Zip = "Select 7z.exe"; GuiLoading = "Loading Configuration GUI..."; ExcelInfoLoading = "Loading Excel data..."; ScriptStart = "Starting Script '{0}' | Version: {1}"; ScriptEnd = "Script '{0}' Finished"; DebugModeActive = "Debug mode is ENABLED."; ConfigLoaded = "Configuration loaded from '{0}'."; ConfigNotFound = "Configuration file not found. Launching initial setup..."; ConfigSaved = "Configuration saved. Please run the script again to process data."; ConfigVersionMismatch = "WARNING: Script version '{0}' does not match config version '{1}'. Please review settings for incompatibilities."; InitialSetupCancelled = "Initial setup cancelled by user. Exiting script."; PathCreating = "Directory '{0}' not found. Creating..."; ModuleMissing = "Module '{0}' is required but could not be installed/updated. Please check permissions and internet connectivity."; NoDataProcessed = "No data processed. Report will not be sent."; UnhandledError = "A critical, unhandled error occurred: {0}"; UserCancelledFileSelection = "User cancelled file selection. Exiting."; ConfigCorrupted = "WARNING: Config file '{0}' is corrupted or empty. Launching initial setup. Error: {1}"; ConfigIncomplete = "ERROR: Excel configuration is incomplete. Please run with -Setup and define Sheet Name and Certificate Column."; EmailNoRecipient = "Email enabled, but no recipient is configured for RunMode '{0}'."; SmtpTestFailed = "SMTP server '{0}:{1}' is not reachable. Skipping email report."; ModuleCheck = "Checking for module '{0}'..."; ModuleNotFound = "Module '{0}' not found. Installing..."; ModuleInstalling = "Installing module '{0}' from PSGallery..."; ModuleUpdateFound = "Newer version of module '{0}' found (Installed: {1}, Gallery: {2}). Updating..."; ModuleUpdating = "Updating module '{0}'..."; ModuleUpToDate = "Module '{0}' is up to date (Version: {1})."; ModuleCheckSkipped = "Skipping module update check for '{0}' (last checked within 24 hours)."; ExcelReadError = "Could not read Excel file at '{0}'. Please check the path and ensure the file is not open elsewhere. Error: {1}"; ReportDateParseError = "Could not parse date '{0}' for certificate '{1}' during report generation."; ProcessingModeParallel = "Using PowerShell 7+ parallel processing mode."; ProcessingModeSequential = "Using PowerShell 5.1 sequential processing mode."
        }
        DE = @{
            GUIWindowTitle = "KonfigGUI {0} - {1}"; OK = "OK"; Cancel = "Abbrechen"; TabGeneral = "Allgemein"; TabPaths = "Pfade"; TabExcel = "Excel"; TabNetwork = "Netzwerk"; TabMail = "E-Mail"; RunMode = "Betriebsmodus"; DevMode = "Entwicklung (DEV)"; ProdMode = "Produktion (PROD)"; Language = "Sprache"; Path7Zip = "7-Zip-Pfad (7z.exe)"; PathLogo = "Logo-Verzeichnis"; PathReport = "Report-Verzeichnis"; PathLog = "Protokoll-Verzeichnis"; ExcelFilePath = "Excel-Dateipfad"; BrowseFile = "Datei suchen..."; BrowseFolder = "Ordner suchen..."; AlwaysUsePath = "Diesen Pfad immer verwenden (Dialog unterdrücken)"; SheetName = "Name des Arbeitsblatts"; HeaderRow = "Zeile f. Überschriften"; CertColumn = "Spalte für Zertifikate"; DNSServer = "DNS-Server"; EnableMail = "E-Mail-Benachrichtigungen aktivieren"; SmtpServer = "SMTP-Server"; SmtpPort = "SMTP-Port"; UseSsl = "SSL verwenden"; SenderAddress = "Absenderadresse"; DevRecipient = "DEV-Empf&#228;nger"; ProdRecipient = "PROD-Empf&#228;nger"; SubjectPrefix = "Betreff-Präfix"; SetSmtpCreds = "SMTP-Anmeldedaten festlegen/&#228;ndern"; CredsSavedTitle = "Anmeldedaten gespeichert"; CredsSavedMsg = "Die SMTP-Anmeldedaten wurden sicher gespeichert."; SelectExcelFile = "Excel-Zertifikatsdatei ausw&#228;hlen"; SelectFolder = "Verzeichnis auswählen"; Select7Zip = "7z.exe auswählen"; GuiLoading = "Lade Konfigurations-GUI..."; ExcelInfoLoading = "Lade Excel-Daten..."; ScriptStart = "Starte Skript '{0}' | Version: {1}"; ScriptEnd = "Skript '{0}' beendet"; DebugModeActive = "Debug-Modus ist AKTIVIERT."; ConfigLoaded = "Konfiguration geladen von '{0}'."; ConfigNotFound = "Konfigurationsdatei nicht gefunden. Ersteinrichtung wird gestartet..."; ConfigSaved = "Konfiguration erfolgreich gespeichert. Bitte Skript erneut ausführen, um Daten zu verarbeiten."; ConfigVersionMismatch = "WARNUNG: Skript-Version '{0}' stimmt nicht mit Konfig-Version '{1}' überein. Bitte Einstellungen auf Inkompatibilitäten prüfen."; InitialSetupCancelled = "Ersteinrichtung vom Benutzer abgebrochen. Skript wird beendet."; PathCreating = "Verzeichnis '{0}' nicht gefunden. Wird erstellt..."; ModuleMissing = "Modul '{0}' wird benötigt, konnte aber nicht installiert/aktualisiert werden. Bitte Berechtigungen und Internetverbindung prüfen."; NoDataProcessed = "Keine Daten verarbeitet. Es wird kein Report versendet."; UnhandledError = "Ein kritischer, unbehandelter Fehler ist aufgetreten: {0}"; UserCancelledFileSelection = "Benutzer hat Dateiauswahl abgebrochen. Skript wird beendet."; ConfigCorrupted = "WARNUNG: Konfig-Datei '{0}' ist beschädigt oder leer. Ersteinrichtung wird gestartet. Fehler: {1}"; ConfigIncomplete = "FEHLER: Excel-Konfiguration ist unvollständig. Bitte mit -Setup den Sheet-Namen und die Zertifikats-Spalte festlegen."; EmailNoRecipient = "E-Mail aktiviert, aber kein Empfänger für Betriebsmodus '{0}' konfiguriert."; SmtpTestFailed = "SMTP-Server '{0}:{1}' ist nicht erreichbar. E-Mail-Report wird übersprungen."; ModuleCheck = "Prüfe Modul '{0}'..."; ModuleNotFound = "Modul '{0}' nicht gefunden. Installiere..."; ModuleInstalling = "Installiere Modul '{0}' aus der PSGallery..."; ModuleUpdateFound = "Neuere Version von Modul '{0}' gefunden (Installiert: {1}, Gallery: {2}). Aktualisiere..."; ModuleUpdating = "Aktualisiere Modul '{0}'..."; ModuleUpToDate = "Modul '{0}' ist auf dem neuesten Stand (Version: {1})."; ModuleCheckSkipped = "Modul-Update-Prüfung für '{0}' übersprungen (zuletzt innerhalb von 24h geprüft)."; ExcelReadError = "Konnte Excel-Datei unter '{0}' nicht lesen. Bitte Pfad prüfen und sicherstellen, dass die Datei nicht anderweitig geöffnet ist. Fehler: {1}"; ReportDateParseError = "Konnte Datum '{0}' für Zertifikat '{1}' bei der Reporterstellung nicht verarbeiten."; ProcessingModeParallel = "Verwende PowerShell 7+ Parallelverarbeitung."; ProcessingModeSequential = "Verwende PowerShell 5.1 sequentielle Verarbeitung."
        }
    }
}
#endregion

#region Hilfsfunktionen
function Write-ScriptLog { param([string]$Message, [string]$Level = "INFO"); if ([string]::IsNullOrWhiteSpace($Message)) { return }; if ($Level -eq "DEBUG" -and (-not $Global:State.Config.DebugMode)) { return }; $logEntry = "[$(Get-Date -Format 'yyyy.MM.dd HH:mm:ss')] [$Level] $Message"; $c = @{INFO = "White"; WARNING = "Yellow"; ERROR = "Red"; DEBUG = "Cyan" }; Write-Host $logEntry -ForegroundColor $c[$Level]; if ($Global:State.LogFilePath) { Add-Content -Path $Global:State.LogFilePath -Value $logEntry -Encoding $Global:State.CorrectEncoding } }
function Test-AndCreatePaths { param($ConfigObject); $dirs = @($ConfigObject.Paths.LogDirectory, $ConfigObject.Paths.ReportDirectory, (Split-Path -Path $ConfigObject.Paths.ConfigFile -Parent)); foreach ($dir in $dirs) { if (-not ([string]::IsNullOrWhiteSpace($dir))) { $fullPath = if ([System.IO.Path]::IsPathRooted($dir)) { $dir } else { Join-Path $State.ScriptRoot $dir }; if (-not (Test-Path $fullPath)) { Write-ScriptLog ($State.UIStrings.PathCreating -f $fullPath); New-Item -Path $fullPath -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null } } } }
function Resolve-ModuleDependency { param($ConfigObject); $ModuleName = 'ImportExcel'; if ($ConfigObject.LastModuleCheck -and ((Get-Date) - [datetime]$ConfigObject.LastModuleCheck).TotalHours -lt 24) { Write-ScriptLog ($State.UIStrings.ModuleCheckSkipped -f $ModuleName) "DEBUG"; Import-Module $ModuleName -ErrorAction SilentlyContinue; return }; Write-ScriptLog ($State.UIStrings.ModuleCheck -f $ModuleName); $installedModule = Get-Module -ListAvailable -Name $ModuleName | Sort-Object Version -Descending | Select-Object -First 1; try { if (-not $installedModule) { Write-ScriptLog ($State.UIStrings.ModuleNotFound -f $ModuleName) "INFO"; Write-ScriptLog ($State.UIStrings.ModuleInstalling -f $ModuleName) "INFO"; Install-Module -Name $ModuleName -Force -AcceptLicense -Scope CurrentUser -ErrorAction Stop } else { $galleryModule = Find-Module -Name $ModuleName -ErrorAction SilentlyContinue; if ($galleryModule -and ([version]$installedModule.Version -lt [version]$galleryModule.Version)) { Write-ScriptLog ($State.UIStrings.ModuleUpdateFound -f $ModuleName, $installedModule.Version, $galleryModule.Version) "INFO"; Write-ScriptLog ($State.UIStrings.ModuleUpdating -f $ModuleName) "INFO"; Update-Module -Name $ModuleName -Force -AcceptLicense -ErrorAction Stop } else { Write-ScriptLog ($State.UIStrings.ModuleUpToDate -f $ModuleName, $installedModule.Version) } }; Import-Module $ModuleName; $ConfigObject.LastModuleCheck = (Get-Date).ToString('o') } catch { throw ($State.UIStrings.ModuleMissing -f $ModuleName) } }
#endregion

#region Konfigurations-Management
function Get-DefaultConfig { return [PSCustomObject]@{ Version = $Global:State.ScriptVersion; RunMode = "DEVto"; Language = "EN"; DebugMode = $true; LastModuleCheck = (Get-Date).AddDays(-2).ToString('o'); Paths = [PSCustomObject]@{ ConfigFile = (Join-Path $Global:State.ScriptRoot "Config\Config-$($Global:State.BaseScriptName).json"); PathTo7Zip = "C:\Program Files\7-Zip\7z.exe"; LogoDirectory = "\\itscmgmt03.srv.meduniwien.ac.at\iso\MUWLogo"; ReportDirectory = "reports"; LogDirectory = "LOG" }; Excel = [PSCustomObject]@{ ExcelPath = ""; SheetName = "Zertifikate"; HeaderRow = 1; CertificateColumnName = "Zertifikat"; AlwaysUseConfigPath = $false }; Network = [PSCustomObject]@{ DnsServer = "149.148.55.55"; TlsVersion = "SystemDefault" }; Intervals = [PSCustomObject]@{ DaysUntilUrgent = 10; DaysUntilCritical = 30; DaysUntilWarning = 60; ArchiveLogsOlderThanDays = 30; DeleteZipArchivesOlderThanDays = 90 }; Mail = [PSCustomObject]@{ Enabled = $true; SmtpServer = "smtpi.meduniwien.ac.at"; SmtpPort = 25; UseSsl = $false; SenderAddress = "$($env:COMPUTERNAME)@meduniwien.ac.at"; DevTo = "thomas.garnreiter@meduniwien.ac.at"; ProdTo = "win-admin@meduniwien.ac.at"; SubjectPrefix = "[Zertifikats-Report]"; CredentialFilePath = (Join-Path $Global:State.ScriptRoot "Config\secure.smtp.cred.xml") }; CorporateDesign = [PSCustomObject]@{ PrimaryColor = "#111d4e"; HoverColor = "#5fb4e5" } } }
function Import-Configuration {
    $configPath = (Get-DefaultConfig).Paths.ConfigFile; $isInitialSetup = $false; $Global:State.Config = Get-DefaultConfig; $Global:State.UIStrings = (Get-UIStrings)[$State.Config.Language]
    if (Test-Path $configPath) {
        try { $content = Get-Content -Path $configPath -Raw -Encoding UTF8; if ([string]::IsNullOrWhiteSpace($content)) { throw "File is empty." }; $loadedConfig = $content | ConvertFrom-Json; if (-not $loadedConfig) { throw "JSON parsing resulted in a null object." }; $Global:State.Config = $loadedConfig; $Global:State.UIStrings = (Get-UIStrings)[$State.Config.Language] } catch { $isInitialSetup = $true; Write-ScriptLog ($State.UIStrings.ConfigCorrupted -f $configPath, $_.Exception.Message) "WARNING" }
    }
    else { $isInitialSetup = $true; Write-ScriptLog $State.UIStrings.ConfigNotFound }
    Test-AndCreatePaths -ConfigObject $Global:State.Config; $logDir = if ([System.IO.Path]::IsPathRooted($State.Config.Paths.LogDirectory)) { $State.Config.Paths.LogDirectory } else { Join-Path $State.ScriptRoot $State.Config.Paths.LogDirectory }; $Global:State.LogFilePath = Join-Path $logDir "$($State.BaseScriptName)_$(Get-Date -Format 'yyyy.MM.dd').log"
    if ($Global:State.Config.Version -ne $Global:State.ScriptVersion) { Write-ScriptLog ($State.UIStrings.ConfigVersionMismatch -f $Global:State.ScriptVersion, $Global:State.Config.Version) "WARNING" }
    if ($isInitialSetup) { if (Show-ConfigurationGUI -InitialSetup) { Write-ScriptLog $State.UIStrings.ConfigSaved } else { Write-ScriptLog $State.UIStrings.InitialSetupCancelled "ERROR" }; exit 0 }
    Write-ScriptLog ($State.UIStrings.ConfigLoaded -f $configPath)
}
function Save-Configuration { $State.Config.Version = $State.ScriptVersion; Test-AndCreatePaths -ConfigObject $State.Config; $State.Config | ConvertTo-Json -Depth 10 | Set-Content -Path $State.Config.Paths.ConfigFile -Encoding $Global:State.CorrectEncoding }
#endregion

#region GUI (WPF)
function Show-ConfigurationGUI {
    param([switch]$InitialSetup)
    try { Resolve-ModuleDependency -ConfigObject $State.Config } catch { throw }
    Write-Progress -Activity ($State.UIStrings.GUIWindowTitle -f $State.ScriptName, $State.ScriptVersion) -Status $State.UIStrings.GuiLoading -PercentComplete 50
    $L = $State.UIStrings; $cfg = $State.Config
    $xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="$($L.GUIWindowTitle -f $State.ScriptName, $State.ScriptVersion)" Height="580" Width="700" WindowStartupLocation="CenterScreen">
    <Window.Resources>
        <Style x:Key="OkButton" TargetType="Button"><Setter Property="Background" Value="$($cfg.CorporateDesign.PrimaryColor)"/><Setter Property="Foreground" Value="White"/><Setter Property="Padding" Value="10,5"/><Setter Property="Margin" Value="5"/><Setter Property="MinWidth" Value="80"/><Style.Triggers><Trigger Property="IsMouseOver" Value="True"><Setter Property="Background" Value="$($cfg.CorporateDesign.HoverColor)"/><Setter Property="Foreground" Value="$($cfg.CorporateDesign.PrimaryColor)"/></Trigger></Style.Triggers></Style>
        <Style TargetType="TabItem"><Setter Property="Padding" Value="10,5"/><Style.Triggers><Trigger Property="IsSelected" Value="True"><Setter Property="Background" Value="$($cfg.CorporateDesign.PrimaryColor)"/><Setter Property="Foreground" Value="White"/></Trigger></Style.Triggers></Style>
        <Style TargetType="Grid" x:Key="PathGrid"><Setter Property="Margin" Value="0,5,0,0"/></Style>
        <Style TargetType="Label"><Setter Property="Margin" Value="0,10,0,0"/></Style>
    </Window.Resources>
    <Grid Margin="10">
        <Grid.RowDefinitions><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
        <TabControl x:Name="MainTabControl" Grid.Row="0">
            <TabItem Header="$($L.TabGeneral)"><StackPanel Margin="10"><Label Content="$($L.RunMode)" Margin="0"/><ComboBox x:Name="RunModeComboBox"><ComboBoxItem Content="DEVto"/><ComboBoxItem Content="PRODto"/></ComboBox><Label Content="$($L.Language)"/><ComboBox x:Name="LanguageComboBox"><ComboBoxItem>EN</ComboBoxItem><ComboBoxItem>DE</ComboBoxItem></ComboBox></StackPanel></TabItem>
            <TabItem Header="$($L.TabExcel)"><StackPanel Margin="10"><Label Content="$($L.ExcelFilePath)" Margin="0"/><Grid Style="{StaticResource PathGrid}"><Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions><TextBox x:Name="ExcelPathTextBox" Grid.Column="0" VerticalContentAlignment="Center"/><Button x:Name="BrowseExcelButton" Grid.Column="1" Content="$($L.BrowseFile)" Margin="5,0"/></Grid><CheckBox x:Name="AlwaysUsePathCheckBox" Content="$($L.AlwaysUsePath)" Margin="0,10,0,0"/><Label Content="$($L.SheetName)"/><ComboBox x:Name="SheetNameComboBox" IsEditable="True"/><Label Content="$($L.HeaderRow)"/><TextBox x:Name="HeaderRowTextBox" /><Label Content="$($L.CertColumn)"/><ComboBox x:Name="CertColumnComboBox" IsEditable="True"/></StackPanel></TabItem>
            <TabItem Header="$($L.TabPaths)"><StackPanel Margin="10"><Label Content="$($L.Path7Zip)"/><Grid Style="{StaticResource PathGrid}"><Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions><TextBox x:Name="Path7ZipTextBox" Grid.Column="0" VerticalContentAlignment="Center"/><Button x:Name="Browse7ZipButton" Grid.Column="1" Content="$($L.BrowseFile)" Margin="5,0"/></Grid><Label Content="$($L.PathLogo)"/><Grid Style="{StaticResource PathGrid}"><Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions><TextBox x:Name="PathLogoTextBox" Grid.Column="0" VerticalContentAlignment="Center"/><Button x:Name="BrowseLogoButton" Grid.Column="1" Content="$($L.BrowseFolder)" Margin="5,0"/></Grid><Label Content="$($L.PathReport)"/><Grid Style="{StaticResource PathGrid}"><Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions><TextBox x:Name="PathReportTextBox" Grid.Column="0" VerticalContentAlignment="Center"/><Button x:Name="BrowseReportButton" Grid.Column="1" Content="$($L.BrowseFolder)" Margin="5,0"/></Grid><Label Content="$($L.PathLog)"/><Grid Style="{StaticResource PathGrid}"><Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions><TextBox x:Name="PathLogTextBox" Grid.Column="0" VerticalContentAlignment="Center"/><Button x:Name="BrowseLogButton" Grid.Column="1" Content="$($L.BrowseFolder)" Margin="5,0"/></Grid></StackPanel></TabItem>
            <TabItem Header="$($L.TabNetwork)"><StackPanel Margin="10"><Label Content="$($L.DNSServer)" Margin="0"/><TextBox x:Name="DnsServerTextBox"/></StackPanel></TabItem>
            <TabItem Header="$($L.TabMail)"><StackPanel Margin="10"><CheckBox x:Name="EnableMailCheckBox" Content="$($L.EnableMail)" FontWeight="Bold"/><Label Content="$($L.SmtpServer)" Margin="0,5,0,0"/><TextBox x:Name="SmtpServerTextBox"/><Label Content="$($L.SmtpPort)"/><TextBox x:Name="SmtpPortTextBox"/><Label Content="$($L.SenderAddress)"/><TextBox x:Name="SenderAddressTextBox"/><Label Content="$($L.DevRecipient)"/><TextBox x:Name="DevRecipientTextBox"/><Label Content="$($L.ProdRecipient)"/><TextBox x:Name="ProdRecipientTextBox"/><Label Content="$($L.SubjectPrefix)"/><TextBox x:Name="SubjectPrefixTextBox"/><CheckBox x:Name="UseSslCheckBox" Content="$($L.UseSsl)" Margin="0,10,0,0"/><Button x:Name="SetSmtpCredsButton" Content="$($L.SetSmtpCreds)" Margin="0,15,0,0" HorizontalAlignment="Left"/></StackPanel></TabItem>
        </TabControl>
        <Grid Grid.Row="1" Margin="0,10,0,0"><Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions><Button x:Name="CancelButton" Content="$($L.Cancel)" IsCancel="True" Width="100" HorizontalAlignment="Left"/><Button x:Name="OkButton" Content="$($L.OK)" IsDefault="True" Width="100" Style="{StaticResource OkButton}" HorizontalAlignment="Right" Grid.Column="1"/></Grid>
    </Grid>
</Window>
"@
    $reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]$xaml); $window = [Windows.Markup.XamlReader]::Load($reader)
    if (Test-Path($p = Join-Path $cfg.Paths.LogoDirectory "muw-logo.ico")) { try { $window.Icon = [System.Windows.Media.Imaging.BitmapImage]::new([System.Uri]$p) } catch { Write-ScriptLog "Failed to load window icon from '$p'." "WARNING" } }
    $ctls = @{}; $names = @('RunModeComboBox', 'LanguageComboBox', 'Path7ZipTextBox', 'Browse7ZipButton', 'PathLogoTextBox', 'BrowseLogoButton', 'PathReportTextBox', 'BrowseReportButton', 'PathLogTextBox', 'BrowseLogButton', 'ExcelPathTextBox', 'BrowseExcelButton', 'AlwaysUsePathCheckBox', 'SheetNameComboBox', 'HeaderRowTextBox', 'CertColumnComboBox', 'DnsServerTextBox', 'EnableMailCheckBox', 'SmtpServerTextBox', 'SmtpPortTextBox', 'SenderAddressTextBox', 'DevRecipientTextBox', 'ProdRecipientTextBox', 'SubjectPrefixTextBox', 'UseSslCheckBox', 'SetSmtpCredsButton', 'CancelButton', 'OkButton', 'MainTabControl'); foreach ($n in $names) { $ctls[$n] = $window.FindName($n) }
    $ctls.RunModeComboBox.Text = $cfg.RunMode; $ctls.LanguageComboBox.Text = $cfg.Language; $ctls.Path7ZipTextBox.Text = $cfg.Paths.PathTo7Zip; $ctls.PathLogoTextBox.Text = $cfg.Paths.LogoDirectory; $ctls.PathReportTextBox.Text = $cfg.Paths.ReportDirectory; $ctls.PathLogTextBox.Text = $cfg.Paths.LogDirectory; $ctls.ExcelPathTextBox.Text = $cfg.Excel.ExcelPath; $ctls.AlwaysUsePathCheckBox.IsChecked = $cfg.Excel.AlwaysUseConfigPath; $ctls.SheetNameComboBox.Text = $cfg.Excel.SheetName; $ctls.HeaderRowTextBox.Text = $cfg.Excel.HeaderRow; $ctls.CertColumnComboBox.Text = $cfg.Excel.CertificateColumnName; $ctls.DnsServerTextBox.Text = $cfg.Network.DnsServer; $ctls.EnableMailCheckBox.IsChecked = $cfg.Mail.Enabled; $ctls.SmtpServerTextBox.Text = $cfg.Mail.SmtpServer; $ctls.SmtpPortTextBox.Text = $cfg.Mail.SmtpPort; $ctls.SenderAddressTextBox.Text = $cfg.Mail.SenderAddress; $ctls.DevRecipientTextBox.Text = $cfg.Mail.DevTo; $ctls.ProdRecipientTextBox.Text = $cfg.Mail.ProdTo; $ctls.SubjectPrefixTextBox.Text = $cfg.Mail.SubjectPrefix; $ctls.UseSslCheckBox.IsChecked = $cfg.Mail.UseSsl
    $UpdateSheetNameDropdown = { param($excelPath)
        $ctls.SheetNameComboBox.ItemsSource = $null; $ctls.SheetNameComboBox.IsEnabled = $false; if ([string]::IsNullOrWhiteSpace($excelPath) -or -not (Test-Path $excelPath)) { return }; try { Write-Progress -Activity $L.ExcelInfoLoading -Status "Reading sheet names..." -PercentComplete 50; $sheetInfo = Get-ExcelSheetInfo -Path $excelPath -ErrorAction Stop; $ctls.SheetNameComboBox.ItemsSource = $sheetInfo.Name; $ctls.SheetNameComboBox.SelectedItem = $cfg.Excel.SheetName; $ctls.SheetNameComboBox.IsEnabled = $true } catch { Write-Warning ($L.ExcelReadError -f $excelPath, $_.Exception.Message) } finally { Write-Progress -Activity $L.ExcelInfoLoading -Completed }
    }
    $UpdateColumnDropdowns = { param($excelPath, $sheetName, $headerRow)
        $ctls.CertColumnComboBox.ItemsSource = $null; $ctls.CertColumnComboBox.IsEnabled = $false; if ([string]::IsNullOrWhiteSpace($excelPath) -or -not (Test-Path $excelPath) -or [string]::IsNullOrWhiteSpace($sheetName)) { return }; try { Write-Progress -Activity $L.ExcelInfoLoading -Status "Reading column headers from '$sheetName'..." -PercentComplete 50; $headers = (Import-Excel -Path $excelPath -WorksheetName $sheetName -HeaderRow $headerRow | Select-Object -First 1).PSObject.Properties.Name; $ctls.CertColumnComboBox.ItemsSource = $headers; $ctls.CertColumnComboBox.SelectedItem = $cfg.Excel.CertificateColumnName; $ctls.CertColumnComboBox.IsEnabled = $true; } catch { Write-Warning ($L.ExcelReadError -f $excelPath, $_.Exception.Message) } finally { Write-Progress -Activity $L.ExcelInfoLoading -Completed }
    }
    $ctls.BrowseExcelButton.add_Click({ $fd = New-Object System.Windows.Forms.OpenFileDialog; $fd.Title = $L.SelectExcelFile; $fd.Filter = "Excel (*.xlsx)|*.xlsx"; if ($fd.ShowDialog() -eq 'OK') { $ctls.ExcelPathTextBox.Text = $fd.FileName; & $UpdateSheetNameDropdown -excelPath $fd.FileName } })
    $ctls.ExcelPathTextBox.add_LostFocus({ if (-not [string]::IsNullOrWhiteSpace($ctls.ExcelPathTextBox.Text)) { & $UpdateSheetNameDropdown -excelPath $ctls.ExcelPathTextBox.Text } })
    $ctls.SheetNameComboBox.add_SelectionChanged({ & $UpdateColumnDropdowns -excelPath $ctls.ExcelPathTextBox.Text -sheetName $ctls.SheetNameComboBox.SelectedItem -headerRow $ctls.HeaderRowTextBox.Text })
    $ctls.HeaderRowTextBox.add_LostFocus({ if (-not [string]::IsNullOrWhiteSpace($ctls.HeaderRowTextBox.Text)) { & $UpdateColumnDropdowns -excelPath $ctls.ExcelPathTextBox.Text -sheetName $ctls.SheetNameComboBox.SelectedItem -headerRow $ctls.HeaderRowTextBox.Text } })
    $ctls.MainTabControl.SelectedIndex = 1; $ctls.SheetNameComboBox.IsEnabled = $false; $ctls.CertColumnComboBox.IsEnabled = $false
    $initialExcelPath = $ctls.ExcelPathTextBox.Text
    if (-not [string]::IsNullOrWhiteSpace($initialExcelPath) -and (Test-Path $initialExcelPath)) { & $UpdateSheetNameDropdown -excelPath $initialExcelPath; if ($ctls.SheetNameComboBox.SelectedItem) { & $UpdateColumnDropdowns -excelPath $initialExcelPath -sheetName $ctls.SheetNameComboBox.SelectedItem -headerRow $ctls.HeaderRowTextBox.Text } }
    $ctls.SetSmtpCredsButton.add_Click({ try { $c = $Host.UI.PromptForCredential($L.CredsSavedTitle, "", "", "SMTP"); if ($c) { $c | Export-CliXml -Path $cfg.Mail.CredentialFilePath; [System.Windows.Forms.MessageBox]::Show($L.CredsSavedMsg, $L.CredsSavedTitle, 'OK', 'Information') } } catch { Write-Warning "Failed to set credentials: $($_.Exception.Message)" } })
    $ctls.OkButton.add_Click({
            $cfg.RunMode = $ctls.RunModeComboBox.SelectedItem.Content; $cfg.Language = $ctls.LanguageComboBox.SelectedItem.Content; $cfg.Paths.PathTo7Zip = $ctls.Path7ZipTextBox.Text; $cfg.Paths.LogoDirectory = $ctls.PathLogoTextBox.Text; $cfg.Paths.ReportDirectory = $ctls.PathReportTextBox.Text; $cfg.Paths.LogDirectory = $ctls.PathLogTextBox.Text; $cfg.Excel.ExcelPath = $ctls.ExcelPathTextBox.Text; $cfg.Excel.AlwaysUseConfigPath = $ctls.AlwaysUsePathCheckBox.IsChecked; $cfg.Excel.SheetName = $ctls.SheetNameComboBox.Text; $cfg.Excel.HeaderRow = [int]$ctls.HeaderRowTextBox.Text; $cfg.Excel.CertificateColumnName = $ctls.CertColumnComboBox.Text; $cfg.Network.DnsServer = $ctls.DnsServerTextBox.Text; $cfg.Mail.Enabled = $ctls.EnableMailCheckBox.IsChecked; $cfg.Mail.SmtpServer = $ctls.SmtpServerTextBox.Text; $cfg.Mail.SmtpPort = [int]$ctls.SmtpPortTextBox.Text; $cfg.Mail.SenderAddress = $ctls.SenderAddressTextBox.Text; $cfg.Mail.DevTo = $ctls.DevRecipientTextBox.Text; $cfg.Mail.ProdTo = $ctls.ProdRecipientTextBox.Text; $cfg.Mail.SubjectPrefix = $ctls.SubjectPrefixTextBox.Text; $cfg.Mail.UseSsl = $ctls.UseSslCheckBox.IsChecked
            Save-Configuration; $window.DialogResult = $true; $window.Close()
        })
    Write-Progress -Activity ($State.UIStrings.GUIWindowTitle -f $State.ScriptName, $State.ScriptVersion) -Status "Done" -Completed
    return $window.ShowDialog()
}
#endregion

#region Kernfunktionen
function Start-LogRotationAndArchive {
    param($ConfigObject)
    $sevenZipPath = $ConfigObject.Paths.PathTo7Zip; $logDir = if ([System.IO.Path]::IsPathRooted($ConfigObject.Paths.LogDirectory)) { $ConfigObject.Paths.LogDirectory } else { Join-Path $State.ScriptRoot $ConfigObject.Paths.LogDirectory }; $use7Zip = Test-Path $sevenZipPath -PathType Leaf
    $archiveCutoff = (Get-Date).AddDays(-$ConfigObject.Intervals.ArchiveLogsOlderThanDays); $logsToArchive = Get-ChildItem -Path $logDir -Filter "*.log" -File | Where-Object { $_.LastWriteTime -lt $archiveCutoff }
    if ($logsToArchive) { Write-ScriptLog "Archiving old log files..." "DEBUG"; $logsToArchive | Group-Object { $_.LastWriteTime.ToString("yyyy_MM") } | ForEach-Object { $zipFile = Join-Path $logDir "$($State.BaseScriptName)_$($_.Name).zip"; if ($use7Zip) { & $sevenZipPath a -tzip $zipFile $_.Group.FullName | Out-Null } else { Compress-Archive -Path $_.Group.FullName -DestinationPath $zipFile -Update -ErrorAction SilentlyContinue }; Remove-Item $_.Group.FullName -Force } }
    $deleteCutoff = (Get-Date).AddDays(-$ConfigObject.Intervals.DeleteZipArchivesOlderThanDays)
    Get-ChildItem -Path $logDir -Filter "*.zip" -File | Where-Object { $_.LastWriteTime -lt $deleteCutoff } | ForEach-Object { Write-ScriptLog "Deleting old log archive: $($_.Name)" "DEBUG"; $_ | Remove-Item -Force }
}
function Get-CertificateExpiryDate {
    param([string]$TargetHost, $ConfigObject)
    $hostname, $port = $TargetHost, 443; if ($TargetHost -match ':(\d+)$') { $hostname = $TargetHost.Split(':')[0]; $port = $matches[1] }
    try { $ipAddressString = (Resolve-DnsName -Name $hostname -Server $ConfigObject.Network.DnsServer -ErrorAction Stop).IPAddress[0]; $ipAddress = [System.Net.IPAddress]::Parse($ipAddressString) } catch { return "DNS resolution failed for '$hostname' using server '$($ConfigObject.Network.DnsServer)'. Error: $($_.Exception.Message)" }
    $tcpClient = New-Object System.Net.Sockets.TcpClient
    try { $tcpClient.Connect($ipAddress, $port); if ($tcpClient.Connected) { $sslStream = New-Object System.Net.Security.SslStream($tcpClient.GetStream(), $false, { $true }); $sslStream.AuthenticateAsClient($hostname); return (New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($sslStream.RemoteCertificate)).NotAfter } } catch { return "Could not retrieve certificate from '$TargetHost' (IP: $ipAddress). Error: $($_.Exception.Message)" } finally { if ($tcpClient.Connected) { $tcpClient.Close() } }; return $null
}
function Get-CertificateData {
    param($ConfigObject)
    Resolve-ModuleDependency -ConfigObject $ConfigObject
    $allExcelData = Import-Excel -Path $ConfigObject.Excel.ExcelPath -WorksheetName $ConfigObject.Excel.SheetName -HeaderRow $ConfigObject.Excel.HeaderRow
    $certColumn = $ConfigObject.Excel.CertificateColumnName
    Write-ScriptLog "Found $($allExcelData.Count) total rows. Filtering..." "DEBUG"
    $excelData = $allExcelData | Where-Object { (-not [string]::IsNullOrWhiteSpace($_.$certColumn)) -and ($_.$certColumn -like '*.meduniwien.ac.at*') }
    Write-ScriptLog "Processing $($excelData.Count) rows after filtering." "DEBUG"

    $renewDateColumn = 'ReNewDate'
    if ($PSVersionTable.PSVersion.Major -ge 7) {
        $getCertFuncDef = "function Get-CertificateExpiryDate { $(& { ${function:Get-CertificateExpiryDate} }) }"
        $results = $excelData | ForEach-Object -ThrottleLimit 8 -Parallel {
            . ([scriptblock]::Create($using:getCertFuncDef)); $row = $_; $config = $using:ConfigObject; $logEntries = [System.Collections.Generic.List[string]]::new()
            $targets = $row.($config.Excel.CertificateColumnName) -split '\|' | ForEach-Object Trim | Where-Object { $_ -like '*.meduniwien.ac.at*' }
            $renewDates = foreach ($target in $targets) { $expiryResult = Get-CertificateExpiryDate -TargetHost $target -ConfigObject $config; if ($expiryResult -is [datetime]) { $expiryResult.ToString("yyyy.MM.dd") } else { if ($expiryResult) { $logEntries.Add($expiryResult) }; "Error/NA" } }
            $outputHashtable = @{}; foreach ($prop in $row.PSObject.Properties) { $outputHashtable[$prop.Name] = $prop.Value }
            $outputHashtable[$using:renewDateColumn] = $renewDates -join " | "; [pscustomobject]@{ Row = ([pscustomobject]$outputHashtable); Logs = $logEntries }
        }
        $processedData = @(); foreach ($result in $results) { $processedData += $result.Row; foreach ($log in $result.Logs) { Write-ScriptLog $log "WARNING" } }; return $processedData
    }
    else {
        return ($excelData | ForEach-Object {
                $newRow = @{}; $_.PSObject.Properties | ForEach-Object { $newRow[$_.Name] = $_.Value }
                $targets = $_.($ConfigObject.Excel.CertificateColumnName) -split '\|' | ForEach-Object Trim | Where-Object { $_ -like '*.meduniwien.ac.at*' }
                $renewDates = foreach ($target in $targets) { $expiryResult = Get-CertificateExpiryDate -TargetHost $target -ConfigObject $ConfigObject; if ($expiryResult -is [datetime]) { $expiryResult.ToString("yyyy.MM.dd") } else { if ($expiryResult) { Write-ScriptLog $expiryResult "WARNING" }; "Error/NA" } }
                $newRow[$renewDateColumn] = $renewDates -join " | "; [PSCustomObject]$newRow
            })
    }
}
function New-HtmlReport {
    param($ProcessedData, $ConfigObject)
    $today = (Get-Date).Date; $renewDateColumn = 'ReNewDate'
    $reportItems = @()
    foreach ($row in $ProcessedData) {
        $certNamesInCell = $row.($ConfigObject.Excel.CertificateColumnName) -split '\|' | ForEach-Object Trim | Where-Object { $_ -like '*.meduniwien.ac.at*' }
        $renewDatesInCell = $row.$renewDateColumn -split '\|' | ForEach-Object Trim

        # This loop creates a report item for each valid certificate found in the cell
        for ($i = 0; $i -lt $certNamesInCell.Count; $i++) {
            $status = "Error"; $daysLeft = "N/A"; $expiryDateString = $renewDatesInCell[$i]
            try {
                if ($expiryDateString -match '^\d{4}\.\d{2}\.\d{2}$') {
                    $expiryDate = [datetime]::ParseExact($expiryDateString, "yyyy.MM.dd", $null)
                    $daysLeft = ($expiryDate - $today).Days
                    if ($daysLeft -le 0) { $status = "Expired" }
                    elseif ($daysLeft -le $ConfigObject.Intervals.DaysUntilUrgent) { $status = "Urgent" }
                    elseif ($daysLeft -le $ConfigObject.Intervals.DaysUntilCritical) { $status = "Critical" }
                    elseif ($daysLeft -le $ConfigObject.Intervals.DaysUntilWarning) { $status = "Warning" }
                    else { $status = "OK" }
                }
            }
            catch { Write-ScriptLog ($State.UIStrings.ReportDateParseError -f $expiryDateString, $certNamesInCell[$i]) "WARNING" }
            $reportItems += [PSCustomObject]@{ Certificate = $certNamesInCell[$i]; ExpiryDate = $expiryDateString; DaysLeft = $daysLeft; Status = $status }
        }
    }
    $head = "<style>body{font-family:Segoe UI,Arial;font-size:10pt}table{border-collapse:collapse;width:100%}th,td{border:1px solid #ddd;padding:8px;text-align:left}th{background-color:#f2f2f2}.status-OK{background-color:#dff0d8}.status-Expired{background-color:#d9534f;color:white;font-weight:700}.status-Urgent{background-color:#e67e22;color:white}.status-Critical{background-color:#f0ad4e}.status-Warning{background-color:#fcf8e3}</style>"
    $body = "<h1>Certificate Expiry Report | $(Get-Date -f yyyy.MM.dd)</h1>"
    $statusOrder = @("Expired", "Urgent", "Critical", "Warning", "OK", "Error")
    $groupedItems = $reportItems | Group-Object Status | Sort-Object { $statusOrder.IndexOf($_.Name) }
    foreach ($group in $groupedItems) { $body += "<h2>Status: $($group.Name) ($($group.Count))</h2>"; $body += $group.Group | Sort-Object DaysLeft | ConvertTo-Html -As Table -Fragment | ForEach-Object { $_ -replace '<table', "<table class='status-table status-$($group.Name)'" } }
    return ConvertTo-Html -Head $head -Body $body | Out-String
}
function Send-ReportEmail {
    param($HtmlBody, $ConfigObject)
    if (-not $ConfigObject.Mail.Enabled) { return }
    $recipient = if ($ConfigObject.RunMode -eq 'PRODto') { $ConfigObject.Mail.ProdTo } else { $ConfigObject.Mail.DevTo }
    if ([string]::IsNullOrWhiteSpace($recipient)) { Write-ScriptLog ($State.UIStrings.EmailNoRecipient -f $ConfigObject.RunMode) "WARNING"; return }
    if (-not (Test-NetConnection -ComputerName $ConfigObject.Mail.SmtpServer -Port $ConfigObject.Mail.SmtpPort -WarningAction SilentlyContinue).TcpTestSucceeded) { Write-ScriptLog ($State.UIStrings.SmtpTestFailed -f $ConfigObject.Mail.SmtpServer, $ConfigObject.Mail.SmtpPort) "WARNING"; return }
    $smtpClient = New-Object System.Net.Mail.SmtpClient($ConfigObject.Mail.SmtpServer, $ConfigObject.Mail.SmtpPort)
    $mailMessage = New-Object System.Net.Mail.MailMessage
    try {
        $smtpClient.EnableSsl = $ConfigObject.Mail.UseSsl
        if (Test-Path $ConfigObject.Mail.CredentialFilePath) { $smtpClient.Credentials = (Import-CliXml -Path $ConfigObject.Mail.CredentialFilePath).GetNetworkCredential() }
        $mailMessage.From = $ConfigObject.Mail.SenderAddress; $mailMessage.To.Add($recipient); $mailMessage.Subject = "$($ConfigObject.Mail.SubjectPrefix) $(Get-Date -f yyyy.MM.dd)"; $mailMessage.Body = $HtmlBody; $mailMessage.IsBodyHtml = $true
        Write-ScriptLog "Sending email to '$recipient'..."; $smtpClient.Send($mailMessage)
    }
    catch { Write-ScriptLog "Failed to send email: $($_.Exception.Message)" "ERROR" } finally { if ($smtpClient) { $smtpClient.Dispose() }; if ($mailMessage) { $mailMessage.Dispose() } }
}
#endregion

#region Hauptausführung
function Invoke-Main {
    Write-ScriptLog ($State.UIStrings.ScriptStart -f $State.ScriptName, $State.Config.Version)
    if ($State.Config.DebugMode) { Write-ScriptLog $State.UIStrings.DebugModeActive "DEBUG" }
    Test-AndCreatePaths -ConfigObject $State.Config; Start-LogRotationAndArchive -ConfigObject $State.Config
    if (-not $State.Config.Excel.AlwaysUseConfigPath) {
        $fd = New-Object System.Windows.Forms.OpenFileDialog; $fd.Title = $State.UIStrings.SelectExcelFile; $fd.Filter = "Excel (*.xlsx)|*.xlsx"
        if ($fd.ShowDialog() -eq 'OK') { $State.Config.Excel.ExcelPath = $fd.FileName } else { Write-ScriptLog $State.UIStrings.UserCancelledFileSelection; return }
    }
    if (-not (Test-Path $State.Config.Excel.ExcelPath)) { Write-ScriptLog "Excel file not found at '$($State.Config.Excel.ExcelPath)'. Exiting." "ERROR"; return }
    if ([string]::IsNullOrWhiteSpace($State.Config.Excel.SheetName) -or [string]::IsNullOrWhiteSpace($State.Config.Excel.CertificateColumnName)) { throw $State.UIStrings.ConfigIncomplete }

    $processedData = Get-CertificateData -ConfigObject $State.Config
    if ($processedData) {
        $htmlReport = New-HtmlReport -ProcessedData $processedData -ConfigObject $State.Config
        $reportDir = if ([System.IO.Path]::IsPathRooted($State.Config.Paths.ReportDirectory)) { $State.Config.Paths.ReportDirectory } else { Join-Path $State.ScriptRoot $State.Config.Paths.ReportDirectory }
        $reportPath = Join-Path $reportDir "$($State.BaseScriptName)_Report_$(Get-Date -f yyyy.MM.dd).html"
        $htmlReport | Set-Content -Path $reportPath -Encoding $Global:State.CorrectEncoding
        Write-ScriptLog "HTML report saved to '$reportPath'"; Send-ReportEmail -HtmlBody $htmlReport -ConfigObject $State.Config
    }
    else { Write-ScriptLog $State.UIStrings.NoDataProcessed "WARNING" }
}

# Skriptstart
try {
    Import-Configuration
    if ($Setup.IsPresent) { Show-ConfigurationGUI; exit 0 }
    Invoke-Main
}
catch {
    $exceptionMessage = if ($_ -is [System.Exception]) { $_.Exception.Message } else { $_.ToString() }
    $errorMessage = if ($State.UIStrings) { $State.UIStrings.UnhandledError -f $exceptionMessage } else { "A critical, unhandled error occurred: $exceptionMessage" }
    Write-ScriptLog $errorMessage "ERROR"
}
finally {
    $endMessage = if ($State.UIStrings) { $State.UIStrings.ScriptEnd -f $State.ScriptName } else { "Script finished: $($State.ScriptName)" }
    Write-ScriptLog $endMessage
}
#endregion

# --- Ende des Skripts v09.00.05 ---

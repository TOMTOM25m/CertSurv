#Requires -Version 5.1

<#
.SYNOPSIS
    Certificate Surveillance Configuration GUI - Regelwerks-konforme Konfigurationsoberfl?che

.DESCRIPTION
    Vollst?ndige WPF-basierte GUI zur Konfiguration des Certificate Surveillance Systems.
    Unterst?tzt Tab-basierte Navigation, Pfad-Konfiguration und regelwerk-konforme Bedienung.

.NOTES
    Author: Flecki (Tom) Garnreiter
    Version: v1.4.0
    Regelwerk: v9.5.0
    Build: 20250924.2
    Component: Configuration GUI
    
    REGELWERK v9.5.0 COMPLIANCE:
    - ? Robocopy f?r File-Operations
    - ? Script Versioning Standards
    - ? Network Operations Best Practices
    - ? WPF GUI Standards mit Tabs
#>

#region Version Management (MANDATORY - Regelwerk v9.5.0)
# Import version information
if (Test-Path "$PSScriptRoot\VERSION.ps1") {
    . "$PSScriptRoot\VERSION.ps1"
    Write-Verbose "VERSION.ps1 loaded - System: v$Global:CertSurvSystemVersion"
} else {
    # Fallback version information
    $Global:CertSurvSystemVersion = "1.4.0"
    $Global:CertSurvGUIVersion = "1.4.0"
    $Global:CertSurvRegelwerkVersion = "9.5.0"
    Write-Warning "VERSION.ps1 not found - using fallback versions"
}

# Display script information (MANDATORY - Regelwerk v9.5.0)
function Show-ScriptInfo {
    Write-Host "?? Setup-CertSurvGUI.ps1 v$Global:CertSurvGUIVersion" -ForegroundColor Green
    Write-Host "?? Build: 20250924.2 | Regelwerk: v$Global:CertSurvRegelwerkVersion" -ForegroundColor Cyan
    Write-Host "?? Author: Flecki (Tom) Garnreiter" -ForegroundColor Cyan
    Write-Host "Server: $env:COMPUTERNAME" -ForegroundColor Yellow
}
#endregion

#region PowerShell Version Detection (MANDATORY - Regelwerk v9.5.0)
$PSVersion = $PSVersionTable.PSVersion
$IsPS7Plus = $PSVersion.Major -ge 7
$IsPS5 = $PSVersion.Major -eq 5
$IsPS51 = $PSVersion.Major -eq 5 -and $PSVersion.Minor -eq 1

Write-Verbose "Setup-CertSurvGUI - PowerShell Version: $($PSVersion.ToString())"
Write-Verbose "Compatibility Mode: $(if($IsPS7Plus){'PowerShell 7.x Enhanced'}elseif($IsPS51){'PowerShell 5.1 Compatible'}else{'PowerShell 5.x Standard'})"
#endregion

#region Assembly Loading and Error Handling
try {
    Add-Type -AssemblyName PresentationFramework
    Add-Type -AssemblyName System.Windows.Forms  
    Add-Type -AssemblyName PresentationCore
} catch {
    Write-Host "Error loading required assemblies: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Ensure you're running on Windows with .NET Framework or PowerShell with WPF support." -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 1
}
#endregion

#region Configuration Templates and Defaults
function Get-DefaultConfiguration {
    return @{
        # Basis-Konfiguration
        "LogLevel" = "INFO"
        "CheckIntervalHours" = 24
        "WarningDaysBeforeExpiry" = 30
        "CriticalDaysBeforeExpiry" = 7
        
        # Pfad-Konfiguration
        "ExcelFilePath" = "C:\Script\CertSurv-Master\Data\Server-List.xlsx"
        "LogDirectory" = "C:\Script\CertSurv-Master\LOG"
        "ConfigDirectory" = "C:\Script\CertSurv-Master\Config"
        "ReportsDirectory" = "C:\Script\CertSurv-Master\Reports"
        "BackupDirectory" = "C:\Script\CertSurv-Master\Backup"
        "TempDirectory" = "C:\Script\CertSurv-Master\Temp"
        
        # CD/Laufwerk-Konfiguration
        "InstallationDrive" = "C:"
        "WorkingDirectory" = "C:\Script\CertSurv-Master"
        "NetworkSharePath" = "\\itscmgmt03.srv.meduniwien.ac.at\iso\CertSurv"
        
        # E-Mail-Konfiguration
        "EnableEmailNotifications" = $false
        "SmtpServer" = "smtp.meduniwien.ac.at"
        "SmtpPort" = 25
        "SmtpUsername" = ""
        "SmtpPassword" = ""
        "FromEmail" = ""
        "ToEmails" = @()
        "EnableSsl" = $false
        
        # WebService-Konfiguration
        "EnableWebService" = $true
        "WebServicePort" = 8443
        "WebServiceUrl" = "https://localhost:8443"
        "WebServiceLogLevel" = "INFO"
        
        # Zertifikat-Scanning
        "CertStores" = @("LocalMachine\My", "LocalMachine\Root", "LocalMachine\CA")
        "ScanRemoteCertificates" = $true
        "CertificateThumbprints" = @()
        
        # Erweiterte Einstellungen
        "MaxConcurrentScans" = 10
        "ScanTimeoutSeconds" = 30
        "RetryAttempts" = 3
        "EnableDetailedLogging" = $false
        "ArchiveOldLogs" = $true
        "MaxLogFiles" = 30
    }
}

#region Configuration Functions
function Get-ConfigContent {
    param([string]$ConfigPath)
    
    if (Test-Path $ConfigPath) {
        try {
            $rawContent = Get-Content $ConfigPath -Raw -Encoding UTF8
            if ([string]::IsNullOrWhiteSpace($rawContent)) {
                Write-Host "Config file is empty, creating default configuration..." -ForegroundColor Yellow
                return Create-DefaultConfig -ConfigPath $ConfigPath
            }
            $content = $rawContent | ConvertFrom-Json
            
            # Merge with defaults to ensure all properties exist
            $defaults = Get-DefaultConfiguration
            $merged = @{}
            foreach ($key in $defaults.Keys) {
                if ($content.PSObject.Properties.Name -contains $key) {
                    $merged[$key] = $content.$key
                } else {
                    $merged[$key] = $defaults[$key]
                    Write-Host "Added missing config property: $key" -ForegroundColor Yellow
                }
            }
            
            Write-Host "Configuration loaded: $($merged.Keys.Count) properties found" -ForegroundColor Green
            return [PSCustomObject]$merged
        } catch {
            Write-Host "Error reading config file: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "Creating default configuration..." -ForegroundColor Yellow
            return Create-DefaultConfig -ConfigPath $ConfigPath
        }
    } else {
        Write-Host "Config file not found: $ConfigPath" -ForegroundColor Red
        Write-Host "Creating default configuration..." -ForegroundColor Yellow
        return Create-DefaultConfig -ConfigPath $ConfigPath
    }
}

function Create-DefaultConfig {
    param([string]$ConfigPath)
    
    $defaultConfig = Get-DefaultConfiguration
    
    try {
        # Ensure directory exists
        $configDir = Split-Path -Parent $ConfigPath
        if (-not (Test-Path $configDir)) {
            New-Item -Path $configDir -ItemType Directory -Force | Out-Null
        }
        
        $defaultConfig | ConvertTo-Json -Depth 10 | Out-File $ConfigPath -Encoding UTF8 -Force
        Write-Host "Default configuration created at: $ConfigPath" -ForegroundColor Green
        return [PSCustomObject]$defaultConfig
    } catch {
        Write-Host "Error creating default config: $($_.Exception.Message)" -ForegroundColor Red
        return [PSCustomObject]$defaultConfig
    }
}

function Save-ConfigContent {
    param(
        [object]$Config,
        [string]$ConfigPath
    )
    
    try {
        # Create backup
        if (Test-Path $ConfigPath) {
            $backupPath = "$ConfigPath.backup.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
            Copy-Item $ConfigPath $backupPath -Force
            Write-Host "Backup created: $backupPath" -ForegroundColor Green
        }
        
        # Save with proper formatting
        $Config | ConvertTo-Json -Depth 10 | Out-File $ConfigPath -Encoding UTF8 -Force
        Write-Host "Configuration saved successfully" -ForegroundColor Green
        return $true
    } catch {
        Write-Host "Error saving config: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}
#endregion

#region GUI Functions
function Show-ConfigGUI {
    param([object]$Config, [string]$ConfigPath)
    
    # Create main window
    $window = [System.Windows.Window]::new()
    $window.Title = "Certificate Surveillance Configuration v$($Global:CertSurvGUIVersion) - Regelwerk v$($Global:CertSurvRegelwerkVersion)"
    $window.Width = 950
    $window.Height = 800
    $window.WindowStartupLocation = 'CenterScreen'
    $window.ResizeMode = 'CanResize'
    
    # Create main grid
    $mainGrid = [System.Windows.Controls.Grid]::new()
    $window.Content = $mainGrid
    
    # Define main grid rows
    $titleRow = [System.Windows.Controls.RowDefinition]::new()
    $titleRow.Height = 'Auto'
    $contentRow = [System.Windows.Controls.RowDefinition]::new()
    $contentRow.Height = '*'
    $buttonRow = [System.Windows.Controls.RowDefinition]::new()
    $buttonRow.Height = 'Auto'
    
    $mainGrid.RowDefinitions.Add($titleRow)
    $mainGrid.RowDefinitions.Add($contentRow)
    $mainGrid.RowDefinitions.Add($buttonRow)
    
    # Add title
    $title = [System.Windows.Controls.TextBlock]::new()
    $title.Text = "Certificate Surveillance System - Regelwerk-konforme Konfiguration"
    $title.FontSize = 18
    $title.FontWeight = 'Bold'
    $title.Margin = [System.Windows.Thickness]::new(10,10,10,20)
    $title.HorizontalAlignment = 'Center'
    [System.Windows.Controls.Grid]::SetRow($title, 0)
    $mainGrid.Children.Add($title)
    
    # Create TabControl
    $tabControl = [System.Windows.Controls.TabControl]::new()
    $tabControl.Margin = [System.Windows.Thickness]::new(10,0,10,10)
    [System.Windows.Controls.Grid]::SetRow($tabControl, 1)
    $mainGrid.Children.Add($tabControl)
    
    # Store controls for saving
    $script:allControls = @{}
    
    # Create tabs
    Create-BasicTab -TabControl $tabControl -Config $Config
    Create-PathsTab -TabControl $tabControl -Config $Config  
    Create-EmailTab -TabControl $tabControl -Config $Config
    Create-WebServiceTab -TabControl $tabControl -Config $Config
    Create-CertificateTab -TabControl $tabControl -Config $Config
    Create-AdvancedTab -TabControl $tabControl -Config $Config
    
    # Create button panel (Regelwerk-konform: OK, Uebernehmen, Abbruch)
    $buttonPanel = [System.Windows.Controls.StackPanel]::new()
    $buttonPanel.Orientation = 'Horizontal'
    $buttonPanel.HorizontalAlignment = 'Center'
    $buttonPanel.Margin = [System.Windows.Thickness]::new(10,10,10,20)
    [System.Windows.Controls.Grid]::SetRow($buttonPanel, 2)
    $mainGrid.Children.Add($buttonPanel)
    
    # OK Button (Uebernehmen und Schliessen)
    $okButton = [System.Windows.Controls.Button]::new()
    $okButton.Content = "OK (Uebernehmen)"
    $okButton.Width = 150
    $okButton.Height = 35
    $okButton.Margin = [System.Windows.Thickness]::new(5)
    $okButton.IsDefault = $true
    $okButton.Add_Click({
        $result = Save-Configuration -Config $Config -ConfigPath $ConfigPath -Controls $script:allControls
        if ($result) {
            $window.DialogResult = $true
            $window.Close()
        }
    })
    $buttonPanel.Children.Add($okButton)
    
    # Apply Button (Anwenden ohne Schliessen)
    $applyButton = [System.Windows.Controls.Button]::new()
    $applyButton.Content = "Anwenden"
    $applyButton.Width = 120
    $applyButton.Height = 35
    $applyButton.Margin = [System.Windows.Thickness]::new(5)
    $applyButton.Add_Click({
        Save-Configuration -Config $Config -ConfigPath $ConfigPath -Controls $script:allControls | Out-Null
    })
    $buttonPanel.Children.Add($applyButton)
    
    # Cancel Button (Abbruch)
    $cancelButton = [System.Windows.Controls.Button]::new()
    $cancelButton.Content = "Abbruch"
    $cancelButton.Width = 120
    $cancelButton.Height = 35
    $cancelButton.Margin = [System.Windows.Thickness]::new(5)
    $cancelButton.IsCancel = $true
    $cancelButton.Add_Click({
        $window.DialogResult = $false
        $window.Close()
    })
    $buttonPanel.Children.Add($cancelButton)
    
    # Show window
    return $window.ShowDialog()
}

function Create-BasicTab {
    param([System.Windows.Controls.TabControl]$TabControl, [object]$Config)
    
    $tab = [System.Windows.Controls.TabItem]::new()
    $tab.Header = "Basis-Einstellungen"
    
    $scrollViewer = [System.Windows.Controls.ScrollViewer]::new()
    $scrollViewer.VerticalScrollBarVisibility = 'Auto'
    
    $grid = Create-FormGrid
    $scrollViewer.Content = $grid
    $tab.Content = $scrollViewer
    
    # Add form fields
    $row = 0
    Add-FormField -Grid $grid -Row ([ref]$row) -Label "Log Level:" -PropertyPath "LogLevel" -Value $Config.LogLevel -Type "ComboBox" -Options @("DEBUG", "INFO", "WARNING", "ERROR") | Out-Null
    Add-FormField -Grid $grid -Row ([ref]$row) -Label "Pruefintervall (Stunden):" -PropertyPath "CheckIntervalHours" -Value $Config.CheckIntervalHours -Type "Integer" | Out-Null
    Add-FormField -Grid $grid -Row ([ref]$row) -Label "Warnung vor Ablauf (Tage):" -PropertyPath "WarningDaysBeforeExpiry" -Value $Config.WarningDaysBeforeExpiry -Type "Integer"
    Add-FormField -Grid $grid -Row ([ref]$row) -Label "Kritisch vor Ablauf (Tage):" -PropertyPath "CriticalDaysBeforeExpiry" -Value $Config.CriticalDaysBeforeExpiry -Type "Integer"
    Add-FormField -Grid $grid -Row ([ref]$row) -Label "Detailliertes Logging:" -PropertyPath "EnableDetailedLogging" -Value $Config.EnableDetailedLogging -Type "Boolean"
    Add-FormField -Grid $grid -Row ([ref]$row) -Label "Alte Logs archivieren:" -PropertyPath "ArchiveOldLogs" -Value $Config.ArchiveOldLogs -Type "Boolean"
    Add-FormField -Grid $grid -Row ([ref]$row) -Label "Max. Log-Dateien:" -PropertyPath "MaxLogFiles" -Value $Config.MaxLogFiles -Type "Integer"
    
    $TabControl.Items.Add($tab)
}

function Create-PathsTab {
    param([System.Windows.Controls.TabControl]$TabControl, [object]$Config)
    
    $tab = [System.Windows.Controls.TabItem]::new()
    $tab.Header = "Pfade und CD-Laufwerke"
    
    $scrollViewer = [System.Windows.Controls.ScrollViewer]::new()
    $scrollViewer.VerticalScrollBarVisibility = 'Auto'
    
    $grid = Create-FormGrid
    $scrollViewer.Content = $grid
    $tab.Content = $scrollViewer
    
    # Add form fields
    $row = 0
    Add-FormField -Grid $grid -Row ([ref]$row) -Label "Installations-Laufwerk (CD):" -PropertyPath "InstallationDrive" -Value $Config.InstallationDrive -Type "String"
    Add-FormField -Grid $grid -Row ([ref]$row) -Label "Arbeitsverzeichnis:" -PropertyPath "WorkingDirectory" -Value $Config.WorkingDirectory -Type "FolderPath"
    Add-FormField -Grid $grid -Row ([ref]$row) -Label "Excel-Datei Pfad:" -PropertyPath "ExcelFilePath" -Value $Config.ExcelFilePath -Type "FilePath"
    Add-FormField -Grid $grid -Row ([ref]$row) -Label "Log-Verzeichnis:" -PropertyPath "LogDirectory" -Value $Config.LogDirectory -Type "FolderPath"
    Add-FormField -Grid $grid -Row ([ref]$row) -Label "Config-Verzeichnis:" -PropertyPath "ConfigDirectory" -Value $Config.ConfigDirectory -Type "FolderPath"
    Add-FormField -Grid $grid -Row ([ref]$row) -Label "Reports-Verzeichnis:" -PropertyPath "ReportsDirectory" -Value $Config.ReportsDirectory -Type "FolderPath"
    Add-FormField -Grid $grid -Row ([ref]$row) -Label "Backup-Verzeichnis:" -PropertyPath "BackupDirectory" -Value $Config.BackupDirectory -Type "FolderPath"
    Add-FormField -Grid $grid -Row ([ref]$row) -Label "Temp-Verzeichnis:" -PropertyPath "TempDirectory" -Value $Config.TempDirectory -Type "FolderPath"
    Add-FormField -Grid $grid -Row ([ref]$row) -Label "Netzwerk-Share:" -PropertyPath "NetworkSharePath" -Value $Config.NetworkSharePath -Type "String"
    
    $TabControl.Items.Add($tab)
}

function Create-EmailTab {
    param([System.Windows.Controls.TabControl]$TabControl, [object]$Config)
    
    $tab = [System.Windows.Controls.TabItem]::new()
    $tab.Header = "E-Mail Benachrichtigungen"
    
    $scrollViewer = [System.Windows.Controls.ScrollViewer]::new()
    $scrollViewer.VerticalScrollBarVisibility = 'Auto'
    
    $grid = Create-FormGrid
    $scrollViewer.Content = $grid
    $tab.Content = $scrollViewer
    
    # Add form fields
    $row = 0
    Add-FormField -Grid $grid -Row ([ref]$row) -Label "E-Mail aktivieren:" -PropertyPath "EnableEmailNotifications" -Value $Config.EnableEmailNotifications -Type "Boolean"
    Add-FormField -Grid $grid -Row ([ref]$row) -Label "SMTP Server:" -PropertyPath "SmtpServer" -Value $Config.SmtpServer -Type "String"
    Add-FormField -Grid $grid -Row ([ref]$row) -Label "SMTP Port:" -PropertyPath "SmtpPort" -Value $Config.SmtpPort -Type "Integer"
    Add-FormField -Grid $grid -Row ([ref]$row) -Label "SMTP Benutzername:" -PropertyPath "SmtpUsername" -Value $Config.SmtpUsername -Type "String"
    Add-FormField -Grid $grid -Row ([ref]$row) -Label "SMTP Passwort:" -PropertyPath "SmtpPassword" -Value $Config.SmtpPassword -Type "Password"
    Add-FormField -Grid $grid -Row ([ref]$row) -Label "Von E-Mail:" -PropertyPath "FromEmail" -Value $Config.FromEmail -Type "String"
    
    # Handle ToEmails array
    $emailsText = if ($Config.ToEmails -and $Config.ToEmails.Count -gt 0) { $Config.ToEmails -join ";" } else { "" }
    Add-FormField -Grid $grid -Row ([ref]$row) -Label "An E-Mails (Semikolon-getrennt):" -PropertyPath "ToEmails" -Value $emailsText -Type "String"
    Add-FormField -Grid $grid -Row ([ref]$row) -Label "SSL aktivieren:" -PropertyPath "EnableSsl" -Value $Config.EnableSsl -Type "Boolean"
    
    $TabControl.Items.Add($tab)
}

function Create-WebServiceTab {
    param([System.Windows.Controls.TabControl]$TabControl, [object]$Config)
    
    $tab = [System.Windows.Controls.TabItem]::new()
    $tab.Header = "WebService"
    
    $scrollViewer = [System.Windows.Controls.ScrollViewer]::new()
    $scrollViewer.VerticalScrollBarVisibility = 'Auto'
    
    $grid = Create-FormGrid
    $scrollViewer.Content = $grid
    $tab.Content = $scrollViewer
    
    # Add form fields
    $row = 0
    Add-FormField -Grid $grid -Row ([ref]$row) -Label "WebService aktivieren:" -PropertyPath "EnableWebService" -Value $Config.EnableWebService -Type "Boolean"
    Add-FormField -Grid $grid -Row ([ref]$row) -Label "WebService Port:" -PropertyPath "WebServicePort" -Value $Config.WebServicePort -Type "Integer"
    Add-FormField -Grid $grid -Row ([ref]$row) -Label "WebService URL:" -PropertyPath "WebServiceUrl" -Value $Config.WebServiceUrl -Type "String"
    Add-FormField -Grid $grid -Row ([ref]$row) -Label "WebService Log Level:" -PropertyPath "WebServiceLogLevel" -Value $Config.WebServiceLogLevel -Type "ComboBox" -Options @("DEBUG", "INFO", "WARNING", "ERROR")
    
    $TabControl.Items.Add($tab)
}

function Create-CertificateTab {
    param([System.Windows.Controls.TabControl]$TabControl, [object]$Config)
    
    $tab = [System.Windows.Controls.TabItem]::new()
    $tab.Header = "Zertifikat-Scanning"
    
    $scrollViewer = [System.Windows.Controls.ScrollViewer]::new()
    $scrollViewer.VerticalScrollBarVisibility = 'Auto'
    
    $grid = Create-FormGrid
    $scrollViewer.Content = $grid
    $tab.Content = $scrollViewer
    
    # Add form fields
    $row = 0
    Add-FormField -Grid $grid -Row ([ref]$row) -Label "Remote Zertifikate scannen:" -PropertyPath "ScanRemoteCertificates" -Value $Config.ScanRemoteCertificates -Type "Boolean"
    
    # Handle CertStores array
    $storesText = if ($Config.CertStores -and $Config.CertStores.Count -gt 0) { $Config.CertStores -join ";" } else { "" }
    Add-FormField -Grid $grid -Row ([ref]$row) -Label "Zertifikat-Stores (Semikolon-getrennt):" -PropertyPath "CertStores" -Value $storesText -Type "String"
    
    # Handle CertificateThumbprints array
    $thumbprintsText = if ($Config.CertificateThumbprints -and $Config.CertificateThumbprints.Count -gt 0) { $Config.CertificateThumbprints -join ";" } else { "" }
    Add-FormField -Grid $grid -Row ([ref]$row) -Label "Zertifikat-Thumbprints (Semikolon-getrennt):" -PropertyPath "CertificateThumbprints" -Value $thumbprintsText -Type "String"
    
    $TabControl.Items.Add($tab)
}

function Create-AdvancedTab {
    param([System.Windows.Controls.TabControl]$TabControl, [object]$Config)
    
    $tab = [System.Windows.Controls.TabItem]::new()
    $tab.Header = "Erweiterte Einstellungen"
    
    $scrollViewer = [System.Windows.Controls.ScrollViewer]::new()
    $scrollViewer.VerticalScrollBarVisibility = 'Auto'
    
    $grid = Create-FormGrid
    $scrollViewer.Content = $grid
    $tab.Content = $scrollViewer
    
    # Add form fields
    $row = 0
    Add-FormField -Grid $grid -Row ([ref]$row) -Label "Max. gleichzeitige Scans:" -PropertyPath "MaxConcurrentScans" -Value $Config.MaxConcurrentScans -Type "Integer"
    Add-FormField -Grid $grid -Row ([ref]$row) -Label "Scan-Timeout (Sekunden):" -PropertyPath "ScanTimeoutSeconds" -Value $Config.ScanTimeoutSeconds -Type "Integer"
    Add-FormField -Grid $grid -Row ([ref]$row) -Label "Wiederholungsversuche:" -PropertyPath "RetryAttempts" -Value $Config.RetryAttempts -Type "Integer"
    
    $TabControl.Items.Add($tab)
}

function Create-FormGrid {
    $grid = [System.Windows.Controls.Grid]::new()
    $grid.Margin = [System.Windows.Thickness]::new(10)
    
    # Define columns
    $labelCol = [System.Windows.Controls.ColumnDefinition]::new()
    $labelCol.Width = '280'
    $inputCol = [System.Windows.Controls.ColumnDefinition]::new()
    $inputCol.Width = '*'
    $buttonCol = [System.Windows.Controls.ColumnDefinition]::new()
    $buttonCol.Width = 'Auto'
    
    $grid.ColumnDefinitions.Add($labelCol)
    $grid.ColumnDefinitions.Add($inputCol)
    $grid.ColumnDefinitions.Add($buttonCol)
    
    return $grid
}

function Add-FormField {
    param(
        [System.Windows.Controls.Grid]$Grid,
        [ref]$Row,
        [string]$Label,
        [string]$PropertyPath,
        [object]$Value,
        [string]$Type = 'String',
        [string[]]$Options = @()
    )
    
    # Add Windows.Forms assembly for dialogs
    Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
    
    # Add row definition
    $rowDef = [System.Windows.Controls.RowDefinition]::new()
    $rowDef.Height = 'Auto'
    $rowDef.MinHeight = 30
    $Grid.RowDefinitions.Add($rowDef)
    
    # Create label
    $labelControl = [System.Windows.Controls.Label]::new()
    $labelControl.Content = $Label
    $labelControl.Margin = [System.Windows.Thickness]::new(5)
    $labelControl.VerticalAlignment = 'Center'
    [System.Windows.Controls.Grid]::SetColumn($labelControl, 0)
    [System.Windows.Controls.Grid]::SetRow($labelControl, $Row.Value)
    $Grid.Children.Add($labelControl)
    
    # Create input control based on type
    $control = $null
    switch ($Type) {
        'Boolean' {
            $control = [System.Windows.Controls.CheckBox]::new()
            $control.IsChecked = [bool]$Value
        }
        'Integer' {
            $control = [System.Windows.Controls.TextBox]::new()
            $control.Text = [string]$Value
        }
        'Password' {
            $control = [System.Windows.Controls.PasswordBox]::new()
            if ($Value) { $control.Password = [string]$Value }
        }
        'ComboBox' {
            $control = [System.Windows.Controls.ComboBox]::new()
            foreach ($option in $Options) {
                $control.Items.Add($option) | Out-Null
            }
            if ($Value) { $control.SelectedItem = $Value }
        }
        'FilePath' {
            $control = [System.Windows.Controls.TextBox]::new()
            $control.Text = [string]$Value
            
            # Add browse button
            $browseButton = [System.Windows.Controls.Button]::new()
            $browseButton.Content = "Durchsuchen..."
            $browseButton.Width = 100
            $browseButton.Height = 25
            $browseButton.Margin = [System.Windows.Thickness]::new(5)
            $browseButton.Add_Click({
                try {
                    $dialog = [System.Windows.Forms.OpenFileDialog]::new()
                    $dialog.Filter = "Excel Files (*.xlsx)|*.xlsx|All Files (*.*)|*.*"
                    if ($control.Text -and $control.Text.Trim() -ne "" -and (Test-Path (Split-Path -Parent $control.Text) -ErrorAction SilentlyContinue)) {
                        $dialog.InitialDirectory = Split-Path -Parent $control.Text
                    }
                    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
                        $control.Text = $dialog.FileName
                    }
                } catch { }
            
            })
            [System.Windows.Controls.Grid]::SetColumn($browseButton, 2)
            [System.Windows.Controls.Grid]::SetRow($browseButton, $Row.Value)
            $Grid.Children.Add($browseButton)
        }
        'FolderPath' {
            $control = [System.Windows.Controls.TextBox]::new()
            $control.Text = [string]$Value
            
            # Add browse button
            $browseButton = [System.Windows.Controls.Button]::new()
            $browseButton.Content = "Durchsuchen..."
            $browseButton.Width = 100
            $browseButton.Height = 25
            $browseButton.Margin = [System.Windows.Thickness]::new(5)
            $browseButton.Add_Click({
                try {
                    $dialog = [System.Windows.Forms.FolderBrowserDialog]::new()
                    if ($control.Text -and $control.Text.Trim() -ne "" -and (Test-Path $control.Text -ErrorAction SilentlyContinue)) {
                        $dialog.SelectedPath = $control.Text
                    }
                    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
                        $control.Text = $dialog.SelectedPath
                    }
                } catch { }
            
            })
            [System.Windows.Controls.Grid]::SetColumn($browseButton, 2)
            [System.Windows.Controls.Grid]::SetRow($browseButton, $Row.Value)
            $Grid.Children.Add($browseButton)
        }
        default {
            $control = [System.Windows.Controls.TextBox]::new()
            $control.Text = [string]$Value
        }
    }
    
    if ($control) {
        $control.Margin = [System.Windows.Thickness]::new(5)
        $control.VerticalAlignment = 'Center'
        [System.Windows.Controls.Grid]::SetColumn($control, 1)
        [System.Windows.Controls.Grid]::SetRow($control, $Row.Value)
        $Grid.Children.Add($control)
        
        # Store control reference
        $script:allControls[$PropertyPath] = @{
            Control = $control
            Type = $Type
        }
    }
    
    $Row.Value++
    $null
}

function Save-Configuration {
    param([object]$Config, [string]$ConfigPath, [hashtable]$Controls)
    
    try {
        foreach ($propertyPath in $Controls.Keys) {
            $controlInfo = $Controls[$propertyPath]
            $control = $controlInfo.Control
            $type = $controlInfo.Type
            
            $value = $null
            switch ($type) {
                'Boolean' { $value = $control.IsChecked }
                'Integer' { $value = [int]$control.Text }
                'Password' { $value = $control.Password }
                'ComboBox' { $value = $control.SelectedItem }
                default { $value = $control.Text }
            }
            
            # Handle special cases for arrays
            if ($propertyPath -in @('ToEmails', 'CertStores', 'CertificateThumbprints') -and $value) {
                $value = $value -split ';' | Where-Object { $_.Trim() } | ForEach-Object { $_.Trim() }
            }
            
            # Update config object
            $Config.$propertyPath = $value
        }
        
        # Save to file
        $result = Save-ConfigContent -Config $Config -ConfigPath $ConfigPath
        if ($result) {
            [System.Windows.MessageBox]::Show("Konfiguration wurde erfolgreich gespeichert!", "Erfolg", "OK", "Information")
            return $true
        } else {
            [System.Windows.MessageBox]::Show("Fehler beim Speichern der Konfiguration!", "Fehler", "OK", "Error")
            return $false
        }
    } catch {
        [System.Windows.MessageBox]::Show("Fehler beim Speichern: $($_.Exception.Message)", "Fehler", "OK", "Error")
        return $false
    }
}

#region Main Execution
try {
    if (Get-Command Show-CertSurvVersionBanner -ErrorAction SilentlyContinue) {
        Show-CertSurvVersionBanner -ComponentName "Configuration GUI"
    } else {
        Write-Host "=" * 70 -ForegroundColor Cyan
        Write-Host "Certificate Surveillance Configuration GUI v$($Global:CertSurvGUIVersion)" -ForegroundColor Green
        Write-Host "Regelwerk: v$($Global:CertSurvRegelwerkVersion) | PowerShell: $($PSVersionTable.PSVersion)" -ForegroundColor Gray
        Write-Host "=" * 70 -ForegroundColor Cyan
    }
    
    # Check configuration file
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $configPath = Join-Path $scriptDir "Config\Config-Cert-Surveillance.json"
    
    if (-not (Test-Path $configPath)) {
        Write-Host "Configuration file not found at: $configPath" -ForegroundColor Red
        Write-Host "Please run this script from the CertSurv installation directory." -ForegroundColor Yellow
        Read-Host "Press Enter to exit"
        exit 1
    }
    
    Write-Host "Found configuration file: $configPath" -ForegroundColor Green
    
    # Load configuration
    $config = Get-ConfigContent -ConfigPath $configPath
    if (-not $config) {
        Write-Host "Failed to load configuration" -ForegroundColor Red
        Read-Host "Press Enter to exit"
        exit 1
    }
    
    Write-Host "Configuration loaded successfully" -ForegroundColor Green
    Write-Host "Starting GUI..." -ForegroundColor Yellow
    
    # Show GUI
    Show-ConfigGUI -Config $config -ConfigPath $configPath
    
} catch {
    Write-Host "Error launching GUI: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack trace:" -ForegroundColor Gray
    Write-Host $_.ScriptStackTrace -ForegroundColor Gray
    Read-Host "Press Enter to exit"
    exit 1
}

    Write-Host "GUI closed." -ForegroundColor Green
#endregion

# --- End of Configuration GUI v$($Global:CertSurvGUIVersion) ; Regelwerk: v$($Global:CertSurvRegelwerkVersion) ; Build: $($Global:CertSurvBuildNumber) ---



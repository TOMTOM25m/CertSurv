#requires -Version 5.1

<#
.SYNOPSIS
    [DE] FL-Gui Modul - WPF-basierte Benutzeroberfläche für Certificate Surveillance Konfiguration
    [EN] FL-Gui Module - WPF-based user interface for Certificate Surveillance configuration
.DESCRIPTION
    [DE] Stellt eine grafische Benutzeroberfläche für die Konfiguration des Certificate Surveillance Systems bereit.
         Ermöglicht die Bearbeitung aller Konfigurationsparameter über ein benutzerfreundliches GUI.
    [EN] Provides a graphical user interface for configuring the Certificate Surveillance system.
         Allows editing of all configuration parameters through a user-friendly GUI.
.NOTES
    Author:         Flecki (Tom) Garnreiter
    Created on:     2025.09.04
    Last modified:  2025.09.04
    Version:        v1.0.0
    MUW-Regelwerk:  v9.3.0
    Copyright:      © 2025 Flecki Garnreiter
    License:        MIT License
#>

$ModuleName = "FL-Gui"
$ModuleVersion = "v1.0.0"

# [DE] Abhängigkeiten importieren / [EN] Import dependencies
try {
    Add-Type -AssemblyName PresentationFramework
    Add-Type -AssemblyName PresentationCore
    Add-Type -AssemblyName WindowsBase
    Add-Type -AssemblyName System.Windows.Forms
} catch {
    Write-Error "Failed to load required WPF assemblies: $($_.Exception.Message)"
    throw
}

function Show-CertSurvSetupGUI {
    <#
    .SYNOPSIS
        [DE] Zeigt die Setup-GUI für Certificate Surveillance an.
        [EN] Shows the setup GUI for Certificate Surveillance.
    .DESCRIPTION
        [DE] Öffnet eine WPF-basierte GUI zur Konfiguration aller Parameter des Certificate Surveillance Systems.
        [EN] Opens a WPF-based GUI for configuring all parameters of the Certificate Surveillance system.
    .PARAMETER Config
        [DE] Das aktuelle Konfigurationsobjekt.
        [EN] The current configuration object.
    .PARAMETER Localization
        [DE] Das Lokalisierungsobjekt für mehrsprachige Unterstützung.
        [EN] The localization object for multi-language support.
    .PARAMETER ScriptDirectory
        [DE] Das Verzeichnis des Hauptskripts.
        [EN] The main script directory.
    .EXAMPLE
        Show-CertSurvSetupGUI -Config $Config -Localization $Localization -ScriptDirectory $ScriptDirectory
    .OUTPUTS
        [DE] $true wenn Konfiguration gespeichert wurde, $false bei Abbruch.
        [EN] $true if configuration was saved, $false if cancelled.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Config,
        
        [Parameter(Mandatory = $true)]
        [object]$Localization,
        
        [Parameter(Mandatory = $true)]
        [string]$ScriptDirectory
    )
    
    try {
        # [DE] XAML-Definition für die GUI / [EN] XAML definition for the GUI
        $xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" # DevSkim: ignore DS137138
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" # DevSkim: ignore DS137138
        Title="Certificate Surveillance Setup - v$ModuleVersion" 
        Height="700" Width="900" 
        WindowStartupLocation="CenterScreen"
        ResizeMode="CanResize">
    <Window.Resources>
        <Style TargetType="Label">
            <Setter Property="FontWeight" Value="Bold"/>
            <Setter Property="Margin" Value="5"/>
            <Setter Property="VerticalAlignment" Value="Center"/>
        </Style>
        <Style TargetType="TextBox">
            <Setter Property="Margin" Value="5"/>
            <Setter Property="Height" Value="25"/>
            <Setter Property="VerticalContentAlignment" Value="Center"/>
        </Style>
        <Style TargetType="CheckBox">
            <Setter Property="Margin" Value="5"/>
            <Setter Property="VerticalAlignment" Value="Center"/>
        </Style>
        <Style TargetType="ComboBox">
            <Setter Property="Margin" Value="5"/>
            <Setter Property="Height" Value="25"/>
            <Setter Property="VerticalContentAlignment" Value="Center"/>
        </Style>
        <Style TargetType="Button">
            <Setter Property="Margin" Value="10"/>
            <Setter Property="Height" Value="35"/>
            <Setter Property="MinWidth" Value="100"/>
            <Setter Property="Background" Value="{DynamicResource PrimaryColor}"/>
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="FontWeight" Value="Bold"/>
        </Style>
        <SolidColorBrush x:Key="PrimaryColor" Color="#111d4e"/>
        <SolidColorBrush x:Key="HoverColor" Color="#5fb4e5"/>
    </Window.Resources>
    
    <ScrollViewer VerticalScrollBarVisibility="Auto">
        <Grid Margin="20">
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="*"/>
                <RowDefinition Height="Auto"/>
            </Grid.RowDefinitions>
            
            <!-- Header -->
            <TextBlock Grid.Row="0" Text="Certificate Surveillance Configuration" 
                       FontSize="24" FontWeight="Bold" 
                       HorizontalAlignment="Center" Margin="0,0,0,20"/>
            
            <!-- Main Configuration Tabs -->
            <TabControl Grid.Row="1" Name="configTabControl">
                
                <!-- General Settings Tab -->
                <TabItem Header="General / Allgemein">
                    <Grid Margin="10">
                        <Grid.RowDefinitions>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                        </Grid.RowDefinitions>
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="200"/>
                            <ColumnDefinition Width="*"/>
                        </Grid.ColumnDefinitions>
                        
                        <Label Grid.Row="0" Grid.Column="0" Content="Version:"/>
                        <TextBox Grid.Row="0" Grid.Column="1" Name="versionTextBox" IsReadOnly="True"/>
                        
                        <Label Grid.Row="1" Grid.Column="0" Content="Run Mode / Betriebsmodus:"/>
                        <ComboBox Grid.Row="1" Grid.Column="1" Name="runModeComboBox">
                            <ComboBoxItem Content="DEV"/>
                            <ComboBoxItem Content="PROD"/>
                        </ComboBox>
                        
                        <Label Grid.Row="2" Grid.Column="0" Content="Language / Sprache:"/>
                        <ComboBox Grid.Row="2" Grid.Column="1" Name="languageComboBox">
                            <ComboBoxItem Content="de-DE"/>
                            <ComboBoxItem Content="en-US"/>
                        </ComboBox>
                        
                        <Label Grid.Row="3" Grid.Column="0" Content="Debug Mode / Debug-Modus:"/>
                        <CheckBox Grid.Row="3" Grid.Column="1" Name="debugModeCheckBox"/>
                        
                        <Label Grid.Row="4" Grid.Column="0" Content="Main Domain / Hauptdomäne:"/>
                        <TextBox Grid.Row="4" Grid.Column="1" Name="mainDomainTextBox"/>
                        
                        <Label Grid.Row="5" Grid.Column="0" Content="DNS Server:"/>
                        <TextBox Grid.Row="5" Grid.Column="1" Name="dnsServerTextBox"/>
                    </Grid>
                </TabItem>
                
                <!-- Excel Configuration Tab -->
                <TabItem Header="Excel Configuration">
                    <Grid Margin="10">
                        <Grid.RowDefinitions>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                        </Grid.RowDefinitions>
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="200"/>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="Auto"/>
                        </Grid.ColumnDefinitions>
                        
                        <Label Grid.Row="0" Grid.Column="0" Content="Excel File Path / Excel-Datei:"/>
                        <TextBox Grid.Row="0" Grid.Column="1" Name="excelPathTextBox"/>
                        <Button Grid.Row="0" Grid.Column="2" Name="browseExcelButton" Content="Browse / Durchsuchen" Width="130"/>
                        
                        <Label Grid.Row="1" Grid.Column="0" Content="Sheet Name / Blattname:"/>
                        <TextBox Grid.Row="1" Grid.Column="1" Name="sheetNameTextBox"/>
                        
                        <Label Grid.Row="2" Grid.Column="0" Content="Header Row / Kopfzeile:"/>
                        <TextBox Grid.Row="2" Grid.Column="1" Name="headerRowTextBox"/>
                        
                        <Label Grid.Row="3" Grid.Column="0" Content="FQDN Column / FQDN-Spalte:"/>
                        <TextBox Grid.Row="3" Grid.Column="1" Name="fqdnColumnTextBox"/>
                        
                        <Label Grid.Row="4" Grid.Column="0" Content="Server Name Column:"/>
                        <TextBox Grid.Row="4" Grid.Column="1" Name="serverNameColumnTextBox"/>
                        
                        <Label Grid.Row="5" Grid.Column="0" Content="Domain Status Column:"/>
                        <TextBox Grid.Row="5" Grid.Column="1" Name="domainStatusColumnTextBox"/>
                        
                        <Label Grid.Row="6" Grid.Column="0" Content="Always Use Config Path:"/>
                        <CheckBox Grid.Row="6" Grid.Column="1" Name="alwaysUseConfigPathCheckBox"/>
                    </Grid>
                </TabItem>
                
                <!-- Certificate Settings Tab -->
                <TabItem Header="Certificate Settings / Zertifikat-Einstellungen">
                    <Grid Margin="10">
                        <Grid.RowDefinitions>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                        </Grid.RowDefinitions>
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="200"/>
                            <ColumnDefinition Width="*"/>
                        </Grid.ColumnDefinitions>
                        
                        <Label Grid.Row="0" Grid.Column="0" Content="Default Port / Standard-Port:"/>
                        <TextBox Grid.Row="0" Grid.Column="1" Name="certificatePortTextBox"/>
                        
                        <Label Grid.Row="1" Grid.Column="0" Content="Warning Days / Warntage:"/>
                        <TextBox Grid.Row="1" Grid.Column="1" Name="warningDaysTextBox"/>
                        
                        <Label Grid.Row="2" Grid.Column="0" Content="Timeout (ms):"/>
                        <TextBox Grid.Row="2" Grid.Column="1" Name="timeoutTextBox"/>
                        
                        <Label Grid.Row="3" Grid.Column="0" Content="Retry Attempts / Wiederholungen:"/>
                        <TextBox Grid.Row="3" Grid.Column="1" Name="retryAttemptsTextBox"/>
                        
                        <Label Grid.Row="4" Grid.Column="0" Content="Certificate Method / Zertifikat-Methode:"/>
                        <ComboBox Grid.Row="4" Grid.Column="1" Name="certificateMethodComboBox">
                            <ComboBoxItem Content="Socket"/>
                            <ComboBoxItem Content="Browser"/>
                        </ComboBox>
                        
                        <Label Grid.Row="5" Grid.Column="0" Content="Enable Browser Check / Browser-Check aktivieren:"/>
                        <CheckBox Grid.Row="5" Grid.Column="1" Name="enableBrowserCheckBox"/>
                        
                        <Label Grid.Row="6" Grid.Column="0" Content="Enable Comparison / Vergleich aktivieren:"/>
                        <CheckBox Grid.Row="6" Grid.Column="1" Name="enableComparisonCheckBox"/>
                        
                        <Label Grid.Row="7" Grid.Column="0" Content="Auto Port Detection / Automatische Port-Erkennung:"/>
                        <CheckBox Grid.Row="7" Grid.Column="1" Name="enableAutoPortDetectionCheckBox"/>
                        
                        <Label Grid.Row="8" Grid.Column="0" Content="Common SSL Ports / Häufige SSL-Ports:"/>
                        <TextBox Grid.Row="8" Grid.Column="1" Name="commonSSLPortsTextBox" ToolTip="Comma-separated list / Komma-getrennte Liste (z.B.: 443,9443,8443)"/>
                        
                        <Label Grid.Row="9" Grid.Column="0" Content="User Agent:"/>
                        <TextBox Grid.Row="9" Grid.Column="1" Name="userAgentTextBox"/>
                        
                        <Label Grid.Row="10" Grid.Column="0" Content="TLS Version / TLS-Version:"/>
                        <ComboBox Grid.Row="10" Grid.Column="1" Name="tlsVersionComboBox">
                            <ComboBoxItem Content="SystemDefault"/>
                            <ComboBoxItem Content="Tls12"/> # DevSkim: ignore DS440000
                            <ComboBoxItem Content="Tls13"/> # DevSkim: ignore DS440000
                        </ComboBox>
                        
                        <Label Grid.Row="11" Grid.Column="0" Content="Report Path / Berichtspfad:"/>
                        <TextBox Grid.Row="11" Grid.Column="1" Name="certificateReportPathTextBox"/>
                    </Grid>
                </TabItem>
                
                <!-- Mail Configuration Tab -->
                <TabItem Header="Mail Configuration / E-Mail-Konfiguration">
                    <Grid Margin="10">
                        <Grid.RowDefinitions>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                        </Grid.RowDefinitions>
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="200"/>
                            <ColumnDefinition Width="*"/>
                        </Grid.ColumnDefinitions>
                        
                        <Label Grid.Row="0" Grid.Column="0" Content="Enable Mail / E-Mail aktivieren:"/>
                        <CheckBox Grid.Row="0" Grid.Column="1" Name="enableMailCheckBox"/>
                        
                        <Label Grid.Row="1" Grid.Column="0" Content="SMTP Server:"/>
                        <TextBox Grid.Row="1" Grid.Column="1" Name="smtpServerTextBox"/>
                        
                        <Label Grid.Row="2" Grid.Column="0" Content="SMTP Port:"/>
                        <TextBox Grid.Row="2" Grid.Column="1" Name="smtpPortTextBox"/>
                        
                        <Label Grid.Row="3" Grid.Column="0" Content="Use SSL:"/>
                        <CheckBox Grid.Row="3" Grid.Column="1" Name="useSslCheckBox"/>
                        
                        <Label Grid.Row="4" Grid.Column="0" Content="Sender Address / Absender:"/>
                        <TextBox Grid.Row="4" Grid.Column="1" Name="senderAddressTextBox"/>
                        
                        <Label Grid.Row="5" Grid.Column="0" Content="DEV Recipient / DEV-Empfänger:"/>
                        <TextBox Grid.Row="5" Grid.Column="1" Name="devRecipientTextBox"/>
                        
                        <Label Grid.Row="6" Grid.Column="0" Content="PROD Recipient / PROD-Empfänger:"/>
                        <TextBox Grid.Row="6" Grid.Column="1" Name="prodRecipientTextBox"/>
                        
                        <Label Grid.Row="7" Grid.Column="0" Content="Subject Prefix / Betreff-Präfix:"/>
                        <TextBox Grid.Row="7" Grid.Column="1" Name="subjectPrefixTextBox"/>
                    </Grid>
                </TabItem>
                
                <!-- Intervals Tab -->
                <TabItem Header="Intervals / Intervalle">
                    <Grid Margin="10">
                        <Grid.RowDefinitions>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                        </Grid.RowDefinitions>
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="250"/>
                            <ColumnDefinition Width="*"/>
                        </Grid.ColumnDefinitions>
                        
                        <Label Grid.Row="0" Grid.Column="0" Content="Days Until Urgent / Tage bis Dringend:"/>
                        <TextBox Grid.Row="0" Grid.Column="1" Name="daysUntilUrgentTextBox"/>
                        
                        <Label Grid.Row="1" Grid.Column="0" Content="Days Until Critical / Tage bis Kritisch:"/>
                        <TextBox Grid.Row="1" Grid.Column="1" Name="daysUntilCriticalTextBox"/>
                        
                        <Label Grid.Row="2" Grid.Column="0" Content="Days Until Warning / Tage bis Warnung:"/>
                        <TextBox Grid.Row="2" Grid.Column="1" Name="daysUntilWarningTextBox"/>
                        
                        <Label Grid.Row="3" Grid.Column="0" Content="Archive Logs Older Than (Days):"/>
                        <TextBox Grid.Row="3" Grid.Column="1" Name="archiveLogsTextBox"/>
                        
                        <Label Grid.Row="4" Grid.Column="0" Content="Delete Archives Older Than (Days):"/>
                        <TextBox Grid.Row="4" Grid.Column="1" Name="deleteArchivesTextBox"/>
                    </Grid>
                </TabItem>
                
                <!-- Paths Tab -->
                <TabItem Header="Paths / Pfade">
                    <Grid Margin="10">
                        <Grid.RowDefinitions>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                        </Grid.RowDefinitions>
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="200"/>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="Auto"/>
                        </Grid.ColumnDefinitions>
                        
                        <Label Grid.Row="0" Grid.Column="0" Content="7-Zip Path / 7-Zip-Pfad:"/>
                        <TextBox Grid.Row="0" Grid.Column="1" Name="pathTo7ZipTextBox"/>
                        <Button Grid.Row="0" Grid.Column="2" Name="browse7ZipButton" Content="Browse / Durchsuchen" Width="130"/>
                        
                        <Label Grid.Row="1" Grid.Column="0" Content="Logo Directory / Logo-Verzeichnis:"/>
                        <TextBox Grid.Row="1" Grid.Column="1" Name="logoDirectoryTextBox"/>
                        <Button Grid.Row="1" Grid.Column="2" Name="browseLogoButton" Content="Browse / Durchsuchen" Width="130"/>
                        
                        <Label Grid.Row="2" Grid.Column="0" Content="Report Directory / Bericht-Verzeichnis:"/>
                        <TextBox Grid.Row="2" Grid.Column="1" Name="reportDirectoryTextBox"/>
                        
                        <Label Grid.Row="3" Grid.Column="0" Content="Log Directory / Log-Verzeichnis:"/>
                        <TextBox Grid.Row="3" Grid.Column="1" Name="logDirectoryTextBox"/>
                    </Grid>
                </TabItem>
                
            </TabControl>
            
            <!-- Buttons -->
            <StackPanel Grid.Row="2" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,20,0,0">
                <Button Name="saveButton" Content="Save / Speichern" IsDefault="True"/>
                <Button Name="cancelButton" Content="Cancel / Abbrechen" IsCancel="True"/>
                <Button Name="testButton" Content="Test Configuration / Konfiguration testen"/>
            </StackPanel>
        </Grid>
    </ScrollViewer>
</Window>
"@

        # [DE] XAML laden und Window erstellen / [EN] Load XAML and create window
        $reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xaml))
        $window = [Windows.Markup.XamlReader]::Load($reader)
        
        # [DE] Steuerelemente abrufen / [EN] Get controls
        $controls = @{}
        $controlNames = @(
            'versionTextBox', 'runModeComboBox', 'languageComboBox', 'debugModeCheckBox', 'mainDomainTextBox', 'dnsServerTextBox',
            'excelPathTextBox', 'browseExcelButton', 'sheetNameTextBox', 'headerRowTextBox', 'fqdnColumnTextBox', 
            'serverNameColumnTextBox', 'domainStatusColumnTextBox', 'alwaysUseConfigPathCheckBox',
            'certificatePortTextBox', 'warningDaysTextBox', 'timeoutTextBox', 'retryAttemptsTextBox', 'certificateMethodComboBox', 
            'enableBrowserCheckBox', 'enableComparisonCheckBox', 'enableAutoPortDetectionCheckBox', 'commonSSLPortsTextBox', 'userAgentTextBox', 'tlsVersionComboBox', 'certificateReportPathTextBox',
            'enableMailCheckBox', 'smtpServerTextBox', 'smtpPortTextBox', 'useSslCheckBox', 'senderAddressTextBox', 
            'devRecipientTextBox', 'prodRecipientTextBox', 'subjectPrefixTextBox',
            'daysUntilUrgentTextBox', 'daysUntilCriticalTextBox', 'daysUntilWarningTextBox', 'archiveLogsTextBox', 'deleteArchivesTextBox',
            'pathTo7ZipTextBox', 'browse7ZipButton', 'logoDirectoryTextBox', 'browseLogoButton', 'reportDirectoryTextBox', 'logDirectoryTextBox',
            'saveButton', 'cancelButton', 'testButton'
        )
        
        foreach ($controlName in $controlNames) {
            $controls[$controlName] = $window.FindName($controlName)
        }
        
        # [DE] Aktuelle Konfigurationswerte laden / [EN] Load current configuration values
        Update-GUIFromConfig -Controls $controls -Config $Config
        
        # [DE] Event-Handler für Buttons / [EN] Event handlers for buttons
        $controls['browseExcelButton'].Add_Click({
            $openFileDialog = New-Object System.Windows.Forms.OpenFileDialog
            $openFileDialog.Filter = "Excel Files (*.xlsx)|*.xlsx|All Files (*.*)|*.*"
            $openFileDialog.Title = "Select Excel File / Excel-Datei auswählen"
            
            if ($openFileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
                $controls['excelPathTextBox'].Text = $openFileDialog.FileName
            }
        })
        
        $controls['browse7ZipButton'].Add_Click({
            $openFileDialog = New-Object System.Windows.Forms.OpenFileDialog
            $openFileDialog.Filter = "Executable Files (*.exe)|*.exe|All Files (*.*)|*.*"
            $openFileDialog.Title = "Select 7-Zip Executable / 7-Zip ausführbare Datei auswählen"
            
            if ($openFileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
                $controls['pathTo7ZipTextBox'].Text = $openFileDialog.FileName
            }
        })
        
        $controls['browseLogoButton'].Add_Click({
            $folderBrowserDialog = New-Object System.Windows.Forms.FolderBrowserDialog
            $folderBrowserDialog.Description = "Select Logo Directory / Logo-Verzeichnis auswählen"
            
            if ($folderBrowserDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
                $controls['logoDirectoryTextBox'].Text = $folderBrowserDialog.SelectedPath
            }
        })
        
        $controls['testButton'].Add_Click({
            Test-ConfigurationValues -Controls $controls
        })
        
        $controls['saveButton'].Add_Click({
            try {
                Update-ConfigFromGUI -Controls $controls -Config $Config
                $configPath = Join-Path -Path $ScriptDirectory -ChildPath "Config\Config-Cert-Surveillance.json"
                $Config | ConvertTo-Json -Depth 10 | Out-File -FilePath $configPath -Encoding UTF8
                
                [System.Windows.MessageBox]::Show(
                    "Configuration saved successfully! / Konfiguration erfolgreich gespeichert!",
                    "Success / Erfolg",
                    [System.Windows.MessageBoxButton]::OK,
                    [System.Windows.MessageBoxImage]::Information
                )
                $window.DialogResult = $true
                $window.Close()
            } catch {
                [System.Windows.MessageBox]::Show(
                    "Error saving configuration: $($_.Exception.Message)",
                    "Error / Fehler",
                    [System.Windows.MessageBoxButton]::OK,
                    [System.Windows.MessageBoxImage]::Error
                )
            }
        })
        
        $controls['cancelButton'].Add_Click({
            $window.DialogResult = $false
            $window.Close()
        })
        
        # [DE] Fenster anzeigen / [EN] Show window
        $result = $window.ShowDialog()
        return $result -eq $true
        
    } catch {
        Write-Error "Error showing setup GUI: $($_.Exception.Message)"
        return $false
    }
}

function Update-GUIFromConfig {
    <#
    .SYNOPSIS
        [DE] Aktualisiert die GUI-Elemente mit den Werten aus der Konfiguration.
        [EN] Updates GUI elements with values from configuration.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Controls,
        
        [Parameter(Mandatory = $true)]
        [object]$Config
    )
    
    try {
        # General Settings
        $Controls['versionTextBox'].Text = $Config.Version
        $Controls['runModeComboBox'].Text = $Config.RunMode
        $Controls['languageComboBox'].Text = $Config.Language
        $Controls['debugModeCheckBox'].IsChecked = $Config.DebugMode
        $Controls['mainDomainTextBox'].Text = $Config.MainDomain
        $Controls['dnsServerTextBox'].Text = $Config.Network.DnsServer
        
        # Excel Configuration
        $Controls['excelPathTextBox'].Text = $Config.Excel.ExcelPath
        $Controls['sheetNameTextBox'].Text = $Config.Excel.SheetName
        $Controls['headerRowTextBox'].Text = $Config.Excel.HeaderRow.ToString()
        $Controls['fqdnColumnTextBox'].Text = $Config.Excel.FqdnColumnName
        $Controls['serverNameColumnTextBox'].Text = $Config.Excel.ServerNameColumnName
        $Controls['domainStatusColumnTextBox'].Text = $Config.Excel.DomainStatusColumnName
        $Controls['alwaysUseConfigPathCheckBox'].IsChecked = $Config.Excel.AlwaysUseConfigPath
        
        # Certificate Settings
        if ($Config.Certificate) {
            $Controls['certificatePortTextBox'].Text = $Config.Certificate.Port.ToString()
            $Controls['warningDaysTextBox'].Text = $Config.Certificate.WarningDays.ToString()
            $Controls['timeoutTextBox'].Text = $Config.Certificate.Timeout.ToString()
            $Controls['retryAttemptsTextBox'].Text = $Config.Certificate.RetryAttempts.ToString()
            $Controls['certificateMethodComboBox'].Text = $Config.Certificate.Method
            $Controls['enableBrowserCheckBox'].IsChecked = $Config.Certificate.EnableBrowserCheck
            $Controls['enableComparisonCheckBox'].IsChecked = $Config.Certificate.EnableComparison
            $Controls['enableAutoPortDetectionCheckBox'].IsChecked = $Config.Certificate.EnableAutoPortDetection
            $Controls['commonSSLPortsTextBox'].Text = ($Config.Certificate.CommonSSLPorts -join ',')
            $Controls['userAgentTextBox'].Text = $Config.Certificate.UserAgent
            $Controls['certificateReportPathTextBox'].Text = $Config.Certificate.ReportPath
        }
        $Controls['tlsVersionComboBox'].Text = $Config.Network.TlsVersion
        
        # Mail Configuration
        $Controls['enableMailCheckBox'].IsChecked = $Config.Mail.Enabled
        $Controls['smtpServerTextBox'].Text = $Config.Mail.SmtpServer
        $Controls['smtpPortTextBox'].Text = $Config.Mail.SmtpPort.ToString()
        $Controls['useSslCheckBox'].IsChecked = $Config.Mail.UseSsl
        $Controls['senderAddressTextBox'].Text = $Config.Mail.SenderAddress
        $Controls['devRecipientTextBox'].Text = $Config.Mail.DevTo
        $Controls['prodRecipientTextBox'].Text = $Config.Mail.ProdTo
        $Controls['subjectPrefixTextBox'].Text = $Config.Mail.SubjectPrefix
        
        # Intervals
        $Controls['daysUntilUrgentTextBox'].Text = $Config.Intervals.DaysUntilUrgent.ToString()
        $Controls['daysUntilCriticalTextBox'].Text = $Config.Intervals.DaysUntilCritical.ToString()
        $Controls['daysUntilWarningTextBox'].Text = $Config.Intervals.DaysUntilWarning.ToString()
        $Controls['archiveLogsTextBox'].Text = $Config.Intervals.ArchiveLogsOlderThanDays.ToString()
        $Controls['deleteArchivesTextBox'].Text = $Config.Intervals.DeleteZipArchivesOlderThanDays.ToString()
        
        # Paths
        $Controls['pathTo7ZipTextBox'].Text = $Config.Paths.PathTo7Zip
        $Controls['logoDirectoryTextBox'].Text = $Config.Paths.LogoDirectory
        $Controls['reportDirectoryTextBox'].Text = $Config.Paths.ReportDirectory
        $Controls['logDirectoryTextBox'].Text = $Config.Paths.LogDirectory
        
    } catch {
        Write-Error "Error updating GUI from config: $($_.Exception.Message)"
    }
}

function Update-ConfigFromGUI {
    <#
    .SYNOPSIS
        [DE] Aktualisiert die Konfiguration mit den Werten aus der GUI.
        [EN] Updates configuration with values from GUI.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Controls,
        
        [Parameter(Mandatory = $true)]
        [object]$Config
    )
    
    try {
        # General Settings
        $Config.RunMode = $Controls['runModeComboBox'].Text
        $Config.Language = $Controls['languageComboBox'].Text
        $Config.DebugMode = $Controls['debugModeCheckBox'].IsChecked
        $Config.MainDomain = $Controls['mainDomainTextBox'].Text
        $Config.Network.DnsServer = $Controls['dnsServerTextBox'].Text
        $Config.Network.TlsVersion = $Controls['tlsVersionComboBox'].Text
        
        # Excel Configuration
        $Config.Excel.ExcelPath = $Controls['excelPathTextBox'].Text
        $Config.Excel.SheetName = $Controls['sheetNameTextBox'].Text
        $Config.Excel.HeaderRow = [int]$Controls['headerRowTextBox'].Text
        $Config.Excel.FqdnColumnName = $Controls['fqdnColumnTextBox'].Text
        $Config.Excel.ServerNameColumnName = $Controls['serverNameColumnTextBox'].Text
        $Config.Excel.DomainStatusColumnName = $Controls['domainStatusColumnTextBox'].Text
        $Config.Excel.AlwaysUseConfigPath = $Controls['alwaysUseConfigPathCheckBox'].IsChecked
        
        # Certificate Settings
        if (-not $Config.Certificate) {
            $Config | Add-Member -MemberType NoteProperty -Name "Certificate" -Value @{}
        }
        $Config.Certificate.Port = [int]$Controls['certificatePortTextBox'].Text
        $Config.Certificate.WarningDays = [int]$Controls['warningDaysTextBox'].Text
        $Config.Certificate.Timeout = [int]$Controls['timeoutTextBox'].Text
        $Config.Certificate.RetryAttempts = [int]$Controls['retryAttemptsTextBox'].Text
        $Config.Certificate.Method = $Controls['certificateMethodComboBox'].Text
        $Config.Certificate.EnableBrowserCheck = $Controls['enableBrowserCheckBox'].IsChecked
        $Config.Certificate.EnableComparison = $Controls['enableComparisonCheckBox'].IsChecked
        $Config.Certificate.EnableAutoPortDetection = $Controls['enableAutoPortDetectionCheckBox'].IsChecked
        $Config.Certificate.CommonSSLPorts = ($Controls['commonSSLPortsTextBox'].Text -split ',' | ForEach-Object { [int]$_.Trim() })
        $Config.Certificate.UserAgent = $Controls['userAgentTextBox'].Text
        $Config.Certificate.ReportPath = $Controls['certificateReportPathTextBox'].Text
        
        # Mail Configuration
        $Config.Mail.Enabled = $Controls['enableMailCheckBox'].IsChecked
        $Config.Mail.SmtpServer = $Controls['smtpServerTextBox'].Text
        $Config.Mail.SmtpPort = [int]$Controls['smtpPortTextBox'].Text
        $Config.Mail.UseSsl = $Controls['useSslCheckBox'].IsChecked
        $Config.Mail.SenderAddress = $Controls['senderAddressTextBox'].Text
        $Config.Mail.DevTo = $Controls['devRecipientTextBox'].Text
        $Config.Mail.ProdTo = $Controls['prodRecipientTextBox'].Text
        $Config.Mail.SubjectPrefix = $Controls['subjectPrefixTextBox'].Text
        
        # Intervals
        $Config.Intervals.DaysUntilUrgent = [int]$Controls['daysUntilUrgentTextBox'].Text
        $Config.Intervals.DaysUntilCritical = [int]$Controls['daysUntilCriticalTextBox'].Text
        $Config.Intervals.DaysUntilWarning = [int]$Controls['daysUntilWarningTextBox'].Text
        $Config.Intervals.ArchiveLogsOlderThanDays = [int]$Controls['archiveLogsTextBox'].Text
        $Config.Intervals.DeleteZipArchivesOlderThanDays = [int]$Controls['deleteArchivesTextBox'].Text
        
        # Paths
        $Config.Paths.PathTo7Zip = $Controls['pathTo7ZipTextBox'].Text
        $Config.Paths.LogoDirectory = $Controls['logoDirectoryTextBox'].Text
        $Config.Paths.ReportDirectory = $Controls['reportDirectoryTextBox'].Text
        $Config.Paths.LogDirectory = $Controls['logDirectoryTextBox'].Text
        
    } catch {
        Write-Error "Error updating config from GUI: $($_.Exception.Message)"
        throw
    }
}

function Test-ConfigurationValues {
    <#
    .SYNOPSIS
        [DE] Testet die Konfigurationswerte auf Gültigkeit.
        [EN] Tests configuration values for validity.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Controls
    )
    
    try {
        $errors = @()
        
        # [DE] Excel-Datei prüfen / [EN] Test Excel file
        $excelPath = $Controls['excelPathTextBox'].Text
        if (-not [string]::IsNullOrWhiteSpace($excelPath)) {
            if (-not (Test-Path $excelPath)) {
                $errors += "Excel file not found / Excel-Datei nicht gefunden: $excelPath"
            }
        }
        
        # [DE] 7-Zip-Pfad prüfen / [EN] Test 7-Zip path
        $zipPath = $Controls['pathTo7ZipTextBox'].Text
        if (-not [string]::IsNullOrWhiteSpace($zipPath)) {
            if (-not (Test-Path $zipPath)) {
                $errors += "7-Zip executable not found / 7-Zip ausführbare Datei nicht gefunden: $zipPath"
            }
        }
        
        # [DE] Zertifikat-Test hinzufügen / [EN] Add certificate test
        $certificateMethod = $Controls['certificateMethodComboBox'].Text
        if (-not [string]::IsNullOrWhiteSpace($certificateMethod)) {
            try {
                Write-Host "Testing certificate retrieval / Teste Zertifikatsabruf..." -ForegroundColor Yellow
                
                # Test with a well-known server
                $testServer = "www.google.com"
                $testPort = [int]$Controls['certificatePortTextBox'].Text
                $testTimeout = [int]$Controls['timeoutTextBox'].Text
                
                # Load certificate module for testing
                $certModulePath = Join-Path -Path (Split-Path $ScriptDirectory -Parent) -ChildPath "Modules\FL-Certificate.psm1"
                if (Test-Path $certModulePath) {
                    Import-Module $certModulePath -Force
                    
                    if ($certificateMethod -eq "Browser") {
                        $certResult = Get-CertificateViaBrowser -ServerName $testServer -Port $testPort -Timeout $testTimeout
                    } elseif ($certificateMethod -eq "Socket") {
                        $certResult = Get-CertificateViaSocket -ServerName $testServer -Port $testPort -Timeout $testTimeout
                    } else {
                        $certResult = Get-RemoteCertificate -ServerName $testServer -Port $testPort -Timeout $testTimeout -Method $certificateMethod
                    }
                    
                    if ($certResult) {
                        Write-Host "✓ Certificate test successful / Zertifikatstest erfolgreich" -ForegroundColor Green
                        Write-Host "  Server: $($certResult.Server)" -ForegroundColor Gray
                        Write-Host "  Subject: $($certResult.Subject)" -ForegroundColor Gray
                        Write-Host "  Method: $($certResult.Method)" -ForegroundColor Gray
                    } else {
                        $errors += "Certificate test failed / Zertifikatstest fehlgeschlagen: $testServer"
                    }
                } else {
                    $errors += "Certificate module not found / Zertifikatsmodul nicht gefunden"
                }
            } catch {
                $errors += "Certificate test error / Zertifikatstest-Fehler: $($_.Exception.Message)"
            }
        }
        
        # [DE] SMTP-Server prüfen / [EN] Test SMTP server
        $smtpServer = $Controls['smtpServerTextBox'].Text
        $smtpPort = $Controls['smtpPortTextBox'].Text
        if ($Controls['enableMailCheckBox'].IsChecked -and -not [string]::IsNullOrWhiteSpace($smtpServer)) {
            try {
                $tcpClient = New-Object System.Net.Sockets.TcpClient
                $tcpClient.Connect($smtpServer, [int]$smtpPort)
                $tcpClient.Close()
            } catch {
                $errors += "SMTP server unreachable / SMTP-Server nicht erreichbar: $smtpServer`:$smtpPort"
            }
        }
        
        # [DE] Numerische Werte prüfen / [EN] Test numeric values
        $numericFields = @{
            'headerRowTextBox' = 'Header Row'
            'certificatePortTextBox' = 'Certificate Port'
            'warningDaysTextBox' = 'Warning Days'
            'timeoutTextBox' = 'Timeout'
            'retryAttemptsTextBox' = 'Retry Attempts'
            'smtpPortTextBox' = 'SMTP Port'
            'daysUntilUrgentTextBox' = 'Days Until Urgent'
            'daysUntilCriticalTextBox' = 'Days Until Critical'
            'daysUntilWarningTextBox' = 'Days Until Warning'
            'archiveLogsTextBox' = 'Archive Logs Days'
            'deleteArchivesTextBox' = 'Delete Archives Days'
        }
        
        foreach ($field in $numericFields.GetEnumerator()) {
            $value = $Controls[$field.Key].Text
            if (-not [string]::IsNullOrWhiteSpace($value)) {
                $numValue = 0
                if (-not [int]::TryParse($value, [ref]$numValue) -or $numValue -lt 0) {
                    $errors += "$($field.Value) must be a positive number / $($field.Value) muss eine positive Zahl sein"
                }
            }
        }
        
        # [DE] Ergebnisse anzeigen / [EN] Show results
        if ($errors.Count -eq 0) {
            [System.Windows.MessageBox]::Show(
                "All configuration values are valid! / Alle Konfigurationswerte sind gültig!",
                "Test Results / Testergebnisse",
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Information
            )
        } else {
            $errorMessage = "Configuration errors found / Konfigurationsfehler gefunden:`n`n" + ($errors -join "`n")
            [System.Windows.MessageBox]::Show(
                $errorMessage,
                "Test Results / Testergebnisse",
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Warning
            )
        }
        
    } catch {
        [System.Windows.MessageBox]::Show(
            "Error testing configuration: $($_.Exception.Message)",
            "Error / Fehler",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Error
        )
    }
}

# [DE] Modul-Exports / [EN] Module exports
Export-ModuleMember -Function Show-CertSurvSetupGUI

Write-Verbose "FL-Gui module v$ModuleVersion loaded successfully"

# --- End of module --- v1.0.0 ; Regelwerk: v9.1.1 ---

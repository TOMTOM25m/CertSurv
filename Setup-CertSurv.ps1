#Requires -Version 5.1#Requires -version 5.1

<#!#Requires -RunAsAdministrator

.SYNOPSIS

    GUI zur Konfiguration von Config-Cert-Surveillance.json#region PowerShell Version Detection (MANDATORY - Regelwerk v9.4.0)

.DESCRIPTION$PSVersion = $PSVersionTable.PSVersion

    Startet eine grafische Oberfläche zur Bearbeitung der wichtigsten Parameter der Zertifikatsüberwachung.$IsPS7Plus = $PSVersion.Major -ge 7

.NOTES$IsPS5 = $PSVersion.Major -eq 5

    Author: GitHub Copilot$IsPS51 = $PSVersion.Major -eq 5 -and $PSVersion.Minor -eq 1

    Version: v1.0.0

    Regelwerk: v9.5.0Write-Verbose "Setup-CertSurv - PowerShell Version: $($PSVersion.ToString())"

#>Write-Verbose "Compatibility Mode: $(if($IsPS7Plus){'PowerShell 7.x Enhanced'}elseif($IsPS51){'PowerShell 5.1 Compatible'}else{'PowerShell 5.x Standard'})"

#endregion

Add-Type -AssemblyName PresentationFramework


# --- Dynamic Config GUI ---
function Add-FieldControl {
    param(
        [object]$parent,
        [string]$labelText,
        [object]$value,
        [int]$row,
        [ref]$controls
    )
    $label = New-Object Windows.Controls.Label
    $label.Content = $labelText
    $label.Margin = "10,$($row*30+10),0,0"
    $label.VerticalAlignment = 'Top'
    $label.HorizontalAlignment = 'Left'
    $parent.Children.Add($label)
    if ($value -is [bool]) {
        $ctrl = New-Object Windows.Controls.CheckBox
        $ctrl.IsChecked = $value
    } elseif ($value -is [int] -or $value -is [double]) {
        $ctrl = New-Object Windows.Controls.TextBox
        $ctrl.Text = $value.ToString()
    } elseif ($value -is [string]) {
        $ctrl = New-Object Windows.Controls.TextBox
        $ctrl.Text = $value
    } elseif ($value -is [System.Collections.IEnumerable] -and $value -isnot [string]) {
        $ctrl = New-Object Windows.Controls.TextBox
        $ctrl.Text = ($value | ConvertTo-Json -Compress)
    } elseif ($value -is [psobject]) {
        $ctrl = New-Object Windows.Controls.TextBox
        $ctrl.Text = ($value | ConvertTo-Json -Compress)
    } else {
        $ctrl = New-Object Windows.Controls.TextBox
        $ctrl.Text = $value.ToString()
    }
    $ctrl.Margin = "150,$($row*30+10),10,0"
    $ctrl.Width = 320
    $ctrl.VerticalAlignment = 'Top'
    $ctrl.HorizontalAlignment = 'Left'
    $parent.Children.Add($ctrl)
    $controls.Value[$labelText] = $ctrl
}

function Show-ConfigGui {
    param(
        [string]$ConfigPath = "C:\Script\CertSurv-Master\Config\Config-Cert-Surveillance.json",
        [string]$DeployPath = "\\itscmgmt03.srv.meduniwien.ac.at\iso\CertSurv\Config\Config-Cert-Surveillance.json"
    )
    if (-not (Test-Path $ConfigPath)) {
        [System.Windows.MessageBox]::Show("Konfigurationsdatei nicht gefunden:\n$ConfigPath", "Fehler", 'OK', 'Error')
        return
    }
    $config = Get-Content $ConfigPath | ConvertFrom-Json
    $window = New-Object Windows.Window
    $window.Title = "Certificate Surveillance Config Editor"
    $window.Width = 600
    $window.Height = 900
    $scrollViewer = New-Object Windows.Controls.ScrollViewer
    $scrollViewer.VerticalScrollBarVisibility = 'Auto'
    $grid = New-Object Windows.Controls.Grid
    $scrollViewer.Content = $grid
    $window.Content = $scrollViewer
    $controls = @{}
    $row = 0
    foreach ($prop in $config.PSObject.Properties) {
        Add-FieldControl -parent $grid -labelText $prop.Name -value $prop.Value -row $row -controls ([ref]$controls)
        $row++
    }
    $saveButton = New-Object Windows.Controls.Button
    $saveButton.Content = "Speichern"
    $saveButton.Margin = "10,$($row*30+20),10,0"
    $saveButton.Width = 120
    $saveButton.Add_Click({
        foreach ($key in $controls.Keys) {
            $ctrl = $controls[$key]
            $val = $ctrl.Text
            if ($config.$key -is [bool]) {
                $config.$key = $ctrl.IsChecked
            } elseif ($config.$key -is [int]) {
                if ($val -match '^-?\d+$') { $config.$key = [int]$val } }
            elseif ($config.$key -is [double]) {
                if ($val -match '^-?\d+(\.\d+)?$') { $config.$key = [double]$val } }
            elseif ($config.$key -is [System.Collections.IEnumerable] -and $config.$key -isnot [string]) {
                try { $config.$key = $val | ConvertFrom-Json } catch {} }
            elseif ($config.$key -is [psobject]) {
                try { $config.$key = $val | ConvertFrom-Json } catch {} }
            else {
                $config.$key = $val
            }
        }
        $config | ConvertTo-Json -Depth 10 | Out-File $ConfigPath -Encoding ASCII
        [System.Windows.MessageBox]::Show("Konfiguration gespeichert!", "Info", 'OK', 'Info')
    })
    $grid.Children.Add($saveButton)
    $deployButton = New-Object Windows.Controls.Button
    $deployButton.Content = "Auf Netzlaufwerk deployen"
    $deployButton.Margin = "150,$($row*30+20),10,0"
    $deployButton.Width = 200
    $deployButton.Add_Click({
        try {
            Copy-Item -Path $ConfigPath -Destination $DeployPath -Force
            [System.Windows.MessageBox]::Show("Konfiguration erfolgreich auf Netzlaufwerk deployed!", "Info", 'OK', 'Info')
        } catch {
            [System.Windows.MessageBox]::Show("Fehler beim Deploy: $($_.Exception.Message)", "Fehler", 'OK', 'Error')
        }
    })
    $grid.Children.Add($deployButton)
    $window.ShowDialog() | Out-Null
}

Show-ConfigGui


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

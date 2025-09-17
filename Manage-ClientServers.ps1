#requires -Version 5.1

<#
.SYNOPSIS
    Client Server Management Tool v1.1.0 - Manuelle WebService Einrichtung
.DESCRIPTION
    Tool für die manuelle, schrittweise Einrichtung aller Server aus dem Excel-Sheet.
    Berücksichtigt, dass jeder Server unterschiedlich konfiguriert ist und individuelle Behandlung benötigt.
.NOTES
    Author: Flecki (Tom) Garnreiter
    Version: v1.1.0
    Regelwerk: v9.3.1
    Usage: Interaktive manuelle Einrichtung aller 151 Server
#>

#----------------------------------------------------------[Initialisations]--------------------------------------------------------
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Script directory and paths
$ScriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Definition
$ConfigPath = Join-Path $ScriptDirectory "Config"
$LogPath = Join-Path $ScriptDirectory "LOG"
$ModulesPath = Join-Path $ScriptDirectory "Modules"

# Import required modules
Import-Module (Join-Path $ModulesPath "FL-Config.psm1") -Force
Import-Module (Join-Path $ModulesPath "FL-Logging.psm1") -Force
Import-Module (Join-Path $ModulesPath "FL-DataProcessing.psm1") -Force

# Initialize logging
$LogFile = Join-Path $LogPath "ClientManagement_$(Get-Date -Format 'yyyy-MM-dd').log"

#----------------------------------------------------------[Functions]--------------------------------------------------------

function Write-ClientLog {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    # Color coding
    $color = switch ($Level) {
        "ERROR" { "Red" }
        "WARN" { "Yellow" }
        "SUCCESS" { "Green" }
        "INFO" { "White" }
        "PROGRESS" { "Cyan" }
        default { "White" }
    }
    
    Write-Host $logEntry -ForegroundColor $color
    if ($LogFile) {
        Add-Content -Path $LogFile -Value $logEntry -Encoding UTF8
    }
}

function Get-AllServersFromExcel {
    param($Config)
    
    Write-ClientLog "Lade alle Server aus Excel-Datei..." -Level PROGRESS
    
    try {
        # Import Excel data using existing function
        $excelResult = Import-ExcelData -ExcelPath $Config.Excel.ExcelPath -WorksheetName $Config.Excel.SheetName -Config $Config -LogFile $LogFile
        
        $servers = @()
        foreach ($row in $excelResult.Data) {
            $serverName = $row.$($Config.Excel.ServerNameColumnName)
            if (-not [string]::IsNullOrWhiteSpace($serverName)) {
                
                # Determine server type and domain
                $isDomainServer = $row._IsDomainServer -eq $true
                $domainContext = $row._DomainContext
                
                if ($isDomainServer -and $domainContext) {
                    $fqdn = "$($serverName.Trim()).$($domainContext.ToLower()).$($Config.MainDomain)"
                    $serverType = "Domain ($domainContext)"
                } else {
                    $fqdn = "$($serverName.Trim()).srv.$($Config.MainDomain)"
                    $serverType = "Workgroup"
                }
                
                $servers += @{
                    Index = $servers.Count + 1
                    ServerName = $serverName.Trim()
                    FQDN = $fqdn
                    ServerType = $serverType
                    DomainContext = $domainContext
                    Row = $row
                    Status = "Pending"
                    WebServiceInstalled = $false
                    LastChecked = $null
                    Notes = ""
                }
            }
        }
        
        Write-ClientLog "✅ $($servers.Count) Server aus Excel geladen" -Level SUCCESS
        return $servers
        
    } catch {
        Write-ClientLog "❌ Fehler beim Laden der Excel-Daten: $($_.Exception.Message)" -Level ERROR
        throw
    }
}

function Save-ClientProgress {
    param($Servers, $ProgressFile)
    
    try {
        $progressData = @{
            LastUpdated = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
            TotalServers = $Servers.Count
            CompletedServers = ($Servers | Where-Object { $_.Status -eq "Completed" }).Count
            FailedServers = ($Servers | Where-Object { $_.Status -eq "Failed" }).Count
            PendingServers = ($Servers | Where-Object { $_.Status -eq "Pending" }).Count
            Servers = $Servers
        }
        
        $progressData | ConvertTo-Json -Depth 10 | Set-Content -Path $ProgressFile -Encoding UTF8
        Write-ClientLog "Fortschritt gespeichert: $ProgressFile" -Level INFO
        
    } catch {
        Write-ClientLog "⚠️ Warnung: Fortschritt konnte nicht gespeichert werden: $($_.Exception.Message)" -Level WARN
    }
}

function Load-ClientProgress {
    param($ProgressFile)
    
    if (Test-Path $ProgressFile) {
        try {
            $progressData = Get-Content -Path $ProgressFile -Raw | ConvertFrom-Json
            Write-ClientLog "Fortschritt geladen: $($progressData.CompletedServers)/$($progressData.TotalServers) abgeschlossen" -Level SUCCESS
            return $progressData.Servers
        } catch {
            Write-ClientLog "⚠️ Warnung: Fortschritt konnte nicht geladen werden: $($_.Exception.Message)" -Level WARN
        }
    }
    return $null
}

function Test-ServerReadiness {
    param($Server)
    
    Write-ClientLog "Teste Server-Bereitschaft: $($Server.FQDN)" -Level PROGRESS
    
    $readinessStatus = @{
        ServerName = $Server.ServerName
        FQDN = $Server.FQDN
        Reachable = $false
        WinRMAvailable = $false
        IISInstalled = $false
        PowerShellVersion = $null
        OSVersion = $null
        LastBootTime = $null
        FreeSpace = $null
        Recommendations = @()
        CanProceed = $false
    }
    
    try {
        # Basic connectivity test
        Write-ClientLog "  -> Teste Netzwerk-Konnektivität..." -Level INFO
        if (Test-NetConnection -ComputerName $Server.FQDN -Port 135 -InformationLevel Quiet) {
            $readinessStatus.Reachable = $true
            Write-ClientLog "  ✅ Server erreichbar" -Level SUCCESS
        } else {
            $readinessStatus.Recommendations += "Server ist nicht über das Netzwerk erreichbar"
            return $readinessStatus
        }
        
        # WinRM test
        Write-ClientLog "  -> Teste WinRM-Verfügbarkeit..." -Level INFO
        if (Test-WSMan -ComputerName $Server.FQDN -ErrorAction SilentlyContinue) {
            $readinessStatus.WinRMAvailable = $true
            Write-ClientLog "  ✅ WinRM verfügbar" -Level SUCCESS
        } else {
            $readinessStatus.Recommendations += "WinRM muss aktiviert werden (Enable-PSRemoting)"
        }
        
        # Detailed system information (only if WinRM is available)
        if ($readinessStatus.WinRMAvailable) {
            try {
                $systemInfo = Invoke-Command -ComputerName $Server.FQDN -ScriptBlock {
                    $osInfo = Get-CimInstance -ClassName Win32_OperatingSystem
                    $psVersion = $PSVersionTable.PSVersion
                    $iisFeature = Get-WindowsFeature -Name IIS-WebServer -ErrorAction SilentlyContinue
                    $diskSpace = Get-CimInstance -ClassName Win32_LogicalDisk | Where-Object { $_.DriveType -eq 3 } | Select-Object DeviceID, @{Name="FreeSpaceGB";Expression={[math]::Round($_.FreeSpace/1GB,2)}}
                    
                    return @{
                        OSVersion = $osInfo.Caption
                        LastBootTime = $osInfo.LastBootUpTime
                        PowerShellVersion = "$($psVersion.Major).$($psVersion.Minor)"
                        IISInstalled = ($iisFeature -and $iisFeature.InstallState -eq "Installed")
                        FreeSpace = $diskSpace
                    }
                } -ErrorAction Stop
                
                $readinessStatus.OSVersion = $systemInfo.OSVersion
                $readinessStatus.LastBootTime = $systemInfo.LastBootTime
                $readinessStatus.PowerShellVersion = $systemInfo.PowerShellVersion
                $readinessStatus.IISInstalled = $systemInfo.IISInstalled
                $readinessStatus.FreeSpace = $systemInfo.FreeSpace
                
                Write-ClientLog "  ✅ System-Info: $($systemInfo.OSVersion), PS $($systemInfo.PowerShellVersion)" -Level SUCCESS
                
                # Recommendations based on system info
                if (-not $systemInfo.IISInstalled) {
                    $readinessStatus.Recommendations += "IIS muss installiert werden"
                }
                
                if ([version]$systemInfo.PowerShellVersion -lt [version]"5.1") {
                    $readinessStatus.Recommendations += "PowerShell 5.1 oder höher wird empfohlen"
                }
                
                $systemDrive = $systemInfo.FreeSpace | Where-Object { $_.DeviceID -eq "C:" }
                if ($systemDrive -and $systemDrive.FreeSpaceGB -lt 1) {
                    $readinessStatus.Recommendations += "Weniger als 1GB freier Speicher auf C:\"
                }
                
            } catch {
                $readinessStatus.Recommendations += "System-Informationen konnten nicht abgerufen werden: $($_.Exception.Message)"
            }
        }
        
        # Overall readiness assessment
        $readinessStatus.CanProceed = $readinessStatus.Reachable -and $readinessStatus.WinRMAvailable -and ($readinessStatus.Recommendations.Count -eq 0)
        
    } catch {
        $readinessStatus.Recommendations += "Unerwarteter Fehler: $($_.Exception.Message)"
    }
    
    return $readinessStatus
}

function Show-ServerMenu {
    param($Server, $ReadinessStatus)
    
    Clear-Host
    Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "    SERVER KONFIGURATION - $($Server.ServerName)" -ForegroundColor Yellow
    Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Server Details:" -ForegroundColor White
    Write-Host "  Name: $($Server.ServerName)" -ForegroundColor Cyan
    Write-Host "  FQDN: $($Server.FQDN)" -ForegroundColor Cyan
    Write-Host "  Typ:  $($Server.ServerType)" -ForegroundColor Cyan
    Write-Host "  Status: $($Server.Status)" -ForegroundColor $(if($Server.Status -eq "Completed"){"Green"}elseif($Server.Status -eq "Failed"){"Red"}else{"Yellow"})
    Write-Host ""
    
    if ($ReadinessStatus) {
        Write-Host "System-Status:" -ForegroundColor White
        Write-Host "  Erreichbar: $(if($ReadinessStatus.Reachable){"✅ Ja"}else{"❌ Nein"})" -ForegroundColor $(if($ReadinessStatus.Reachable){"Green"}else{"Red"})
        Write-Host "  WinRM: $(if($ReadinessStatus.WinRMAvailable){"✅ Verfügbar"}else{"❌ Nicht verfügbar"})" -ForegroundColor $(if($ReadinessStatus.WinRMAvailable){"Green"}else{"Red"})
        Write-Host "  IIS: $(if($ReadinessStatus.IISInstalled){"✅ Installiert"}else{"❌ Nicht installiert"})" -ForegroundColor $(if($ReadinessStatus.IISInstalled){"Green"}else{"Red"})
        if ($ReadinessStatus.OSVersion) {
            Write-Host "  OS: $($ReadinessStatus.OSVersion)" -ForegroundColor Cyan
        }
        if ($ReadinessStatus.PowerShellVersion) {
            Write-Host "  PowerShell: $($ReadinessStatus.PowerShellVersion)" -ForegroundColor Cyan
        }
        Write-Host ""
        
        if ($ReadinessStatus.Recommendations.Count -gt 0) {
            Write-Host "⚠️ Empfehlungen:" -ForegroundColor Yellow
            foreach ($rec in $ReadinessStatus.Recommendations) {
                Write-Host "  • $rec" -ForegroundColor Yellow
            }
            Write-Host ""
        }
    }
    
    Write-Host "Verfügbare Aktionen:" -ForegroundColor White
    Write-Host "  [1] System-Check durchführen" -ForegroundColor Green
    Write-Host "  [2] WebService installieren" -ForegroundColor Green
    Write-Host "  [3] WebService testen" -ForegroundColor Green
    Write-Host "  [4] Manuelle Befehle ausführen" -ForegroundColor Yellow
    Write-Host "  [5] Server als abgeschlossen markieren" -ForegroundColor Cyan
    Write-Host "  [6] Server überspringen" -ForegroundColor Yellow
    Write-Host "  [7] Notizen hinzufügen" -ForegroundColor White
    Write-Host "  [n] Nächster Server" -ForegroundColor Cyan
    Write-Host "  [q] Beenden" -ForegroundColor Red
    Write-Host ""
}

function Install-WebServiceOnServer {
    param($Server)
    
    Write-ClientLog "Starte WebService Installation auf $($Server.FQDN)..." -Level PROGRESS
    
    try {
        # Use the existing deployment script functionality
        $deploymentSource = "\\itscmgmt03.srv.meduniwien.ac.at\iso\CertDeployment"
        
        Write-ClientLog "Deployment-Quelle: $deploymentSource" -Level INFO
        
        # Execute deployment (simplified version of Deploy-TestServer.ps1 logic)
        $session = New-PSSession -ComputerName $Server.FQDN -ErrorAction Stop
        
        try {
            $result = Invoke-Command -Session $session -ScriptBlock {
                param($ServerFQDN)
                
                # Install IIS if needed
                $iisFeature = Get-WindowsFeature -Name IIS-WebServer -ErrorAction SilentlyContinue
                if (-not $iisFeature -or $iisFeature.InstallState -ne "Installed") {
                    Write-Output "Installing IIS..."
                    Install-WindowsFeature -Name IIS-WebServer, IIS-WebServerRole, IIS-CommonHttpFeatures, IIS-HttpFeatures, IIS-NetFxExtensibility45, IIS-ASPNET45 -IncludeManagementTools
                }
                
                # Create WebService directory
                $webServicePath = "C:\inetpub\CertWebService"
                if (Test-Path $webServicePath) {
                    Remove-Item $webServicePath -Recurse -Force
                }
                New-Item -Path $webServicePath -ItemType Directory -Force | Out-Null
                
                # Create certificate data script
                $updateScript = @'
#requires -Version 5.1
Set-StrictMode -Version Latest

try {
    $certificates = Get-ChildItem Cert:\LocalMachine\My | Where-Object {
        ($_.NotAfter -gt (Get-Date)) -and
        ($_.Subject -notlike '*Microsoft*') -and
        ($_.Subject -notlike '*Windows*') -and
        ($_.Subject -notlike '*DO_NOT_TRUST*')
    }
    
    $certificateData = foreach ($cert in $certificates) {
        @{
            Subject = $cert.Subject
            Issuer = $cert.Issuer
            NotBefore = $cert.NotBefore.ToString('yyyy-MM-dd HH:mm:ss')
            NotAfter = $cert.NotAfter.ToString('yyyy-MM-dd HH:mm:ss')
            DaysRemaining = [math]::Floor(($cert.NotAfter - (Get-Date)).TotalDays)
            Thumbprint = $cert.Thumbprint
            HasPrivateKey = $cert.HasPrivateKey
            Store = 'LocalMachine\My'
        }
    }
    
    $result = @{
        status = "ready"
        message = "Certificate Web Service is operational"
        version = "v1.1.0"
        generated = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        server_name = $env:COMPUTERNAME
        certificate_count = $certificateData.Count
        certificates = $certificateData
        total_count = $certificateData.Count
        filters_applied = @("exclude_microsoft_certs", "exclude_root_certs", "active_certificates_only")
        endpoints = @{
            certificates = "/certificates.json"
            summary = "/summary.json"
            health = "/health.json"
        }
    }
    
    $jsonPath = "C:\inetpub\CertWebService\certificates.json"
    $result | ConvertTo-Json -Depth 10 | Set-Content -Path $jsonPath -Encoding UTF8
    
    Write-Host "Certificate data updated: $($certificateData.Count) certificates"
    
} catch {
    Write-Error "Failed to update certificate data: $($_.Exception.Message)"
}
'@
                
                $updateScript | Set-Content -Path "$webServicePath\Update-CertificateData.ps1" -Encoding UTF8
                
                # Create initial certificates.json
                $initialData = @{
                    status = "ready"
                    message = "Certificate Web Service is operational"
                    version = "v1.1.0"
                    generated = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
                    server_name = $env:COMPUTERNAME
                    certificates = @()
                    total_count = 0
                    endpoints = @{
                        certificates = "/certificates.json"
                        summary = "/summary.json"
                        health = "/health.json"
                    }
                }
                
                $initialData | ConvertTo-Json -Depth 10 | Set-Content -Path "$webServicePath\certificates.json" -Encoding UTF8
                
                # Configure IIS
                Import-Module WebAdministration -Force
                
                # Remove existing if present
                if (Get-IISAppPool -Name "CertWebService" -ErrorAction SilentlyContinue) {
                    Remove-IISAppPool -Name "CertWebService" -Confirm:$false
                }
                if (Get-IISSite -Name "CertWebService" -ErrorAction SilentlyContinue) {
                    Remove-IISSite -Name "CertWebService" -Confirm:$false
                }
                
                # Create new
                New-IISAppPool -Name "CertWebService" -Force
                Set-ItemProperty -Path "IIS:\AppPools\CertWebService" -Name processModel.identityType -Value ApplicationPoolIdentity
                
                New-IISSite -Name "CertWebService" -PhysicalPath $webServicePath -BindingInformation "*:9080:" -ApplicationPool "CertWebService"
                New-IISSiteBinding -Name "CertWebService" -BindingInformation "*:9443:" -Protocol https
                
                # Start services
                Start-IISAppPool -Name "CertWebService"
                Start-IISSite -Name "CertWebService"
                
                # Configure firewall
                New-NetFirewallRule -DisplayName "Certificate WebService HTTP" -Direction Inbound -Protocol TCP -LocalPort 9080 -Action Allow -ErrorAction SilentlyContinue
                New-NetFirewallRule -DisplayName "Certificate WebService HTTPS" -Direction Inbound -Protocol TCP -LocalPort 9443 -Action Allow -ErrorAction SilentlyContinue
                
                # Generate initial certificate data
                & "$webServicePath\Update-CertificateData.ps1"
                
                return @{
                    Success = $true
                    WebServicePath = $webServicePath
                    ServerName = $env:COMPUTERNAME
                    Message = "WebService erfolgreich installiert"
                }
                
            } -ArgumentList $Server.FQDN
            
            if ($result.Success) {
                Write-ClientLog "✅ WebService erfolgreich installiert!" -Level SUCCESS
                $Server.WebServiceInstalled = $true
                $Server.Status = "Completed"
                $Server.LastChecked = Get-Date
                return $true
            } else {
                Write-ClientLog "❌ Installation fehlgeschlagen: $($result.Message)" -Level ERROR
                return $false
            }
            
        } finally {
            Remove-PSSession $session
        }
        
    } catch {
        Write-ClientLog "❌ Installation fehlgeschlagen: $($_.Exception.Message)" -Level ERROR
        return $false
    }
}

function Test-WebServiceOnServer {
    param($Server)
    
    Write-ClientLog "Teste WebService auf $($Server.FQDN)..." -Level PROGRESS
    
    try {
        $testUrl = "https://$($Server.FQDN):9443/certificates.json"
        Write-ClientLog "Test URL: $testUrl" -Level INFO
        
        $response = Invoke-RestMethod -Uri $testUrl -TimeoutSec 10 -ErrorAction Stop
        
        if ($response.status -eq "ready") {
            Write-ClientLog "✅ WebService Test erfolgreich!" -Level SUCCESS
            Write-ClientLog "  Server: $($response.server_name)" -Level SUCCESS
            Write-ClientLog "  Zertifikate: $($response.total_count)" -Level SUCCESS
            Write-ClientLog "  Version: $($response.version)" -Level SUCCESS
            return $true
        } else {
            Write-ClientLog "❌ WebService antwortet, aber Status ist nicht 'ready'" -Level ERROR
            return $false
        }
        
    } catch {
        Write-ClientLog "❌ WebService Test fehlgeschlagen: $($_.Exception.Message)" -Level ERROR
        
        # Try HTTP as fallback
        try {
            $httpUrl = "http://$($Server.FQDN):9080/certificates.json"
            Write-ClientLog "Versuche HTTP Fallback: $httpUrl" -Level WARN
            
            $response = Invoke-RestMethod -Uri $httpUrl -TimeoutSec 10 -ErrorAction Stop
            if ($response.status -eq "ready") {
                Write-ClientLog "✅ HTTP WebService Test erfolgreich!" -Level SUCCESS
                return $true
            }
        } catch {
            Write-ClientLog "❌ Auch HTTP Test fehlgeschlagen" -Level ERROR
        }
        
        return $false
    }
}

#----------------------------------------------------------[Main Execution]--------------------------------------------------------

try {
    Write-ClientLog "═══════════════════════════════════════════════════════════════════" -Level SUCCESS
    Write-ClientLog "    CLIENT SERVER MANAGEMENT TOOL v1.1.0" -Level SUCCESS  
    Write-ClientLog "═══════════════════════════════════════════════════════════════════" -Level SUCCESS
    Write-ClientLog ""
    
    # Load configuration
    $ConfigFile = Join-Path $ConfigPath "Config-Cert-Surveillance.json"
    if (-not (Test-Path $ConfigFile)) {
        throw "Konfigurationsdatei nicht gefunden: $ConfigFile"
    }
    
    $Config = Get-Content -Path $ConfigFile -Raw | ConvertFrom-Json
    Write-ClientLog "Konfiguration geladen: $ConfigFile" -Level INFO
    
    # Progress file
    $ProgressFile = Join-Path $LogPath "ClientProgress.json"
    
    # Load or create server list
    $servers = Load-ClientProgress -ProgressFile $ProgressFile
    if (-not $servers) {
        Write-ClientLog "Erstelle neue Serverliste aus Excel..." -Level PROGRESS
        $servers = Get-AllServersFromExcel -Config $Config
        Save-ClientProgress -Servers $servers -ProgressFile $ProgressFile
    }
    
    Write-ClientLog "Gefundene Server: $($servers.Count)" -Level INFO
    Write-ClientLog "Abgeschlossen: $(($servers | Where-Object { $_.Status -eq 'Completed' }).Count)" -Level SUCCESS
    Write-ClientLog "Fehlgeschlagen: $(($servers | Where-Object { $_.Status -eq 'Failed' }).Count)" -Level ERROR
    Write-ClientLog "Ausstehend: $(($servers | Where-Object { $_.Status -eq 'Pending' }).Count)" -Level WARN
    Write-ClientLog ""
    
    # Main processing loop
    $currentIndex = 0
    $pendingServers = $servers | Where-Object { $_.Status -eq "Pending" }
    
    if ($pendingServers.Count -eq 0) {
        Write-ClientLog "🎉 Alle Server wurden bereits bearbeitet!" -Level SUCCESS
        Write-ClientLog "Abgeschlossen: $(($servers | Where-Object { $_.Status -eq 'Completed' }).Count)" -Level SUCCESS
        Write-ClientLog "Fehlgeschlagen: $(($servers | Where-Object { $_.Status -eq 'Failed' }).Count)" -Level ERROR
        return
    }
    
    foreach ($server in $pendingServers) {
        $currentIndex++
        
        Write-ClientLog "Bearbeite Server $currentIndex von $($pendingServers.Count): $($server.ServerName)" -Level PROGRESS
        
        $readinessStatus = $null
        $continue = $true
        
        while ($continue) {
            Show-ServerMenu -Server $server -ReadinessStatus $readinessStatus
            
            $action = Read-Host "Wählen Sie eine Aktion"
            
            switch ($action.ToLower()) {
                "1" {
                    $readinessStatus = Test-ServerReadiness -Server $server
                    Write-ClientLog "System-Check abgeschlossen" -Level INFO
                    Read-Host "Drücken Sie Enter um fortzufahren"
                }
                "2" {
                    if (Install-WebServiceOnServer -Server $server) {
                        Write-ClientLog "✅ WebService Installation erfolgreich!" -Level SUCCESS
                    } else {
                        $server.Status = "Failed"
                        Write-ClientLog "❌ WebService Installation fehlgeschlagen" -Level ERROR
                    }
                    Save-ClientProgress -Servers $servers -ProgressFile $ProgressFile
                    Read-Host "Drücken Sie Enter um fortzufahren"
                }
                "3" {
                    if (Test-WebServiceOnServer -Server $server) {
                        Write-ClientLog "✅ WebService funktioniert korrekt!" -Level SUCCESS
                    } else {
                        Write-ClientLog "❌ WebService Test fehlgeschlagen" -Level ERROR
                    }
                    Read-Host "Drücken Sie Enter um fortzufahren"
                }
                "4" {
                    Write-Host "Manuelle Befehle für $($server.FQDN):" -ForegroundColor Yellow
                    Write-Host "  Enter-PSSession -ComputerName $($server.FQDN)" -ForegroundColor Cyan
                    Write-Host "  Invoke-Command -ComputerName $($server.FQDN) -ScriptBlock { Get-Service }" -ForegroundColor Cyan
                    Read-Host "Drücken Sie Enter um fortzufahren"
                }
                "5" {
                    $server.Status = "Completed"
                    $server.LastChecked = Get-Date
                    Save-ClientProgress -Servers $servers -ProgressFile $ProgressFile
                    Write-ClientLog "✅ Server als abgeschlossen markiert" -Level SUCCESS
                    $continue = $false
                }
                "6" {
                    $server.Status = "Failed"
                    $server.Notes = "Manuell übersprungen"
                    Save-ClientProgress -Servers $servers -ProgressFile $ProgressFile
                    Write-ClientLog "⚠️ Server übersprungen" -Level WARN
                    $continue = $false
                }
                "7" {
                    $notes = Read-Host "Notizen für $($server.ServerName)"
                    $server.Notes = $notes
                    Save-ClientProgress -Servers $servers -ProgressFile $ProgressFile
                    Write-ClientLog "📝 Notizen gespeichert" -Level INFO
                }
                "n" {
                    $continue = $false
                }
                "q" {
                    Write-ClientLog "Beende Client Management Tool..." -Level WARN
                    return
                }
                default {
                    Write-ClientLog "Ungültige Auswahl" -Level WARN
                }
            }
        }
    }
    
    Write-ClientLog "🎉 Alle ausstehenden Server wurden bearbeitet!" -Level SUCCESS
    
} catch {
    Write-ClientLog "❌ Fehler im Client Management Tool: $($_.Exception.Message)" -Level ERROR
    throw
    
} finally {
    if ($servers) {
        Save-ClientProgress -Servers $servers -ProgressFile $ProgressFile
    }
    Write-ClientLog "=== Client Management Tool beendet ===" -Level INFO
}

# --- End of script --- v1.1.0 ; Regelwerk: v9.3.1 ---
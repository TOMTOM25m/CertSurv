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
        try {
            $testResult = Test-WSMan -ComputerName $Server.FQDN -ErrorAction Stop
            $readinessStatus.WinRMAvailable = $true
            Write-ClientLog "  ✅ WinRM verfügbar" -Level SUCCESS
        } catch {
            $readinessStatus.Recommendations += "WinRM muss aktiviert werden (Enable-PSRemoting)"
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
    Write-Host "  [2] WebService manuell installieren" -ForegroundColor Green
    Write-Host "  [3] WebService testen" -ForegroundColor Green
    Write-Host "  [4] Manuelle Verbindung herstellen" -ForegroundColor Yellow
    Write-Host "  [5] Server als abgeschlossen markieren" -ForegroundColor Cyan
    Write-Host "  [6] Server überspringen" -ForegroundColor Yellow
    Write-Host "  [7] Notizen hinzufügen" -ForegroundColor White
    Write-Host "  [n] Nächster Server" -ForegroundColor Cyan
    Write-Host "  [q] Beenden" -ForegroundColor Red
    Write-Host ""
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
                    Write-ClientLog "Manuelle Installation erforderlich:" -Level WARN
                    Write-Host "1. Verbinden Sie sich mit dem Server: Enter-PSSession -ComputerName $($server.FQDN)" -ForegroundColor Yellow
                    Write-Host "2. Führen Sie Deploy-TestServer.ps1 aus oder installieren Sie IIS manuell" -ForegroundColor Yellow
                    Write-Host "3. Konfigurieren Sie WebService auf Ports 9080/9443" -ForegroundColor Yellow
                    $confirm = Read-Host "Wurde die Installation durchgeführt? (j/n)"
                    if ($confirm -eq "j") {
                        $server.WebServiceInstalled = $true
                        Write-ClientLog "✅ WebService als installiert markiert" -Level SUCCESS
                    }
                    Save-ClientProgress -Servers $servers -ProgressFile $ProgressFile
                    Read-Host "Drücken Sie Enter um fortzufahren"
                }
                "3" {
                    if (Test-WebServiceOnServer -Server $server) {
                        Write-ClientLog "✅ WebService funktioniert korrekt!" -Level SUCCESS
                        $server.WebServiceInstalled = $true
                    } else {
                        Write-ClientLog "❌ WebService Test fehlgeschlagen" -Level ERROR
                    }
                    Read-Host "Drücken Sie Enter um fortzufahren"
                }
                "4" {
                    Write-Host "Manuelle Verbindung zum Server:" -ForegroundColor Yellow
                    Write-Host "  Enter-PSSession -ComputerName $($server.FQDN)" -ForegroundColor Cyan
                    Write-Host "  # oder" -ForegroundColor Gray
                    Write-Host "  mstsc /v:$($server.FQDN)" -ForegroundColor Cyan
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
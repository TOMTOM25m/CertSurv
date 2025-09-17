#requires -Version 5.1

<#
.SYNOPSIS
    Manual WebService Deployment for Test Server v1.1.0
.DESCRIPTION
    Manuelles Deployment-Skript für die Einrichtung eines Test-Servers mit IIS WebService.
    Dieses Skript wird von \\itscmgmt03.srv.meduniwien.ac.at\iso\CertDeployment aufgerufen.
.NOTES
    Author: Flecki (Tom) Garnreiter
    Version: v1.1.0
    Regelwerk: v9.3.1
    Deployment Source: \\itscmgmt03.srv.meduniwien.ac.at\iso\CertDeployment
    Usage: Remote ausführbar für einzelne Test-Server
#>

#----------------------------------------------------------[Initialisations]--------------------------------------------------------
param(
    [Parameter(Mandatory = $false)]
    [string]$TargetServer,
    
    [Parameter(Mandatory = $false)]
    [string]$DeploymentSource = "\\itscmgmt03.srv.meduniwien.ac.at\iso\CertDeployment",
    
    [Parameter(Mandatory = $false)]
    [switch]$TestMode = $false,
    
    [Parameter(Mandatory = $false)]
    [switch]$ForceReinstall = $false
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Script metadata
$ScriptVersion = "v1.1.0"
$RulebookVersion = "v9.3.1"

#----------------------------------------------------------[Functions]--------------------------------------------------------

function Write-DeployLog {
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
        default { "White" }
    }
    
    Write-Host $logEntry -ForegroundColor $color
}

function Test-AdminRights {
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-ServerFromList {
    param([string]$PreferredServer)
    
    Write-DeployLog "Verfügbare Test-Server aus Serverliste:"
    
    # Beispiel-Server aus der typischen MedUni-Umgebung
    $testServers = @(
        @{ Name = "EX01"; FQDN = "EX01.srv.meduniwien.ac.at"; Type = "Exchange" },
        @{ Name = "FS01"; FQDN = "FS01.srv.meduniwien.ac.at"; Type = "FileServer" },
        @{ Name = "WEB01"; FQDN = "WEB01.srv.meduniwien.ac.at"; Type = "WebServer" },
        @{ Name = "APP01"; FQDN = "APP01.srv.meduniwien.ac.at"; Type = "AppServer" },
        @{ Name = "TEST01"; FQDN = "TEST01.srv.meduniwien.ac.at"; Type = "TestServer" }
    )
    
    for ($i = 0; $i -lt $testServers.Count; $i++) {
        $server = $testServers[$i]
        Write-Host "  [$($i+1)] $($server.Name) - $($server.FQDN) ($($server.Type))" -ForegroundColor Cyan
    }
    
    if ($PreferredServer) {
        $selected = $testServers | Where-Object { $_.Name -eq $PreferredServer -or $_.FQDN -eq $PreferredServer }
        if ($selected) {
            Write-DeployLog "Vorausgewählter Server: $($selected.Name)" -Level SUCCESS
            return $selected
        }
    }
    
    Write-Host ""
    $choice = Read-Host "Wählen Sie einen Test-Server (1-$($testServers.Count)) oder geben Sie einen benutzerdefinierten FQDN ein"
    
    if ($choice -match '^\d+$' -and [int]$choice -ge 1 -and [int]$choice -le $testServers.Count) {
        return $testServers[[int]$choice - 1]
    } else {
        # Custom server
        return @{ 
            Name = $choice.Split('.')[0]
            FQDN = $choice
            Type = "Custom" 
        }
    }
}

function Test-ServerConnectivity {
    param($Server)
    
    Write-DeployLog "Teste Verbindung zu $($Server.FQDN)..."
    
    # Test basic connectivity
    if (-not (Test-NetConnection -ComputerName $Server.FQDN -Port 135 -InformationLevel Quiet)) {
        throw "Server $($Server.FQDN) ist nicht erreichbar (Port 135 WMI)"
    }
    
    # Test WinRM
    if (-not (Test-WSMan -ComputerName $Server.FQDN -ErrorAction SilentlyContinue)) {
        Write-DeployLog "WinRM nicht verfügbar, versuche WinRM zu aktivieren..." -Level WARN
        # Attempt to enable WinRM
        try {
            Invoke-Command -ComputerName $Server.FQDN -ScriptBlock { Enable-PSRemoting -Force } -ErrorAction Stop
        } catch {
            throw "WinRM konnte nicht auf $($Server.FQDN) aktiviert werden: $($_.Exception.Message)"
        }
    }
    
    Write-DeployLog "✅ Server $($Server.FQDN) ist erreichbar und bereit" -Level SUCCESS
    return $true
}

function Deploy-WebServiceToServer {
    param($Server, $DeploymentSource)
    
    Write-DeployLog "Starte WebService Deployment auf $($Server.FQDN)..."
    
    try {
        # Create remote session
        $session = New-PSSession -ComputerName $Server.FQDN
        
        # Copy deployment files
        $localTempPath = Join-Path $env:TEMP "CertWebService-Deploy"
        $remoteTempPath = "C:\Temp\CertWebService-Deploy"
        
        Write-DeployLog "Kopiere Deployment-Dateien von $DeploymentSource..."
        
        # Create local temp directory and copy from network share
        if (Test-Path $localTempPath) { Remove-Item $localTempPath -Recurse -Force }
        New-Item -Path $localTempPath -ItemType Directory -Force | Out-Null
        
        # Copy deployment package from network share
        $deploymentPackage = Join-Path $DeploymentSource "CertWebService-Package.zip"
        if (Test-Path $deploymentPackage) {
            Copy-Item $deploymentPackage $localTempPath -Force
        } else {
            Write-DeployLog "Erstelle Deployment-Paket..." -Level WARN
            # Create deployment package on the fly
            $packagePath = New-DeploymentPackage -OutputPath $localTempPath
        }
        
        # Copy to remote server
        Copy-Item $localTempPath -Destination $remoteTempPath -ToSession $session -Recurse -Force
        
        # Execute deployment on remote server
        Write-DeployLog "Führe Installation auf $($Server.FQDN) aus..."
        
        $deploymentResult = Invoke-Command -Session $session -ScriptBlock {
            param($RemotePath, $ServerInfo)
            
            # Extract package if it's a zip
            $zipFile = Get-ChildItem "$RemotePath\*.zip" | Select-Object -First 1
            if ($zipFile) {
                Expand-Archive -Path $zipFile.FullName -DestinationPath $RemotePath -Force
            }
            
            # Install IIS if not present
            $iisFeature = Get-WindowsFeature -Name IIS-WebServer
            if ($iisFeature.InstallState -ne "Installed") {
                Write-Output "Installing IIS..."
                Install-WindowsFeature -Name IIS-WebServer, IIS-WebServerRole, IIS-CommonHttpFeatures, IIS-HttpFeatures, IIS-NetFxExtensibility45, IIS-ASPNET45 -IncludeManagementTools
            }
            
            # Setup WebService directory
            $webServicePath = "C:\inetpub\CertWebService"
            if (Test-Path $webServicePath) {
                Remove-Item $webServicePath -Recurse -Force
            }
            New-Item -Path $webServicePath -ItemType Directory -Force | Out-Null
            
            # Copy WebService files
            $sourceFiles = Get-ChildItem $RemotePath -Recurse | Where-Object { $_.Extension -in @('.ps1', '.psm1', '.json', '.html', '.css') }
            foreach ($file in $sourceFiles) {
                $destPath = Join-Path $webServicePath $file.Name
                Copy-Item $file.FullName $destPath -Force
            }
            
            # Create IIS Application Pool
            Import-Module WebAdministration -Force
            
            if (Get-IISAppPool -Name "CertWebService" -ErrorAction SilentlyContinue) {
                Remove-IISAppPool -Name "CertWebService" -Confirm:$false
            }
            
            New-IISAppPool -Name "CertWebService" -Force
            Set-ItemProperty -Path "IIS:\AppPools\CertWebService" -Name processModel.identityType -Value ApplicationPoolIdentity
            Set-ItemProperty -Path "IIS:\AppPools\CertWebService" -Name recycling.periodicRestart.time -Value "00:00:00"
            
            # Create IIS Website
            if (Get-IISSite -Name "CertWebService" -ErrorAction SilentlyContinue) {
                Remove-IISSite -Name "CertWebService" -Confirm:$false
            }
            
            New-IISSite -Name "CertWebService" -PhysicalPath $webServicePath -BindingInformation "*:9080:" -ApplicationPool "CertWebService"
            
            # Add HTTPS binding (9443)
            New-IISSiteBinding -Name "CertWebService" -BindingInformation "*:9443:" -Protocol https
            
            # Start Application Pool and Website
            Start-IISAppPool -Name "CertWebService"
            Start-IISSite -Name "CertWebService"
            
            # Configure firewall
            New-NetFirewallRule -DisplayName "Certificate WebService HTTP" -Direction Inbound -Protocol TCP -LocalPort 9080 -Action Allow -ErrorAction SilentlyContinue
            New-NetFirewallRule -DisplayName "Certificate WebService HTTPS" -Direction Inbound -Protocol TCP -LocalPort 9443 -Action Allow -ErrorAction SilentlyContinue
            
            # Generate initial certificate data
            $scriptPath = Join-Path $webServicePath "Update-CertificateData.ps1"
            if (Test-Path $scriptPath) {
                & $scriptPath
            }
            
            return @{
                Success = $true
                WebServicePath = $webServicePath
                ServerName = $env:COMPUTERNAME
                Ports = @(9080, 9443)
                Message = "WebService erfolgreich installiert"
            }
            
        } -ArgumentList $remoteTempPath, $Server
        
        if ($deploymentResult.Success) {
            Write-DeployLog "✅ WebService erfolgreich auf $($Server.FQDN) installiert!" -Level SUCCESS
            Write-DeployLog "HTTP-Endpoint: http://$($Server.FQDN):9080/certificates.json" -Level SUCCESS
            Write-DeployLog "HTTPS-Endpoint: https://$($Server.FQDN):9443/certificates.json" -Level SUCCESS
        } else {
            throw "Deployment fehlgeschlagen: $($deploymentResult.Message)"
        }
        
        # Test the deployment
        Write-DeployLog "Teste WebService Endpoint..."
        Start-Sleep -Seconds 5
        
        try {
            $testUrl = "http://$($Server.FQDN):9080/certificates.json"
            $response = Invoke-RestMethod -Uri $testUrl -TimeoutSec 10
            if ($response.status -eq "ready") {
                Write-DeployLog "✅ WebService Test erfolgreich - $($response.total_count) Zertifikate verfügbar" -Level SUCCESS
            }
        } catch {
            Write-DeployLog "⚠️ WebService Test fehlgeschlagen, aber Installation wurde abgeschlossen" -Level WARN
        }
        
        return $deploymentResult
        
    } finally {
        if ($session) { Remove-PSSession $session }
        if (Test-Path $localTempPath) { Remove-Item $localTempPath -Recurse -Force }
    }
}

function New-DeploymentPackage {
    param([string]$OutputPath)
    
    Write-DeployLog "Erstelle Deployment-Paket..."
    
    # Create basic WebService files
    $webServiceDir = Join-Path $OutputPath "WebService"
    New-Item -Path $webServiceDir -ItemType Directory -Force | Out-Null
    
    # Create Update-CertificateData.ps1
    $updateScript = @'
#requires -Version 5.1

# Update Certificate Data Script for IIS WebService
Set-StrictMode -Version Latest

try {
    # Get all certificates from local machine store
    $certificates = Get-ChildItem Cert:\LocalMachine\My | Where-Object {
        ($_.NotAfter -gt (Get-Date)) -and
        ($_.Subject -notlike '*Microsoft*') -and
        ($_.Subject -notlike '*Windows*') -and
        ($_.Subject -notlike '*DO_NOT_TRUST*')
    }
    
    # Convert to structured data
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
    
    # Save to web directory
    $jsonPath = "C:\inetpub\CertWebService\certificates.json"
    $result | ConvertTo-Json -Depth 10 | Set-Content -Path $jsonPath -Encoding UTF8
    
    Write-Host "Certificate data updated: $($certificateData.Count) certificates"
    
} catch {
    Write-Error "Failed to update certificate data: $($_.Exception.Message)"
}
'@
    
    $updateScript | Set-Content -Path (Join-Path $webServiceDir "Update-CertificateData.ps1") -Encoding UTF8
    
    # Create default certificates.json
    $defaultJson = @{
        status = "ready"
        message = "Certificate Web Service is operational"
        version = "v1.1.0"
        generated = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        certificates = @()
        total_count = 0
        endpoints = @{
            certificates = "/certificates.json"
            summary = "/summary.json"
            health = "/health.json"
        }
    }
    
    $defaultJson | ConvertTo-Json -Depth 10 | Set-Content -Path (Join-Path $webServiceDir "certificates.json") -Encoding UTF8
    
    Write-DeployLog "✅ Deployment-Paket erstellt in $webServiceDir" -Level SUCCESS
    return $webServiceDir
}

#----------------------------------------------------------[Main Execution]--------------------------------------------------------

try {
    Write-DeployLog "=== Manual WebService Deployment v$ScriptVersion ===" -Level SUCCESS
    Write-DeployLog "Deployment Source: $DeploymentSource"
    
    # Check admin rights
    if (-not (Test-AdminRights)) {
        throw "Administrator-Rechte erforderlich für Remote-Deployment"
    }
    
    # Check deployment source
    if (-not (Test-Path $DeploymentSource)) {
        Write-DeployLog "⚠️ Deployment Source nicht gefunden: $DeploymentSource" -Level WARN
        Write-DeployLog "Deployment wird lokal erstellt..." -Level WARN
    }
    
    # Select target server
    $server = Get-ServerFromList -PreferredServer $TargetServer
    Write-DeployLog "Ziel-Server: $($server.Name) - $($server.FQDN)"
    
    if ($TestMode) {
        Write-DeployLog "🧪 TEST-MODUS: Nur Verbindungstest wird durchgeführt" -Level WARN
        Test-ServerConnectivity -Server $server
        Write-DeployLog "✅ Test abgeschlossen - Server ist bereit für Deployment" -Level SUCCESS
        return
    }
    
    # Confirm deployment
    Write-Host ""
    Write-Host "DEPLOYMENT BESTÄTIGUNG:" -ForegroundColor Yellow
    Write-Host "  Server: $($server.FQDN)" -ForegroundColor Cyan
    Write-Host "  Ports: 9080 (HTTP), 9443 (HTTPS)" -ForegroundColor Cyan
    Write-Host "  IIS Installation: Wird automatisch eingerichtet" -ForegroundColor Cyan
    Write-Host ""
    
    $confirm = Read-Host "Deployment fortsetzen? (j/n)"
    if ($confirm -ne 'j' -and $confirm -ne 'J' -and $confirm -ne 'y' -and $confirm -ne 'Y') {
        Write-DeployLog "Deployment abgebrochen" -Level WARN
        return
    }
    
    # Test connectivity
    Test-ServerConnectivity -Server $server
    
    # Deploy WebService
    $deployResult = Deploy-WebServiceToServer -Server $server -DeploymentSource $DeploymentSource
    
    Write-DeployLog ""
    Write-DeployLog "🎯 DEPLOYMENT ERFOLGREICH ABGESCHLOSSEN!" -Level SUCCESS
    Write-DeployLog "Server: $($server.FQDN)" -Level SUCCESS
    Write-DeployLog "WebService URLs:" -Level SUCCESS
    Write-DeployLog "  HTTP:  http://$($server.FQDN):9080/certificates.json" -Level SUCCESS
    Write-DeployLog "  HTTPS: https://$($server.FQDN):9443/certificates.json" -Level SUCCESS
    Write-DeployLog ""
    Write-DeployLog "Nächste Schritte:" -Level INFO
    Write-DeployLog "1. Testen Sie den WebService mit Browser oder Invoke-RestMethod" -Level INFO
    Write-DeployLog "2. Führen Sie Cert-Surveillance.ps1 aus um den API-Zugriff zu testen" -Level INFO
    Write-DeployLog "3. Bei Erfolg können weitere Server deployed werden" -Level INFO
    
} catch {
    Write-DeployLog "❌ Deployment fehlgeschlagen: $($_.Exception.Message)" -Level ERROR
    Write-DeployLog "Stack Trace: $($_.ScriptStackTrace)" -Level ERROR
    exit 1
    
} finally {
    Write-DeployLog "=== Deployment Abgeschlossen ===" -Level INFO
}

# --- End of script --- v1.1.0 ; Regelwerk: v9.3.1 ---
'@
    
$htmlContent = @'
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Certificate WebService Deployment</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background-color: #f5f5f5; }
        .container { max-width: 800px; margin: 0 auto; background-color: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        .header { background-color: #111d4e; color: white; padding: 15px; text-align: center; margin: -20px -20px 20px -20px; }
        .status { padding: 10px; margin: 10px 0; border-radius: 5px; }
        .success { background-color: #d4edda; border-left: 4px solid #28a745; }
        .info { background-color: #d1ecf1; border-left: 4px solid #17a2b8; }
        .endpoint { background-color: #f8f9fa; padding: 10px; margin: 5px 0; border-radius: 3px; font-family: monospace; }
        pre { background-color: #f8f9fa; padding: 10px; border-radius: 3px; overflow-x: auto; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🌐 Certificate WebService</h1>
            <p>Manual Deployment Package v1.1.0</p>
        </div>
        
        <div class="status success">
            <h2>✅ Deployment Package Ready</h2>
            <p>Dieses Paket ist bereit für die manuelle Installation auf Test-Servern.</p>
        </div>
        
        <div class="status info">
            <h2>📋 Deployment-Anweisungen</h2>
            <ol>
                <li>Stellen Sie sicher, dass Sie Administrator-Rechte haben</li>
                <li>Führen Sie <code>Deploy-TestServer.ps1</code> aus</li>
                <li>Wählen Sie einen Server aus der Liste oder geben Sie einen benutzerdefinierten FQDN ein</li>
                <li>Bestätigen Sie das Deployment</li>
                <li>Testen Sie die WebService-Endpoints</li>
            </ol>
        </div>
        
        <h3>🔗 WebService Endpoints</h3>
        <div class="endpoint">
            <strong>HTTP:</strong> http://[server]:9080/certificates.json
        </div>
        <div class="endpoint">
            <strong>HTTPS:</strong> https://[server]:9443/certificates.json
        </div>
        
        <h3>🧪 Test Commands</h3>
        <pre>
# PowerShell Test
Invoke-RestMethod -Uri "http://testserver.srv.meduniwien.ac.at:9080/certificates.json"

# Browser Test  
http://testserver.srv.meduniwien.ac.at:9080/certificates.json
        </pre>
        
        <div class="status info">
            <h2>📁 Network Share Location</h2>
            <p><strong>Deployment Source:</strong> <code>\\itscmgmt03.srv.meduniwien.ac.at\iso\CertDeployment</code></p>
            <p>Dieses Paket sollte im obigen Netzwerkfreigabe-Verzeichnis abgelegt werden.</p>
        </div>
    </div>
</body>
</html>
'@